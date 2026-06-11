import CoreGraphics

/// The *rendered* top edge of a tower card (V37).
///
/// Tower cards draw under render-time `visualEffect` transforms — the depth-stack recede
/// (`StackTransform`), the slot-emit rise (`SlotEmit`) and the focus promotion bump, all
/// scaled about the card's **bottom edge** and then y-offset — but `GeometryReader`
/// preferences report the LAYOUT frame. The V24 focus-affordance anchoring used those layout
/// tops, so the anchor drifted from where the covers actually drew and the metadata reveal
/// straddled the cover seam (ui-audit round 1, blocker). This recomputes the same pure
/// transform chain to map a layout frame to its visual top edge — stateless and scrubbable,
/// like the transforms it mirrors.
enum CardVisualTop {
    /// - Parameters:
    ///   - layoutFrame: the card's untransformed frame in the scroll viewport.
    ///   - viewportHeight: the scroll viewport height.
    ///   - promotion: the card's eased focus emphasis (`BookFocus.promotion`); 0 for
    ///     unfocused cards.
    /// - Returns: the y of the card's rendered top edge in viewport coordinates.
    static func at(layoutFrame: CGRect, viewportHeight: CGFloat, promotion: CGFloat = 0) -> CGFloat {
        guard viewportHeight > 0 else { return layoutFrame.minY }
        let t = StackTransform.at(midY: layoutFrame.midY, viewportHeight: viewportHeight)
        let emit = SlotEmit.at(midY: layoutFrame.midY, viewportHeight: viewportHeight)
        // Mirrors the card's visualEffect chain: one composed scale about the bottom edge
        // (the bottom stays put), then the recede tuck + emit sink translate the whole card.
        let scale = t.scale * emit.scale * (1 + promotion * BookFocus.scaleBoost)
        return layoutFrame.maxY + t.yOffset + emit.yOffset - layoutFrame.height * scale
    }
}
