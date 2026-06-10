import CoreGraphics

/// Lensing drag puck geometry (glass moment #2 / motion grammar #6, apple/CLAUDE.md).
///
/// A small glass drop that appears on finger-down and tracks the active drag, refracting
/// the cover beneath it (the reference's translucent touch dot, elevated to Liquid Glass).
/// The geometry is a pure continuous function of the drag location + speed — no state, no
/// time, fully scrubbable. The view (`LensingPuckView`) only renders this value; appearance
/// and disappearance are animated there.
struct LensingPuck: Equatable {
    /// Where to draw the puck, in the scroll view's local space.
    var center: CGPoint
    var diameter: CGFloat
    /// Fades 0 → 1 on finger-down, 1 → 0 on release (the view animates the transition).
    var opacity: CGFloat

    /// No active drag — fully transparent.
    static let hidden = LensingPuck(center: .zero, diameter: 0, opacity: 0)

    /// Resting lens size.
    static let baseDiameter: CGFloat = 96
    /// Raise the lens above the touch point so the finger doesn't occlude the refraction.
    static let lift: CGFloat = 30
    /// Velocity reactivity: faster drags swell the lens slightly (specular-sheen adjacent,
    /// grammar #6) before clamping at `maxDiameter`.
    static let speedDiameterGain: CGFloat = 0.04
    static let maxDiameter: CGFloat = 132

    /// The puck for an active drag at `location` moving at `dragSpeed` (points/sec),
    /// clamped to sit fully inside `bounds`.
    static func at(location: CGPoint, dragSpeed: CGFloat = 0, in bounds: CGSize) -> LensingPuck {
        let diameter = min(maxDiameter, baseDiameter + speedDiameterGain * dragSpeed)
        let radius = diameter / 2
        let lifted = CGPoint(x: location.x, y: location.y - lift)
        return LensingPuck(
            center: CGPoint(
                x: clamp(lifted.x, radius, bounds.width - radius),
                y: clamp(lifted.y, radius, bounds.height - radius)
            ),
            diameter: diameter,
            opacity: 1
        )
    }

    /// Clamp to `[lower, upper]`, tolerating a degenerate range (bounds smaller than the
    /// puck) by collapsing to `lower` rather than inverting.
    private static func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), max(lower, upper))
    }
}
