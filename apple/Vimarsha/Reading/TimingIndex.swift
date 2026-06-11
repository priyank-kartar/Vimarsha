import Foundation

/// The ONE owner of every `paraTimings`/figure-span lookup (app-architecture.md §Figure &
/// timing flow — "never four parallel implementations"): live-paragraph computation,
/// auto-scroll targets (via `blockIndex`), tap-to-seek, and figure span activation.
/// Pure value math over a decoded bundle; no clocks, no state.
nonisolated struct TimingIndex: Sendable {
    private let timings: [String: [Int]]
    private let figures: [FigureDTO]
    private let indexById: [String: Int]

    init(bundle: ChapterBundleDTO) {
        timings = bundle.paraTimings
        figures = bundle.figureMap
        indexById = Dictionary(
            bundle.blocks.enumerated().map { ($1.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// The block being narrated at `ms`: the timed block with the LATEST start ≤ ms
    /// (the Flutter `_recompute` rule — robust to gaps between blocks). Ties break to
    /// the earlier block in reading order, deterministically. Nil before the first
    /// timed block or when nothing is timed.
    func currentBlockId(atMs ms: Int) -> String? {
        var best: (id: String, start: Int)?
        for (id, range) in timings {
            guard let start = range.first, start <= ms else { continue }
            if let current = best {
                let earlierInReadingOrder =
                    (indexById[id] ?? .max) < (indexById[current.id] ?? .max)
                if start > current.start || (start == current.start && earlierInReadingOrder) {
                    best = (id, start)
                }
            } else {
                best = (id, start)
            }
        }
        return best?.id
    }

    /// Tap-to-seek: where a block's narration starts. Nil for untimed blocks.
    func startMs(forBlock id: String) -> Int? {
        timings[id]?.first
    }

    /// Figure span activation: every figure whose `[startMs, endMs]` window contains
    /// `ms` (inclusive — the contract's spans are closed). Unresolved figures (nil ms,
    /// e.g. the rules missed the mention) never activate.
    func activeFigures(atMs ms: Int) -> [FigureDTO] {
        figures.filter { figure in
            guard let start = figure.startMs, let end = figure.endMs else { return false }
            return ms >= start && ms <= end
        }
    }

    /// Auto-scroll target: a block's position in reading order.
    func blockIndex(forId id: String) -> Int? {
        indexById[id]
    }
}
