import Testing
import CoreGraphics
@testable import Vimarsha

/// `CardVisualTop` (V37): the *rendered* top edge of a tower card. The cards draw under
/// `visualEffect` transforms (StackTransform recede + SlotEmit rise + the focus promotion
/// bump, all scaled about the bottom edge then y-offset), but `GeometryReader` reports the
/// LAYOUT frame — anchoring the focus affordances to layout tops is what let the metadata
/// reveal straddle the cover seam (ui-audit round 1, blocker). This maps layout → visual.
@Suite("CardVisualTop — layout frame → rendered top edge")
struct CardVisualTopTests {
    private let vh: CGFloat = 874
    /// Realistic card height for a 402-wide viewport (CardGeometry: 0.70·402 ≈ 281 wide,
    /// aspect 0.50 → ≈ 141 tall).
    private let cardHeight: CGFloat = 141

    private func frame(midY: CGFloat) -> CGRect {
        CGRect(x: 0, y: midY - cardHeight / 2, width: 281, height: cardHeight)
    }

    @Test("degenerate viewport → the layout top, untransformed")
    func degenerateViewport() {
        let f = frame(midY: 400)
        #expect(CardVisualTop.at(layoutFrame: f, viewportHeight: 0) == f.minY)
    }

    @Test("a card exactly on the front slot renders at its layout top (both transforms identity)")
    func atSlotIsIdentity() {
        let f = frame(midY: vh * StackTransform.frontSlot)
        let top = CardVisualTop.at(layoutFrame: f, viewportHeight: vh)
        #expect(abs(top - f.minY) < 0.001)
    }

    @Test("a card below the slot (still emitting) renders LOWER than its layout top")
    func belowSlotSinksTowardShelf() {
        // SlotEmit sinks it toward the shelf anchor and shrinks it about the bottom edge —
        // both push the rendered top edge down-screen.
        let f = frame(midY: vh * 0.86)
        let top = CardVisualTop.at(layoutFrame: f, viewportHeight: vh)
        #expect(top > f.minY)
    }

    @Test("a receding card (above the slot) renders HIGHER than its layout top")
    func aboveSlotTucksUp() {
        // The recede tuck outruns the bottom-anchored shrink for realistic card heights,
        // so the rendered top moves up-screen.
        let f = frame(midY: vh * 0.45)
        let top = CardVisualTop.at(layoutFrame: f, viewportHeight: vh)
        #expect(top < f.minY)
    }

    @Test("the focus promotion bump raises the rendered top (bottom-anchored grow)")
    func promotionRaisesTop() {
        let f = frame(midY: vh * StackTransform.frontSlot)
        let rest = CardVisualTop.at(layoutFrame: f, viewportHeight: vh)
        let promoted = CardVisualTop.at(layoutFrame: f, viewportHeight: vh, promotion: 1)
        #expect(promoted < rest)
        // Exactly the scale-boosted height about the fixed bottom edge.
        #expect(abs((rest - promoted) - cardHeight * BookFocus.scaleBoost) < 0.001)
    }
}
