import Foundation
import SwiftData
import SwiftUI

/// The library's store (app-architecture.md layering: view → store → seams): owns the
/// persisted `Book` rows and the import flow (V10 copy → V11 cover → V12 row). UI-facing
/// and `@Observable`; file IO runs detached off the main actor.
@Observable
final class LibraryStore {
    private let context: ModelContext
    private let importer: EpubImporter
    private let backend: any BackendClient

    /// All books, oldest-first (the shelf reads bottom-up like the reference stack).
    private(set) var books: [Book] = []
    /// Pre-downsampled cover art per book (decoded off-main at load, never during
    /// scroll — apple/CLAUDE.md §Performance budget).
    private(set) var covers: [UUID: Image] = [:]
    /// Honest error posture: the last failed import, surfaced as a status line on the
    /// surface (not an alert); cleared on the next attempt.
    var importError: String?

    init(
        context: ModelContext,
        importer: EpubImporter = .live,
        backend: any BackendClient = URLSessionBackendClient()
    ) {
        self.context = context
        self.importer = importer
        self.backend = backend
        load()
    }

    /// What the shelf shows: persisted books when any exist; the static seeds as the
    /// empty-state/demo path (V12 — the seed shelf stops being the only library).
    var shelf: [ShelfBook] {
        books.isEmpty
            ? ShelfBook.seeds
            : books.map { ShelfBook(book: $0, cover: covers[$0.id]) }
    }

    func load() {
        let descriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.addedAt)])
        books = (try? context.fetch(descriptor)) ?? []
        loadMissingCovers()
    }

    /// Decode (downsampled) any cover art not yet cached, off the main actor; each
    /// finished decode updates `covers` and re-renders the shelf.
    private func loadMissingCovers() {
        for book in books where covers[book.id] == nil {
            guard let coverPath = book.coverPath else { continue }
            let url = importer.containerRoot.appending(path: coverPath)
            let id = book.id
            Task { [weak self] in
                guard let image = await Task.detached(operation: { CoverArt.shelfImage(at: url) }).value
                else { return }
                self?.covers[id] = image
            }
        }
    }

    /// Import a picked EPUB: container copy + cover extraction off-main, `POST /toc`
    /// through the seam (V13), then persist the book + its chapter rows in one go.
    /// All-or-nothing (Flutter `LibraryRepository` parity): if the backend can't read the
    /// book, the copied files are rolled back and nothing lands. The backend's meta is
    /// the authority; the OPF-read `EpubInfo` fills any blanks (last resort: filename).
    func addBook(from pickedURL: URL) async {
        importError = nil
        let importer = self.importer
        let backend = self.backend
        do {
            let (imported, info, toc) = try await Task.detached {
                () -> (ImportedEpub, EpubInfo.Metadata?, TocResponse) in
                let imported = try importer.importEpub(at: pickedURL)
                let stored = importer.containerRoot.appending(path: imported.relativePath)
                do {
                    let toc = try await backend.fetchToc(epubAt: stored)
                    return (imported, EpubInfo.extract(fromEpubAt: stored), toc)
                } catch {
                    // No half-state: a book the backend can't serve never lands.
                    try? FileManager.default.removeItem(at: stored.deletingLastPathComponent())
                    throw error
                }
            }.value
            let fallbackTitle = info?.title ?? pickedURL.deletingPathExtension().lastPathComponent
            let book = Book(
                id: imported.bookId,
                title: toc.book.title.isEmpty ? fallbackTitle : toc.book.title,
                author: toc.book.author.isEmpty ? (info?.author ?? "") : toc.book.author,
                epubPath: imported.relativePath,
                coverPath: imported.coverRelativePath
            )
            book.chapters = toc.chapters.map { Chapter(index: $0.index, title: $0.title) }
            context.insert(book)
            try context.save()
            load()
        } catch {
            importError = "Couldn't import book"
        }
    }

    /// Remove the book row (cascades to chapters) and its container subtree
    /// (data-model.md §Rules — deletion).
    func deleteBook(_ book: Book) {
        let bookDir = importer.containerRoot
            .appending(path: book.epubPath)
            .deletingLastPathComponent()
        try? FileManager.default.removeItem(at: bookDir)
        context.delete(book)
        try? context.save()
        load()
    }
}
