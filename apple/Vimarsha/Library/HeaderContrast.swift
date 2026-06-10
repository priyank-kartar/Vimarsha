import CoreGraphics

/// Settle contrast shift (motion grammar #7, apple/CLAUDE.md).
///
/// The editorial header type animates light → full contrast as a pure continuous function
/// of its scroll **distance-to-rest** — full (near-black on light / brightest on dark) when
/// settled at the top, fading toward light floors as the book tower scrolls up under the
/// glass header plane. No state, no time: fully scrubbable, and it settle-darkens on the
/// loop-back to top. The ghost display title fades furthest (lowest floor) so it reads as a
/// watermark the covers scroll under, while the headline keeps the most contrast.
struct HeaderContrast: Equatable {
    /// VIMARSHA — the ghosted display serif; dims most as the tower scrolls under.
    var ghost: CGFloat
    /// LIBRARY — the small-caps section label.
    var label: CGFloat
    /// MY BOOKS — the headline; keeps the most contrast at rest, fades least.
    var headline: CGFloat

    /// Resting (settled, at top) opacities — the V03 editorial baseline.
    static let restGhost: CGFloat = 0.26
    static let restLabel: CGFloat = 0.6
    static let restHeadline: CGFloat = 1.0

    /// Faded floors once the header has scrolled a full settle span away from rest.
    static let ghostFloor: CGFloat = 0.05
    static let labelFloor: CGFloat = 0.18
    static let headlineFloor: CGFloat = 0.32

    /// Distance-to-rest, as a fraction of viewport height, over which the shift completes.
    static let settleSpan: CGFloat = 0.5

    static let rest = HeaderContrast(ghost: restGhost, label: restLabel, headline: restHeadline)

    /// - Parameters:
    ///   - distanceToRest: scroll offset from the top (≥ 0; the resting position is 0).
    ///     Negative values (overscroll bounce) clamp to rest.
    ///   - viewportHeight: the scroll viewport height; the settle span scales with it.
    static func at(distanceToRest: CGFloat, viewportHeight: CGFloat) -> HeaderContrast {
        guard viewportHeight > 0 else { return .rest }
        let settle = min(1, max(0, distanceToRest) / (viewportHeight * settleSpan))
        return HeaderContrast(
            ghost: restGhost + (ghostFloor - restGhost) * settle,
            label: restLabel + (labelFloor - restLabel) * settle,
            headline: restHeadline + (headlineFloor - restHeadline) * settle
        )
    }
}
