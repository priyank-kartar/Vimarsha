import CoreGraphics

/// Glass top-scrim visibility math (glass moment #1 / motion grammar #3, apple/CLAUDE.md
/// §Liquid Glass rules).
///
/// The scrim is the glass region hugging the top safe area that receding covers **dissolve
/// into** instead of hard-clipping. It must be *contextual* (the V27 finding): invisible at
/// rest — so it never reads as an empty pill dangling at the top — fading in only while a
/// cover is actually passing under the top region, and fading back out once the cover has
/// gone.
///
/// Visibility is a pure continuous function of how close the nearest cover's **top edge** is
/// to the top of the viewport: a triangular window per card, the strongest taken across the
/// stack. Scroll-driven (scrubbable), never a timer. The view multiplies this into its own
/// glass tint opacity; the Reduce Transparency matte fallback follows the same rule.
enum TopScrim {
    /// A card whose top edge is at/below this fraction of viewport height begins fading the
    /// scrim in — the cover is approaching the top region from below.
    static let enterFraction: CGFloat = 0.16
    /// Top edge at this fraction (the very top) → the scrim is fully present: the cover is
    /// dissolving under it.
    static let peakFraction: CGFloat = 0.0
    /// Top edge this far ABOVE the top (negative = above the viewport top) → the cover has
    /// fully passed and the scrim has faded back out.
    static let exitFraction: CGFloat = -0.18

    /// One card's contribution to scrim visibility, from its viewport-space top edge (0 = the
    /// top of the viewport). A triangular window: 0 below `enter`, ramping to 1 at `peak`,
    /// then ramping back to 0 by `exit`.
    static func contribution(topEdge: CGFloat, viewportHeight vh: CGFloat) -> CGFloat {
        guard vh > 0 else { return 0 }
        let enter = enterFraction * vh
        let peak = peakFraction * vh
        let exit = exitFraction * vh
        if topEdge >= enter || topEdge <= exit { return 0 }
        if topEdge >= peak {
            return (enter - topEdge) / (enter - peak)   // entering: enter → peak  ⇒ 0 → 1
        }
        return (topEdge - exit) / (peak - exit)         // exiting:  peak → exit  ⇒ 1 → 0
    }

    /// Scrim visibility ∈ [0, 1]: the strongest single cover currently in the dissolve window.
    /// Empty input (Reduce Motion flat list, or before the first layout pass) → 0 (invisible).
    static func opacity(cardTopEdges: [CGFloat], viewportHeight vh: CGFloat) -> CGFloat {
        let best = cardTopEdges.map { contribution(topEdge: $0, viewportHeight: vh) }.max() ?? 0
        return min(1, max(0, best))
    }
}
