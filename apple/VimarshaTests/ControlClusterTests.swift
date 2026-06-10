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
}
