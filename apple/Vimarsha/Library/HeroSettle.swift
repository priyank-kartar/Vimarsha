import CoreGraphics

/// Coupled scroll+zoom hero settle math (motion grammar #5, apple/CLAUDE.md §Motion grammar).
///
/// The reference's opening move: the editorial title block translates up and off while the
/// whole book tower **scales toward the viewer as one rigid group** — "barely moves at the
/// start, peak velocity mid, damps to rest" (ease-in-out), anchored so a chosen point stays
/// fixed. Here the header translate-off is the natural scroll of the header out of the
/// viewport, and this supplies the coupled rigid-group zoom as a pure continuous function of
/// the scroll **distance-to-rest** — no state, no timers, fully scrubbable, and it un-zooms
/// on the loop-back to top.
///
/// The zoom rides *on top of* the per-card depth-stack transform (`StackTransform`): one
/// scale applied to the tower as a whole, so the staircase keeps its internal parallax while
/// the group settles from the zoomed-out hero state into the browsing zoom level. The anchor
/// is the front slot (`StackTransform.frontSlot`) — the dominant front cover holds while the
/// receding covers grow toward the viewer, matching the reference's fixed-point zoom.
struct HeroSettle: Equatable {
    /// Rigid-group scale of the whole tower (≥ `baseScale`, never past `peakScale`).
    var scale: CGFloat
    /// The fixed point the zoom is anchored on, as unit fractions of the tower's bounds
    /// (x, y ∈ [0, 1]). The view converts this to a `UnitPoint` for `scaleEffect(anchor:)`.
    var anchor: CGPoint

    /// Zoomed-out hero scale, at the top with the header fully visible.
    static let baseScale: CGFloat = 1.0
    /// Browsing-level scale once the header has translated off — the tower has settled toward
    /// the viewer. Kept subtle so the parallax, not the zoom, carries the motion.
    static let peakScale: CGFloat = 1.06
    /// Distance-to-rest, as a fraction of viewport height, over which the settle completes —
    /// tuned to roughly when the header has scrolled off (coupled to the translate-off).
    static let settleBand: CGFloat = 0.55
    /// The fixed anchor point: horizontally centred, vertically on the front slot, so the
    /// dominant front cover stays put while the rear of the stack grows toward the viewer.
    static let anchorPoint = CGPoint(x: 0.5, y: StackTransform.frontSlot)

    static let rest = HeroSettle(scale: baseScale, anchor: anchorPoint)

    /// - Parameters:
    ///   - distanceToRest: scroll offset from the top (≥ 0; the resting hero position is 0).
    ///     Negative values (overscroll bounce) clamp to rest.
    ///   - viewportHeight: the scroll viewport height; the settle band scales with it.
    static func at(distanceToRest: CGFloat, viewportHeight: CGFloat) -> HeroSettle {
        guard viewportHeight > 0 else { return .rest }
        let raw = min(1, max(0, distanceToRest) / (viewportHeight * settleBand))
        // Ease-in-out (smoothstep): flat at both ends, steepest mid-band — the reference's
        // "barely moves at start, peak velocity mid, damps to rest" velocity profile.
        let eased = raw * raw * (3 - 2 * raw)
        return HeroSettle(
            scale: baseScale + (peakScale - baseScale) * eased,
            anchor: anchorPoint
        )
    }
}
