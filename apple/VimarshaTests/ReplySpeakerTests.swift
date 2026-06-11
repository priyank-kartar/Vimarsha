import Foundation
import SwiftData
import Testing
@testable import Vimarsha

/// V35 — spoken replies: `/speak` audio plays on the speaker's OWN ephemeral engine
/// (the chapter engine keeps its MP3), narration pauses only when speech actually
/// starts (fetching is not a conflict) and resumes after if it was playing; failures
/// flag the button and leave narration untouched. Real player over fake engines.
@MainActor
struct ReplySpeakerTests {
    private struct Fixture {
        let speaker: ReplySpeaker
        let player: PlayerController
        let chapterEngine: FakeAudioEngine
        let speechEngine: FakeAudioEngine
    }

    private func makeFixture(
        speak: @escaping @Sendable (String) async throws -> Data = { _ in Data("mp3".utf8) }
    ) throws -> Fixture {
        let container = try ModelContainer(
            for: Book.self, Chapter.self, Memo.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let root = FileManager.default.temporaryDirectory
            .appending(path: "ReplySpeakerTests-\(UUID().uuidString)")
        let book = Book(title: "T", author: "A", epubPath: "Library/Books/x/book.epub")
        let chapter = Chapter(index: 0, title: "One")
        chapter.status = .ready
        chapter.audioPath = "Library/Books/x/chapters/0/chapter.mp3"
        chapter.bundlePath = "Library/Books/x/chapters/0/bundle.json"
        let bundleURL = root.appending(path: chapter.bundlePath!)
        try FileManager.default.createDirectory(
            at: bundleURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(ChapterBundleDTO.timedFixture).write(to: bundleURL)
        book.chapters = [chapter]
        context.insert(book)
        try context.save()

        let chapterEngine = FakeAudioEngine()
        let player = PlayerController(engine: chapterEngine, context: context, containerRoot: root)
        try player.load(chapter)
        var backend = FakeBackendClient.returning()
        backend.onSpeak = speak
        let speechEngine = FakeAudioEngine()
        let speaker = ReplySpeaker(backend: backend, speechEngine: speechEngine, player: player)
        return Fixture(
            speaker: speaker, player: player,
            chapterEngine: chapterEngine, speechEngine: speechEngine
        )
    }

    @Test("speaking a reply pauses narration and plays on the speaker's own engine")
    func speakPausesNarration() async throws {
        let f = try makeFixture()
        f.player.play()
        await f.speaker.speak("The reply.", at: 1)

        #expect(f.speaker.speakingIndex == 1)
        #expect(!f.player.isPlaying)
        #expect(f.speechEngine.isPlaying)
        // The chapter engine still holds the chapter MP3 — only paused.
        #expect(f.chapterEngine.loadedURL?.lastPathComponent == "chapter.mp3")
        #expect(f.speechEngine.loadedURL?.lastPathComponent.hasPrefix("spoken-reply-") == true)
    }

    @Test("the reply finishing resumes narration that was playing")
    func finishResumes() async throws {
        let f = try makeFixture()
        f.player.play()
        await f.speaker.speak("The reply.", at: 1)
        f.speechEngine.finish()

        #expect(f.speaker.speakingIndex == nil)
        #expect(f.player.isPlaying)
    }

    @Test("paused narration stays paused after the reply")
    func pausedStaysPaused() async throws {
        let f = try makeFixture()
        await f.speaker.speak("The reply.", at: 1)
        f.speechEngine.finish()
        #expect(!f.player.isPlaying)
    }

    @Test("tapping the speaking reply stops it and resumes narration")
    func toggleStops() async throws {
        let f = try makeFixture()
        f.player.play()
        await f.speaker.speak("The reply.", at: 1)
        await f.speaker.speak("The reply.", at: 1)

        #expect(f.speaker.speakingIndex == nil)
        #expect(!f.speechEngine.isPlaying)
        #expect(f.player.isPlaying)
    }

    @Test("a second reply while one speaks is ignored — no audio pile-up")
    func secondSpeakIgnored() async throws {
        let f = try makeFixture()
        await f.speaker.speak("First.", at: 1)
        await f.speaker.speak("Second.", at: 3)
        #expect(f.speaker.speakingIndex == 1)
    }

    @Test("a failed fetch flags the reply and narration keeps playing")
    func failureFlagsAndKeepsNarration() async throws {
        let f = try makeFixture(speak: { _ in throw URLError(.cannotConnectToHost) })
        f.player.play()
        await f.speaker.speak("The reply.", at: 2)

        #expect(f.speaker.failedIndex == 2)
        #expect(f.speaker.speakingIndex == nil)
        #expect(f.player.isPlaying)
    }

    @Test("stop on panel close resumes narration mid-reply")
    func stopResumes() async throws {
        let f = try makeFixture()
        f.player.play()
        await f.speaker.speak("The reply.", at: 1)
        f.speaker.stop()
        #expect(f.player.isPlaying)
        #expect(f.speaker.speakingIndex == nil)
    }
}
