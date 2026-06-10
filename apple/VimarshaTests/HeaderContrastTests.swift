import Testing
import CoreGraphics
@testable import Vimarsha

/// Settle contrast shift (motion grammar #7). The header type gains contrast as it nears
/// rest (top) and fades as the book tower scrolls up under the glass header plane. Pure
/// function of scroll distance-to-rest — no timers, fully scrubbable.
@Suite("HeaderContrast — settle contrast shift math")
struct HeaderContrastTests {
    let viewport: CGFloat = 800

    @Test("at rest (top) the header is at full baseline contrast")
    func atRestIsBaseline() {
        #expect(HeaderContrast.at(distanceToRest: 0, viewportHeight: viewport) == .rest)
    }

    @Test("overscroll past rest (negative distance) clamps to rest")
    func overscrollClampsToRest() {
        #expect(HeaderContrast.at(distanceToRest: -200, viewportHeight: viewport) == .rest)
    }

    @Test("zero or negative viewport is safe (returns rest)")
    func degenerateViewport() {
        #expect(HeaderContrast.at(distanceToRest: 400, viewportHeight: 0) == .rest)
        #expect(HeaderContrast.at(distanceToRest: 400, viewportHeight: -50) == .rest)
    }

    @Test("contrast dims monotonically as the header scrolls away from rest")
    func dimsMonotonicallyAwayFromRest() {
        let near = HeaderContrast.at(distanceToRest: 100, viewportHeight: viewport)
        let far = HeaderContrast.at(distanceToRest: 300, viewportHeight: viewport)
        #expect(near.ghost > far.ghost)
        #expect(near.label > far.label)
        #expect(near.headline > far.headline)
        // already dimmer than the resting baseline once scrolled at all
        #expect(near.ghost < HeaderContrast.restGhost)
        #expect(near.headline < HeaderContrast.restHeadline)
    }

    @Test("reaches the faded floors at the settle span and clamps beyond it")
    func reachesFloorsAtSettleSpan() {
        let span = viewport * HeaderContrast.settleSpan
        let atSpan = HeaderContrast.at(distanceToRest: span, viewportHeight: viewport)
        #expect(abs(atSpan.ghost - HeaderContrast.ghostFloor) < 1e-6)
        #expect(abs(atSpan.label - HeaderContrast.labelFloor) < 1e-6)
        #expect(abs(atSpan.headline - HeaderContrast.headlineFloor) < 1e-6)
        // no further dimming past the span
        #expect(HeaderContrast.at(distanceToRest: span * 2, viewportHeight: viewport) == atSpan)
    }

    @Test("the ghost title fades furthest — it dims most as the tower scrolls under")
    func ghostDimsMost() {
        #expect(HeaderContrast.ghostFloor < HeaderContrast.labelFloor)
        #expect(HeaderContrast.labelFloor < HeaderContrast.headlineFloor)
    }

    @Test("transform is continuous near rest (no jump as the header leaves the top)")
    func continuousNearRest() {
        let tiny = HeaderContrast.at(distanceToRest: 0.5, viewportHeight: viewport)
        #expect(abs(tiny.headline - HeaderContrast.restHeadline) < 0.01)
        #expect(abs(tiny.ghost - HeaderContrast.restGhost) < 0.01)
    }
}
