import SwiftData
import SwiftUI

@main
struct VimarshaApp: App {
    /// The app-lifetime `ModelContainer`. MUST be retained for the whole process: a
    /// container's own `mainContext` holds only a WEAK reference back to it, so if the
    /// container deallocates, the next `context.insert`/`save` dereferences a nil weak
    /// container and traps inside SwiftData. Created once (App structs are re-instantiated
    /// by SwiftUI; a `static` keeps a single container alive regardless).
    static let sharedContainer: ModelContainer? = try? ModelContainer(
        for: Book.self, Chapter.self, Memo.self, ChatThread.self, ChatLine.self
    )

    /// The persisted library (V12). A store-opening failure (corrupt/locked database)
    /// degrades to the seed shelf with no import affordance rather than crashing —
    /// honest states on the one surface.
    @State private var store: LibraryStore?
    /// The ONE app-lifetime audio device owner (V16; apple/CLAUDE.md §Seams).
    /// Player controllers borrow it and pause it — nothing else may create one.
    @State private var audioEngine = AVFoundationAudioEngine()
    /// The ONE app-lifetime mic owner (V28) — the record half of the same seam.
    @State private var recorder = AVAudioRecorderEngine()
    /// The single-live-surface router (spec 2026-06-28) — app-lifetime so the active surface
    /// and book session survive `App` re-instantiation, like the engines above.
    @State private var coordinator = SurfaceCoordinator()

    init() {
        if let container = Self.sharedContainer {
            _store = State(initialValue: LibraryStore(context: container.mainContext))
        }
    }

    @Environment(\.scenePhase) private var scenePhase
    /// Live status-bar / notch height. The full-bleed paging surface propagates a ZERO
    /// safe-area inset into the pages, so the top glass controls (gallery toggle, add book)
    /// would sit under the clock. We read the real inset from the key window — but ONLY after
    /// the window exists: at first `body` evaluation on a real device there is no key window
    /// yet, so a direct read returns 0 and the buttons render on the status bar. So it's held
    /// in @State and refreshed on appear / when the scene becomes active.
    @State private var topInset: CGFloat = 0
    @State private var bottomInset: CGFloat = 0
    /// True while a surface (reading / a morphed plane) covers the library — the horizontal
    /// paging scroll locks so a swipe on the reading screen can't page to Scientific Literature
    /// and the live paging scroll can't feed the keyboard-reflow loop.
    @State private var surfaceCoveringLibrary = false
    /// Holds the flat Discuss backdrop up until the sheet has FULLY dismissed (not merely until
    /// `activeSurface` leaves `.discuss`). Returning to `.reading` immediately would remount the
    /// library + reading surface WHILE the sheet/keyboard are still animating away, so the rebuild
    /// measures a transient container size — the reading content mis-scales and the bottom transport
    /// lays out off-screen. Swapping back only on the sheet's `onDisappear` rebuilds in stable
    /// geometry, exactly like a normal library→reading open (which never shows the bug).
    @State private var discussBackdrop = false

    #if os(iOS)
    private func keyWindowInsets() -> UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets ?? .zero
    }
    #endif

    private func refreshSafeAreaInsets() {
        #if os(iOS)
        let insets = keyWindowInsets()
        // Only adopt a REAL reading. While the Discuss sheet + keyboard are mid-dismiss (and the
        // library rebuilds behind them), the main window isn't key, so the read is a transient 0
        // — adopting it rode VIMARSHA up under the status bar and dropped the reading transport
        // under the home indicator. Keep the last good inset instead.
        if insets.top > 0 { topInset = insets.top }
        if insets.bottom > 0 { bottomInset = insets.bottom }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if DiscussLoopRepro.isActive {
                DiscussLoopReproView()
                    .environment(\.topSafeInset, topInset)
                    .environment(\.bottomSafeInset, bottomInset)
                    .onAppear { refreshSafeAreaInsets() }
            } else {
                mainScene
            }
            #else
            mainScene
            #endif
        }
        #if os(macOS)
        .defaultSize(width: 480, height: 920)
        #endif
    }

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    private var mainScene: some View {
        Group {
            if discussBackdrop {
                // TRUE single live surface: while Discuss is up, NOTHING live is rendered behind
                // the sheet — just a flat canvas. The paging library would otherwise re-layout
                // under the keyboard and spin a non-settling text-resolution loop on device
                // (0x8BADF00D). DiscussPanelView over a plain canvas is device-proven stable.
                // The book session lives in the coordinator, so closing Discuss restores reading.
                // Driven by `discussBackdrop` (not `activeSurface` directly) so it stays up until
                // the sheet has fully dismissed — the live surface then rebuilds in stable geometry.
                Palette.canvas.ignoresSafeArea()
            } else {
                pagingLibrary
            }
        }
        // Raise the flat backdrop the instant Discuss opens; it's lowered again only by the
        // sheet's `onDisappear` (full dismissal), so the reading surface never rebuilds mid-animation.
        .onChange(of: coordinator.activeSurface) { _, surface in
            if surface == .discuss { discussBackdrop = true }
        }
        // One source of truth for the safe-area insets, read by every surface's edge controls.
        .environment(\.topSafeInset, topInset)
        .environment(\.bottomSafeInset, bottomInset)
        // No keyboard-focus ring lingering on the round glass buttons after a click.
        .focusEffectDisabled()
        // Share-to-Vimarsha: an EPUB opened from Files / the share sheet arrives here.
        .onOpenURL { url in
            Task { await store?.addBook(from: url) }
        }
        // Ship one book: import the bundled Stolen Focus once, on first launch.
        .task { await store?.seedBundledBookIfNeeded() }
        // Resolve the real top inset once the window exists, and refresh on reactivation.
        .onAppear { refreshSafeAreaInsets() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshSafeAreaInsets() }
        }
        // Discuss is presented in a `.sheet` (single-live-surface): the reading surface is
        // UNMOUNTED behind it (the original cross-surface render loop, already fixed), and the
        // sheet's own presentation context has battle-tested keyboard handling. An in-canvas
        // plane under SwiftUI's native keyboard avoidance never converged on device — every
        // attempt just relocated a non-settling layout loop (GlassEffectShapeSet, then Text
        // resolution; 0x8BADF00D crash reports 2026-06-29). The Prime-Directive in-canvas morph
        // is deferred to a follow-up once that avoidance behaviour is understood.
        .sheet(isPresented: discussPresented) { discussSheet }
    }

    /// The two swipeable library sections (My Books ⇄ Scientific Literature). A horizontal paging
    /// scroll; each page fills the container. Rendered only when Discuss is NOT up.
    private var pagingLibrary: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                LibraryStackView(
                    store: store, audioEngine: audioEngine, recorder: recorder,
                    surfaceCovering: $surfaceCoveringLibrary, coordinator: coordinator
                )
                .containerRelativeFrame([.horizontal, .vertical])
                ScientificLiteratureView(covered: surfaceCoveringLibrary)
                    .containerRelativeFrame([.horizontal, .vertical])
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollDisabled(surfaceCoveringLibrary)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var discussPresented: Binding<Bool> {
        Binding(
            get: { coordinator.activeSurface == .discuss },
            // Idempotent dismissal: this setter AND the panel's chevron-down `onClose` both
            // fire for one dismissal, so route through `closeDiscuss()` (a no-op unless still
            // in .discuss) — otherwise the surface recedes two levels to the library and the
            // session is released. See `SurfaceCoordinator.closeDiscuss`.
            set: { presented in if !presented { coordinator.closeDiscuss() } }
        )
    }

    @ViewBuilder
    private var discussSheet: some View {
        if let session = coordinator.session, let store {
            DiscussPanelView(
                chat: session.chatStore,
                voice: session.voiceInput,
                speaker: session.replySpeaker,
                archive: store.discussArchive(for: session),
                reduceTransparency: reduceTransparency,
                onClose: { coordinator.closeDiscuss() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            // Solid background: nothing live is behind it (reading unmounted, library glass gated),
            // so the panel reads as the foreground with no refraction of moving content.
            .presentationBackground(Palette.canvas)
            .onDisappear {
                session.voiceInput?.cancelHold()
                session.replySpeaker.stop()
                // Only now — sheet + keyboard fully gone — swap the flat backdrop for the live
                // library/reading surface, so it rebuilds in stable geometry (controls on-screen,
                // correct scaling) instead of mid-dismiss.
                discussBackdrop = false
            }
        }
    }
}
