import Testing
import CoreGraphics
@testable import Vimarsha

/// Book-focus / grow-to-front math (motion grammar #2). Which card owns the front slot, and
/// how settled it is — a pure function of each card's viewport midY. No timers, scrubbable.
@Suite("BookFocus — scroll-settle / grow-to-front math")
struct BookFocusTests {
    let viewport: CGFloat = 1000
    var slotY: CGFloat { viewport * StackTransform.frontSlot }
    var window: CGFloat { viewport * BookFocus.settleWindow }

    @Test("no measured cards yields no focus")
    func emptyIsNone() {
        #expect(BookFocus.at(midYs: [:], viewportHeight: viewport) == .none)
    }

    @Test("zero or negative viewport is safe (no focus)")
    func degenerateViewport() {
        #expect(BookFocus.at(midYs: [0: 720], viewportHeight: 0) == .none)
        #expect(BookFocus.at(midYs: [0: 720], viewportHeight: -50) == .none)
    }

    @Test("a card sitting exactly on the front slot is focused at full emphasis")
    func onSlotIsFullEmphasis() {
        let focus = BookFocus.at(midYs: [3: slotY], viewportHeight: viewport)
        #expect(focus.index == 3)
        #expect(abs(focus.emphasis - 1) < 1e-6)
    }

    @Test("a card beyond the settle window owns no focus")
    func beyondWindowIsNone() {
        let focus = BookFocus.at(midYs: [2: slotY - window - 1], viewportHeight: viewport)
        #expect(focus == .none)
    }

    @Test("the card nearest the front slot wins among several")
    func nearestWins() {
        let focus = BookFocus.at(
            midYs: [0: slotY - 300, 1: slotY - 40, 2: slotY + 160],
            viewportHeight: viewport
        )
        #expect(focus.index == 1)
        #expect(focus.emphasis > 0)
    }

    @Test("emphasis falls off monotonically as the card moves off the slot")
    func emphasisFallsOff() {
        let onSlot = BookFocus.at(midYs: [1: slotY], viewportHeight: viewport)
        let near = BookFocus.at(midYs: [1: slotY + window * 0.25], viewportHeight: viewport)
        let far = BookFocus.at(midYs: [1: slotY + window * 0.75], viewportHeight: viewport)
        #expect(onSlot.emphasis > near.emphasis)
        #expect(near.emphasis > far.emphasis)
        #expect(far.emphasis > 0)
    }

    @Test("emphasis is symmetric above/below the slot (distance, not direction)")
    func symmetricAboutSlot() {
        let above = BookFocus.at(midYs: [1: slotY - window * 0.5], viewportHeight: viewport)
        let below = BookFocus.at(midYs: [1: slotY + window * 0.5], viewportHeight: viewport)
        #expect(abs(above.emphasis - below.emphasis) < 1e-6)
    }

    @Test("promotion is eased (≤ emphasis in the interior, exact at the endpoints)")
    func promotionEased() {
        let onSlot = BookFocus.at(midYs: [0: slotY], viewportHeight: viewport)
        #expect(abs(onSlot.promotion - 1) < 1e-6)            // emphasis 1 → promotion 1
        #expect(BookFocus.none.promotion == 0)               // emphasis 0 → promotion 0
        let mid = BookFocus.at(midYs: [0: slotY + window * 0.5], viewportHeight: viewport)
        #expect(mid.promotion < mid.emphasis)                // strictly eased in between
        #expect(mid.promotion > 0)
    }

    @Test("focus is continuous near the slot (no jump as a card settles on)")
    func continuousNearSlot() {
        let justOff = BookFocus.at(midYs: [0: slotY - 1], viewportHeight: viewport)
        #expect(justOff.index == 0)
        #expect(abs(justOff.emphasis - 1) < 0.01)
    }
}
