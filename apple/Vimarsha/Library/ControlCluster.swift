import CoreGraphics

/// Glass control cluster (glass moment #5, apple/CLAUDE.md §UI map state 2): the focused
/// book's actions — Play/Narrate, Figures, Voice note, Discuss — morph **out of** the hero
/// cover as glass controls and **re-absorb on scroll**.
///
/// `emerge` is a pure, scrubbable function of the focus `promotion` (motion grammar #2): the
/// controls stay melded into one glass blob over the cover until the book is meaningfully
/// settled on the front slot, then fan apart into four separate controls; scrolling away
/// reverses it (the blob re-melds and fades back into the cover). No state, no timers — the
/// `GlassEffectContainer` meld/split renders this scalar (`StackTransform`/`BookFocus` style).
struct ControlCluster: Equatable {
    /// The book-level affordances that grow from the focused cover, in display order
    /// (left→right). Book-level only: Play opens the chapter list; Voice notes and Saved
    /// discussions open this book's archives across all chapters. Figures is NOT here — it's
    /// a reading-time control that lives on the reading surface, and only when the open
    /// chapter actually has figures. Live Discuss likewise lives only inside the reading
    /// surface; the cluster surfaces the SAVED conversations.
    enum Control: Int, CaseIterable, Identifiable, Hashable {
        case play, memo, conversations

        var id: Int { rawValue }

        /// SF Symbol for the glass control.
        var symbol: String {
            switch self {
            case .play: "play.fill"
            case .memo: "mic.fill"
            case .conversations: "bubble.left.and.bubble.right.fill"
            }
        }

        /// VoiceOver label (the reference has zero chrome; every control still gets a name).
        var label: String {
            switch self {
            case .play: "Play"
            case .memo: "Voice notes"
            case .conversations: "Saved discussions"
            }
        }
    }

    /// 0 = fully absorbed into the cover (controls melded into one glass blob, invisible),
    /// 1 = fully emerged (four separate glass controls fanned out and settled).
    var emerge: CGFloat

    static let absorbed = ControlCluster(emerge: 0)

    /// Promotion below which the cluster stays absorbed — controls only morph out once the
    /// book is meaningfully settled on the front slot, so they don't flash on every cover that
    /// sweeps past the slot mid-scroll. A settled-at-rest book clears it comfortably; the
    /// smoothstep easing keeps it faint until the book is genuinely settled.
    static let emergeThreshold: CGFloat = 0.3

    /// Emerge below which the cluster renders NOTHING (V39). The emerge curve is continuous,
    /// so a half-settled book (e.g. launch rest at promotion ≈ 0.5) used to leak a faint
    /// melded pill mid-cover (`opacity == emerge`, ui-audit round 1). Below this floor the
    /// cluster is invisible AND removed from the hierarchy; above it `opacity` ramps fast to
    /// full, so the gate never pops (opacity is exactly 0 at the floor) and stays scrubbable.
    static let visibilityFloor: CGFloat = 0.25

    /// Whether the cluster renders at all (the hierarchy gate, V39).
    var isVisible: Bool { emerge >= Self.visibilityFloor }

    /// Rendered opacity (V39): 0 up to the visibility floor, then a linear ramp to 1 at full
    /// emerge — replaces the raw `opacity == emerge` that ghosted at partial promotion.
    var opacity: CGFloat {
        guard isVisible else { return 0 }
        let ramp = (emerge - Self.visibilityFloor) / (1 - Self.visibilityFloor)
        return max(0, min(1, ramp))
    }

    /// The terminal form this cluster resolves to at scroll rest (V46): the
    /// `GlassEffectContainer` meld/split shape is only meaningful *while the morph is in
    /// motion* — a static state frozen between the visibility floor and full emergence
    /// renders as a lumpy half-melded blob (ui-audit round 3). At rest a visible cluster
    /// snaps to fully emerged (four split circles, live controls); an invisible one stays
    /// absorbed (the cover keeps its clean face). Both terminal forms are fixed points.
    var restResolved: ControlCluster {
        isVisible ? ControlCluster(emerge: 1) : .absorbed
    }

    /// The cluster the view actually renders (V46): raw scrubbable emerge while the scroll
    /// is in motion, the rest-resolved terminal form once it settles. One owner for the
    /// decision so the cluster view and the deboss dodge (V45) can never disagree.
    static func displayed(promotion: CGFloat, scrollAtRest: Bool) -> ControlCluster {
        let raw = at(promotion: promotion)
        return scrollAtRest ? raw.restResolved : raw
    }

    /// - Parameter promotion: the eased focus emphasis (`BookFocus.promotion`, 0…1).
    static func at(promotion: CGFloat) -> ControlCluster {
        guard promotion > emergeThreshold else { return .absorbed }
        let raw = (promotion - emergeThreshold) / (1 - emergeThreshold)
        let clamped = max(0, min(1, raw))
        // Smoothstep so the controls accelerate out of the cover then settle (no hard pop).
        let eased = clamped * clamped * (3 - 2 * clamped)
        return ControlCluster(emerge: eased)
    }

    /// Horizontal offset of control `index` (of `count`) from the cluster centre, scaled by
    /// `emerge`: controls start melded at the centre (offset 0) and fan to `spacing` apart.
    func xOffset(forControl index: Int, of count: Int, spacing: CGFloat) -> CGFloat {
        guard count > 1 else { return 0 }
        let centre = CGFloat(count - 1) / 2
        return (CGFloat(index) - centre) * spacing * emerge
    }
}
