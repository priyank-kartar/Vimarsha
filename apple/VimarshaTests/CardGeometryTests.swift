import Testing
import CoreGraphics
@testable import Vimarsha

@Suite("CardGeometry — uniform book-card sizing (ADR-011)")
struct CardGeometryTests {
    @Test("width scales with the viewport while below the cap")
    func widthScalesBelowCap() {
        let w = CardGeometry.width(forViewportWidth: 400)
        #expect(w == 400 * CardGeometry.widthFraction)
    }

    @Test("width clamps to the cap on wide viewports")
    func widthClampsToCap() {
        // A viewport wide enough that fraction·width would exceed the cap.
        let viewport = CardGeometry.widthCap / CardGeometry.widthFraction + 500
        #expect(CardGeometry.width(forViewportWidth: viewport) == CardGeometry.widthCap)
    }

    @Test("width is monotonic in viewport width up to the cap")
    func widthMonotonic() {
        #expect(CardGeometry.width(forViewportWidth: 300) < CardGeometry.width(forViewportWidth: 500))
    }

    @Test("aspect is a single uniform upright-book constant (~1.5), independent of any book")
    func uniformAspect() {
        #expect(CardGeometry.aspect == 1.5)
    }

    @Test("height is width · aspect, and stack overlap is a fraction of that height")
    func heightAndOverlap() {
        let w = CardGeometry.width(forViewportWidth: 400)
        #expect(CardGeometry.height(forViewportWidth: 400) == w * CardGeometry.aspect)
        // Inter-card spacing is negative (cards tuck) and exactly the overlap fraction of height.
        #expect(CardGeometry.stackSpacing(forViewportWidth: 400)
                == -CardGeometry.height(forViewportWidth: 400) * CardGeometry.stackOverlapFraction)
    }

    @Test("non-positive viewport is safe (never negative)")
    func degenerateViewport() {
        #expect(CardGeometry.width(forViewportWidth: 0) == 0)
        #expect(CardGeometry.width(forViewportWidth: -100) == 0)
    }
}
