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

    /// A persisted book + `ready` chapter and a controller wired to a fake engine.
    private func makeFixture(progressMs: Int = 0, status: ChapterStatus = .ready) throws -> Fixture {
        let container = try ModelContainer(
            for: Book.self, Chapter.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let book = Book(title: "T", author: "A", epubPath: "Library/Books/x/book.epub")
        let chapter = Chapter(index: 0, title: "One")
        chapter.status = status
        chapter.audioPath = status == .ready ? "Library/Books/x/chapters/0/chapter.mp3" : nil
        chapter.progressMs = progressMs
        book.chapters = [chapter]
        context.insert(book)
        try context.save()
        let engine = FakeAudioEngine()
        let controller = PlayerController(
            engine: engine, context: context,
            containerRoot: FileManager.default.temporaryDirectory
        )
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
