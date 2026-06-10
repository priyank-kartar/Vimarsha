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

    @ScaledMetric(relativeTo: .largeTitle) private var ghostSize: CGFloat = 52
    @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = 11
    @ScaledMetric(relativeTo: .title) private var headlineSize: CGFloat = 34

    /// Scroll distance-to-rest (≥ 0; 0 at the top). Drives the settle contrast shift
    /// (motion grammar #7) via `HeaderContrast` — header-only state, so the book tower is
    /// extracted into `BookTower` to keep this scroll tick off the heavy ForEach.
    @State private var distanceToRest: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: reduceMotion ? 24 : -geo.size.height * 0.04) {
                    header(in: geo.size)
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
            .overlay(alignment: .top) { topScrim }
        }
    }

    // MARK: Header — settle contrast shift (motion grammar #7)

    /// Ghost serif title / small-caps label / headline; their contrast is a pure function of
    /// `distanceToRest` (full at the top, fading as the tower scrolls under the glass plane;
    /// the ghost fades furthest). Reduce Motion pins it to the resting baseline.
    private func header(in size: CGSize) -> some View {
        let c = reduceMotion
            ? HeaderContrast.rest
            : HeaderContrast.at(distanceToRest: distanceToRest, viewportHeight: size.height)
        return VStack(spacing: 14) {
            Text("VIMARSHA")
                .font(.system(size: ghostSize, weight: .light, design: .serif))
                .tracking(6)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 24)
                .foregroundStyle(Palette.textPrimary.opacity(c.ghost))
            Text("LIBRARY")
                .font(.system(size: labelSize, weight: .medium))
                .tracking(5)
                .foregroundStyle(Palette.textPrimary.opacity(c.label))
            Text("MY BOOKS")
                .font(.system(size: headlineSize, weight: .regular, design: .serif))
                .tracking(2)
                .foregroundStyle(Palette.textPrimary.opacity(c.headline))
        }
        .multilineTextAlignment(.center)
        .accessibilityAddTraits(.isHeader)
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
