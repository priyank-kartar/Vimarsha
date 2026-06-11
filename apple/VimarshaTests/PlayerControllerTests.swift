import Foundation
import SwiftData
import Testing
@testable import Vimarsha

/// V16 — the player controller over the audio seam: real in-memory SwiftData rows, the
/// sanctioned `FakeAudioEngine` double for the device.
@MainActor
struct PlayerControllerTests {
    private struct Fixture {
        let controller: PlayerController
        let engine: FakeAudioEngine
        let chapter: Chapter
        let context: ModelContext
    }

    /// A persisted book + `ready` chapter (with a REAL cached bundle.json on disk — V18
    /// decodes it at load) and a controller wired to a fake engine.
    private func makeFixture(
        progressMs: Int = 0, status: ChapterStatus = .ready,
        bundle: ChapterBundleDTO = .timedFixture, writeBundle: Bool = true
    ) throws -> Fixture {
        let container = try ModelContainer(
            for: Book.self, Chapter.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let root = FileManager.default.temporaryDirectory
            .appending(path: "PlayerControllerTests-\(UUID().uuidString)")
        let book = Book(title: "T", author: "A", epubPath: "Library/Books/x/book.epub")
        let chapter = Chapter(index: 0, title: "One")
        chapter.status = status
        if status == .ready {
            chapter.audioPath = "Library/Books/x/chapters/0/chapter.mp3"
            chapter.bundlePath = "Library/Books/x/chapters/0/bundle.json"
            if writeBundle {
                let bundleURL = root.appending(path: chapter.bundlePath!)
                try FileManager.default.createDirectory(
                    at: bundleURL.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                try JSONEncoder().encode(bundle).write(to: bundleURL)
            }
        }
        chapter.progressMs = progressMs
        book.chapters = [chapter]
        context.insert(book)
        try context.save()
        let engine = FakeAudioEngine()
        let controller = PlayerController(engine: engine, context: context, containerRoot: root)
        return Fixture(controller: controller, engine: engine, chapter: chapter, context: context)
    }

    @Test func loadReadsDurationAndRecordsItOnTheRow() throws {
        let f = try makeFixture()
        f.engine.stubbedDurationMs = 24_576
        try f.controller.load(f.chapter)
        #expect(f.controller.durationMs == 24_576)
        #expect(f.chapter.durationMs == 24_576)
        #expect(f.engine.loadedURL?.lastPathComponent == "chapter.mp3")
        #expect(!f.controller.isPlaying)
    }

    @Test func loadResumesSavedPosition() throws {
        let f = try makeFixture(progressMs: 12_000)
        try f.controller.load(f.chapter)
        #expect(f.engine.seeks == [12_000])
        #expect(f.controller.positionMs == 12_000)
    }

    @Test func loadAtZeroProgressDoesNotSeek() throws {
        let f = try makeFixture(progressMs: 0)
        try f.controller.load(f.chapter)
        #expect(f.engine.seeks.isEmpty)
        #expect(f.controller.positionMs == 0)
    }

    @Test func loadClampsStaleProgressPastTheEnd() throws {
        let f = try makeFixture(progressMs: 99_000)
        f.engine.stubbedDurationMs = 30_000
        try f.controller.load(f.chapter)
        #expect(f.controller.positionMs == 30_000)
    }

    @Test func loadRejectsNonReadyChapter() throws {
        let f = try makeFixture(status: .none)
        #expect(throws: PlayerController.LoadError.self) { try f.controller.load(f.chapter) }
    }

    @Test func playAndPauseMirrorTheEngine() throws {
        let f = try makeFixture()
        try f.controller.load(f.chapter)
        f.controller.play()
        #expect(f.controller.isPlaying)
        #expect(f.engine.isPlaying)
        f.controller.pause()
        #expect(!f.controller.isPlaying)
        #expect(!f.engine.isPlaying)
    }

    @Test func pausePersistsProgress() throws {
        let f = try makeFixture()
        try f.controller.load(f.chapter)
        f.controller.play()
        f.engine.advance(byMs: 3_000)
        f.controller.tick()
        f.controller.pause()
        #expect(f.chapter.progressMs == 3_000)
    }

    @Test func ticksThrottlePersistenceToTheSaveInterval() throws {
        let f = try makeFixture()
        try f.controller.load(f.chapter)
        f.controller.play()
        f.engine.advance(byMs: 3_000)
        f.controller.tick()
        #expect(f.chapter.progressMs == 0)          // < 5s moved: not saved yet
        f.engine.advance(byMs: 3_000)
        f.controller.tick()
        #expect(f.chapter.progressMs == 6_000)      // crossed the interval: saved
    }

    @Test func seekClampsToTheLoadedDuration() throws {
        let f = try makeFixture()
        f.engine.stubbedDurationMs = 10_000
        try f.controller.load(f.chapter)
        f.controller.seek(toMs: 99_000)
        #expect(f.controller.positionMs == 10_000)
        f.controller.seek(toMs: -5)
        #expect(f.controller.positionMs == 0)
    }

    @Test func skipMovesRelativeAndClamps() throws {
        let f = try makeFixture()
        f.engine.stubbedDurationMs = 10_000
        try f.controller.load(f.chapter)
        f.controller.seek(toMs: 5_000)
        f.controller.skip(byMs: -2_000)
        #expect(f.controller.positionMs == 3_000)
        f.controller.skip(byMs: 60_000)
        #expect(f.controller.positionMs == 10_000)
    }

    @Test func setRateForwardsToTheEngine() throws {
        let f = try makeFixture()
        try f.controller.load(f.chapter)
        f.controller.setRate(1.5)
        #expect(f.controller.rate == 1.5)
        #expect(f.engine.rate == 1.5)
    }

    @Test func loadDecodesTheCachedBundleAndBuildsTiming() throws {
        let f = try makeFixture()
        try f.controller.load(f.chapter)
        #expect(f.controller.bundle?.blocks.count == 3)
        #expect(f.controller.currentBlockId == "b1")  // playhead 0 → first timed block
    }

    @Test func currentBlockIdFollowsThePlayhead() throws {
        let f = try makeFixture()
        try f.controller.load(f.chapter)
        f.controller.play()
        f.engine.advance(byMs: 1_500)
        f.controller.tick()
        #expect(f.controller.currentBlockId == "b2")
        f.controller.seek(toMs: 2_500)
        #expect(f.controller.currentBlockId == "b3")
    }

    @Test func loadResumesIntoTheRightBlock() throws {
        let f = try makeFixture(progressMs: 1_200)
        try f.controller.load(f.chapter)
        #expect(f.controller.currentBlockId == "b2")
    }

    @Test func tapToSeekJumpsToTheBlockStart() throws {
        let f = try makeFixture()
        try f.controller.load(f.chapter)
        f.controller.seekToBlock("b3")
        #expect(f.controller.positionMs == 2_000)
        #expect(f.engine.seeks.last == 2_000)
        #expect(f.controller.currentBlockId == "b3")
    }

    @Test func untimedBlocksAreNotSeekTargets() throws {
        let f = try makeFixture()
        try f.controller.load(f.chapter)
        f.controller.seek(toMs: 1_500)
        f.controller.seekToBlock("not-timed")
        #expect(f.controller.positionMs == 1_500)  // unchanged
    }

    @Test func missingBundleFileFailsTheLoad() throws {
        let f = try makeFixture(writeBundle: false)
        #expect(throws: (any Error).self) { try f.controller.load(f.chapter) }
        #expect(f.controller.bundle == nil)
    }

    @Test func activeFiguresFollowThePlayhead() throws {
        let f = try makeFixture(bundle: .figuredFixture)
        try f.controller.load(f.chapter)
        #expect(f.controller.activeFigures.isEmpty)  // playhead 0, span starts at 500
        f.controller.play()
        f.engine.advance(byMs: 700)
        f.controller.tick()
        #expect(f.controller.activeFigures.map(\.figureId) == ["f1"])
        f.controller.seek(toMs: 2_600)
        #expect(f.controller.activeFigures.isEmpty)  // past endMs → carrier recedes
    }

    @Test func allFiguresListsTheWholeMapRegardlessOfTiming() throws {
        let f = try makeFixture(bundle: .figuredFixture)
        try f.controller.load(f.chapter)
        // The gallery's source: every figure, including the unresolved (nil-ms) one
        // that never auto-pops.
        #expect(f.controller.allFigures.map(\.figureId) == ["f1", "f2"])
    }

    @Test func naturalFinishStopsAndPersistsAtTheEnd() throws {
        let f = try makeFixture()
        f.engine.stubbedDurationMs = 8_000
        try f.controller.load(f.chapter)
        f.controller.play()
        f.engine.finish()
        #expect(!f.controller.isPlaying)
        #expect(f.controller.positionMs == 8_000)
        #expect(f.chapter.progressMs == 8_000)
    }
}

nonisolated extension ChapterBundleDTO {
    /// Three timed paragraphs — enough to watch the live block move.
    static let timedFixture = ChapterBundleDTO(
        chapterId: "chap1", title: "Chapter One",
        blocks: [
            BlockDTO(id: "b1", index: 0, kind: "paragraph", text: "First."),
            BlockDTO(id: "b2", index: 1, kind: "paragraph", text: "Second."),
            BlockDTO(id: "b3", index: 2, kind: "paragraph", text: "Third."),
        ],
        figureMap: [],
        audio: "chap1.mp3",
        paraTimings: ["b1": [0, 1_000], "b2": [1_000, 2_000], "b3": [2_000, 3_000]]
    )

    /// `timedFixture` plus a figure map: one resolved span (auto-pops) and one
    /// unresolved (nil ms — gallery-only, never activates).
    static let figuredFixture = ChapterBundleDTO(
        chapterId: "chap1", title: "Chapter One",
        blocks: timedFixture.blocks + [
            BlockDTO(id: "fig1", index: 3, kind: "figure", caption: "A diagram"),
            BlockDTO(id: "fig2", index: 4, kind: "figure", caption: "Unresolved"),
        ],
        figureMap: [
            FigureDTO(
                figureId: "f1", kind: "figure", asset: nil, caption: "A diagram",
                label: "Figure 1", startPara: "b1", endPara: "b2",
                startMs: 500, endMs: 2_500, image: nil
            ),
            FigureDTO(
                figureId: "f2", kind: "figure", asset: nil, caption: "Unresolved",
                label: "Figure 2", startPara: "b3", endPara: "b3",
                startMs: nil, endMs: nil, image: nil
            ),
        ],
        audio: "chap1.mp3",
        paraTimings: timedFixture.paraTimings
    )
}
