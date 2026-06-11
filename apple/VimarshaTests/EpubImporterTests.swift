import Foundation
import Testing
@testable import Vimarsha

/// V10 — EPUB import into the app container. Real file IO against a temp container root
/// (the repo's test philosophy: only `BackendClient` and the audio seam get doubles;
/// file work tests real).
struct EpubImporterTests {
    /// A fresh fake container root per test.
    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "EpubImporterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// A fake picked EPUB (the importer copies bytes; it doesn't parse — that's V11).
    private func makePickedEpub(in dir: URL, bytes: Data = Data("epub-bytes".utf8)) throws -> URL {
        let url = dir.appending(path: "picked.epub")
        try bytes.write(to: url)
        return url
    }

    @Test func importCopiesEpubIntoContainerLayout() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try makePickedEpub(in: root, bytes: Data("the-book".utf8))

        let id = UUID()
        let importer = EpubImporter(containerRoot: root, makeId: { id })
        let imported = try importer.importEpub(at: source)

        // data-model.md cache layout: Library/Books/<bookId>/book.epub, container-relative.
        #expect(imported.bookId == id)
        #expect(imported.relativePath == "Library/Books/\(id.uuidString)/book.epub")
        let stored = root.appending(path: imported.relativePath)
        #expect(try Data(contentsOf: stored) == Data("the-book".utf8))
    }

    @Test func eachImportGetsItsOwnBookDirectory() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try makePickedEpub(in: root)

        let importer = EpubImporter(containerRoot: root)
        let first = try importer.importEpub(at: source)
        let second = try importer.importEpub(at: source)

        #expect(first.bookId != second.bookId)
        #expect(first.relativePath != second.relativePath)
        #expect(FileManager.default.fileExists(atPath: root.appending(path: first.relativePath).path))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: second.relativePath).path))
    }

    @Test func failedImportLeavesNoHalfState() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let missing = root.appending(path: "nope.epub")

        let id = UUID()
        let importer = EpubImporter(containerRoot: root, makeId: { id })
        #expect(throws: (any Error).self) {
            try importer.importEpub(at: missing)
        }
        // The book directory created for the copy is rolled back (Flutter
        // LibraryRepository parity: no half-state on failure).
        let bookDir = root.appending(path: "Library/Books/\(id.uuidString)")
        #expect(!FileManager.default.fileExists(atPath: bookDir.path))
    }
}
