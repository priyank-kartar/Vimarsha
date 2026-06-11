import Foundation

/// A picked EPUB copied into the app container (V10).
struct ImportedEpub: Equatable, Sendable {
    let bookId: UUID
    /// Container-relative path (`Library/Books/<bookId>/book.epub`). Persisted paths are
    /// container-relative because the container moves between installs (data-model.md).
    let relativePath: String
}

/// Copies a user-picked EPUB into the app container, following the cache layout in
/// `plan/04-architecture/data-model.md`: `Library/Books/<bookId>/book.epub`.
///
/// The security-scoped origin (a `fileImporter` URL outside our sandbox) is accessed just
/// long enough to copy and released after — the app keeps its own copy, so no persistent
/// bookmark is stored (app-architecture.md "security-scoped origin released after copy").
/// File IO stays off the main actor (`nonisolated`); callers wrap it in a `Task`.
nonisolated struct EpubImporter {
    /// The app-container root the `Library/Books` tree lives under.
    let containerRoot: URL
    /// Injectable for tests; fresh UUID v4 in production (Flutter `LibraryRepository` parity).
    var makeId: @Sendable () -> UUID = { UUID() }

    /// The production importer, rooted at the app's Application Support directory.
    static let live = EpubImporter(containerRoot: .applicationSupportDirectory)

    /// Copy `pickedURL` into `Library/Books/<freshId>/book.epub`. On failure the
    /// half-created book directory is rolled back (no half-state, Flutter parity).
    func importEpub(at pickedURL: URL) throws -> ImportedEpub {
        let scoped = pickedURL.startAccessingSecurityScopedResource()
        defer { if scoped { pickedURL.stopAccessingSecurityScopedResource() } }

        let id = makeId()
        let relativePath = "Library/Books/\(id.uuidString)/book.epub"
        let destination = containerRoot.appending(path: relativePath)
        let bookDir = destination.deletingLastPathComponent()
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: bookDir, withIntermediateDirectories: true)
            try fm.copyItem(at: pickedURL, to: destination)
        } catch {
            try? fm.removeItem(at: bookDir)
            throw error
        }
        return ImportedEpub(bookId: id, relativePath: relativePath)
    }
}
