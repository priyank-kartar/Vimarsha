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
    /// The four affordances that grow from the focused cover, in display order (left→right).
    enum Control: Int, CaseIterable, Identifiable, Hashable {
        case play, figures, memo, discuss

        var id: Int { rawValue }

        /// SF Symbol for the glass control.
        var symbol: String {
            switch self {
            case .play: "play.fill"
            case .figures: "photo.on.rectangle.angled"
            case .memo: "mic.fill"
            case .discuss: "bubble.left.and.bubble.right.fill"
            }
        }

        /// VoiceOver label (the reference has zero chrome; every control still gets a name).
        var label: String {
            switch self {
            case .play: "Play"
            case .figures: "Figures"
            case .memo: "Voice note"
            case .discuss: "Discuss"
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
