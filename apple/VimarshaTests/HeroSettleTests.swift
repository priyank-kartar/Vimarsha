import Testing
import CoreGraphics
@testable import Vimarsha

/// Coupled scroll+zoom hero settle math (motion grammar #5). As the editorial header
/// translates off the top, the whole book tower scales toward the viewer **as one rigid
/// group** — a pure continuous function of the scroll distance-to-rest, ease-in-out, no
/// timers, fully scrubbable, anchored so a chosen point (the front slot) stays fixed.
@Suite("HeroSettle — coupled scroll+zoom hero settle math")
struct HeroSettleTests {
    let viewport: CGFloat = 1000

    @Test("zero or negative viewport is safe (rest)")
    func degenerateViewport() {
        #expect(HeroSettle.at(distanceToRest: 300, viewportHeight: 0) == .rest)
        #expect(HeroSettle.at(distanceToRest: 300, viewportHeight: -50) == .rest)
    }

    @Test("at the top (distance 0) the tower sits at base scale — the zoomed-out hero state")
    func atTopIsBaseScale() {
        let h = HeroSettle.at(distanceToRest: 0, viewportHeight: viewport)
        #expect(abs(h.scale - HeroSettle.baseScale) < 1e-9)
    }

    @Test("negative distance (overscroll bounce) clamps to rest")
    func overscrollClampsToRest() {
        #expect(HeroSettle.at(distanceToRest: -120, viewportHeight: viewport) == .rest)
    }

    @Test("past the settle band the tower holds at peak scale (zoomed into the browsing level)")
    func pastBandHoldsAtPeak() {
        let atBand = HeroSettle.at(distanceToRest: viewport * HeroSettle.settleBand, viewportHeight: viewport)
        let beyond = HeroSettle.at(distanceToRest: viewport * 2, viewportHeight: viewport)
        #expect(abs(atBand.scale - HeroSettle.peakScale) < 1e-9)
        #expect(abs(beyond.scale - HeroSettle.peakScale) < 1e-9)
    }

    @Test("the zoom grows monotonically across the settle band (no reversal)")
    func monotonicGrowth() {
        var last = HeroSettle.at(distanceToRest: 0, viewportHeight: viewport).scale
        for d in stride(from: CGFloat(0), through: viewport * HeroSettle.settleBand, by: 20) {
            let s = HeroSettle.at(distanceToRest: d, viewportHeight: viewport).scale
            #expect(s >= last - 1e-9)
            last = s
        }
    }

    @Test("scale never overshoots the peak (rigid group, no bounce)")
    func noOvershoot() {
        for d in stride(from: CGFloat(-100), through: viewport * 2, by: 25) {
            let s = HeroSettle.at(distanceToRest: d, viewportHeight: viewport).scale
            #expect(s >= HeroSettle.baseScale - 1e-9)
            #expect(s <= HeroSettle.peakScale + 1e-9)
        }
    }

    @Test("ease-in-out: barely moves at the start, accelerates toward the middle")
    func easeInOutShape() {
        // Smoothstep is flat at both ends and steepest at the centre. Near the start, the
        // covered fraction of the zoom should trail the linear progress (slow start).
        let band = viewport * HeroSettle.settleBand
        let early = HeroSettle.at(distanceToRest: band * 0.2, viewportHeight: viewport)
        let earlyFraction = (early.scale - HeroSettle.baseScale) / (HeroSettle.peakScale - HeroSettle.baseScale)
        #expect(earlyFraction < 0.2)                          // eased-in: behind linear

        // The band centre sits exactly at the linear midpoint (smoothstep is symmetric).
        let mid = HeroSettle.at(distanceToRest: band * 0.5, viewportHeight: viewport)
        let midFraction = (mid.scale - HeroSettle.baseScale) / (HeroSettle.peakScale - HeroSettle.baseScale)
        #expect(abs(midFraction - 0.5) < 1e-6)
    }

    @Test("the zoom is anchored on the front slot so that chosen point stays fixed")
    func anchoredOnFrontSlot() {
        let h = HeroSettle.at(distanceToRest: 200, viewportHeight: viewport)
        #expect(abs(h.anchor.x - 0.5) < 1e-9)
        #expect(abs(h.anchor.y - StackTransform.frontSlot) < 1e-9)
    }

    @Test("the settle band scales with the viewport (a fraction of its height, not pixels)")
    func bandScalesWithViewport() {
        // Same fractional distance into the band → same scale at any viewport height.
        let a = HeroSettle.at(distanceToRest: 500 * HeroSettle.settleBand * 0.5, viewportHeight: 500)
        let b = HeroSettle.at(distanceToRest: 1500 * HeroSettle.settleBand * 0.5, viewportHeight: 1500)
        #expect(abs(a.scale - b.scale) < 1e-9)
    }
}
