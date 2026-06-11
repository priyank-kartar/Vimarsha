import Foundation

/// Pure selection rules for the figure overlay's stack (V20; glass moment #8 —
/// "stacked when spans overlap"). The set of figures active at the playhead changes as
/// narration moves; the selection survives ticks while the set is stable, resets when
/// it changes, and pages with wrap-around chevrons. Mirrors the Flutter
/// `FigureOverlay._reconcile` design.
nonisolated struct FigureOverlaySelection: Equatable, Sendable {
    /// Identity of the active set (joined figure ids) — a changed set resets paging.
    let key: String
    /// Which stacked figure is on top (0-based, in span order).
    var index: Int

    static func key(for figures: [FigureDTO]) -> String {
        figures.map(\.figureId).joined(separator: ",")
    }

    /// Reconcile against the figures active NOW: empty → nil (the carrier recedes);
    /// a new set → top of the stack; the same set keeps the user's paging (a stale
    /// out-of-range index recovers to 0).
    static func reconciled(
        _ previous: FigureOverlaySelection?, with figures: [FigureDTO]
    ) -> FigureOverlaySelection? {
        guard !figures.isEmpty else { return nil }
        let key = key(for: figures)
        guard let previous, previous.key == key, previous.index < figures.count else {
            return FigureOverlaySelection(key: key, index: 0)
        }
        return previous
    }

    func next(count: Int) -> FigureOverlaySelection {
        FigureOverlaySelection(key: key, index: count > 0 ? (index + 1) % count : 0)
    }

    func previous(count: Int) -> FigureOverlaySelection {
        FigureOverlaySelection(key: key, index: count > 0 ? (index + count - 1) % count : 0)
    }
}
