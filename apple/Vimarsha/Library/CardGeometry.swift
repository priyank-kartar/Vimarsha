import CoreGraphics

/// Uniform book-card geometry for the library stack
/// ([ADR-011](../../../plan/00-overview/decision-log.md)): every card shares ONE width and
/// ONE aspect, so the pile reads as a calm, neat, editorial staircase rather than a
/// scattered heap. Visual variety comes from cover art / cloth color only — per-book size
/// variation added noise without carrying meaning.
///
/// This replaces the old per-index `widthFactor` rhythm and the use of `ShelfBook.aspect`
/// for card sizing (the seed's `aspect` field is retained for future cover-art fitting, not
/// layout). Pure math, no state — same value live and in snapshots.
enum CardGeometry {
    /// Card width as a fraction of the viewport width.
    static let widthFraction: CGFloat = 0.70
    /// Cap so the stack stays editorial on wide windows (macOS / iPad) instead of ballooning.
    static let widthCap: CGFloat = 460
    /// Cover height relative to its width — uniform across every card. An upright trade-book
    /// board (~1.5 : a 6.14×9.21" hardback), so the whole cover art reads instead of the old
    /// cropped landscape slab; matches typical EPUB cover art ratio so `scaledToFill` shows
    /// essentially the full image.
    static let aspect: CGFloat = 1.5
    /// How much of a card tucks behind the next one in the depth-stack (motion grammar #1) —
    /// a fraction of card HEIGHT, so the shingled staircase reads the same regardless of the
    /// card's absolute height. Front card stays fully visible; receding cards show ~70%.
    static let stackOverlapFraction: CGFloat = 0.30

    /// The card's rendered height for a given viewport width (width · aspect).
    static func height(forViewportWidth viewportWidth: CGFloat) -> CGFloat {
        width(forViewportWidth: viewportWidth) * aspect
    }

    /// Negative VStack spacing that tucks each card behind the next by `stackOverlapFraction`
    /// of its height — the inter-card overlap for the depth-stack (kept proportional to card
    /// height so the staircase shingle survives any aspect change).
    static func stackSpacing(forViewportWidth viewportWidth: CGFloat) -> CGFloat {
        -height(forViewportWidth: viewportWidth) * stackOverlapFraction
    }

    /// The card's rendered width for a given viewport width: a fixed fraction, capped.
    static func width(forViewportWidth viewportWidth: CGFloat) -> CGFloat {
        min(max(0, viewportWidth) * widthFraction, widthCap)
    }
}
