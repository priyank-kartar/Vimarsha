import SwiftUI

/// A generated cloth-bound hardback (apple/CLAUDE.md §Physical book rendering):
/// cloth face with a soft sheen, debossed tone-on-tone serif title, a fore-edge page
/// block peeking out below the board, and an optional gilt stripe.
/// Contact shadow is applied by the stack (it depends on stack position).
struct HardbackCoverView: View {
    let book: ShelfBook
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
        // carries variety. `ShelfBook.aspect` is no longer used for layout.
        .aspectRatio(1 / CardGeometry.aspect, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(book.title), \(book.author)")
    }

    private var board: some View {
        RoundedRectangle(cornerRadius: boardRadius, style: .continuous)
            .fill(book.cloth)
            .overlay(coverArt)
            .overlay(clothSheen)
            .overlay(titleBlock)
            .padding(.bottom, 7)
    }

    /// Real cover art (V11/V12) over the board — matte paper, clipped to the board shape;
    /// the cloth + debossed title remain the missing-art fallback. The sheen stays on top:
    /// it's the material's light sweep, art or cloth alike.
    @ViewBuilder
    private var coverArt: some View {
        if let cover = book.cover {
            RoundedRectangle(cornerRadius: boardRadius, style: .continuous)
                .fill(.clear)
                .overlay(cover.resizable().scaledToFill())
                .clipShape(RoundedRectangle(cornerRadius: boardRadius, style: .continuous))
        }
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
        // Fit the WHOLE block to the cover face (V44, ui-audit round 2): the scale factor
        // sat on the title alone, so at XXXL the un-scalable subtitle pushed the block past
        // the board and its bottom line rode into the fore-edge page texture. Block-level
        // scaling + a vertical inset keep every glyph above the page-edge strip.
        .padding(.vertical, 12)
        .lineLimit(3)
        .minimumScaleFactor(0.4)
        // Fade the printed title as the metadata reveal takes over (V24 — kill the double
        // title). Real art carries its own printed title, so the debossed block never
        // shows over it.
        .opacity(book.cover == nil ? titleOpacity : 0)
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
        HardbackCoverView(book: ShelfBook.seeds[3])
        HardbackCoverView(book: ShelfBook.seeds[0])
    }
    .frame(width: 340)
    .padding(24)
    .background(Palette.canvas)
}
