import CoreGraphics

/// Where the focused-book affordances (metadata reveal + glass control cluster, motion
/// grammar #2 / glass moment #5) sit (V24).
///
/// The cluster must read as **extruded from the focused cover** — it sits just inside that
/// cover's *visible* bottom edge, which is the top of the next book that overlaps it in the
/// stack. Anchoring to the viewport bottom (the pre-V24 behaviour) let the cluster float over
/// the *next* cover (e.g. the gold "A SENSE OF PLACE" board), so its weakly-tinted glass
/// refracted that cover's colour and it overlapped the wrong book. This pure function maps the
/// next book's top edge → the bottom padding that lifts the affordances above it; clamped so
/// it never drops below a resting margin nor lifts past mid-viewport. No state, no time —
/// scrubbable like the rest of the library math.
enum FocusAffordancePlacement {
    /// Never sit closer than this to the viewport bottom (the resting position when the focused
    /// cover's bottom is below the fold, i.e. nothing to clear).
    static let margin: CGFloat = 28

    /// Sit this far above the next (occluding) book's top edge, so the cluster stays on the
    /// focused cover rather than grazing the book below it.
    static let insetAboveNext: CGFloat = 14

    /// Keep this much clearance below the focused cover's own top edge — the affordances must
    /// never touch (let alone cross) the seam with the cover above it (V37).
    static let insetBelowTop: CGFloat = 8

    /// Never lift the affordances past this fraction of the viewport height — they belong on
    /// the lower reading surface, not floating up into the stack.
    static let maxLift: CGFloat = 0.5

    /// - Parameters:
    ///   - nextTopY: the next (occluding) book's top edge in viewport coordinates — the
    ///     focused cover's visible bottom. `nil` when the focused book is the front-most.
    ///   - viewportHeight: the scroll viewport height.
    /// - Returns: the bottom padding for the affordance stack.
    static func bottomPadding(nextTopY: CGFloat?, viewportHeight: CGFloat) -> CGFloat {
        guard viewportHeight > 0 else { return margin }
        let anchorBottom: CGFloat
        if let nextTopY {
            // Sit just above the next book; but if its top is below the fold, fall back to rest.
            anchorBottom = min(nextTopY - insetAboveNext, viewportHeight - margin)
        } else {
            anchorBottom = viewportHeight - margin
        }
        let padding = viewportHeight - anchorBottom
        return min(max(padding, margin), viewportHeight * maxLift)
    }

    /// The hard height clamp (V37): the affordance stack may only occupy the focused cover's
    /// own visible band — from just below its rendered top edge down to the anchor the
    /// `bottomPadding` establishes. Anything taller (XXXL type, short bands) must drop content
    /// or clip; it must never spill across the seam onto the cover above.
    ///
    /// - Parameters:
    ///   - focusedTopY: the focused cover's rendered top edge (`CardVisualTop`) in viewport
    ///     coordinates; `nil` while unmeasured.
    ///   - bottomPadding: the resolved `bottomPadding(nextTopY:viewportHeight:)` for the same
    ///     frame, anchoring the stack's bottom.
    ///   - viewportHeight: the scroll viewport height.
    /// - Returns: the maximum height for the affordance stack, ≥ 0.
    static func maxHeight(
        focusedTopY: CGFloat?, bottomPadding: CGFloat, viewportHeight: CGFloat
    ) -> CGFloat {
        let anchorBottom = viewportHeight - bottomPadding
        guard let focusedTopY else { return max(0, anchorBottom) }
        return max(0, anchorBottom - focusedTopY - insetBelowTop)
    }
}
