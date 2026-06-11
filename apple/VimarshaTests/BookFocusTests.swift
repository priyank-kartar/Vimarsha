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

/// V41 — the debossed-title fade keyed to affordance visibility (ui-audit round 1: the
/// linear `1 - promotion` left a half-strength double title at launch rest). The printed
/// title must be GONE while the metadata reveal repeats it — V42 scopes the fade to
/// metadata actually being visible (these tests pin the metadata-visible behaviour).
@Suite("BookFocus — deboss title fade (V41)")
struct DebossTitleFadeTests {
    @Test("unfocused cover keeps its printed title")
    func fullAtZero() {
        #expect(BookFocus.debossTitleOpacity(promotion: 0, metadataVisible: true) == 1)
        #expect(BookFocus.debossTitleOpacity(promotion: -0.2, metadataVisible: true) == 1)  // clamped
    }

    @Test("printed title is fully gone at the fade-out promotion and beyond")
    func goneAtFadeOut() {
        #expect(BookFocus.debossTitleOpacity(
            promotion: BookFocus.titleFadeOutPromotion, metadataVisible: true) == 0)
        #expect(BookFocus.debossTitleOpacity(promotion: 0.5, metadataVisible: true) == 0)   // launch-rest regression
        #expect(BookFocus.debossTitleOpacity(promotion: 1, metadataVisible: true) == 0)
    }

    @Test("fade is monotonically decreasing across the band")
    func monotone() {
        let samples = stride(from: 0.0, through: 1.0, by: 0.05).map {
            BookFocus.debossTitleOpacity(promotion: CGFloat($0), metadataVisible: true)
        }
        for (a, b) in zip(samples, samples.dropFirst()) {
            #expect(b <= a)
        }
    }

    @Test("deboss is gone under the cluster while the metadata reveal repeats the title")
    func goneBeforeClusterEmerges() {
        // The medium-rest audit state: while the metadata band shows, the printed title
        // must be fully faded before the cluster pill is visible (single title).
        for promotion in stride(from: 0.0, through: 1.0, by: 0.01) {
            let p = CGFloat(promotion)
            if ControlCluster.at(promotion: p).isVisible {
                #expect(BookFocus.debossTitleOpacity(promotion: p, metadataVisible: true) == 0)
            }
        }
    }

    @Test("fade eases out gently near rest (smoothstep, not a hard linear edge)")
    func easedNearEdges() {
        // Smoothstep: slope ~0 at both ends, so a barely-promoted card barely fades.
        let nearZero = BookFocus.debossTitleOpacity(promotion: 0.02, metadataVisible: true)
        #expect(nearZero > 0.99)
    }
}

/// V42 — ui-audit round 2: when the focused cover's visible band is too short for the
/// metadata reveal (XXXL type → `ViewThatFits` yields to the cluster-only branch), the
/// deboss fade must NOT engage — the printed title is the focused book's only label, and
/// fading it left an anonymous empty slab under the icon pill.
@Suite("BookFocus — deboss title stays when metadata yields (V42)")
struct DebossTitleMetadataYieldTests {
    @Test("with no metadata reveal the printed title stays at every promotion")
    func staysWithoutMetadata() {
        for promotion in stride(from: 0.0, through: 1.0, by: 0.05) {
            #expect(BookFocus.debossTitleOpacity(
                promotion: CGFloat(promotion), metadataVisible: false) == 1)
        }
    }

    @Test("the exact XXXL audit state: cluster visible, metadata yielded → title is the label")
    func xxxlAuditState() {
        // Launch rest at XXXL: promotion high enough that the cluster shows, but the
        // band only fits the cluster — the deboss title must stay full strength.
        let promotion: CGFloat = 0.6
        #expect(ControlCluster.at(promotion: promotion).isVisible)
        #expect(BookFocus.debossTitleOpacity(promotion: promotion, metadataVisible: false) == 1)
    }

    @Test("metadata visible keeps the V41 fade (regression guard)")
    func metadataVisibleStillFades() {
        #expect(BookFocus.debossTitleOpacity(promotion: 0.5, metadataVisible: true) == 0)
    }
}
