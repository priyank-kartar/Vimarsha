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

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: reduceMotion ? 24 : -geo.size.height * 0.04) {
                    LibraryHeader(contrast: contrast(in: geo.size))
                        .padding(.top, 64)
                        .padding(.bottom, 72)
                    BookTower(size: geo.size, reduceMotion: reduceMotion)
                }
                .padding(.bottom, geo.size.height * 0.22)
                .frame(width: geo.size.width)
            }
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in
                distanceToRest = max(0, y)
            }
            .background(Palette.canvas.ignoresSafeArea())
            // The puck floats in viewport space (it follows the finger, not the content),
            // so the gesture + overlay live on the ScrollView, outside the scrolling tower.
            .simultaneousGesture(lensingDrag(in: geo.size))
            .overlay { LensingPuckView(puck: puck, reduceTransparency: reduceTransparency) }
            .overlay(alignment: .top) { topScrim }
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

/// The depth-stacked book tower (motion grammar #1). Extracted so the library's
/// scroll-driven header state changes don't re-evaluate this ForEach every frame — its
/// inputs (`size`, `reduceMotion`) are stable during a scroll, so SwiftUI skips it. The
/// per-card transforms run render-side only (`visualEffect`), no layout thrash.
private struct BookTower: View {
    let size: CGSize
    let reduceMotion: Bool

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
                .frame(width: min(size.width - 48, 460))
                .shadow(color: .black.opacity(0.25), radius: 14, y: 10)
        } else {
            let viewportHeight = size.height
            HardbackCoverView(book: book)
                .frame(width: min(size.width * widthFactor(at: index), 460))
                .visualEffect { content, proxy in
                    let t = StackTransform.at(
                        midY: proxy.frame(in: .scrollView).midY,
                        viewportHeight: viewportHeight
                    )
                    return content
                        .scaleEffect(t.scale, anchor: .bottom)
                        .opacity(t.opacity)
                        .offset(y: t.yOffset)
                }
                // Contact shadow; deepens via scale → reads strongest on the front card.
                .shadow(color: .black.opacity(0.30), radius: 16, y: 12)
        }
    }

    /// Slight per-position width variation gives the staircase its hand-stacked rhythm.
    private func widthFactor(at index: Int) -> CGFloat {
        0.62 + CGFloat((index + 1) % 4) * 0.05
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
