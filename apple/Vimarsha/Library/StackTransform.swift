import CoreGraphics

/// Depth-stack parallax scroll math (motion grammar #1, apple/CLAUDE.md).
///
/// A card's transform is a pure continuous function of its midY in the scroll viewport —
/// no state, no time, fully scrubbable. The front slot sits low in the viewport; cards
/// above it recede (shrink, dim, tuck upward behind the stack — toward the top scrim they
/// dissolve under); cards at or below the front slot are full-size (the next book rising
/// from the bottom edge).
struct StackTransform: Equatable {
    var scale: CGFloat
    var opacity: CGFloat
    var yOffset: CGFloat

    static let identity = StackTransform(scale: 1, opacity: 1, yOffset: 0)

    /// Floors keep the stack from collapsing (apple/CLAUDE.md: clamp rear floors).
    static let rearScaleFloor: CGFloat = 0.62
    static let rearOpacityFloor: CGFloat = 0.35

    /// Front slot position as a fraction of viewport height.
    static let frontSlot: CGFloat = 0.72
    /// How fast cards shrink/dim per viewport-height of travel above the front slot.
    static let scaleFalloff: CGFloat = 0.55
    static let opacityFalloff: CGFloat = 0.95
    /// Upward tuck per viewport-height of travel — receding cards offset up to fake
    /// z-recede (reference analysis: covers "offset up behind the Island").
    static let tuck: CGFloat = 0.16

    static func at(midY: CGFloat, viewportHeight: CGFloat) -> StackTransform {
        guard viewportHeight > 0 else { return .identity }
        // 0 at the front slot, positive above it (receding), negative below (entering).
        let travel = (viewportHeight * frontSlot - midY) / viewportHeight
        guard travel > 0 else { return .identity }
        return StackTransform(
            scale: max(rearScaleFloor, 1 - scaleFalloff * travel),
            opacity: max(rearOpacityFloor, 1 - opacityFalloff * travel),
            yOffset: -(tuck * travel * viewportHeight)
        )
    }
}
