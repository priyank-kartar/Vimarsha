import Foundation
import Testing
import SwiftData
@testable import Vimarsha

@Suite("LibraryStore narrates in the book's voice")
@MainActor
struct LibraryStoreVoiceTests {
    @Test func downloadStampsNarratedVoiceFromBook() async throws {
        let env = try await VoiceStoreEnv.make()
        defer { try? FileManager.default.removeItem(at: env.root) }
        env.book.voiceId = "Milo"
        let task = env.store.downloadChapter(env.chapter)
        await task?.value
        #expect(env.fake.lastImportVoice == "am_michael")     // Milo → am_michael
        #expect(env.chapter.status == .ready)
        #expect(env.chapter.narratedVoiceId == "Milo")
    }

    @Test func rerenderReDownloadsAReadyChapterInCurrentVoice() async throws {
        let env = try await VoiceStoreEnv.make()
        defer { try? FileManager.default.removeItem(at: env.root) }
        env.book.voiceId = "Aria"
        await env.store.downloadChapter(env.chapter)?.value
        #expect(env.chapter.narratedVoiceId == "Aria")
        env.book.voiceId = "Imogen"
        #expect(env.chapter.isStaleForBookVoice)
        await env.store.rerenderChapter(env.chapter)?.value
        #expect(env.fake.lastImportVoice == "bf_emma")         // Imogen → bf_emma
        #expect(env.chapter.narratedVoiceId == "Imogen")
        #expect(!env.chapter.isStaleForBookVoice)
    }
}

// MARK: - Test environment

@MainActor
struct VoiceStoreEnv {
    let root: URL
    let store: LibraryStore
    let fake: FakeBackendClient
    let book: Book
    let chapter: Chapter

    static func make() async throws -> VoiceStoreEnv {
        // Set up a temp container root.
        let root = FileManager.default.temporaryDirectory
            .appending(path: "VoiceStoreEnv-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        // Build a minimal EPUB on disk — the fake never reads it but ChapterDownloader
        // calls Data(contentsOf:) so it must exist.
        let epub = ZipFixture.epub(
            opf: """
            <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
              <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:title>Voice Test Book</dc:title>
                <dc:creator>Test Author</dc:creator>
              </metadata>
              <manifest/>
            </package>
            """,
            files: []
        )
        let pickedEpub = root.appending(path: "picked.epub")
        try epub.write(to: pickedEpub)

        // Wire the fake: /toc returns two chapters, /import returns a ready bundle,
        // /audio returns non-empty bytes so download reaches .ready.
        let fake = FakeBackendClient.narrating()

        // Build the store and import the book via the normal path so epubPath lands on disk.
        let container = try ModelContainer(
            for: Book.self, Chapter.self, Memo.self, ChatThread.self, ChatLine.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = LibraryStore(
            context: ModelContext(container),
            importer: EpubImporter(containerRoot: root),
            backend: fake
        )
        await store.addBook(from: pickedEpub)
        let book = try #require(store.books.first)
        let chapter = try #require(book.chapters.first(where: { $0.index == 0 }))

        return VoiceStoreEnv(root: root, store: store, fake: fake, book: book, chapter: chapter)
    }
}
