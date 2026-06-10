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

    @Test("card above the front slot shrinks, dims, and tucks upward (negative y)")
    func aboveFrontRecedes() {
        let t = StackTransform.at(midY: frontY - 300, viewportHeight: viewport)
        #expect(t.scale < 1)
        #expect(t.opacity < 1)
        #expect(t.yOffset < 0)
    }

    @Test("recede deepens monotonically with height above the front slot")
    func monotonicRecede() {
        let mid = StackTransform.at(midY: frontY - 200, viewportHeight: viewport)
        let high = StackTransform.at(midY: frontY - 400, viewportHeight: viewport)
        #expect(high.scale < mid.scale)
        #expect(high.opacity < mid.opacity)
        #expect(high.yOffset < mid.yOffset)
    }

    @Test("far above the front slot, scale and opacity clamp to the rear floors")
    func floorsClamp() {
        let t = StackTransform.at(midY: frontY - 5000, viewportHeight: viewport)
        #expect(t.scale == StackTransform.rearScaleFloor)
        #expect(t.opacity == StackTransform.rearOpacityFloor)
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
