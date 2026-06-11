import Foundation
import SwiftData
import Testing
@testable import Vimarsha

/// V32 — saved conversations (save-on-demand): each Save inserts a NEW ordered thread,
/// empty saves are refused, deletion cascades lines, and deleting a book sweeps its
/// threads. Real in-memory SwiftData throughout.
@MainActor
struct ChatPersistenceTests {
    private struct Fixture {
        let store: LibraryStore
        let book: Book
        let context: ModelContext
    }

    private func makeFixture() throws -> Fixture {
        let container = try ModelContainer(
            for: Book.self, Chapter.self, Memo.self, ChatThread.self, ChatLine.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let root = FileManager.default.temporaryDirectory
            .appending(path: "ChatPersistenceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let book = Book(title: "T", author: "A", epubPath: "Library/Books/x/book.epub")
        context.insert(book)
        try context.save()
        let store = LibraryStore(
            context: context, importer: EpubImporter(containerRoot: root),
            backend: FakeBackendClient.returning()
        )
        return Fixture(store: store, book: book, context: context)
    }

    @Test func saveInsertsOneOrderedThread() throws {
        let f = try makeFixture()
        let thread = f.store.saveChatThread(
            book: f.book, chapterIndex: 2, anchorBlockId: "b7", title: "What is entropy?",
            messages: [.user("Q1"), .assistant("A1"), .user("Q2"), .assistant("A2")]
        )

        #expect(thread != nil)
        let fetched = try f.context.fetch(FetchDescriptor<ChatThread>())
        #expect(fetched.count == 1)
        #expect(fetched[0].book?.id == f.book.id)
        #expect(fetched[0].chapterIndex == 2)
        #expect(fetched[0].anchorBlockId == "b7")
        #expect(fetched[0].title == "What is entropy?")
        let lines = fetched[0].lines.sorted { $0.index < $1.index }
        #expect(lines.map(\.role) == ["user", "assistant", "user", "assistant"])
        #expect(lines.map(\.text) == ["Q1", "A1", "Q2", "A2"])
    }

    @Test func eachSaveIsANewThread() throws {
        let f = try makeFixture()
        f.store.saveChatThread(
            book: f.book, chapterIndex: 0, anchorBlockId: nil, title: nil,
            messages: [.user("Q"), .assistant("A")]
        )
        f.store.saveChatThread(
            book: f.book, chapterIndex: 0, anchorBlockId: nil, title: nil,
            messages: [.user("Q"), .assistant("A")]
        )
        #expect(try f.context.fetch(FetchDescriptor<ChatThread>()).count == 2)
    }

    @Test func emptySaveIsRefused() throws {
        let f = try makeFixture()
        let thread = f.store.saveChatThread(
            book: f.book, chapterIndex: 0, anchorBlockId: nil, title: nil, messages: []
        )
        #expect(thread == nil)
        #expect(try f.context.fetch(FetchDescriptor<ChatThread>()).isEmpty)
    }

    @Test func threadsListIsChapterScopedNewestFirst() throws {
        let f = try makeFixture()
        let old = ChatThread(chapterIndex: 1, createdAt: Date(timeIntervalSince1970: 100))
        let new = ChatThread(chapterIndex: 1, createdAt: Date(timeIntervalSince1970: 200))
        let other = ChatThread(chapterIndex: 3, createdAt: Date(timeIntervalSince1970: 300))
        for thread in [old, new, other] {
            thread.book = f.book
            f.context.insert(thread)
        }
        try f.context.save()

        let listed = f.store.chatThreads(for: f.book, chapterIndex: 1)
        #expect(listed.map(\.id) == [new.id, old.id])
    }

    @Test func deleteThreadCascadesLines() throws {
        let f = try makeFixture()
        let thread = f.store.saveChatThread(
            book: f.book, chapterIndex: 0, anchorBlockId: nil, title: nil,
            messages: [.user("Q"), .assistant("A")]
        )!
        f.store.deleteChatThread(thread)

        #expect(try f.context.fetch(FetchDescriptor<ChatThread>()).isEmpty)
        #expect(try f.context.fetch(FetchDescriptor<ChatLine>()).isEmpty)
    }

    @Test func deletingTheBookSweepsItsThreads() throws {
        let f = try makeFixture()
        f.store.saveChatThread(
            book: f.book, chapterIndex: 0, anchorBlockId: nil, title: nil,
            messages: [.user("Q"), .assistant("A")]
        )
        f.store.deleteBook(f.book)

        #expect(try f.context.fetch(FetchDescriptor<ChatThread>()).isEmpty)
        #expect(try f.context.fetch(FetchDescriptor<ChatLine>()).isEmpty)
    }
}
