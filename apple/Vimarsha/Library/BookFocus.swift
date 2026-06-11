import CoreGraphics

/// Book-focus state (motion grammar #2 — grow-to-front promotion, apple/CLAUDE.md §UI map
/// state 2).
///
/// Scroll-settle detection as a pure continuous function of where each card sits in the
/// viewport: the book whose midY is nearest the front slot **owns** the front slot, and a
/// continuous `emphasis` (0…1) reports how dead-centre it is on that slot — peaking when the
/// card settles onto the line, falling to 0 at the edge of the settle window. No state, no
/// time: fully scrubbable, like `StackTransform`/`HeaderContrast`. The view layers a
/// grow-to-front scale bump, a deepening contact shadow, and the focused-book metadata
/// reveal on top of this scalar.
struct BookFocus: Equatable {
    /// Shelf index that owns the front slot, or `-1` when no card is within the settle window.
    var index: Int
    /// How fully settled the focused card is on the front slot: 1 when its midY is exactly on
    /// the slot line, 0 at the window edge (and beyond, where there is no focus).
    var emphasis: CGFloat

    static let none = BookFocus(index: -1, emphasis: 0)

    /// How far (as a fraction of viewport height) a card may sit from the front slot and still
    /// count as the focused book / contribute emphasis. Inside this band the reveal ramps up.
    static let settleWindow: CGFloat = 0.18

    /// Extra grow-to-front scale applied to the focused card on top of `StackTransform`'s
    /// front-slot 1.0 — the promotion bump (motion grammar #2). Bumped 0.04 → 0.07 in V24:
    /// the +4% promotion read too faint against the uniform-card stack (V09 finding #2), so the
    /// settled book now grows a clearer ~7% to claim the front slot.
    static let scaleBoost: CGFloat = 0.07

    /// Eased emphasis (steeper near the front, motion grammar #2 "steeper curve near the
    /// front"): grows slowly then accelerates as the card settles onto the slot. Drives the
    /// metadata reveal, the scale bump, and the contact-shadow deepening so they stay subtle
    /// until the book is nearly settled. Always `≤ emphasis` on `(0, 1)`.
    var promotion: CGFloat { emphasis * emphasis }

    /// Promotion at which the focused cover's debossed title has fully faded out (V41).
    /// Sits comfortably below the cluster's effective visibility promotion (≈0.53 — where
    /// `ControlCluster.at(promotion:).isVisible` first turns on), so by the time ANY focus
    /// affordance is meaningfully visible the printed title is already gone.
    static let titleFadeOutPromotion: CGFloat = 0.4

    /// Opacity of the focused cover's debossed title block (V41, ui-audit round 1; scoped
    /// in V42, round 2). The metadata reveal (opacity == promotion) repeats the title in
    /// the same eyeline, so the printed title must be GONE while the reveal shows — the
    /// old linear `1 - promotion` left a half-strength double title at launch rest
    /// (promotion ≈ 0.5). Smoothstepped 1 → 0 over `0…titleFadeOutPromotion`: scrubbable,
    /// gentle at both ends.
    ///
    /// `metadataVisible` is whether the metadata reveal actually renders (V42): at XXXL the
    /// affordance band can only fit the cluster, so `ViewThatFits` yields the metadata —
    /// and then the deboss title is the focused book's ONLY label and must stay printed.
    /// Fading it left an anonymous empty slab under the icon pill (ui-audit round 2).
    static func debossTitleOpacity(promotion: CGFloat, metadataVisible: Bool) -> CGFloat {
        guard metadataVisible else { return 1 }
        let t = max(0, min(1, promotion / titleFadeOutPromotion))
        let eased = t * t * (3 - 2 * t)
        return 1 - eased
    }

    /// - Parameters:
    ///   - midYs: each visible card's midY in the scroll viewport, keyed by shelf index
    ///     (only some cards may be measured during layout — partial maps are fine).
    ///   - viewportHeight: the scroll viewport height; the front slot + window scale with it.
    static func at(midYs: [Int: CGFloat], viewportHeight: CGFloat) -> BookFocus {
        guard viewportHeight > 0, !midYs.isEmpty else { return .none }
        let slotY = viewportHeight * StackTransform.frontSlot
        let window = viewportHeight * settleWindow

        var bestIndex = -1
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, midY) in midYs {
            let distance = abs(midY - slotY)
            // Tie-break on the lower shelf index so focus is deterministic at the midpoint.
            if distance < bestDistance || (distance == bestDistance && index < bestIndex) {
                bestDistance = distance
                bestIndex = index
            }
        }

        guard bestDistance <= window else { return .none }
        let emphasis = 1 - bestDistance / window
        return BookFocus(index: bestIndex, emphasis: max(0, min(1, emphasis)))
    }
}
