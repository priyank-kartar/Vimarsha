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

    /// All books, oldest-first (the shelf reads bottom-up like the reference stack).
    private(set) var books: [Book] = []
    /// Pre-downsampled cover art per book (decoded off-main at load, never during
    /// scroll — apple/CLAUDE.md §Performance budget).
    private(set) var covers: [UUID: Image] = [:]
    /// Honest error posture: the last failed import, surfaced as a status line on the
    /// surface (not an alert); cleared on the next attempt.
    var importError: String?

    init(context: ModelContext, importer: EpubImporter = .live) {
        self.context = context
        self.importer = importer
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

    /// Import a picked EPUB: container copy + cover extraction off-main, then persist the
    /// row. Title/author come straight from the OPF (`EpubInfo`); a metadata-less EPUB
    /// falls back to its filename. Chapters arrive with V13's `/toc`.
    func addBook(from pickedURL: URL) async {
        importError = nil
        let importer = self.importer
        do {
            let (imported, info) = try await Task.detached {
                let imported = try importer.importEpub(at: pickedURL)
                let stored = importer.containerRoot.appending(path: imported.relativePath)
                return (imported, EpubInfo.extract(fromEpubAt: stored))
            }.value
            let book = Book(
                id: imported.bookId,
                title: info?.title ?? pickedURL.deletingPathExtension().lastPathComponent,
                author: info?.author ?? "",
                epubPath: imported.relativePath,
                coverPath: imported.coverRelativePath
            )
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
