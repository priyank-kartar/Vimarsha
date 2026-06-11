import Testing
import CoreGraphics
@testable import Vimarsha

/// Glass top-scrim visibility math (glass moment #1 / motion grammar #3). The scrim must be
/// **contextual** — invisible at rest (the V27 finding: it used to read as an empty pill
/// dangling at the top), fading in only while a cover is actually passing under the top
/// region and fading back out once it has gone. Visibility is a pure continuous function of
/// how close the nearest cover's top edge is to the top of the viewport — scroll-driven, no
/// timers.
@Suite("TopScrim — contextual glass scrim visibility")
struct TopScrimTests {
    let vh: CGFloat = 1000

    @Test("degenerate viewport is safe (invisible)")
    func degenerate() {
        #expect(TopScrim.opacity(cardTopEdges: [0, -10], viewportHeight: 0) == 0)
    }

    @Test("nothing measured → invisible (Reduce Motion flat list / before first layout)")
    func emptyInvisible() {
        #expect(TopScrim.opacity(cardTopEdges: [], viewportHeight: vh) == 0)
    }

    @Test("at rest the nearest cover sits below the top region → fully invisible")
    func restInvisible() {
        // Rest: the topmost cover's top edge is ~0.26vh down — below `enterFraction`.
        let o = TopScrim.opacity(
            cardTopEdges: [0.26 * vh, 0.55 * vh, 0.9 * vh], viewportHeight: vh
        )
        #expect(o == 0)
    }

    @Test("a cover approaching the top fades the scrim in (0 → 1)")
    func fadesInOnApproach() {
        let enter = TopScrim.enterFraction * vh
        let peak = TopScrim.peakFraction * vh
        #expect(TopScrim.contribution(topEdge: enter, viewportHeight: vh) == 0)
        let mid = TopScrim.contribution(topEdge: (enter + peak) / 2, viewportHeight: vh)
        #expect(mid > 0.4 && mid < 0.6)
        #expect(abs(TopScrim.contribution(topEdge: peak, viewportHeight: vh) - 1) < 1e-9)
    }

    @Test("a cover at/above the top is fully scrimmed (it is dissolving into the glass)")
    func fullWhileDissolving() {
        #expect(abs(TopScrim.contribution(topEdge: 0, viewportHeight: vh) - 1) < 1e-9)
        let aboveMid = (TopScrim.peakFraction + TopScrim.exitFraction) / 2 * vh
        let c = TopScrim.contribution(topEdge: aboveMid, viewportHeight: vh)
        #expect(c > 0.4 && c < 0.6)   // half-way back out
    }

    @Test("a cover fully passed above the top → scrim faded back out")
    func fadesOutAfter() {
        let exit = TopScrim.exitFraction * vh
        #expect(TopScrim.contribution(topEdge: exit, viewportHeight: vh) == 0)
        #expect(TopScrim.contribution(topEdge: exit - 50, viewportHeight: vh) == 0)
    }

    @Test("visibility takes the strongest cover in the window (nearest dominates)")
    func strongestWins() {
        // one cover dissolving at the top (→ 1), the rest far below (→ 0)
        let o = TopScrim.opacity(cardTopEdges: [0.5 * vh, 0.0, 0.8 * vh], viewportHeight: vh)
        #expect(abs(o - 1) < 1e-9)
    }

    @Test("opacity stays clamped to [0, 1] across a full scroll sweep")
    func clamped() {
        for y in stride(from: -0.5 * vh, through: vh, by: 0.02 * vh) {
            let o = TopScrim.opacity(cardTopEdges: [y], viewportHeight: vh)
            #expect(o >= 0 && o <= 1)
        }
    }
}
