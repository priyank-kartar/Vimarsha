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

    private func currentTopSafeAreaInset() -> CGFloat {
        #if os(iOS)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 0
        #else
        0
        #endif
    }

    var body: some Scene {
        WindowGroup {
            // Two swipeable library sections: My Books ⇄ Scientific Literature. A horizontal
            // paging scroll (each page fills the container) — the signature My Books surface is
            // untouched, the papers section sits a swipe to its right.
            // The pages draw edge-to-edge (full-bleed canvas), so SwiftUI propagates a zero top
            // inset into them; the real status-bar / notch height comes from the key window so
            // the library's top glass controls can clear it.
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    LibraryStackView(
                        store: store, audioEngine: audioEngine, recorder: recorder,
                        topSafeInset: topInset
                    )
                    .containerRelativeFrame([.horizontal, .vertical])
                    ScientificLiteratureView()
                        .containerRelativeFrame([.horizontal, .vertical])
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            // No keyboard-focus ring lingering on the round glass buttons after a click
            // (every icon button) — this is a tap/scroll surface, not a focus-driven one.
            .focusEffectDisabled()
            // Share-to-Vimarsha: an EPUB opened from Files / the share sheet ("Copy to
            // Vimarsha") arrives here → import it onto the shelf.
            .onOpenURL { url in
                Task { await store?.addBook(from: url) }
            }
            // Ship one book: import the bundled Stolen Focus once, on first launch.
            .task { await store?.seedBundledBookIfNeeded() }
            // Resolve the real top inset once the window exists (see `topInset`), and refresh
            // it whenever the scene reactivates (rotation / returning from background).
            .onAppear { topInset = currentTopSafeAreaInset() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { topInset = currentTopSafeAreaInset() }
            }
        }
        #if os(macOS)
        .defaultSize(width: 480, height: 920)
        #endif
    }
}
