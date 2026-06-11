import Testing
import CoreGraphics
@testable import Vimarsha

/// `DebossDodge` (V45, ui-audit round 3): at XXXL rest the glass control cluster renders
/// directly on the focused cover's debossed label — controls over glyphs. The dodge maps the
/// cluster's measured viewport rect into the cover's local space and locally fades only the
/// deboss lines the glass actually covers, with a soft feather, at a strength that saturates
/// with the cluster's own visibility. Pure math, scrubbable — no state, no time.
@Suite("DebossDodge — the deboss yields to the glass cluster")
struct DebossDodgeTests {
    @Test("viewport → cover-local mapping divides out the cover's rendered scale")
    func bandMapsThroughCoverTransform() throws {
        // Cover rendered at top 500 with scale 2: a cluster at viewport 600…700 sits at
        // cover-local 50…100.
        let band = try #require(DebossDodge.band(
            clusterTop: 600, clusterBottom: 700, clusterOpacity: 1,
            coverVisualTop: 500, coverScale: 2
        ))
        #expect(abs(band.top - 50) < 0.001)
        #expect(abs(band.bottom - 100) < 0.001)
    }

    @Test("strength saturates at the cluster's interaction threshold")
    func strengthSaturates() throws {
        // Fully visible cluster → full dodge.
        let full = try #require(DebossDodge.band(
            clusterTop: 0, clusterBottom: 10, clusterOpacity: 1,
            coverVisualTop: 0, coverScale: 1
        ))
        #expect(full.strength == 1)
        // At the saturation point the dodge is already full — by the time the controls are
        // interactive the print beneath them is gone.
        let atThreshold = try #require(DebossDodge.band(
            clusterTop: 0, clusterBottom: 10,
            clusterOpacity: DebossDodge.strengthSaturationOpacity,
            coverVisualTop: 0, coverScale: 1
        ))
        #expect(atThreshold.strength == 1)
        // Below it the dodge eases in (smoothstep midpoint = half strength).
        let half = try #require(DebossDodge.band(
            clusterTop: 0, clusterBottom: 10,
            clusterOpacity: DebossDodge.strengthSaturationOpacity / 2,
            coverVisualTop: 0, coverScale: 1
        ))
        #expect(abs(half.strength - 0.5) < 0.001)
    }

    @Test("an invisible or degenerate cluster produces no dodge")
    func degenerateInputsAreNil() {
        #expect(DebossDodge.band(
            clusterTop: 0, clusterBottom: 10, clusterOpacity: 0,
            coverVisualTop: 0, coverScale: 1
        ) == nil)
        #expect(DebossDodge.band(
            clusterTop: 10, clusterBottom: 10, clusterOpacity: 1,
            coverVisualTop: 0, coverScale: 1
        ) == nil)
        #expect(DebossDodge.band(
            clusterTop: 0, clusterBottom: 10, clusterOpacity: 1,
            coverVisualTop: 0, coverScale: 0
        ) == nil)
    }

    @Test("mask alpha: opaque outside the feather, 1−strength inside the band, linear ramps between")
    func alphaIsPiecewiseLinear() {
        let band = DebossDodge.Band(top: 60, bottom: 100, strength: 1)
        let f = DebossDodge.feather
        #expect(DebossDodge.alpha(at: 60 - f - 1, band: band) == 1)        // above the feather
        #expect(DebossDodge.alpha(at: 60 - f / 2, band: band) == 0.5)      // mid fade-out
        #expect(DebossDodge.alpha(at: 80, band: band) == 0)                // fully dodged
        #expect(DebossDodge.alpha(at: 100 + f / 2, band: band) == 0.5)     // mid fade-in
        #expect(DebossDodge.alpha(at: 100 + f + 1, band: band) == 1)       // below the feather
    }

    @Test("partial strength only dips the alpha partway")
    func partialStrengthPartialDip() {
        let band = DebossDodge.Band(top: 60, bottom: 100, strength: 0.5)
        #expect(DebossDodge.alpha(at: 80, band: band) == 0.5)
        #expect(DebossDodge.alpha(at: 0, band: band) == 1)
    }

    @Test("mask stops are clamped to the cover and non-decreasing")
    func maskStopsClampedSorted() {
        // Band overflowing the cover bottom: every location stays in 0…1 and ordered, so
        // the gradient is always renderable.
        let band = DebossDodge.Band(top: 120, bottom: 160, strength: 1)
        let stops = DebossDodge.maskStops(band: band, coverHeight: 137)
        #expect(!stops.isEmpty)
        for stop in stops {
            #expect(stop.location >= 0 && stop.location <= 1)
            #expect(stop.alpha >= 0 && stop.alpha <= 1)
        }
        for (a, b) in zip(stops, stops.dropFirst()) {
            #expect(a.location <= b.location)
        }
        // The cover's top edge is untouched; the cover's bottom edge (inside the band) is
        // fully open (alpha 0).
        #expect(stops.first?.alpha == 1)
        #expect(stops.last?.location == 1)
        #expect(stops.last?.alpha == 0)
    }

    @Test("degenerate cover height yields no stops")
    func degenerateCoverHeight() {
        let band = DebossDodge.Band(top: 10, bottom: 20, strength: 1)
        #expect(DebossDodge.maskStops(band: band, coverHeight: 0).isEmpty)
    }
}
