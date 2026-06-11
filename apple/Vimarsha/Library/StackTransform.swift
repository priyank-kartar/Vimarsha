import CoreGraphics

/// Depth-stack parallax scroll math (motion grammar #1, apple/CLAUDE.md).
///
/// A card's transform is a pure continuous function of its midY in the scroll viewport —
/// no state, no time, fully scrubbable. The front slot sits low in the viewport; cards
/// above it recede (shrink, dim, **desaturate**, tuck upward behind the stack) and, in the
/// last band of travel under the glass top-scrim, **dissolve** — opacity falls below the
/// rear floor to 0 so a cover melts into the scrim instead of hard-clipping (recede-and-clip
/// #3). Cards at or below the front slot are full-size, full-chroma (the next book rising
/// from the bottom edge).
struct StackTransform: Equatable {
    var scale: CGFloat
    var opacity: CGFloat
    var yOffset: CGFloat
    /// Color saturation (1 = full chroma at the front, lerps toward `rearSaturationFloor` on
    /// recede). Recessed covers desaturate slightly; the front cover is full-chroma
    /// (apple/CLAUDE.md §Physical book rendering).
    var saturation: CGFloat

    static let identity = StackTransform(scale: 1, opacity: 1, yOffset: 0, saturation: 1)

    /// Floors keep the stack from collapsing (apple/CLAUDE.md: clamp rear floors). With
    /// uniform card sizes (ADR-011) depth rides entirely on the transform, so the scale floor
    /// is a touch deeper than the original 0.62 to keep the staircase reading strong.
    static let rearScaleFloor: CGFloat = 0.60
    static let rearOpacityFloor: CGFloat = 0.35
    /// Recede desaturation floor — full chroma (1.0) at the front fades to ~0.85 at the floor.
    static let rearSaturationFloor: CGFloat = 0.85

    /// Front slot position as a fraction of viewport height.
    static let frontSlot: CGFloat = 0.72
    /// How fast cards shrink/dim/desaturate per viewport-height of travel above the front slot.
    static let scaleFalloff: CGFloat = 0.55
    static let opacityFalloff: CGFloat = 0.95
    static let saturationFalloff: CGFloat = 0.25
    /// Upward tuck per viewport-height of travel — receding cards offset up to fake
    /// z-recede (reference analysis: covers "offset up behind the Island").
    static let tuck: CGFloat = 0.16
    /// Final dissolve band, in viewport-heights of travel just below the top edge: across this
    /// last stretch the (already floored) opacity ramps to 0 so the cover melts into the glass
    /// top-scrim (recede-and-clip #3 / glass moment #1) rather than clipping at the floor.
    static let dissolveBand: CGFloat = 0.15

    static func at(midY: CGFloat, viewportHeight: CGFloat) -> StackTransform {
        guard viewportHeight > 0 else { return .identity }
        // 0 at the front slot, positive above it (receding), negative below (entering).
        let travel = (viewportHeight * frontSlot - midY) / viewportHeight
        guard travel > 0 else { return .identity }

        var opacity = max(rearOpacityFloor, 1 - opacityFalloff * travel)
        // Dissolve under the scrim: over the last `dissolveBand` of travel (the cover passing
        // beneath the glass top-scrim, ending at the top edge where travel == frontSlot), fade
        // the floored opacity to 0. Below the band the mid-recede plateau is untouched.
        let dissolveStart = frontSlot - dissolveBand
        if travel > dissolveStart {
            let d = min(1, (travel - dissolveStart) / dissolveBand)
            opacity *= (1 - d)
        }

        return StackTransform(
            scale: max(rearScaleFloor, 1 - scaleFalloff * travel),
            opacity: opacity,
            yOffset: -(tuck * travel * viewportHeight),
            saturation: max(rearSaturationFloor, 1 - saturationFalloff * travel)
        )
    }
}
