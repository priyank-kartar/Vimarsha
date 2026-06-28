import Foundation
import SwiftData
import Testing
@testable import Vimarsha

/// `BookSession` (single-live-surface, chunk 1): the book-lifetime object that owns the
/// player/chat/memo/voice/speaker so they survive surface switches. `open` lifts the wiring
/// out of `LibraryStackView.openReadingSurface`; `close` lifts its teardown.
@MainActor
struct BookSessionTests {
    private func makeStore() throws -> (store: LibraryStore, context: ModelContext, root: URL) {
        let container = try ModelContainer(
            for: Book.self, Chapter.self, Memo.self, ChatThread.self, ChatLine.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let root = FileManager.default.temporaryDirectory
            .appending(path: "BookSessionTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = LibraryStore(
            context: context, importer: EpubImporter(containerRoot: root),
            backend: FakeBackendClient.returning()
        )
        return (store, context, root)
    }

    @discardableResult
    private func insertChapter(
        context: ModelContext, root: URL, ready: Bool = true
    ) throws -> (Book, Chapter) {
        let book = Book(title: "T", author: "A", epubPath: "Library/Books/x/book.epub")
        let chapter = Chapter(index: 0, title: "One")
        if ready {
            chapter.status = .ready
            chapter.audioPath = "Library/Books/x/chapters/0/chapter.mp3"
            chapter.bundlePath = "Library/Books/x/chapters/0/bundle.json"
            let bundleURL = root.appending(path: chapter.bundlePath!)
            try FileManager.default.createDirectory(
                at: bundleURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try JSONEncoder().encode(ChapterBundleDTO.timedFixture).write(to: bundleURL)
        }
        book.chapters = [chapter]
        context.insert(book)
        try context.save()
        return (book, chapter)
    }

    @Test func openLoadsTheReadyChapterAndBuildsTheSession() throws {
        let f = try makeStore()
        let (book, chapter) = try insertChapter(context: f.context, root: f.root)
        let session = try #require(BookSession.open(
            store: f.store, audioEngine: FakeAudioEngine(), recorder: nil,
            book: book, chapter: chapter,
            memoEngine: FakeAudioEngine(), speechEngine: FakeAudioEngine()
        ))
        #expect(session.player.bundle != nil)
        #expect(session.context.chapter.index == 0)
        // No recorder → no mic-backed objects.
        #expect(session.memoCapture == nil)
        #expect(session.voiceInput == nil)
    }

    @Test func openReturnsNilForANonReadyChapter() throws {
        let f = try makeStore()
        let (book, chapter) = try insertChapter(context: f.context, root: f.root, ready: false)
        let session = BookSession.open(
            store: f.store, audioEngine: FakeAudioEngine(), recorder: nil,
            book: book, chapter: chapter,
            memoEngine: FakeAudioEngine(), speechEngine: FakeAudioEngine()
        )
        #expect(session == nil)
    }

    @Test func closePausesThePlayer() throws {
        let f = try makeStore()
        let (book, chapter) = try insertChapter(context: f.context, root: f.root)
        let session = try #require(BookSession.open(
            store: f.store, audioEngine: FakeAudioEngine(), recorder: nil,
            book: book, chapter: chapter,
            memoEngine: FakeAudioEngine(), speechEngine: FakeAudioEngine()
        ))
        session.player.play()
        #expect(session.player.isPlaying)
        session.close()
        #expect(!session.player.isPlaying)
    }
}
