import Testing
import CoreGraphics
@testable import Vimarsha

@Suite("StackTransform — depth-stack parallax math")
struct StackTransformTests {
    let viewport: CGFloat = 1000
    var frontY: CGFloat { viewport * StackTransform.frontSlot }

    @Test("card in the front slot is identity")
    func frontSlotIsIdentity() {
        #expect(StackTransform.at(midY: frontY, viewportHeight: viewport) == .identity)
    }

    @Test("card below the front slot (entering from bottom) stays full-size")
    func belowFrontIsIdentity() {
        #expect(StackTransform.at(midY: frontY + 200, viewportHeight: viewport) == .identity)
    }

    @Test("card above the front slot shrinks, dims, desaturates, and tucks upward (negative y)")
    func aboveFrontRecedes() {
        let t = StackTransform.at(midY: frontY - 300, viewportHeight: viewport)
        #expect(t.scale < 1)
        #expect(t.opacity < 1)
        #expect(t.saturation < 1)
        #expect(t.yOffset < 0)
    }

    @Test("recede deepens monotonically with height above the front slot")
    func monotonicRecede() {
        let mid = StackTransform.at(midY: frontY - 200, viewportHeight: viewport)
        let high = StackTransform.at(midY: frontY - 400, viewportHeight: viewport)
        #expect(high.scale < mid.scale)
        #expect(high.opacity < mid.opacity)
        #expect(high.saturation < mid.saturation)
        #expect(high.yOffset < mid.yOffset)
    }

    @Test("far above the front slot, scale and saturation clamp to the rear floors")
    func floorsClamp() {
        // midY far above the viewport top: scale + saturation hold at their floors. Opacity
        // is NOT floored here — it has fully dissolved (see `dissolvesUnderScrim`).
        let t = StackTransform.at(midY: frontY - 5000, viewportHeight: viewport)
        #expect(t.scale == StackTransform.rearScaleFloor)
        #expect(t.saturation == StackTransform.rearSaturationFloor)
    }

    @Test("saturation lerps full→floor on recede and clamps (motion grammar #1 desaturation)")
    func desaturatesOnRecede() {
        #expect(StackTransform.at(midY: frontY, viewportHeight: viewport).saturation == 1)
        let receded = StackTransform.at(midY: frontY - 300, viewportHeight: viewport)
        #expect(receded.saturation > StackTransform.rearSaturationFloor)
        #expect(receded.saturation < 1)
        let deep = StackTransform.at(midY: frontY - 5000, viewportHeight: viewport)
        #expect(deep.saturation == StackTransform.rearSaturationFloor)
    }

    @Test("opacity dissolves below the rear floor to 0 in the last band of travel (recede-and-clip #3)")
    func dissolvesUnderScrim() {
        // Before the dissolve band (travel < frontSlot − dissolveBand = 0.57), opacity
        // holds at/above the floor — the mid-recede plateau is untouched.
        let beforeBand = StackTransform.at(midY: viewport * 0.20, viewportHeight: viewport) // travel 0.52
        #expect(beforeBand.opacity >= StackTransform.rearOpacityFloor - 0.0001)
        // Inside the band, opacity drops BELOW the rear floor (it's dissolving out).
        let nearTop = StackTransform.at(midY: viewport * 0.04, viewportHeight: viewport) // travel 0.68
        #expect(nearTop.opacity < StackTransform.rearOpacityFloor)
        // At the top edge (travel == frontSlot), the cover has fully dissolved into the scrim.
        let atTopEdge = StackTransform.at(midY: 0, viewportHeight: viewport)
        #expect(atTopEdge.opacity < 0.001)
    }

    @Test("transform is continuous at the front slot (no jump as a card crosses it)")
    func continuousAtFrontSlot() {
        let justAbove = StackTransform.at(midY: frontY - 1, viewportHeight: viewport)
        #expect(abs(justAbove.scale - 1) < 0.01)
        #expect(abs(justAbove.opacity - 1) < 0.01)
        #expect(abs(justAbove.yOffset) < 1)
    }

    @Test("zero or negative viewport is safe")
    func degenerateViewport() {
        #expect(StackTransform.at(midY: 100, viewportHeight: 0) == .identity)
        #expect(StackTransform.at(midY: 100, viewportHeight: -50) == .identity)
    }
}
