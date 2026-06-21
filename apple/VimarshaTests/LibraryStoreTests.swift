import Foundation
import SwiftData
import Testing
@testable import Vimarsha

/// V12 — SwiftData persistence + the library store. Real in-memory SwiftData and a real
/// temp-dir importer (house rule: only `BackendClient`/audio get doubles).
@MainActor
struct LibraryStoreTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Book.self, Chapter.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "LibraryStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// A picked EPUB with real OPF metadata + a cover image, on disk.
    private func makePickedEpub(in dir: URL) throws -> URL {
        let epub = ZipFixture.epub(
            opf: """
            <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
              <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:title>A Sense of Place</dc:title>
                <dc:creator>David Thulstrup</dc:creator>
              </metadata>
              <manifest>
                <item id="art" href="front.png" media-type="image/png" properties="cover-image"/>
              </manifest>
            </package>
            """,
            files: [.init(name: "OEBPS/front.png", data: Data([0x89, 0x50, 0x4E, 0x47, 5]))]
        )
        let url = dir.appending(path: "picked.epub")
        try epub.write(to: url)
        return url
    }

    // MARK: models

    @Test func bookAndChaptersRoundTrip() throws {
        let context = try makeContext()
        let book = Book(title: "Optic", author: "Studio Feixen", epubPath: "Library/Books/x/book.epub")
        book.chapters = [
            Chapter(index: 0, title: "One"),
            Chapter(index: 1, title: "Two"),
        ]
        context.insert(book)
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<Book>()).first)
        #expect(fetched.title == "Optic")
        #expect(fetched.author == "Studio Feixen")
        #expect(fetched.coverPath == nil)
        #expect(fetched.chapters.count == 2)
        let chapter = try #require(fetched.chapters.first(where: { $0.index == 1 }))
        #expect(chapter.title == "Two")
        #expect(chapter.status == .none)        // fresh chapters haven't been narrated
        #expect(chapter.progressMs == 0)
    }

    @Test func chapterStatusPersistsThroughRawStorage() throws {
        let context = try makeContext()
        let book = Book(title: "T", author: "", epubPath: "p")
        let chapter = Chapter(index: 0, title: "C")
        book.chapters = [chapter]
        context.insert(book)
        chapter.status = .error
        chapter.errorReason = "no narratable text"
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<Chapter>()).first)
        #expect(fetched.status == .error)
        #expect(fetched.errorReason == "no narratable text")
    }

    @Test func deletingABookCascadesToItsChapters() throws {
        let context = try makeContext()
        let book = Book(title: "T", author: "", epubPath: "p")
        book.chapters = [Chapter(index: 0, title: "C")]
        context.insert(book)
        try context.save()

        context.delete(book)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Chapter>()).isEmpty)
    }

    // MARK: store

    private func makeStore(
        root: URL, backend: FakeBackendClient = .returning()
    ) throws -> LibraryStore {
        LibraryStore(
            context: try makeContext(),
            importer: EpubImporter(containerRoot: root),
            backend: backend
        )
    }

    @Test func addBookImportsFetchesTocAndPersists() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try makeStore(root: root)
        await store.addBook(from: try makePickedEpub(in: root))

        #expect(store.importError == nil)
        let book = try #require(store.books.first)
        // The backend's meta is the authority (V13) — it overrides the OPF values.
        #expect(book.title == "Backend Title")
        #expect(book.author == "Backend Author")
        #expect(book.coverPath?.hasSuffix("cover.png") == true)
        // Chapter rows from /toc, fresh lifecycle state.
        #expect(book.chapters.count == 2)
        let chapter = try #require(book.chapters.first(where: { $0.index == 1 }))
        #expect(chapter.title == "Chapter Two")
        #expect(chapter.status == .none)
        // The files actually landed where the rows point.
        #expect(FileManager.default.fileExists(atPath: root.appending(path: book.epubPath).path))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: book.coverPath!).path))
    }

    @Test func emptyBackendTitleFallsBackToOpfMetadata() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try makeStore(root: root, backend: .returning(title: "", author: ""))
        await store.addBook(from: try makePickedEpub(in: root))

        let book = try #require(store.books.first)
        #expect(book.title == "A Sense of Place")   // dc:title via EpubInfo
        #expect(book.author == "David Thulstrup")   // dc:creator via EpubInfo
    }

    @Test func addBookFailureSurfacesAndPersistsNothing() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try makeStore(root: root)
        await store.addBook(from: root.appending(path: "missing.epub"))

        #expect(store.books.isEmpty)
        #expect(store.importError != nil)
    }

    @Test func tocFailureRollsBackTheCopiedFiles() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try makeStore(root: root, backend: .failing())
        await store.addBook(from: try makePickedEpub(in: root))

        // No half-state (Flutter parity): no row, no error-book, and no orphan files.
        #expect(store.books.isEmpty)
        #expect(store.importError != nil)
        let booksDir = root.appending(path: "Library/Books")
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: booksDir.path)) ?? []
        #expect(leftovers.isEmpty)
    }

    @Test func deleteBookRemovesRowAndContainerSubtree() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try makeStore(root: root)
        await store.addBook(from: try makePickedEpub(in: root))
        let book = try #require(store.books.first)
        let bookDir = root.appending(path: book.epubPath).deletingLastPathComponent()
        #expect(FileManager.default.fileExists(atPath: bookDir.path))

        store.deleteBook(book)
        #expect(store.books.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: bookDir.path))
    }

    // MARK: chapter download lifecycle (V14)

    /// A persisted book with chapter rows, imported through the normal flow.
    private func makeStoreWithBook(
        root: URL, backend: FakeBackendClient
    ) async throws -> (LibraryStore, Book) {
        let store = try makeStore(root: root, backend: backend)
        await store.addBook(from: try makePickedEpub(in: root))
        return (store, try #require(store.books.first))
    }

    @Test func downloadChapterCachesAndMarksReady() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        // .narrating() builds on .returning(), so /toc works for the import too.
        let (store, book) = try await makeStoreWithBook(root: root, backend: .narrating())
        let chapter = try #require(book.chapters.first(where: { $0.index == 0 }))

        let task = try #require(store.downloadChapter(chapter))
        #expect(chapter.status == .pending)     // honest in-flight state, synchronously
        await task.value

        #expect(chapter.status == .ready)
        #expect(chapter.errorReason == nil)
        let bundlePath = try #require(chapter.bundlePath)
        let audioPath = try #require(chapter.audioPath)
        #expect(FileManager.default.fileExists(atPath: root.appending(path: bundlePath).path))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: audioPath).path))
    }

    @Test func downloadFailureMarksErrorWithReason() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        var backend = FakeBackendClient.returning()
        backend.onImportChapter = { _, _ in throw BackendError.badStatus(500) }
        let (store, book) = try await makeStoreWithBook(root: root, backend: backend)
        let chapter = try #require(book.chapters.first)

        await store.downloadChapter(chapter)?.value

        #expect(chapter.status == .error)
        #expect(chapter.errorReason != nil)
        #expect(chapter.bundlePath == nil)
    }

    @Test func errorChaptersCanRetryButReadyAndPendingCannot() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let (store, book) = try await makeStoreWithBook(root: root, backend: .narrating())
        let chapter = try #require(book.chapters.first)

        chapter.status = .ready
        #expect(store.downloadChapter(chapter) == nil)
        chapter.status = .pending
        #expect(store.downloadChapter(chapter) == nil)
        chapter.status = .error
        let retry = store.downloadChapter(chapter)
        #expect(retry != nil)
        await retry?.value
        #expect(chapter.status == .ready)
    }

    @Test func deleteBookCancelsItsInFlightDownload() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        var backend = FakeBackendClient.narrating()
        backend.onImportChapter = { _, _ in
            // Long enough that only cancellation can finish this test promptly.
            try await Task.sleep(for: .seconds(60))
            return .fixture()
        }
        let (store, book) = try await makeStoreWithBook(root: root, backend: backend)
        let chapter = try #require(book.chapters.first)

        let task = try #require(store.downloadChapter(chapter))
        store.deleteBook(book)
        await task.value                        // returns promptly only if cancelled

        #expect(store.books.isEmpty)            // and the deleted row was never resurrected
    }

    // MARK: self-heal on load (V14, data-model.md §Rules)

    @Test func readyChapterWithMissingFilesHealsToNone() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let (store, book) = try await makeStoreWithBook(root: root, backend: .narrating())
        let chapter = try #require(book.chapters.first)
        chapter.status = .ready                 // claims ready, but no files exist
        chapter.bundlePath = "Library/Books/x/chapters/0/bundle.json"
        chapter.audioPath = "Library/Books/x/chapters/0/chapter.mp3"

        store.load()

        #expect(chapter.status == .none)
        #expect(chapter.bundlePath == nil)
        #expect(chapter.audioPath == nil)
    }

    @Test func orphanedPendingChapterHealsToNone() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let (store, book) = try await makeStoreWithBook(root: root, backend: .narrating())
        let chapter = try #require(book.chapters.first)
        chapter.status = .pending               // a relaunch orphaned the job

        store.load()

        #expect(chapter.status == .none)
    }

    @Test func healedReadyChapterSurvivesWhenFilesExist() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let (store, book) = try await makeStoreWithBook(root: root, backend: .narrating())
        let chapter = try #require(book.chapters.first)
        await store.downloadChapter(chapter)?.value
        #expect(chapter.status == .ready)

        store.load()                            // files are real → stays ready

        #expect(chapter.status == .ready)
        #expect(chapter.bundlePath != nil)
    }

    @Test func booksAreSortedByRecencyMostRecentFirst() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let context = try makeContext()
        let older = Book(title: "Older", author: "", epubPath: "a")
        older.addedAt = Date(timeIntervalSince1970: 100)
        let newer = Book(title: "Newer", author: "", epubPath: "b")
        newer.addedAt = Date(timeIntervalSince1970: 200)
        context.insert(newer)
        context.insert(older)
        try context.save()

        let store = LibraryStore(context: context, importer: EpubImporter(containerRoot: root))
        store.load()
        // No opens yet → falls back to addedAt, most-recent first.
        #expect(store.books.map(\.title) == ["Newer", "Older"])
    }

    @Test func markOpenedBubblesBookToTop() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let context = try makeContext()
        let a = Book(title: "Older", author: "", epubPath: "a")
        a.addedAt = Date(timeIntervalSince1970: 100)
        let b = Book(title: "Newer", author: "", epubPath: "b")
        b.addedAt = Date(timeIntervalSince1970: 200)
        context.insert(a)
        context.insert(b)
        try context.save()

        let store = LibraryStore(context: context, importer: EpubImporter(containerRoot: root))
        store.load()
        #expect(store.books.map(\.title) == ["Newer", "Older"])

        // Opening the older book bubbles it to the top (latest-listened leads).
        let older = try #require(store.books.first { $0.title == "Older" })
        store.markOpened(older)
        #expect(store.books.map(\.title) == ["Older", "Newer"])
    }
}
