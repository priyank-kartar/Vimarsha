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

    /// Which book owns the front slot, and how settled it is (motion grammar #2). Recomputed
    /// from each card's measured midY as the tower scrolls; drives the grow-to-front bump,
    /// the deepening contact shadow, and the focused-book metadata reveal. Reduce Motion (a
    /// flat list with no front slot) leaves this at `.none`.
    @State private var focus: BookFocus = .none

    /// Each card's viewport top edge, keyed by shelf index — used to anchor the focus
    /// affordances just inside the focused cover's visible bottom (the next book's top edge),
    /// so the cluster sits on the focused cover, not floating over the book below it (V24).
    @State private var cardTops: [Int: CGFloat] = [:]

    /// EPUB import (V10). The system document picker is OS-driven chrome (like the
    /// keyboard) — exempt from the morph rule, and the only way the sandbox grants access
    /// to a user-chosen file. The picked EPUB lands in the container and persists via
    /// `LibraryStore.addBook` (V12), joining the shelf live.
    @State private var showsEpubPicker = false

    /// The book whose chapter list plane is risen (V14) — a state of the surface, not a
    /// sheet. Opened from the focused book's Play control (the stand-in trigger until the
    /// audio engine/reading morph lands in V16/V17); closed by the X or the backdrop.
    @State private var chapterBook: Book?

    /// The opened chapter (V17): a ready chapter row morphs the hardback OPEN into the
    /// reading surface — a state of this same surface, never a push. Closing back-morphs.
    @State private var reading: ReadingContext?

    /// The opened chapter's player (V18): created at open, paused + released at close —
    /// the shared engine itself lives on in `VimarshaApp`.
    @State private var player: PlayerController?

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
                        .padding(.bottom, 72)
                    // Coupled scroll+zoom hero settle (motion grammar #5): as the header above
                    // translates off, the whole tower scales toward the viewer as one rigid
                    // group, anchored on the front slot. One scale on the tower as a whole —
                    // the per-card depth-stack parallax rides inside it. Reduce Motion exempt
                    // (the static fallback has no hero zoom).
                    BookTower(
                        shelf: shelf, size: geo.size, reduceMotion: reduceMotion, focus: focus,
                        morphNamespace: coverMorph, openedBookId: reading?.shelfBook.id
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
            // Scroll-settle detection (motion grammar #2): each card publishes its viewport
            // midY; the nearest to the front slot owns focus. Suppressed under Reduce Motion.
            .onPreferenceChange(CardMidYKey.self) { midYs in
                focus = reduceMotion
                    ? .none
                    : BookFocus.at(midYs: midYs, viewportHeight: geo.size.height)
            }
            .onPreferenceChange(CardTopYKey.self) { cardTops = $0 }
            .background(Palette.canvas.ignoresSafeArea())
            // The puck floats in viewport space (it follows the finger, not the content),
            // so the gesture + overlay live on the ScrollView, outside the scrolling tower.
            .simultaneousGesture(lensingDrag(in: geo.size))
            .overlay { LensingPuckView(puck: puck, reduceTransparency: reduceTransparency) }
            .overlay(alignment: .top) { topScrim(in: geo.size) }
            .overlay(alignment: .bottom) { focusAffordances(in: geo.size) }
            .overlay(alignment: .topTrailing) { addBookButton }
            .overlay { chapterListPlane }
            .overlay { readingSurface }
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
            VStack(spacing: 18) {
                FocusMetadataView(book: shelf[focus.index], reveal: focus.promotion)
                ControlClusterView(
                    cluster: ControlCluster.at(promotion: focus.promotion),
                    reduceTransparency: reduceTransparency,
                    onActivate: { control in
                        // Play raises the chapter list plane (V14) — the stand-in until
                        // the audio engine (V16) and reading morph (V17) take it over.
                        // Other controls stay stubs; seeds have no chapters to show.
                        if control == .play, let book = focusedBook {
                            withAnimation(chapterPlaneAnimation) { chapterBook = book }
                        }
                    }
                )
            }
            // Anchor inside the focused cover's visible bottom — above the next book that
            // overlaps it — so the cluster reads as extruded from the cover, not floating over
            // the book below (V24).
            .padding(.bottom, FocusAffordancePlacement.bottomPadding(
                nextTopY: cardTops[focus.index + 1],
                viewportHeight: size.height
            ))
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
        }
        let shelfBook = ShelfBook(book: book, cover: store?.covers[book.id])
        withAnimation(coverMorphAnimation) {
            chapterBook = nil
            reading = ReadingContext(book: book, chapter: chapter, shelfBook: shelfBook)
        }
    }

    /// Back-morph and release the player — pausing it persists the resume position; the
    /// shared engine is never disposed (the Flutter `AudioHandler` lesson).
    private func closeReadingSurface() {
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
                reduceTransparency: reduceTransparency,
                onClose: { closeReadingSurface() },
                morphNamespace: reduceMotion ? nil : coverMorph
            )
            .transition(.opacity)
        }
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
    /// Cover-morph shared element (V17): the card whose book is open hands its geometry to
    /// the reading surface's cover plate and hides while open.
    let morphNamespace: Namespace.ID
    let openedBookId: String?

    var body: some View {
        ForEach(Array(shelf.enumerated()), id: \.element.id) { index, book in
            card(book, at: index)
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
            // card promotes, so only it fades.
            HardbackCoverView(book: book, titleOpacity: 1 - promotion)
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
                // Publish this card's viewport midY (front-slot detection) and top edge (so the
                // focus affordances can anchor inside this cover's visible bottom, V24).
                .background {
                    GeometryReader { proxy in
                        let frame = proxy.frame(in: .scrollView)
                        Color.clear
                            .preference(key: CardMidYKey.self, value: [index: frame.midY])
                            .preference(key: CardTopYKey.self, value: [index: frame.minY])
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

/// Collects each card's viewport top edge (keyed by shelf index) so the focus affordances can
/// anchor inside the focused cover's visible bottom — the next book's top edge (V24).
private struct CardTopYKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Focused-book metadata reveal (motion grammar #2): the settling book's title + author fade
/// up in the editorial serif on the matte canvas (content is paper, never glass). `reveal` is
/// the eased focus emphasis (0 = hidden, 1 = fully settled). Parameterized so it renders
/// identically from the live scroll state and from snapshot tests.
struct FocusMetadataView: View {
    let book: ShelfBook
    let reveal: CGFloat

    @ScaledMetric(relativeTo: .title3) private var titleSize: CGFloat = 22
    @ScaledMetric(relativeTo: .caption2) private var authorSize: CGFloat = 10

    var body: some View {
        VStack(spacing: 5) {
            Text(book.title)
                .font(.system(size: titleSize, weight: .regular, design: .serif))
                .tracking(1)
                .foregroundStyle(Palette.textPrimary)
            Text(book.author.uppercased())
                .font(.system(size: authorSize, weight: .medium))
                .tracking(2.5)
                .foregroundStyle(Palette.textPrimary.opacity(0.6))
        }
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
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
