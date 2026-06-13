import SwiftUI
import UniformTypeIdentifiers

/// The library surface: editorial header scrolling into the depth-stacked book tower
/// (apple/CLAUDE.md §UI map state 1; motion grammar #1).
///
/// Overlap comes from negative stack spacing; document order puts lower (front) cards on
/// top, matching the reference staircase. Transforms run in `visualEffect` — render-time
/// only, no layout thrash — as a pure function of each card's position (`StackTransform`).
struct LibraryStackView: View {
    /// The persisted library (V12). `nil` (previews/snapshots) renders the seed shelf
    /// with no import affordance.
    var store: LibraryStore?
    /// The app-lifetime audio device owner (V16) — handed to each chapter's player.
    /// `nil` (previews/snapshots) opens the reading shell without playback.
    var audioEngine: (any AudioEngine)?
    /// The app-lifetime mic owner (V28) — handed to each open chapter's memo capture.
    /// `nil` (previews/snapshots) hides the mic control.
    var recorder: (any RecorderEngine)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    /// Scroll distance-to-rest (≥ 0; 0 at the top). Drives the settle contrast shift
    /// (motion grammar #7) via `HeaderContrast` — header-only state, so the book tower is
    /// extracted into `BookTower` to keep this scroll tick off the heavy ForEach.
    @State private var distanceToRest: CGFloat = 0

    /// Lensing drag puck (glass moment #2 / motion grammar #6): appears on finger-down,
    /// tracks the drag, refracts the cover beneath; fades out on release.
    @State private var puck: LensingPuck = .hidden

    /// Whether the scroll is settled (V46): launch starts at rest; any scroll phase other
    /// than `.idle` is motion. At rest the control cluster renders its rest-resolved
    /// terminal form (fully split or absorbed) — the `GlassEffectContainer` mid-meld shape
    /// is only ever shown while this is false (the morph is actually in motion).
    @State private var scrollAtRest = true

    /// Which book owns the front slot, and how settled it is (motion grammar #2). Recomputed
    /// from each card's measured midY as the tower scrolls; drives the grow-to-front bump,
    /// the deepening contact shadow, and the focused-book metadata reveal. Reduce Motion (a
    /// flat list with no front slot) leaves this at `.none`.
    @State private var focus: BookFocus = .none

    /// Tap-to-focus override: the index of a cover the user tapped to summon its control
    /// cluster, regardless of where it sits in the tower. The front-slot settle model needs
    /// a tall tower to bring a book onto the slot — a small library (one or two books) sits
    /// above the slot and can never scroll down to it, so scroll-focus alone would never
    /// emerge the cluster. A tap pins full focus here; the next scroll interaction clears it
    /// and hands control back to the scroll-driven settle.
    @State private var tappedIndex: Int?

    /// Each card's viewport LAYOUT top edge, keyed by shelf index — drives the top scrim's
    /// contextual visibility (V27, tuned against layout tops).
    @State private var cardTops: [Int: CGFloat] = [:]

    /// Each card's RENDERED top edge (`CardVisualTop` — the layout top mapped through the
    /// card's visualEffect transforms). The focus affordances anchor against these, because
    /// the seams the user sees are the rendered ones, not the layout ones (V37).
    @State private var cardVisualTops: [Int: CGFloat] = [:]

    /// Whether the metadata reveal actually renders (V42): `ViewThatFits` yields it when the
    /// focused cover's band only fits the cluster (XXXL type), and then the cover's deboss
    /// title must stay printed — it's the focused book's only label. The chosen branch
    /// reports via `FocusMetadataVisibleKey`; defaults to false (deboss stays) until it does.
    @State private var metadataRevealShown = false

    /// The control cluster's rendered frame in GLOBAL coordinates (V45) — measured, not
    /// recomputed, so `@ScaledMetric` sizes, `ViewThatFits` branching and overlay insets
    /// can't drift it. `nil` while the cluster renders nothing (below its visibility floor).
    @State private var clusterGlobalFrame: CGRect?

    /// The scroll viewport's global top edge (V45) — calibrates the cluster's global frame
    /// into the same viewport space the card preferences (`cardVisualTops`) report in.
    @State private var scrollOriginGlobalY: CGFloat = 0

    /// EPUB import (V10). The system document picker is OS-driven chrome (like the
    /// keyboard) — exempt from the morph rule, and the only way the sandbox grants access
    /// to a user-chosen file. The picked EPUB lands in the container and persists via
    /// `LibraryStore.addBook` (V12), joining the shelf live.
    @State private var showsEpubPicker = false

    /// The book whose chapter list plane is risen (V14) — a state of the surface, not a
    /// sheet. Opened from the focused book's Play control (the stand-in trigger until the
    /// audio engine/reading morph lands in V16/V17); closed by the X or the backdrop.
    @State private var chapterBook: Book?

    /// The book whose Voice-notes archive plane is risen (library cluster mic control) —
    /// every memo across the book's chapters, with playback. Nil = closed.
    @State private var memoBook: Book?
    /// Playback for the open Voice-notes archive; created with `memoBook`, stopped + released
    /// when it closes (its own ephemeral engine, the MemoNotes precedent).
    @State private var bookMemoPlayer: BookMemoPlayer?

    /// The book pending a remove-confirmation (nil = no confirm shown).
    @State private var pendingDeleteBook: Book?
    /// The book whose narrator-voice picker is open (nil = closed).
    @State private var voiceBook: Book?
    /// Ephemeral player for voice previews — a DEDICATED engine so previews never disturb the
    /// chapter player's shared device owner.
    @State private var voicePreview: VoicePreviewPlayer?

    /// The book whose Saved-discussions archive plane is risen (library cluster speech-bubble
    /// control) — every saved conversation across the book's chapters. Nil = closed.
    @State private var conversationsBook: Book?
    /// Within the conversations archive, the thread opened read-only (nil = the list).
    @State private var openThreadId: UUID?

    /// The opened chapter (V17): a ready chapter row morphs the hardback OPEN into the
    /// reading surface — a state of this same surface, never a push. Closing back-morphs.
    @State private var reading: ReadingContext?

    /// The opened chapter's player (V18): created at open, paused + released at close —
    /// the shared engine itself lives on in `VimarshaApp`.
    @State private var player: PlayerController?

    /// The opened chapter's hold-to-record memos (V28): created with the player,
    /// cancelled + released at close — the shared recorder lives on in `VimarshaApp`.
    @State private var memoCapture: MemoCapture?

    /// The opened chapter's Notes state (V30): memo playback rides its own ephemeral
    /// engine (the chapter's shared engine keeps its MP3); stopped + released at close.
    @State private var memoNotes: MemoNotes?

    /// The opened chapter's live Discuss conversation (V33): in-memory, created with the
    /// player so the thread survives the panel closing/reopening; released (discarded —
    /// save-on-demand) only when the book closes.
    @State private var chatStore: ChatStore?

    /// The opened chapter's hold-to-talk voice input (V34): shares the app-lifetime
    /// recorder; cancelled + released at close like the memo capture.
    @State private var voiceInput: VoiceInput?

    /// The opened chapter's spoken replies (V35): /speak audio on its own ephemeral
    /// engine (the MemoNotes precedent); stopped + released at close.
    @State private var replySpeaker: ReplySpeaker?

    /// The cover-morph shared-element namespace (tower card ↔ reading cover plate).
    @Namespace private var coverMorph

    /// What the tower renders: the persisted library, or the seed shelf as the
    /// empty-state/demo path (V12).
    private var shelf: [ShelfBook] {
        store?.shelf ?? ShelfBook.seeds
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: reduceMotion ? 24 : -geo.size.height * 0.052) {
                    LibraryHeader(contrast: contrast(in: geo.size))
                        .padding(.top, 64)
                        // Top scroll headroom (mirrors the bottom `0.22·H` at line below): without
                        // it the FIRST book can never settle down onto the front slot (0.72·H) — it
                        // sits jammed under the header in the receded zone, which got obvious once
                        // covers became tall upright boards (ADR-011 aspect 1.5). This gap lets the
                        // first cover scroll into full focus while the header stays pinned at the top.
                        .padding(.bottom, geo.size.height * 0.18)
                    // Coupled scroll+zoom hero settle (motion grammar #5): as the header above
                    // translates off, the whole tower scales toward the viewer as one rigid
                    // group, anchored on the front slot. One scale on the tower as a whole —
                    // the per-card depth-stack parallax rides inside it. Reduce Motion exempt
                    // (the static fallback has no hero zoom).
                    BookTower(
                        shelf: shelf, size: geo.size, reduceMotion: reduceMotion, focus: focus,
                        metadataRevealShown: metadataRevealShown,
                        debossDodge: debossDodge(in: geo.size),
                        morphNamespace: coverMorph, openedBookId: reading?.shelfBook.id,
                        onTapBook: { focusBook(at: $0) },
                        onRequestDelete: { index in
                            // Seed/empty covers have no persisted row — guard by bounds.
                            if let store, index >= 0, index < store.books.count {
                                pendingDeleteBook = store.books[index]
                            }
                        }
                    )
                        .scaleEffect(
                            heroSettle(in: geo.size).scale,
                            anchor: heroAnchor(in: geo.size)
                        )
                }
                .padding(.bottom, geo.size.height * 0.22)
                .frame(width: geo.size.width)
            }
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in
                distanceToRest = max(0, y)
            }
            // Rest-snap (V46): when the scroll settles to idle, the cluster animates from
            // wherever its scrubbable emerge landed to a terminal form; touch-down animates
            // it back toward the raw emerge (then live scroll updates take over directly —
            // scrubbing is the animation, and the whole stack is in motion anyway).
            // Reduce Motion swaps the spring for an instant resolve.
            .onScrollPhaseChange { _, newPhase in
                // A real scroll gesture reclaims focus from a tap-pin (the tower's settle
                // takes back over the moment the user starts browsing again).
                if newPhase == .interacting || newPhase == .decelerating {
                    tappedIndex = nil
                }
                let atRest = newPhase == .idle
                guard atRest != scrollAtRest else { return }
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) {
                    scrollAtRest = atRest
                }
            }
            // The viewport's global origin (V45): the cluster measures itself in .global
            // (the one space an overlay and the scroll content share); subtracting this maps
            // it into the viewport coordinates the card preferences use.
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: {
                scrollOriginGlobalY = $0
            }
            // Scroll-settle detection (motion grammar #2): each card publishes its viewport
            // midY; the nearest to the front slot owns focus. Suppressed under Reduce Motion.
            .onPreferenceChange(CardMidYKey.self) { midYs in
                focus = resolvedFocus(midYs: midYs, viewportHeight: geo.size.height)
            }
            .onPreferenceChange(CardTopYKey.self) { cardTops = $0 }
            .onPreferenceChange(CardVisualTopKey.self) { cardVisualTops = $0 }
            .background(Palette.canvas.ignoresSafeArea())
            // The puck floats in viewport space (it follows the finger, not the content),
            // so the gesture + overlay live on the ScrollView, outside the scrolling tower.
            .simultaneousGesture(lensingDrag(in: geo.size))
            .overlay { LensingPuckView(puck: puck, reduceTransparency: reduceTransparency) }
            .overlay(alignment: .top) { topScrim(in: geo.size) }
            .overlay(alignment: .bottom) { focusAffordances(in: geo.size) }
            // Which `ViewThatFits` branch rendered (V42): only the metadata branch emits
            // true, so a yielded band (cluster-only, XXXL) reads false — and the focused
            // cover keeps its printed title. Sits ABOVE the affordance overlay so the
            // preference actually reaches it.
            .onPreferenceChange(FocusMetadataVisibleKey.self) { metadataRevealShown = $0 }
            .onPreferenceChange(ClusterFrameKey.self) { clusterGlobalFrame = $0 }
            .overlay(alignment: .topTrailing) { addBookButton }
            .overlay { chapterListPlane }
            .overlay { bookMemosPlane }
            .overlay { bookConversationsPlane }
            .overlay { voicePickerPlane }
            .overlay { readingSurface }
            // Destructive confirm for removing a book — a transient system confirmation (like
            // the file importer below), not a navigation surface.
            .confirmationDialog(
                "Remove “\(pendingDeleteBook?.title ?? "")”?",
                isPresented: Binding(
                    get: { pendingDeleteBook != nil },
                    set: { if !$0 { pendingDeleteBook = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingDeleteBook
            ) { book in
                Button("Remove Book", role: .destructive) {
                    store?.deleteBook(book)
                    pendingDeleteBook = nil
                }
                Button("Cancel", role: .cancel) { pendingDeleteBook = nil }
            } message: { _ in
                Text("Removes the book from Vimarsha along with its narration, voice notes, and saved discussions. You can re-import it from the original EPUB.")
            }
            .fileImporter(
                isPresented: $showsEpubPicker,
                allowedContentTypes: [.epub]
            ) { result in
                handlePickedEpub(result)
            }
        }
    }

    // MARK: EPUB import (V10)

    /// A small glass "+" floating at the top-trailing corner — interactive → sky tint
    /// (apple/CLAUDE.md §Liquid Glass rules); Reduce Transparency gets the matte fallback.
    /// The import-error status line rides under it (honest states, no alerts). Absent
    /// without a store (previews) — there'd be nowhere to put the book.
    @ViewBuilder
    private var addBookButton: some View {
        if let store {
            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    store.importError = nil
                    showsEpubPicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Palette.textPrimary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .background {
                    if reduceTransparency {
                        Circle().fill(Palette.surface)
                            .overlay(Circle().strokeBorder(Palette.sky.opacity(0.5), lineWidth: 1))
                    } else {
                        Color.clear.glassEffect(
                            .regular.tint(Palette.sky.opacity(0.26)).interactive(), in: .circle
                        )
                    }
                }
                .accessibilityLabel("Add book")

                if let importError = store.importError {
                    Text(importError)
                        .font(.caption2)
                        .foregroundStyle(Palette.textPrimary.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Palette.surface))
                }
            }
            .padding(.trailing, 20)
            .padding(.top, 8)
        }
    }

    /// Import the picked EPUB through the store (container copy + cover + persisted row);
    /// the shelf re-renders live when `store.books` updates. Failure surfaces as the
    /// status line.
    private func handlePickedEpub(_ result: Result<URL, any Error>) {
        guard case .success(let url) = result else { return }  // cancel: nothing to surface
        Task { await store?.addBook(from: url) }
    }

    // MARK: Focused-book affordances — metadata reveal + glass control cluster

    /// The settled book's title/author (motion grammar #2) with the glass control cluster
    /// (glass moment #5) beneath it: Play/Figures/Voice note/Discuss morph out of the focused
    /// cover and re-absorb on scroll. Both fade with the same eased `promotion`, so they grow
    /// and recede together. Hosting the metadata here (rather than free-floating) addresses the
    /// V06 note that the bare caption grazed the next rising cover. Hidden when nothing is
    /// settled or under Reduce Motion (focus is `.none`).
    @ViewBuilder
    private func focusAffordances(in size: CGSize) -> some View {
        if focus.index >= 0, focus.index < shelf.count {
            // Anchor inside the focused cover's visible bottom — above the next book that
            // overlaps it (V24) — using RENDERED tops (V37): the seams the user sees are the
            // transformed ones, not the layout ones.
            let bottomPadding = FocusAffordancePlacement.bottomPadding(
                nextTopY: cardVisualTops[focus.index + 1],
                viewportHeight: size.height
            )
            // Hard clamp (V37, ui-audit blocker): the affordances may only occupy the focused
            // cover's own visible band. When the band is too short for metadata + cluster
            // (XXXL type, tight stacks), the metadata yields and the cluster alone shows;
            // `.clipped()` is the backstop so nothing ever crosses the seam above.
            let maxHeight = FocusAffordancePlacement.maxHeight(
                focusedTopY: cardVisualTops[focus.index],
                bottomPadding: bottomPadding,
                viewportHeight: size.height
            )
            ViewThatFits(in: .vertical) {
                VStack(spacing: 12) {
                    FocusMetadataView(
                        book: shelf[focus.index],
                        // Saturating ramp (V43): fully opaque by the resting promotion —
                        // `reveal == promotion` left the band (text included) half-faded
                        // at rest, which is what actually failed WCAG over the blue cover.
                        reveal: BookFocus.metadataRevealOpacity(promotion: focus.promotion),
                        reduceTransparency: reduceTransparency
                    )
                    controlCluster
                }
                // Only the rendered branch publishes (V42): metadata present → the deboss
                // fade may engage; yielded (cluster-only) → the printed title stays.
                .preference(key: FocusMetadataVisibleKey.self, value: true)
                controlCluster
            }
            .frame(maxHeight: maxHeight, alignment: .bottom)
            .clipped()
            .padding(.bottom, bottomPadding)
        }
    }

    /// The cluster both renderers share (V46): the raw scrubbable emerge while the scroll is
    /// in motion, the rest-resolved terminal form at rest — one owner so the cluster view
    /// and the deboss dodge (V45) can never disagree about what's on screen.
    private var displayedCluster: ControlCluster {
        ControlCluster.displayed(promotion: focus.promotion, scrollAtRest: scrollAtRest)
    }

    /// The glass control cluster (glass moment #5), shared by both `ViewThatFits` branches —
    /// when the focused cover's visible band can't hold metadata + cluster, the cluster wins
    /// (it's the affordance; the metadata is decorative).
    private var controlCluster: some View {
        ControlClusterView(
            cluster: displayedCluster,
            reduceTransparency: reduceTransparency,
            onActivate: { control in
                // Book-level controls; seeds (no persisted book) have nothing to show.
                guard let book = focusedBook else { return }
                switch control {
                case .play:
                    // Raises the chapter list plane (V14) → pick a chapter → reading surface.
                    withAnimation(chapterPlaneAnimation) { chapterBook = book }
                case .narrator:
                    voicePreview = VoicePreviewPlayer(engine: AVFoundationAudioEngine())
                    withAnimation(chapterPlaneAnimation) { voiceBook = book }
                case .memo:
                    openBookMemos(book)
                case .conversations:
                    openThreadId = nil
                    withAnimation(chapterPlaneAnimation) { conversationsBook = book }
                }
            }
        )
        // Publish the cluster's rendered frame (V45): below the visibility floor the view
        // renders nothing, so the preference vanishes with it and the dodge follows.
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: ClusterFrameKey.self, value: proxy.frame(in: .global))
            }
        }
    }

    /// Where the cluster's glass actually covers the focused cover, in cover-local
    /// coordinates (V45): the deboss mask dodges exactly that band, so controls never render
    /// over glyphs while the printed label (V42) survives above/below them.
    private func debossDodge(in size: CGSize) -> DebossDodge.Band? {
        guard !reduceMotion, focus.index >= 0,
              let clusterFrame = clusterGlobalFrame,
              let coverTop = cardVisualTops[focus.index],
              let layoutTop = cardTops[focus.index]
        else { return nil }
        let cardWidth = CardGeometry.width(forViewportWidth: size.width)
        let midY = layoutTop + cardWidth * CardGeometry.aspect / 2
        return DebossDodge.band(
            clusterTop: clusterFrame.minY - scrollOriginGlobalY,
            clusterBottom: clusterFrame.maxY - scrollOriginGlobalY,
            clusterOpacity: displayedCluster.opacity,
            coverVisualTop: coverTop,
            coverScale: CardVisualTop.scale(
                midY: midY, viewportHeight: size.height, promotion: focus.promotion
            )
        )
    }

    /// The effective focus (motion grammar #2): a tap-pin wins when present (full
    /// promotion, so the cluster fully emerges under the tapped cover wherever it sits);
    /// otherwise the scroll-driven settle. Reduce Motion (flat list, no front slot) stays
    /// `.none`. A pinned index that's fallen out of range (book deleted) is ignored.
    private func resolvedFocus(midYs: [Int: CGFloat], viewportHeight: CGFloat) -> BookFocus {
        guard !reduceMotion else { return .none }
        if let tappedIndex, tappedIndex >= 0, tappedIndex < shelf.count {
            return BookFocus(index: tappedIndex, emphasis: 1)
        }
        return BookFocus.at(midYs: midYs, viewportHeight: viewportHeight)
    }

    /// Tap-to-focus (apple/CLAUDE.md §Accessibility — gesture affordances): pin focus to the
    /// tapped cover so its cluster emerges; tapping the already-focused book is a no-op (its
    /// cluster is already up). Animated so the cluster grows rather than popping.
    private func focusBook(at index: Int) {
        guard index >= 0, index < shelf.count else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) {
            tappedIndex = index
            focus = BookFocus(index: index, emphasis: 1)
        }
    }

    /// The focused book as a persisted row — nil for the seed shelf (nothing to narrate).
    /// `shelf` mirrors `store.books` one-to-one when any real book exists, so the focus
    /// index maps straight across.
    private var focusedBook: Book? {
        guard let store, !store.books.isEmpty,
              focus.index >= 0, focus.index < store.books.count
        else { return nil }
        return store.books[focus.index]
    }

    // MARK: Chapter list plane (V14 — a morphed list state, never a sheet)

    /// Interruptible spring for the plane's rise/settle; Reduce Motion gets the
    /// cross-dissolve (discrete-state-morph fallback rule).
    private var chapterPlaneAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.18) : .spring(response: 0.42, dampingFraction: 0.86)
    }

    /// A dimmed backdrop (tap to close) under the glass-backed chapter list. The plane
    /// rises from the bottom — where the cluster that summoned it lives — and recedes the
    /// same way; under Reduce Motion both become a dissolve.
    @ViewBuilder
    private var chapterListPlane: some View {
        if let book = chapterBook {
            ZStack {
                Palette.ink0.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(chapterPlaneAnimation) { chapterBook = nil } }
                    .accessibilityLabel("Dismiss chapters")
                    .accessibilityAddTraits(.isButton)
                ChapterListView(
                    book: book,
                    reduceTransparency: reduceTransparency,
                    onDownload: { chapter in store?.downloadChapter(chapter) },
                    onOpen: { chapter in openReadingSurface(book: book, chapter: chapter) },
                    onRerender: { chapter in store?.rerenderChapter(chapter) },
                    onClose: { withAnimation(chapterPlaneAnimation) { chapterBook = nil } }
                )
            }
            .transition(
                reduceMotion
                    ? .opacity
                    : .move(edge: .bottom).combined(with: .opacity)
            )
        }
    }

    // MARK: Voice picker plane (D3 — narrator-voice selection, morphed list state)

    @ViewBuilder
    private var voicePickerPlane: some View {
        if let book = voiceBook {
            ZStack {
                Palette.ink0.opacity(0.45).ignoresSafeArea()
                    .onTapGesture { closeVoicePicker() }
                    .accessibilityLabel("Dismiss voice picker").accessibilityAddTraits(.isButton)
                VoicePickerView(
                    currentVoiceId: book.voiceId,
                    reduceTransparency: reduceTransparency,
                    onPreview: { voice in
                        player?.pause()                 // courtesy pause of chapter playback
                        try? voicePreview?.preview(voice)
                    },
                    onSelect: { voice in
                        book.voiceId = voice.id
                        try? store?.saveContext()
                        closeVoicePicker()
                    },
                    onClose: { closeVoicePicker() }
                )
            }
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func closeVoicePicker() {
        voicePreview?.stop()
        voicePreview = nil
        withAnimation(chapterPlaneAnimation) { voiceBook = nil }
    }

    // MARK: Book-level archives (library cluster — morphed list states, never sheets)

    /// Reusable glass plane chrome for the book archives (Voice notes / Saved discussions),
    /// matching `ChapterListView`: a labelled, glass-backed plane that rises within the
    /// surface, scrollable matte content, an `xmark` close. Reduce Transparency → matte.
    @ViewBuilder
    private func archivePlane<Content: View>(
        label: String, title: String, onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            Palette.ink0.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .accessibilityLabel("Dismiss")
                .accessibilityAddTraits(.isButton)
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .tracking(4)
                        .foregroundStyle(Palette.textPrimary.opacity(0.55))
                    Text(title)
                        .font(.system(size: 20, weight: .regular, design: .serif))
                        .tracking(1)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 56)
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .topTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary.opacity(0.7))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .background(Circle().fill(Palette.textPrimary.opacity(0.06)))
                    .padding(.trailing, 14)
                    .accessibilityLabel("Close")
                }
                .padding(.top, 22)
                .padding(.bottom, 14)
                ScrollView {
                    content()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 18)
                }
            }
            .frame(maxWidth: 420)
            .frame(maxHeight: 520)
            .background {
                let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
                if reduceTransparency {
                    shape.fill(Palette.surface)
                } else {
                    Color.clear.glassEffect(.regular.tint(Palette.sky.opacity(0.18)), in: shape)
                }
            }
            .padding(.horizontal, 24)
        }
        .transition(
            reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
        )
    }

    /// The book's Voice notes archive — every memo across its chapters, with playback and
    /// delete. No open-at-pin (there's no open chapter at the library surface).
    @ViewBuilder
    private var bookMemosPlane: some View {
        if let book = memoBook, let player = bookMemoPlayer {
            archivePlane(label: "VOICE NOTES", title: book.title, onClose: { closeBookMemos() }) {
                MemoNotesView(
                    memos: player.memos,
                    playingMemoId: player.playingMemoId,
                    reduceTransparency: reduceTransparency,
                    onPlay: { player.play($0) },
                    onRetry: { player.retry($0) },
                    onDelete: { player.delete($0) }
                )
            }
        }
    }

    /// The book's Saved discussions archive — every saved conversation across its chapters;
    /// tap reopens one read-only, trash deletes (threads are user content).
    @ViewBuilder
    private var bookConversationsPlane: some View {
        if let book = conversationsBook, let store {
            archivePlane(
                label: "SAVED DISCUSSIONS", title: book.title,
                onClose: { withAnimation(chapterPlaneAnimation) { conversationsBook = nil } }
            ) {
                if let openThreadId,
                   let thread = store.bookChatThreads(book).first(where: { $0.id == openThreadId }) {
                    DiscussTranscriptView(
                        messages: thread.lines
                            .sorted { $0.index < $1.index }
                            .map { ChatMessageDTO(role: $0.role, text: $0.text) }
                    )
                } else {
                    ConversationsListView(
                        threads: store.bookChatThreads(book),
                        onOpen: { openThreadId = $0.id },
                        onDelete: { store.deleteChatThread($0) }
                    )
                }
            }
        }
    }

    /// Open the Voice notes archive: spin up a playback controller on its own ephemeral
    /// engine, then rise the plane.
    private func openBookMemos(_ book: Book) {
        guard let store else { return }
        bookMemoPlayer = store.makeBookMemoPlayer(for: book, memoEngine: AVFoundationAudioEngine())
        withAnimation(chapterPlaneAnimation) { memoBook = book }
    }

    /// Close the Voice notes archive: stop any clip and release the controller.
    private func closeBookMemos() {
        bookMemoPlayer?.stop()
        bookMemoPlayer = nil
        withAnimation(chapterPlaneAnimation) { memoBook = nil }
    }

    // MARK: Reading surface (V17 — the cover morphs open; back-morph on close)

    /// The cover-open spring: interruptible, retargets mid-flight; Reduce Motion gets the
    /// cross-dissolve (discrete-state-morph fallback rule, apple/CLAUDE.md §Accessibility).
    private var coverMorphAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.18) : .spring(response: 0.5, dampingFraction: 0.88)
    }

    /// Open a ready chapter: the chapter plane recedes and the focused hardback opens into
    /// the reading canvas in the same gesture-driven beat — the cover art is the shared
    /// element (matched geometry). The chapter's player loads (bundle + audio + resume)
    /// before the morph; an unreadable cache refuses to open a dead surface (the next
    /// `load()` self-heal will catch the stale row).
    private func openReadingSurface(book: Book, chapter: Chapter) {
        guard chapter.status == .ready else { return }
        if let store, let audioEngine {
            let candidate = store.makePlayer(engine: audioEngine)
            guard (try? candidate.load(chapter)) != nil else { return }
            player = candidate
            if let recorder {
                memoCapture = store.makeMemoCapture(recorder: recorder, player: candidate)
            }
            memoNotes = store.makeMemoNotes(
                player: candidate, memoEngine: AVFoundationAudioEngine()
            )
            chatStore = store.makeChatStore(player: candidate)
            if let recorder {
                voiceInput = store.makeVoiceInput(recorder: recorder, player: candidate)
            }
            replySpeaker = store.makeReplySpeaker(
                player: candidate, speechEngine: AVFoundationAudioEngine()
            )
        }
        let shelfBook = ShelfBook(book: book, cover: store?.covers[book.id])
        withAnimation(coverMorphAnimation) {
            chapterBook = nil
            reading = ReadingContext(book: book, chapter: chapter, shelfBook: shelfBook)
        }
    }

    /// Back-morph and release the player — pausing it persists the resume position; the
    /// shared engine is never disposed (the Flutter `AudioHandler` lesson). A memo still
    /// recording is abandoned (cancel discards — no half-pinned rows).
    private func closeReadingSurface() {
        memoCapture?.cancelHold()
        memoCapture = nil
        memoNotes?.stopPlayback()
        memoNotes = nil
        chatStore = nil
        voiceInput?.cancelHold()
        voiceInput = nil
        replySpeaker?.stop()
        replySpeaker = nil
        player?.pause()
        player = nil
        withAnimation(coverMorphAnimation) { reading = nil }
    }

    /// The opened-book state riding above the stack. The canvas itself cross-fades; the
    /// cover is the matched-geometry shared element flying from the tower card to the
    /// plate (suppressed under Reduce Motion — the dissolve carries the transition).
    @ViewBuilder
    private var readingSurface: some View {
        if let reading {
            ReadingSurfaceView(
                book: reading.shelfBook,
                chapterIndex: reading.chapter.index,
                chapterTitle: reading.chapter.title,
                player: player,
                memoCapture: memoCapture,
                memoNotes: memoNotes,
                chatStore: chatStore,
                voiceInput: voiceInput,
                replySpeaker: replySpeaker,
                discussArchive: discussArchive(for: reading),
                reduceTransparency: reduceTransparency,
                onClose: { closeReadingSurface() },
                morphNamespace: reduceMotion ? nil : coverMorph
            )
            .transition(.opacity)
        }
    }

    /// The chapter's saved-conversation handles (V35): list/save/delete through the
    /// store — each Save inserts a NEW thread titled by the opening question.
    private func discussArchive(for reading: ReadingContext) -> DiscussArchive? {
        guard let store else { return nil }
        let book = reading.book
        let chapterIndex = reading.chapter.index
        return DiscussArchive(
            threads: { store.chatThreads(for: book, chapterIndex: chapterIndex) },
            save: { [chatStore] in
                guard let chatStore, chatStore.hasExchange else { return false }
                return store.saveChatThread(
                    book: book,
                    chapterIndex: chapterIndex,
                    anchorBlockId: chatStore.anchorBlockId,
                    title: chatStore.suggestedTitle,
                    messages: chatStore.messages
                ) != nil
            },
            deleteThread: { store.deleteChatThread($0) }
        )
    }

    /// A zero-distance drag that rides alongside the scroll (`simultaneousGesture`) so the
    /// puck can appear on finger-down and track the fling without blocking the scroll.
    /// Reduce Motion suppresses it (a continuous decorative effect, not an affordance).
    private func lensingDrag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard !reduceMotion else { return }
                let speed = hypot(value.velocity.width, value.velocity.height)
                puck = LensingPuck.at(location: value.location, dragSpeed: speed, in: size)
            }
            .onEnded { _ in
                // Fade out in place — keep the last center/diameter so it doesn't jump.
                puck = LensingPuck(center: puck.center, diameter: puck.diameter, opacity: 0)
            }
    }

    /// Coupled scroll+zoom hero settle (motion grammar #5): the rigid-group tower zoom as a
    /// pure function of distance-to-rest. Reduce Motion pins it to rest (no hero zoom).
    private func heroSettle(in size: CGSize) -> HeroSettle {
        reduceMotion
            ? .rest
            : .at(distanceToRest: distanceToRest, viewportHeight: size.height)
    }

    /// The hero zoom's fixed anchor as a SwiftUI `UnitPoint` (front slot — the dominant front
    /// cover holds while the receding stack grows toward the viewer).
    private func heroAnchor(in size: CGSize) -> UnitPoint {
        let p = heroSettle(in: size).anchor
        return UnitPoint(x: p.x, y: p.y)
    }

    /// Settle contrast shift (motion grammar #7): full at the top, fading as the tower
    /// scrolls under the glass plane. Reduce Motion pins it to the resting baseline.
    private func contrast(in size: CGSize) -> HeaderContrast {
        reduceMotion
            ? .rest
            : .at(distanceToRest: distanceToRest, viewportHeight: size.height)
    }

    // MARK: Glass top scrim (glass moment #1 — receding covers dissolve under it)

    /// A glass band hugging the top safe area that receding covers dissolve into. Redesigned
    /// in V27 to be *contextual*: it used to read as a fat empty pill dangling at the top in
    /// every state. Now it hugs the top edge (full-width, bottom-rounded — not a free-floating
    /// capsule) and its opacity is a scroll-driven function of the nearest cover's proximity
    /// to the top (`TopScrim`) — invisible at rest, fading in only while a cover dissolves
    /// under it, fading back out after. The Reduce Transparency matte fallback obeys the same
    /// visibility rule. Tint is re-tuned per mode (lighter on the butter/light canvas where
    /// the old pill read worst).
    @ViewBuilder
    private func topScrim(in size: CGSize) -> some View {
        let visibility = TopScrim.opacity(
            cardTopEdges: Array(cardTops.values), viewportHeight: size.height
        )
        let shape = UnevenRoundedRectangle(
            bottomLeadingRadius: 26, bottomTrailingRadius: 26, style: .continuous
        )
        Group {
            if reduceTransparency {
                // Opaque fallback (apple/CLAUDE.md §Accessibility): token-tinted matte.
                shape.fill(Palette.surface)
            } else {
                Color.clear.glassEffect(.regular.tint(scrimTint), in: shape)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 84)
        .opacity(visibility)
        // Hug the physical top edge / safe area rather than float below it.
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Glass tint for the top scrim, re-tuned per mode (V27). Sky reads as cool glass on the
    /// `ink` canvas; lighter on the `butter`/light canvas so it occludes without muddying.
    private var scrimTint: Color {
        colorScheme == .dark ? Palette.sky.opacity(0.22) : Palette.sky.opacity(0.13)
    }
}

/// The editorial header: ghost serif title / small-caps label / headline. Its type
/// contrast is supplied by `HeaderContrast` (settle contrast shift, motion grammar #7) —
/// full at rest, fading as the tower scrolls under the glass plane, the ghost fading
/// furthest. Parameterized (not self-tracking) so it renders identically from the live
/// scroll state and from snapshot tests.
struct LibraryHeader: View {
    let contrast: HeaderContrast

    @ScaledMetric(relativeTo: .largeTitle) private var ghostSize: CGFloat = 52
    @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = 11
    @ScaledMetric(relativeTo: .title) private var headlineSize: CGFloat = 34

    var body: some View {
        VStack(spacing: 14) {
            Text("VIMARSHA")
                .font(.system(size: ghostSize, weight: .light, design: .serif))
                .tracking(6)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 24)
                .foregroundStyle(Palette.textPrimary.opacity(contrast.ghost))
            Text("LIBRARY")
                .font(.system(size: labelSize, weight: .medium))
                .tracking(5)
                .foregroundStyle(Palette.textPrimary.opacity(contrast.label))
            Text("MY BOOKS")
                .font(.system(size: headlineSize, weight: .regular, design: .serif))
                .tracking(2)
                .foregroundStyle(Palette.textPrimary.opacity(contrast.headline))
        }
        .multilineTextAlignment(.center)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The depth-stacked book tower (motion grammar #1 + #2). Each card publishes its viewport
/// midY (`CardMidYKey`) so the library can detect which book owns the front slot; the focused
/// card then gets a grow-to-front scale bump and a deepening contact shadow on top of the
/// depth-stack transform. Per-card transforms still run render-side only (`visualEffect`), no
/// layout thrash.
private struct BookTower: View {
    /// The books to render — persisted library or the seed empty-state (V12).
    let shelf: [ShelfBook]
    let size: CGSize
    let reduceMotion: Bool
    /// Active front-slot focus (motion grammar #2); `.none` under Reduce Motion / at the top.
    let focus: BookFocus
    /// Whether the metadata reveal is actually rendered (V42): when the affordance band
    /// yields it (XXXL), the focused cover's deboss title stays — it IS the label.
    let metadataRevealShown: Bool
    /// The cover-local band the glass cluster covers on the FOCUSED card (V45) — its deboss
    /// lines fade locally under the glass so controls never render over glyphs.
    let debossDodge: DebossDodge.Band?
    /// Cover-morph shared element (V17): the card whose book is open hands its geometry to
    /// the reading surface's cover plate and hides while open.
    let morphNamespace: Namespace.ID
    let openedBookId: String?
    /// Tap-to-focus (a small library can't scroll a book onto the front slot): tapping a
    /// cover pins focus to it so its control cluster emerges.
    let onTapBook: (Int) -> Void
    /// Long-press / right-click a cover → request its removal (a destructive confirm follows).
    var onRequestDelete: (Int) -> Void = { _ in }

    var body: some View {
        // Inter-card overlap lives HERE (not the outer tower VStack) so it stays proportional
        // to card height — the shingled staircase reads the same now that cards are upright
        // book boards (ADR-011 aspect 1.5), and the header↔tower gap is decoupled from it.
        // Reduce Motion: a flat full-size list with a calm positive gap, no tuck.
        let spacing = reduceMotion ? 24 : CardGeometry.stackSpacing(forViewportWidth: size.width)
        VStack(spacing: spacing) {
            ForEach(Array(shelf.enumerated()), id: \.element.id) { index, book in
                card(book, at: index)
                    // Tap-to-focus: summon this cover's control cluster (the front-slot settle
                    // can't reach a book in a small library). `contentShape` makes the whole
                    // cover tappable; the visualEffect transforms are render-only, so the hit
                    // target stays the card's layout frame.
                    .contentShape(Rectangle())
                    .onTapGesture { onTapBook(index) }
                    // Remove-book affordance (long-press / right-click). A system context menu
                    // is the one OS-driven surface sanctioned here (like the keyboard) — the
                    // long-press is itself the deliberate gesture; a confirm still follows.
                    .contextMenu {
                        Button(role: .destructive) { onRequestDelete(index) } label: {
                            Label("Remove Book", systemImage: "trash")
                        }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Shows playback controls")
                    .accessibilityAction { onTapBook(index) }
                    .accessibilityAction(named: "Remove book") { onRequestDelete(index) }
            }
        }
    }

    @ViewBuilder
    private func card(_ book: ShelfBook, at index: Int) -> some View {
        if reduceMotion {
            // Static-layout fallback (apple/CLAUDE.md §Accessibility): flat FULL-SIZE list,
            // no per-book rhythm, no transforms. Discrete morphs are dissolves, so no
            // matched geometry here either.
            HardbackCoverView(book: book)
                .frame(width: CardGeometry.width(forViewportWidth: size.width))
                .shadow(color: .black.opacity(0.25), radius: 14, y: 10)
        } else {
            let viewportHeight = size.height
            // Grow-to-front promotion (motion grammar #2): only the focused card grows, and
            // its eased `promotion` deepens the contact shadow as it settles onto the slot.
            let promotion = focus.index == index ? focus.promotion : 0
            // Fade this cover's printed title as it settles, so the metadata reveal isn't a
            // second title in the same eyeline (V24 — kill the double title). Only the focused
            // card promotes, so only it fades. The fade completes BEFORE any focus affordance
            // is meaningfully visible (V41 — the linear `1 - promotion` double-titled at rest)
            // — but only while the metadata reveal actually renders (V42: a yielded band
            // keeps the printed title; it's the focused book's only label). The branch flip
            // is discrete, so the opacity change rides a short ease (no hard cut).
            HardbackCoverView(
                book: book,
                titleOpacity: BookFocus.debossTitleOpacity(
                    promotion: promotion, metadataVisible: metadataRevealShown
                ),
                debossDodge: focus.index == index ? debossDodge : nil
            )
                .animation(.easeInOut(duration: 0.2), value: metadataRevealShown)
                // Uniform card width (ADR-011) — one size for every book; the depth-stack
                // transform alone supplies the staircase, no per-index width rhythm.
                .frame(width: CardGeometry.width(forViewportWidth: size.width))
                .visualEffect { content, proxy in
                    let midY = proxy.frame(in: .scrollView).midY
                    let t = StackTransform.at(midY: midY, viewportHeight: viewportHeight)
                    // Slot-emit staircase fan-up (motion grammar #4): below the front slot the
                    // cover rises from the bottom shelf anchor; above it `emit` is identity and
                    // `StackTransform` owns the recede — the two compose seamlessly at the slot.
                    let emit = SlotEmit.at(midY: midY, viewportHeight: viewportHeight)
                    return content
                        .scaleEffect(
                            t.scale * emit.scale * (1 + promotion * BookFocus.scaleBoost),
                            anchor: .bottom
                        )
                        .opacity(t.opacity * emit.opacity)
                        // Recede desaturation (motion grammar #1): recessed covers lose a
                        // little chroma; the front cover is full-chroma.
                        .saturation(t.saturation)
                        .offset(y: t.yOffset + emit.yOffset)
                }
                // Publish this card's viewport midY (front-slot detection), layout top edge
                // (top-scrim visibility, V27) and RENDERED top edge (focus-affordance
                // anchoring, V37 — visualEffect transforms don't move the layout frame, so the
                // rendered top is recomputed from the same pure math the card draws with).
                .background {
                    GeometryReader { proxy in
                        let frame = proxy.frame(in: .scrollView)
                        Color.clear
                            .preference(key: CardMidYKey.self, value: [index: frame.midY])
                            .preference(key: CardTopYKey.self, value: [index: frame.minY])
                            .preference(
                                key: CardVisualTopKey.self,
                                value: [index: CardVisualTop.at(
                                    layoutFrame: frame,
                                    viewportHeight: viewportHeight,
                                    promotion: promotion
                                )]
                            )
                    }
                }
                // Contact shadow; deepens with the grow-to-front promotion → strongest on the
                // settled front card (motion grammar #2 "contact shadow deepens as scale → 1").
                .shadow(
                    color: .black.opacity(0.30 + promotion * 0.18),
                    radius: 16 + promotion * 10,
                    y: 12 + promotion * 6
                )
                // Cover-morph shared element (V17): while this book is open the reading
                // surface's plate owns the id (this card yields source) and the card hides —
                // the hardback has "left" the stack; back-morph returns it.
                .matchedGeometryEffect(
                    id: "cover-\(book.id)", in: morphNamespace,
                    isSource: openedBookId != book.id
                )
                .opacity(openedBookId == book.id ? 0 : 1)
        }
    }
}

/// What the reading surface needs from the moment of opening (V17): the persisted rows
/// (V18 loads the cached bundle + audio from them) and the shelf rendering of the cover
/// (the matched-geometry shared element).
struct ReadingContext {
    let book: Book
    let chapter: Chapter
    let shelfBook: ShelfBook
}

/// Collects each card's viewport midY (keyed by shelf index) so `BookFocus` can find the card
/// nearest the front slot. Merges partial maps as cards report during layout.
private struct CardMidYKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Collects each card's viewport LAYOUT top edge (keyed by shelf index) — the top scrim's
/// contextual visibility input (V27).
private struct CardTopYKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Whether the metadata reveal is actually rendered (V42): emitted as `true` only by the
/// metadata branch of the affordance `ViewThatFits`, so a yielded band (cluster-only at
/// XXXL) resolves to the default `false` — and the focused cover keeps its printed title.
private struct FocusMetadataVisibleKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

/// The control cluster's rendered frame in global coordinates (V45). Published only while
/// the cluster actually renders (it is absent below its visibility floor), so the deboss
/// dodge appears and vanishes with the glass itself.
private struct ClusterFrameKey: PreferenceKey {
    static let defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}

/// Collects each card's RENDERED top edge (`CardVisualTop`, keyed by shelf index) so the
/// focus affordances anchor against the seams the user actually sees (V37).
private struct CardVisualTopKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Focused-book metadata reveal (motion grammar #2): the settling book's title + author fade
/// up in the editorial serif. The reveal floats over *arbitrary* cover art, so the text rides
/// a sky-tinted glass plate (V38 — bare `textPrimary` over an uncontrolled cover failed WCAG
/// both modes; the plate is the overlay carrier, the text stays the per-mode token). Reduce
/// Transparency swaps the glass for the token-tinted matte. `reveal` is the eased focus
/// emphasis (0 = hidden, 1 = fully settled). Parameterized so it renders identically from
/// the live scroll state and from snapshot tests.
struct FocusMetadataView: View {
    let book: ShelfBook
    let reveal: CGFloat
    var reduceTransparency: Bool = false

    /// The matte token underlay beneath the band's glass (V43, ui-audit round 2): glass
    /// tint alone let mid-luminance covers bloom through (blue cover measured ≈1.4–2.6:1).
    /// At this opacity `BandContrast.guaranteedContrast` clears WCAG AA (≥4.5:1) for title
    /// AND subtitle over ANY cover, both modes — pinned by `BandContrastTests`.
    static let plateUnderlayOpacity: Double = 0.85

    /// Subtitle alpha (V43): raised 0.7 → 0.8 — at 0.7 the worst-case cover dipped the
    /// translucent author line just under 4.5:1 in light mode.
    static let subtitleOpacity: Double = 0.8

    @ScaledMetric(relativeTo: .title3) private var titleSize: CGFloat = 22
    @ScaledMetric(relativeTo: .caption2) private var authorSize: CGFloat = 10

    private let plateShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        VStack(spacing: 4) {
            Text(book.title)
                .font(.system(size: titleSize, weight: .regular, design: .serif))
                .tracking(1)
                .foregroundStyle(Palette.textPrimary)
            Text(book.author.uppercased())
                .font(.system(size: authorSize, weight: .medium))
                .tracking(2.5)
                .foregroundStyle(Palette.textPrimary.opacity(Self.subtitleOpacity))
        }
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background {
            if reduceTransparency {
                // Opaque fallback (apple/CLAUDE.md §Accessibility): token-tinted matte plate.
                plateShape.fill(Palette.surface)
            } else {
                // A matte `surface` underlay GUARANTEES the band's backdrop (V43 — tint-only
                // glass let cover art bloom through to WCAG failure); the sky glass above it
                // keeps the refracting rim. Deliberately not `.interactive()` — not a control.
                plateShape.fill(Palette.surface.opacity(Self.plateUnderlayOpacity))
                    .overlay(
                        Color.clear.glassEffect(
                            .regular.tint(Palette.sky.opacity(0.30)), in: plateShape
                        )
                    )
            }
        }
        .padding(.horizontal, 32)
        .opacity(reveal)
        // The cover already carries an accessibility label; this reveal is decorative.
        .accessibilityHidden(true)
    }
}

#Preview("Library — dark (canonical)") {
    LibraryStackView()
        .preferredColorScheme(.dark)
}

#Preview("Library — light") {
    LibraryStackView()
        .preferredColorScheme(.light)
}
