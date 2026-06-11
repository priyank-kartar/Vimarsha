import SwiftUI

/// The library surface: editorial header scrolling into the depth-stacked book tower
/// (apple/CLAUDE.md §UI map state 1; motion grammar #1).
///
/// Overlap comes from negative stack spacing; document order puts lower (front) cards on
/// top, matching the reference staircase. Transforms run in `visualEffect` — render-time
/// only, no layout thrash — as a pure function of each card's position (`StackTransform`).
struct LibraryStackView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: reduceMotion ? 24 : -geo.size.height * 0.052) {
                    LibraryHeader(contrast: contrast(in: geo.size))
                        .padding(.top, 64)
                        .padding(.bottom, 72)
                    BookTower(size: geo.size, reduceMotion: reduceMotion, focus: focus)
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
            .background(Palette.canvas.ignoresSafeArea())
            // The puck floats in viewport space (it follows the finger, not the content),
            // so the gesture + overlay live on the ScrollView, outside the scrolling tower.
            .simultaneousGesture(lensingDrag(in: geo.size))
            .overlay { LensingPuckView(puck: puck, reduceTransparency: reduceTransparency) }
            .overlay(alignment: .top) { topScrim }
            .overlay(alignment: .bottom) { focusAffordances }
        }
    }

    // MARK: Focused-book affordances — metadata reveal + glass control cluster

    /// The settled book's title/author (motion grammar #2) with the glass control cluster
    /// (glass moment #5) beneath it: Play/Figures/Voice note/Discuss morph out of the focused
    /// cover and re-absorb on scroll. Both fade with the same eased `promotion`, so they grow
    /// and recede together. Hosting the metadata here (rather than free-floating) addresses the
    /// V06 note that the bare caption grazed the next rising cover. Hidden when nothing is
    /// settled or under Reduce Motion (focus is `.none`).
    @ViewBuilder
    private var focusAffordances: some View {
        if focus.index >= 0, focus.index < BookSeed.shelf.count {
            VStack(spacing: 18) {
                FocusMetadataView(book: BookSeed.shelf[focus.index], reveal: focus.promotion)
                ControlClusterView(
                    cluster: ControlCluster.at(promotion: focus.promotion),
                    reduceTransparency: reduceTransparency
                )
            }
            .padding(.bottom, 36)
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

    /// Settle contrast shift (motion grammar #7): full at the top, fading as the tower
    /// scrolls under the glass plane. Reduce Motion pins it to the resting baseline.
    private func contrast(in size: CGSize) -> HeaderContrast {
        reduceMotion
            ? .rest
            : .at(distanceToRest: distanceToRest, viewportHeight: size.height)
    }

    // MARK: Glass top scrim (glass moment #1 — receding covers dissolve under it)

    @ViewBuilder
    private var topScrim: some View {
        Group {
            if reduceTransparency {
                // Opaque fallback (apple/CLAUDE.md §Accessibility): token-tinted matte.
                Capsule().fill(Palette.surface)
                    .frame(height: 54)
            } else {
                Color.clear
                    .frame(height: 54)
                    .glassEffect(.regular.tint(Palette.sky.opacity(0.18)), in: Capsule())
            }
        }
        .padding(.horizontal, 100)
        .padding(.top, 6)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
    let size: CGSize
    let reduceMotion: Bool
    /// Active front-slot focus (motion grammar #2); `.none` under Reduce Motion / at the top.
    let focus: BookFocus

    var body: some View {
        ForEach(Array(BookSeed.shelf.enumerated()), id: \.element.id) { index, book in
            card(book, at: index)
        }
    }

    @ViewBuilder
    private func card(_ book: BookSeed, at index: Int) -> some View {
        if reduceMotion {
            // Static-layout fallback (apple/CLAUDE.md §Accessibility): flat FULL-SIZE list,
            // no per-book rhythm, no transforms.
            HardbackCoverView(book: book)
                .frame(width: CardGeometry.width(forViewportWidth: size.width))
                .shadow(color: .black.opacity(0.25), radius: 14, y: 10)
        } else {
            let viewportHeight = size.height
            // Grow-to-front promotion (motion grammar #2): only the focused card grows, and
            // its eased `promotion` deepens the contact shadow as it settles onto the slot.
            let promotion = focus.index == index ? focus.promotion : 0
            HardbackCoverView(book: book)
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
                        .offset(y: t.yOffset + emit.yOffset)
                }
                // Publish this card's viewport midY for front-slot detection.
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: CardMidYKey.self,
                            value: [index: proxy.frame(in: .scrollView).midY]
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
        }
    }
}

/// Collects each card's viewport midY (keyed by shelf index) so `BookFocus` can find the card
/// nearest the front slot. Merges partial maps as cards report during layout.
private struct CardMidYKey: PreferenceKey {
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
    let book: BookSeed
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
