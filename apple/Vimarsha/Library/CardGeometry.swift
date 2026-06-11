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
    /// Cover height relative to its width — uniform across every card (wide, short slab).
    static let aspect: CGFloat = 0.50

    /// The card's rendered width for a given viewport width: a fixed fraction, capped.
    static func width(forViewportWidth viewportWidth: CGFloat) -> CGFloat {
        min(max(0, viewportWidth) * widthFraction, widthCap)
    }
}
