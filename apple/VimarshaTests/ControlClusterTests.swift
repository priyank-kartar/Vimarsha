import Testing
import CoreGraphics
@testable import Vimarsha

/// Glass control cluster math (glass moment #5 / apple/CLAUDE.md §UI map state 2): the four
/// controls morph out of the focused cover and re-absorb on scroll. `emerge` is a pure,
/// scrubbable function of the focus promotion; per-control offsets fan the melded blob apart.
@Suite("ControlCluster — emerge / fan-out math")
struct ControlClusterTests {
    @Test("the four controls are play, figures, memo, discuss in order")
    func controlOrder() {
        #expect(ControlCluster.Control.allCases == [.play, .figures, .memo, .discuss])
    }

    @Test("promotion at or below the threshold leaves the cluster fully absorbed")
    func belowThresholdIsAbsorbed() {
        #expect(ControlCluster.at(promotion: 0) == .absorbed)
        #expect(ControlCluster.at(promotion: ControlCluster.emergeThreshold) == .absorbed)
        #expect(ControlCluster.at(promotion: ControlCluster.emergeThreshold - 0.05).emerge == 0)
    }

    @Test("full promotion fully emerges the cluster")
    func fullPromotionFullyEmerges() {
        #expect(abs(ControlCluster.at(promotion: 1).emerge - 1) < 1e-6)
    }

    @Test("emerge clamps to 0…1 and never inverts past full promotion")
    func emergeClamped() {
        let over = ControlCluster.at(promotion: 1.5)
        #expect(over.emerge >= 0 && over.emerge <= 1)
        #expect(abs(over.emerge - 1) < 1e-6)
    }

    @Test("emerge rises monotonically with promotion across the active band")
    func emergeMonotonic() {
        let low = ControlCluster.at(promotion: 0.5)
        let mid = ControlCluster.at(promotion: 0.7)
        let high = ControlCluster.at(promotion: 0.9)
        #expect(low.emerge < mid.emerge)
        #expect(mid.emerge < high.emerge)
        #expect(low.emerge > 0)
    }

    @Test("emerge is eased (smoothstep) — strictly between 0 and 1 mid-band")
    func emergeEased() {
        let mid = ControlCluster.at(promotion: (1 + ControlCluster.emergeThreshold) / 2)
        #expect(mid.emerge > 0 && mid.emerge < 1)
    }

    @Test("controls are melded at the centre when absorbed (zero offset)")
    func meldedWhenAbsorbed() {
        let c = ControlCluster.absorbed
        for i in 0..<4 {
            #expect(c.xOffset(forControl: i, of: 4, spacing: 64) == 0)
        }
    }

    @Test("offsets fan symmetrically about the centre and sum to zero")
    func fanSymmetric() {
        let c = ControlCluster.at(promotion: 1)
        let offsets = (0..<4).map { c.xOffset(forControl: $0, of: 4, spacing: 64) }
        #expect(abs(offsets.reduce(0, +)) < 1e-6)
        // First control sits left of centre, last sits right.
        #expect(offsets.first! < 0)
        #expect(offsets.last! > 0)
    }

    @Test("fan-out spread scales with emerge")
    func spreadScalesWithEmerge() {
        let partial = ControlCluster.at(promotion: 0.7)
        let full = ControlCluster.at(promotion: 1)
        let partialEdge = partial.xOffset(forControl: 3, of: 4, spacing: 64)
        let fullEdge = full.xOffset(forControl: 3, of: 4, spacing: 64)
        #expect(partialEdge > 0)
        #expect(partialEdge < fullEdge)
    }

    @Test("a single control never offsets (degenerate count)")
    func singleControlNoOffset() {
        #expect(ControlCluster.at(promotion: 1).xOffset(forControl: 0, of: 1, spacing: 64) == 0)
    }

    // MARK: Visibility gate (V39) — no ghost pill below the floor

    @Test("below the visibility floor the cluster is invisible (opacity exactly 0)")
    func belowFloorIsInvisible() {
        let ghost = ControlCluster(emerge: ControlCluster.visibilityFloor - 0.01)
        #expect(!ghost.isVisible)
        #expect(ghost.opacity == 0)
        #expect(!ControlCluster.absorbed.isVisible)
        #expect(ControlCluster.absorbed.opacity == 0)
    }

    @Test("opacity ramps from 0 at the floor up to 1 at full emerge")
    func opacityRampsAboveFloor() {
        let atFloor = ControlCluster(emerge: ControlCluster.visibilityFloor)
        #expect(atFloor.isVisible)
        #expect(abs(atFloor.opacity) < 1e-6)
        let full = ControlCluster(emerge: 1)
        #expect(abs(full.opacity - 1) < 1e-6)
        let mid = ControlCluster(emerge: (ControlCluster.visibilityFloor + 1) / 2)
        #expect(mid.opacity > 0 && mid.opacity < 1)
    }

    @Test("opacity is monotonic in emerge and clamped to 0…1")
    func opacityMonotonicClamped() {
        let lo = ControlCluster(emerge: 0.4)
        let hi = ControlCluster(emerge: 0.8)
        #expect(lo.opacity < hi.opacity)
        #expect(ControlCluster(emerge: 1.2).opacity == 1)
        #expect(ControlCluster(emerge: -0.2).opacity == 0)
    }

    @Test("the rest-state ghost is gated: a half-settled book's cluster is not visible")
    func restGhostGated() {
        // The ui-audit ghost: launch rest left the focused book at promotion ≈ 0.5, whose
        // small-but-nonzero emerge leaked a ~20px pill mid-cover. That state must now be
        // fully invisible.
        let rest = ControlCluster.at(promotion: 0.5)
        #expect(rest.emerge > 0)         // it IS partially emerged…
        #expect(!rest.isVisible)         // …but renders nothing.
    }

    // MARK: Rest resolution (V46) — a static rest state is a terminal form, never mid-meld

    @Test("a visible mid-meld emerge resolves to fully emerged at scroll rest")
    func restResolvesVisibleToFull() {
        // The ui-audit round 3 "lumpy scalloped blob": rest landed between the visibility
        // floor and full emergence and froze the GlassEffectContainer's in-between shape.
        let midMeld = ControlCluster(emerge: (ControlCluster.visibilityFloor + 1) / 2)
        #expect(midMeld.restResolved == ControlCluster(emerge: 1))
        #expect(ControlCluster(emerge: ControlCluster.visibilityFloor).restResolved.emerge == 1)
    }

    @Test("a sub-floor emerge resolves to absorbed at scroll rest")
    func restResolvesGhostToAbsorbed() {
        // Medium rest keeps its clean cover — an invisible cluster stays invisible.
        let ghost = ControlCluster(emerge: ControlCluster.visibilityFloor - 0.01)
        #expect(ghost.restResolved == .absorbed)
        #expect(ControlCluster.absorbed.restResolved == .absorbed)
    }

    @Test("terminal forms are fixed points of the rest resolution")
    func terminalFormsAreFixedPoints() {
        #expect(ControlCluster(emerge: 1).restResolved == ControlCluster(emerge: 1))
        #expect(ControlCluster(emerge: 0).restResolved == ControlCluster(emerge: 0))
    }

    @Test("the displayed cluster is rest-resolved at rest, raw while scrolling")
    func displayedClusterFollowsScrollPhase() {
        // A promotion that lands mid-meld (visible, not fully emerged).
        let promotion: CGFloat = 0.75
        let raw = ControlCluster.at(promotion: promotion)
        #expect(raw.isVisible && raw.emerge < 1)  // the audit's frozen-blob precondition
        #expect(ControlCluster.displayed(promotion: promotion, scrollAtRest: false) == raw)
        #expect(
            ControlCluster.displayed(promotion: promotion, scrollAtRest: true)
                == ControlCluster(emerge: 1)
        )
        // Sub-floor at rest stays absorbed — medium rest keeps its clean cover.
        #expect(ControlCluster.displayed(promotion: 0.5, scrollAtRest: true) == .absorbed)
    }
}
