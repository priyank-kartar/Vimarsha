import Testing
import CoreGraphics
@testable import Vimarsha

/// Slot-emit / staircase fan-up math (motion grammar #4). A cover rises from the bottom
/// shelf anchor (the viewport bottom edge) into its staircase slot as it scrolls up toward
/// the front slot — a pure continuous function of midY, no timers, fully scrubbable. The
/// counterpart to `StackTransform`'s recede above the slot; the two meet at the slot with no
/// jump.
@Suite("SlotEmit — staircase fan-up math")
struct SlotEmitTests {
    let viewport: CGFloat = 1000
    var slotY: CGFloat { viewport * StackTransform.frontSlot }

    @Test("zero or negative viewport is safe (identity)")
    func degenerateViewport() {
        #expect(SlotEmit.at(midY: 500, viewportHeight: 0) == .identity)
        #expect(SlotEmit.at(midY: 500, viewportHeight: -50) == .identity)
    }

    @Test("a card at the front slot has fully arrived (identity)")
    func atFrontSlotIsIdentity() {
        let e = SlotEmit.at(midY: slotY, viewportHeight: viewport)
        #expect(abs(e.scale - 1) < 1e-6)
        #expect(abs(e.opacity - 1) < 1e-6)
        #expect(abs(e.yOffset) < 1e-6)
    }

    @Test("a card above the front slot has already arrived (identity — recede is StackTransform's)")
    func aboveFrontSlotIsIdentity() {
        #expect(SlotEmit.at(midY: slotY - 300, viewportHeight: viewport) == .identity)
    }

    @Test("a card at the viewport bottom edge sits at the shelf anchor (sunk, shrunk, unseen)")
    func atBottomEdgeIsAnchored() {
        let e = SlotEmit.at(midY: viewport, viewportHeight: viewport)
        #expect(abs(e.scale - SlotEmit.anchorScale) < 1e-6)
        #expect(abs(e.opacity - SlotEmit.anchorOpacity) < 1e-6)
        #expect(e.yOffset > 0)                                  // pushed DOWN toward the shelf
        #expect(abs(e.yOffset - SlotEmit.riseFraction * viewport) < 1e-6)
    }

    @Test("below the bottom edge clamps to the anchor (no sinking past the shelf)")
    func belowBottomEdgeClampsToAnchor() {
        let edge = SlotEmit.at(midY: viewport, viewportHeight: viewport)
        let under = SlotEmit.at(midY: viewport + 400, viewportHeight: viewport)
        #expect(under == edge)
    }

    @Test("the cover rises monotonically as its midY climbs from the shelf to the slot")
    func monotonicRise() {
        let low = SlotEmit.at(midY: slotY + 220, viewportHeight: viewport)   // nearer the shelf
        let high = SlotEmit.at(midY: slotY + 80, viewportHeight: viewport)    // nearer the slot
        #expect(high.scale > low.scale)
        #expect(high.opacity > low.opacity)
        #expect(high.yOffset < low.yOffset)                                  // less sink as it rises
    }

    @Test("no overshoot past identity anywhere in the band (springy but no bounce)")
    func noOvershoot() {
        for midY in stride(from: slotY, through: viewport, by: 10) {
            let e = SlotEmit.at(midY: midY, viewportHeight: viewport)
            #expect(e.scale <= 1 + 1e-9)
            #expect(e.scale >= SlotEmit.anchorScale - 1e-9)
            #expect(e.opacity <= 1 + 1e-9)
            #expect(e.opacity >= 0 - 1e-9)
            #expect(e.yOffset >= -1e-9)                                       // never rises past rest
        }
    }

    @Test("the rise is ease-out — past the linear midpoint at the band centre (soft landing)")
    func easeOutFrontLoaded() {
        // Midpoint of the emit band (progress 0.5): midY = (slotY + viewport) / 2.
        let mid = SlotEmit.at(midY: (slotY + viewport) / 2, viewportHeight: viewport)
        let linearScale = SlotEmit.anchorScale + (1 - SlotEmit.anchorScale) * 0.5
        #expect(mid.scale > linearScale)                                     // decelerating into rest
        #expect(mid.opacity > 0.5)
    }

    @Test("transform is continuous at the slot (no jump as a card finishes arriving)")
    func continuousAtSlot() {
        let justBelow = SlotEmit.at(midY: slotY + 1, viewportHeight: viewport)
        #expect(abs(justBelow.scale - 1) < 0.01)
        #expect(abs(justBelow.opacity - 1) < 0.01)
        #expect(abs(justBelow.yOffset) < 1)
    }
}
