import CoreGraphics

/// Slot-emit / staircase fan-up math (motion grammar #4, apple/CLAUDE.md §Motion grammar).
///
/// The entrance counterpart to the depth-stack recede: a cover rises from a shared bottom
/// shelf anchor (the viewport's bottom edge) into its staircase slot as it scrolls up toward
/// the front slot. Like every library motion this is a pure continuous function of the card's
/// midY — no timers, fully scrubbable ("driven by scroll offset, not time"). A card at the
/// bottom edge sits at the anchor (sunk toward the shelf, shrunk, not yet appeared); as its
/// midY climbs to the front slot it eases up to identity with an ease-out "soft landing"
/// (springy but no overshoot past rest). Above the front slot a card has fully arrived
/// (identity) and `StackTransform` takes over the recede — the two meet at the slot with no
/// jump, so the staircase is one continuous surface.
///
/// The per-item stagger ("covers rise sequentially … fan into a stepped staircase") is
/// intrinsic, not scripted: overlapping cards have staggered midYs, so as the tower scrolls
/// each card emits just after the one below it — the stepped fan-up falls out of the geometry.
struct SlotEmit: Equatable {
    var scale: CGFloat
    var opacity: CGFloat
    /// Downward (positive) offset toward the shelf anchor; 0 once the card has arrived.
    var yOffset: CGFloat

    static let identity = SlotEmit(scale: 1, opacity: 1, yOffset: 0)

    /// Scale at the shelf anchor — a cover just emerging sits slightly shrunk.
    static let anchorScale: CGFloat = 0.86
    /// Opacity at the shelf anchor — the cover rises into existence from the shelf block.
    static let anchorOpacity: CGFloat = 0
    /// How far the anchored card sinks toward the shelf below its rest, as a fraction of
    /// viewport height.
    static let riseFraction: CGFloat = 0.12
    /// The fraction of the rise by which the fade-in completes (V47, ui-audit round 3): a
    /// cover one slot below the front sits mid-band at rest, and at partial opacity the
    /// focused cover's bottom anatomy (bright board, fore-edge strip, contact shadow) bled
    /// THROUGH its face — reading as "page lines" across its debossed title. Translucency
    /// belongs to the shelf-anchor end of the rise; from here up the cover is solid.
    static let opacitySaturation: CGFloat = 0.5

    /// - Parameters:
    ///   - midY: the card's midY in the scroll viewport.
    ///   - viewportHeight: the scroll viewport height; the slot + emit band scale with it.
    static func at(midY: CGFloat, viewportHeight: CGFloat) -> SlotEmit {
        guard viewportHeight > 0 else { return .identity }
        // The emit band runs from the viewport bottom edge (anchor, progress 0) up to the
        // front slot (arrived, progress 1) — so the anchor is exactly the bottom edge and a
        // cover travels its full rise as it scrolls from first appearance to the slot.
        let span = (1 - StackTransform.frontSlot) * viewportHeight
        guard span > 0 else { return .identity }
        let progress = max(0, min(1, (viewportHeight - midY) / span))
        // Ease-out (decelerate into rest): fast emergence off the shelf, soft landing on the
        // slot, strictly monotonic — no overshoot past identity.
        let eased = 1 - (1 - progress) * (1 - progress)
        // Opacity rides the same ease-out but on a remapped progress that completes at
        // `opacitySaturation` (V47): the fade-in lives near the shelf anchor, and the cover
        // is fully solid for the rest of its rise — neighbors never bleed through it.
        let opacityProgress = min(1, progress / opacitySaturation)
        let opacityEased = 1 - (1 - opacityProgress) * (1 - opacityProgress)
        return SlotEmit(
            scale: anchorScale + (1 - anchorScale) * eased,
            opacity: anchorOpacity + (1 - anchorOpacity) * opacityEased,
            yOffset: riseFraction * viewportHeight * (1 - eased)
        )
    }
}
