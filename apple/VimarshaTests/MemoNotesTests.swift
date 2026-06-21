import Foundation
import SwiftData
import Testing
@testable import Vimarsha

/// V30 — the Notes state's controller: memo playback on its own ephemeral engine
/// (the Flutter spec's "separate handler instance" — the chapter's shared engine keeps
/// its loaded MP3), open-at-pin seeks narration, delete sweeps row + audio. Real
/// in-memory SwiftData + real temp files; fakes for both engines.
@MainActor
struct MemoNotesTests {
    private struct Fixture {
        let notes: MemoNotes
        let player: PlayerController
        let chapterEngine: FakeAudioEngine
        let memoEngine: FakeAudioEngine
        let store: LibraryStore
        let chapter: Chapter
        let context: ModelContext
        let root: URL
    }

    private func makeFixture() throws -> Fixture {
        let container = try ModelContainer(
            for: Book.self, Chapter.self, Memo.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let root = FileManager.default.temporaryDirectory
            .appending(path: "MemoNotesTests-\(UUID().uuidString)")
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
        let memoEngine = FakeAudioEngine()
        let store = LibraryStore(
            context: context, importer: EpubImporter(containerRoot: root),
            backend: FakeBackendClient.returning()
        )
        let notes = MemoNotes(
            player: player, memoEngine: memoEngine, store: store, containerRoot: root
        )
        return Fixture(
            notes: notes, player: player, chapterEngine: chapterEngine,
            memoEngine: memoEngine, store: store, chapter: chapter,
            context: context, root: root
        )
    }

    /// A saved memo row with real audio bytes on disk.
    private func makeMemo(
        in f: Fixture, paragraphIndex: Int = 1, positionMs: Int = 1_500
    ) throws -> Memo {
        let memo = Memo(
            paragraphIndex: paragraphIndex, positionMs: positionMs,
            audioPath: "Library/Books/x/memos/\(UUID().uuidString).m4a"
        )
        memo.chapter = f.chapter
        f.context.insert(memo)
        try f.context.save()
        let url = f.root.appending(path: memo.audioPath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data("aac".utf8).write(to: url)
        return memo
    }

    @Test("playing a memo loads its file into the memo engine and pauses narration")
    func playPausesNarration() throws {
        let f = try makeFixture()
        let memo = try makeMemo(in: f)
        f.player.play()
        f.notes.play(memo)
        #expect(!f.player.isPlaying)                       // audio-conflict rule
        #expect(f.memoEngine.isPlaying)
        #expect(f.memoEngine.loadedURL == f.root.appending(path: memo.audioPath))
        #expect(f.notes.playingMemoId == memo.id)
        // The chapter's engine still holds the chapter MP3 — untouched.
        #expect(f.chapterEngine.loadedURL?.lastPathComponent == "chapter.mp3")
    }

    @Test("narration resumes when a memo finishes if it was playing before")
    func resumesNarrationAfterMemoFinishes() throws {
        let f = try makeFixture()
        let memo = try makeMemo(in: f)
        f.player.play()
        f.notes.play(memo)
        #expect(!f.player.isPlaying)        // paused for the memo
        f.memoEngine.finish()               // memo plays to its natural end
        #expect(f.player.isPlaying)         // book resumes
        #expect(f.notes.playingMemoId == nil)
    }

    @Test("a memo finishing does NOT resume narration that was already paused")
    func doesNotResumeIfNarrationWasPaused() throws {
        let f = try makeFixture()
        let memo = try makeMemo(in: f)
        // book not playing when the memo starts
        f.notes.play(memo)
        f.memoEngine.finish()
        #expect(!f.player.isPlaying)        // stays paused
    }

    @Test("manually stopping a memo never auto-resumes narration")
    func manualStopDoesNotResume() throws {
        let f = try makeFixture()
        let memo = try makeMemo(in: f)
        f.player.play()
        f.notes.play(memo)                  // pauses the book
        f.notes.play(memo)                  // tap again = manual stop
        #expect(!f.player.isPlaying)        // not resumed (manual)
    }

    @Test("tapping the playing memo stops it; another memo switches over")
    func toggleAndSwitch() throws {
        let f = try makeFixture()
        let first = try makeMemo(in: f)
        let second = try makeMemo(in: f)
        f.notes.play(first)
        f.notes.play(first)                                // toggle off
        #expect(!f.memoEngine.isPlaying)
        #expect(f.notes.playingMemoId == nil)
        f.notes.play(first)
        f.notes.play(second)                               // switch
        #expect(f.notes.playingMemoId == second.id)
        #expect(f.memoEngine.loadedURL == f.root.appending(path: second.audioPath))
    }

    @Test("open-at-pin stops memo playback and seeks narration to the pinned ms")
    func openAtPinSeeks() throws {
        let f = try makeFixture()
        let memo = try makeMemo(in: f, positionMs: 2_200)
        f.notes.play(memo)
        f.notes.openAtPin(memo)
        #expect(!f.memoEngine.isPlaying)
        #expect(f.player.positionMs == 2_200)
        #expect(f.chapterEngine.seeks.contains(2_200))
    }

    @Test("delete sweeps the row and the audio file, stopping it if playing")
    func deleteSweeps() throws {
        let f = try makeFixture()
        let memo = try makeMemo(in: f)
        let audioURL = f.root.appending(path: memo.audioPath)
        f.notes.play(memo)
        f.notes.delete(memo)
        #expect(!f.memoEngine.isPlaying)
        #expect(f.notes.playingMemoId == nil)
        #expect(try f.context.fetch(FetchDescriptor<Memo>()).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: audioURL.path))
    }

    @Test("memos list is the open chapter's, newest first")
    func memosNewestFirst() throws {
        let f = try makeFixture()
        let older = try makeMemo(in: f)
        older.createdAt = .now.addingTimeInterval(-60)
        let newer = try makeMemo(in: f)
        try f.context.save()
        #expect(f.notes.memos.map(\.id) == [newer.id, older.id])
    }

    @Test("retry routes to the store's transcription (the V29 path)")
    func retryRoutesToStore() throws {
        let f = try makeFixture()
        let memo = try makeMemo(in: f)
        memo.status = .error
        f.notes.retry(memo)
        #expect(memo.status == .pending)                   // store re-submitted it
    }
}
