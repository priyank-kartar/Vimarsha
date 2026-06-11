import SwiftUI

/// A generated cloth-bound hardback (apple/CLAUDE.md §Physical book rendering):
/// cloth face with a soft sheen, debossed tone-on-tone serif title, a fore-edge page
/// block peeking out below the board, and an optional gilt stripe.
/// Contact shadow is applied by the stack (it depends on stack position).
struct HardbackCoverView: View {
    let book: BookSeed
    /// Opacity of the debossed title block (V24). Defaults to fully printed; the focused card
    /// fades it toward 0 as its metadata reveal rises, so the title never reads twice in one
    /// eyeline (the cover's debossed title + the serif metadata reveal below it).
    var titleOpacity: CGFloat = 1

    @ScaledMetric(relativeTo: .title2) private var titleSize: CGFloat = 30
    @ScaledMetric(relativeTo: .caption2) private var authorSize: CGFloat = 10

    private let boardRadius: CGFloat = 7

    var body: some View {
        ZStack(alignment: .bottom) {
            foreEdge
            board
        }
        // Uniform card aspect (ADR-011) — every book is the same slab; cover art, not size,
        // carries variety. `BookSeed.aspect` is no longer used for layout.
        .aspectRatio(1 / CardGeometry.aspect, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(book.title), \(book.author)")
    }

    private var board: some View {
        RoundedRectangle(cornerRadius: boardRadius, style: .continuous)
            .fill(book.cloth)
            .overlay(clothSheen)
            .overlay(titleBlock)
            .padding(.bottom, 7)
    }

    /// A faint diagonal light sweep so the cloth reads as material, not flat fill.
    private var clothSheen: some View {
        RoundedRectangle(cornerRadius: boardRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [.white.opacity(0.10), .clear, .black.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text(book.title.uppercased())
                .font(.system(size: titleSize, weight: .regular, design: .serif))
                .tracking(1.5)
                .minimumScaleFactor(0.4)
            Text(book.author.uppercased())
                .font(.system(size: authorSize, weight: .medium))
                .tracking(2.5)
                .opacity(0.85)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(book.ink)
        // Debossed: a dark inner edge above, a light catch below — pressed into the cloth.
        .shadow(color: .black.opacity(0.30), radius: 0.5, y: -0.6)
        .shadow(color: .white.opacity(0.18), radius: 0.5, y: 0.7)
        .padding(.horizontal, 18)
        .lineLimit(3)
        // Fade the printed title as the metadata reveal takes over (V24 — kill the double title).
        .opacity(titleOpacity)
    }

    /// The page block under the board: stacked paper lines, optionally gilt.
    private var foreEdge: some View {
        VStack(spacing: 1.4) {
            ForEach(0..<3, id: \.self) { _ in
                Capsule().fill(Palette.pageEdge).frame(height: 1.1)
            }
            if book.gilt {
                Capsule().fill(Palette.gilt).frame(height: 1.6)
            }
        }
        .padding(.horizontal, 10)
    }
}

#Preview("Shelf samples", traits: .sizeThatFitsLayout) {
    VStack(spacing: 16) {
        HardbackCoverView(book: BookSeed.shelf[3])
        HardbackCoverView(book: BookSeed.shelf[0])
    }
    .frame(width: 340)
    .padding(24)
    .background(Palette.canvas)
}
