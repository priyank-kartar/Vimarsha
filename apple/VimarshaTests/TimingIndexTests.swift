import Foundation
import Testing
@testable import Vimarsha

/// V18 — the one paraTimings/figure-span lookup owner (app-architecture.md §Figure &
/// timing flow).
struct TimingIndexTests {
    /// Three timed paragraphs + one untimed heading + two figures (one unresolved).
    private func makeIndex() -> TimingIndex {
        TimingIndex(bundle: ChapterBundleDTO(
            chapterId: "c1", title: "One",
            blocks: [
                BlockDTO(id: "h1", index: 0, kind: "heading", text: "Title"),
                BlockDTO(id: "b1", index: 1, kind: "paragraph", text: "First."),
                BlockDTO(id: "b2", index: 2, kind: "paragraph", text: "Second."),
                BlockDTO(id: "b3", index: 3, kind: "paragraph", text: "Third."),
            ],
            figureMap: [
                FigureDTO(
                    figureId: "f1", kind: "figure", startPara: "b1", endPara: "b2",
                    startMs: 500, endMs: 2_000
                ),
                FigureDTO(
                    figureId: "f2", kind: "figure", startPara: "b3", endPara: "b3",
                    startMs: nil, endMs: nil
                ),
            ],
            paraTimings: ["b1": [100, 1_000], "b2": [1_000, 2_000], "b3": [2_000, 3_000]]
        ))
    }

    @Test func beforeTheFirstTimedBlockNothingNarrates() {
        #expect(makeIndex().currentBlockId(atMs: 0) == nil)
    }

    @Test func latestStartAtOrBeforeTheClockWins() {
        let index = makeIndex()
        #expect(index.currentBlockId(atMs: 100) == "b1")
        #expect(index.currentBlockId(atMs: 999) == "b1")
        #expect(index.currentBlockId(atMs: 1_500) == "b2")
        #expect(index.currentBlockId(atMs: 99_000) == "b3")  // past the end: last block holds
    }

    @Test func emptyTimingsMeanNoCurrentBlock() {
        let index = TimingIndex(bundle: ChapterBundleDTO(
            chapterId: "c1", title: "T", blocks: [], figureMap: []
        ))
        #expect(index.currentBlockId(atMs: 5_000) == nil)
    }

    @Test func equalStartsBreakToReadingOrderDeterministically() {
        let index = TimingIndex(bundle: ChapterBundleDTO(
            chapterId: "c1", title: "T",
            blocks: [
                BlockDTO(id: "a", index: 0, kind: "paragraph", text: "A"),
                BlockDTO(id: "b", index: 1, kind: "paragraph", text: "B"),
            ],
            figureMap: [],
            paraTimings: ["b": [0, 900], "a": [0, 900]]
        ))
        #expect(index.currentBlockId(atMs: 400) == "a")
    }

    @Test func startMsAnswersTapToSeek() {
        let index = makeIndex()
        #expect(index.startMs(forBlock: "b2") == 1_000)
        #expect(index.startMs(forBlock: "h1") == nil)     // untimed: no seek target
        #expect(index.startMs(forBlock: "missing") == nil)
    }

    @Test func figureSpansActivateInclusively() {
        let index = makeIndex()
        #expect(index.activeFigures(atMs: 499).isEmpty)
        #expect(index.activeFigures(atMs: 500).map(\.figureId) == ["f1"])   // closed start
        #expect(index.activeFigures(atMs: 2_000).map(\.figureId) == ["f1"]) // closed end
        #expect(index.activeFigures(atMs: 2_001).isEmpty)
    }

    @Test func unresolvedFiguresNeverActivate() {
        // f2 has nil spans — absent at every clock.
        #expect(makeIndex().activeFigures(atMs: 2_500).isEmpty)
    }

    @Test func blockIndexAnswersAutoScrollTargets() {
        let index = makeIndex()
        #expect(index.blockIndex(forId: "h1") == 0)
        #expect(index.blockIndex(forId: "b3") == 3)
        #expect(index.blockIndex(forId: "missing") == nil)
    }
}
