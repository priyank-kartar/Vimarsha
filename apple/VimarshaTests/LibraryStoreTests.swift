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

    @Test func addBookImportsExtractsAndPersists() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(
            context: try makeContext(),
            importer: EpubImporter(containerRoot: root)
        )
        await store.addBook(from: try makePickedEpub(in: root))

        #expect(store.importError == nil)
        let book = try #require(store.books.first)
        #expect(book.title == "A Sense of Place")
        #expect(book.author == "David Thulstrup")
        #expect(book.coverPath?.hasSuffix("cover.png") == true)
        // The files actually landed where the rows point.
        #expect(FileManager.default.fileExists(atPath: root.appending(path: book.epubPath).path))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: book.coverPath!).path))
    }

    @Test func addBookFailureSurfacesAndPersistsNothing() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(
            context: try makeContext(),
            importer: EpubImporter(containerRoot: root)
        )
        await store.addBook(from: root.appending(path: "missing.epub"))

        #expect(store.books.isEmpty)
        #expect(store.importError != nil)
    }

    @Test func deleteBookRemovesRowAndContainerSubtree() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(
            context: try makeContext(),
            importer: EpubImporter(containerRoot: root)
        )
        await store.addBook(from: try makePickedEpub(in: root))
        let book = try #require(store.books.first)
        let bookDir = root.appending(path: book.epubPath).deletingLastPathComponent()
        #expect(FileManager.default.fileExists(atPath: bookDir.path))

        store.deleteBook(book)
        #expect(store.books.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: bookDir.path))
    }

    @Test func booksAreSortedByAddedAt() async throws {
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
        #expect(store.books.map(\.title) == ["Older", "Newer"])
    }
}
