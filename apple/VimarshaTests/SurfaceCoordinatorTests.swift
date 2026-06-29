import Foundation
import SwiftData
import Testing
@testable import Vimarsha

/// `SurfaceCoordinator` (single-live-surface, chunk 1): the app-lifetime router. One live
/// surface at a time; the `BookSession` is created on chapter-open and released only when the
/// surface returns to the library.
@MainActor
struct SurfaceCoordinatorTests {
    private func makeFixture() throws -> (store: LibraryStore, book: Book, chapter: Chapter) {
        let container = try ModelContainer(
            for: Book.self, Chapter.self, Memo.self, ChatThread.self, ChatLine.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let root = FileManager.default.temporaryDirectory
            .appending(path: "SurfaceCoordinatorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = LibraryStore(
            context: context, importer: EpubImporter(containerRoot: root),
            backend: FakeBackendClient.returning()
        )
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
        return (store, book, chapter)
    }

    @discardableResult
    private func enterReading(_ c: SurfaceCoordinator, _ f: (store: LibraryStore, book: Book, chapter: Chapter)) -> Bool {
        c.openReading(
            book: f.book, chapter: f.chapter, store: f.store,
            audioEngine: FakeAudioEngine(), recorder: nil,
            memoEngine: FakeAudioEngine(), speechEngine: FakeAudioEngine()
        )
    }

    @Test func startsAtLibraryWithNoSession() {
        let c = SurfaceCoordinator()
        #expect(c.activeSurface == .library)
        #expect(c.session == nil)
    }

    @Test func openingAChapterEntersReadingWithASession() throws {
        let f = try makeFixture()
        let c = SurfaceCoordinator()
        #expect(enterReading(c, f))
        #expect(c.activeSurface == .reading)
        #expect(c.session != nil)
    }

    @Test func discussKeepsTheSameSession() throws {
        let f = try makeFixture()
        let c = SurfaceCoordinator()
        enterReading(c, f)
        let session = try #require(c.session)
        c.openDiscuss()
        #expect(c.activeSurface == .discuss)
        #expect(c.session === session)
    }

    @Test func closingDiscussReturnsToReadingSessionIntact() throws {
        let f = try makeFixture()
        let c = SurfaceCoordinator()
        enterReading(c, f)
        let session = try #require(c.session)
        c.openDiscuss()
        c.close()
        #expect(c.activeSurface == .reading)
        #expect(c.session === session)
    }

    /// Regression: the Discuss chevron-down fires its `onClose` AND the `.sheet`'s
    /// `isPresented`-binding setter on dismissal — two close calls for ONE user action.
    /// A raw double `close()` recedes two levels (.discuss → .reading → .library), releasing
    /// the session (reading transport/controls vanish; the library remounts to a scroll-0
    /// "messed-up scaling" state). `closeDiscuss()` must be idempotent: a redundant dismissal
    /// stays on .reading with the session intact.
    @Test func dismissingDiscussIsIdempotentAndStaysOnReading() throws {
        let f = try makeFixture()
        let c = SurfaceCoordinator()
        enterReading(c, f)
        let session = try #require(c.session)
        c.openDiscuss()
        c.closeDiscuss()   // the chevron-down's onClose
        c.closeDiscuss()   // the sheet binding's dismissal setter — must be a no-op
        #expect(c.activeSurface == .reading)
        #expect(c.session === session)
    }

    @Test func closingReadingReturnsToLibraryAndReleasesSession() throws {
        let f = try makeFixture()
        let c = SurfaceCoordinator()
        enterReading(c, f)
        c.close()
        #expect(c.activeSurface == .library)
        #expect(c.session == nil)
    }

    @Test func libraryLevelPlaneHasNoSession() throws {
        let f = try makeFixture()
        let c = SurfaceCoordinator()
        c.openChapterList(f.book)
        #expect(c.activeSurface == .chapterList(f.book))
        #expect(c.session == nil)
    }

    /// The invariant: a session exists exactly while a reading-level surface is up.
    @Test func sessionExistsIffReadingLevel() throws {
        let f = try makeFixture()
        let c = SurfaceCoordinator()
        #expect(c.session == nil)                 // .library
        enterReading(c, f)
        #expect(c.session != nil)                 // .reading
        c.openNotes(); #expect(c.session != nil)  // .notes
        c.close(); c.close()                      // notes → reading → library
        #expect(c.activeSurface == .library)
        #expect(c.session == nil)
    }
}
