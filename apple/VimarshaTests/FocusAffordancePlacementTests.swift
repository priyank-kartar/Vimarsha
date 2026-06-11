import Testing
import CoreGraphics
@testable import Vimarsha

/// `FocusAffordancePlacement` (V24): the focus metadata + glass control cluster must sit just
/// inside the focused cover's visible bottom — above the next book that occludes it — not
/// float at the viewport bottom over the next cover. Pure padding math, scrubbable, clamped.
@Suite("FocusAffordancePlacement — cover-anchored bottom padding")
struct FocusAffordancePlacementTests {
    private let vh: CGFloat = 800

    @Test("degenerate viewport → the resting margin")
    func degenerateViewport() {
        #expect(FocusAffordancePlacement.bottomPadding(nextTopY: 100, viewportHeight: 0)
            == FocusAffordancePlacement.margin)
    }

    @Test("front-most focused book (no next book) → rests at the bottom margin")
    func noNextBook() {
        #expect(FocusAffordancePlacement.bottomPadding(nextTopY: nil, viewportHeight: vh)
            == FocusAffordancePlacement.margin)
    }

    @Test("focused cover bottom off-screen (next book below the fold) → bottom margin")
    func nextBookBelowFold() {
        // Next book's top edge is below the viewport → nothing to clear, rest at the margin.
        let p = FocusAffordancePlacement.bottomPadding(nextTopY: vh + 120, viewportHeight: vh)
        #expect(p == FocusAffordancePlacement.margin)
    }

    @Test("next book visible high up → the cluster lifts to sit above it")
    func liftsAboveVisibleNextBook() {
        let nextTop = vh * 0.6
        let p = FocusAffordancePlacement.bottomPadding(nextTopY: nextTop, viewportHeight: vh)
        // Anchored `insetAboveNext` above the next book's top edge.
        let expected = vh - (nextTop - FocusAffordancePlacement.insetAboveNext)
        #expect(abs(p - expected) < 0.001)
        #expect(p > FocusAffordancePlacement.margin)
    }

    @Test("a next book crowding the top is clamped — never lifts past mid-viewport")
    func clampsAtMaxLift() {
        let p = FocusAffordancePlacement.bottomPadding(nextTopY: vh * 0.1, viewportHeight: vh)
        #expect(p == vh * FocusAffordancePlacement.maxLift)
    }

    @Test("never drops below the resting margin")
    func neverBelowMargin() {
        // Next book at the very bottom edge → padding would be tiny; floored at the margin.
        let p = FocusAffordancePlacement.bottomPadding(nextTopY: vh - 2, viewportHeight: vh)
        #expect(p >= FocusAffordancePlacement.margin)
    }

    @Test("monotonic: a higher next book lifts the cluster at least as much")
    func monotonicLift() {
        let high = FocusAffordancePlacement.bottomPadding(nextTopY: vh * 0.5, viewportHeight: vh)
        let low = FocusAffordancePlacement.bottomPadding(nextTopY: vh * 0.7, viewportHeight: vh)
        #expect(high >= low)
    }

    // MARK: maxHeight — the hard clamp inside the focused cover's own bounds (V37)

    @Test("unmeasured focused top → bounded only by the anchor (full height above the padding)")
    func maxHeightWithoutFocusedTop() {
        let padding = FocusAffordancePlacement.margin
        let h = FocusAffordancePlacement.maxHeight(
            focusedTopY: nil, bottomPadding: padding, viewportHeight: vh
        )
        #expect(h == vh - padding)
    }

    @Test("focused top visible → height runs from just below it down to the anchor")
    func maxHeightInsideFocusedCover() {
        let focusedTop = vh * 0.55
        let padding: CGFloat = 120
        let h = FocusAffordancePlacement.maxHeight(
            focusedTopY: focusedTop, bottomPadding: padding, viewportHeight: vh
        )
        let expected = (vh - padding) - focusedTop - FocusAffordancePlacement.insetBelowTop
        #expect(abs(h - expected) < 0.001)
        #expect(h > 0)
    }

    @Test("degenerate band (focused top at/below the anchor) clamps to zero, never negative")
    func maxHeightNeverNegative() {
        let padding: CGFloat = 200
        let h = FocusAffordancePlacement.maxHeight(
            focusedTopY: vh - 100, bottomPadding: padding, viewportHeight: vh
        )
        #expect(h == 0)
    }

    @Test("monotonic: a higher focused top (taller visible band) allows at least as much height")
    func maxHeightMonotonic() {
        let tall = FocusAffordancePlacement.maxHeight(
            focusedTopY: vh * 0.4, bottomPadding: 100, viewportHeight: vh
        )
        let short = FocusAffordancePlacement.maxHeight(
            focusedTopY: vh * 0.6, bottomPadding: 100, viewportHeight: vh
        )
        #expect(tall >= short)
    }

    @Test("degenerate viewport → zero height (nothing to place)")
    func maxHeightDegenerateViewport() {
        let h = FocusAffordancePlacement.maxHeight(
            focusedTopY: 100, bottomPadding: 28, viewportHeight: 0
        )
        #expect(h == 0)
    }
}
