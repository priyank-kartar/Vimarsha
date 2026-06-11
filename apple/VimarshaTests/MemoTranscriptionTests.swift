import Foundation
import SwiftData
import Testing
@testable import Vimarsha

/// V29 — memo transcription through the network seam: `LibraryStore.transcribeMemo`
/// drives `pending → ready/error` (the chapter-status pattern) with store-owned tasks,
/// and retry re-attempts error/stranded-pending rows. Real in-memory SwiftData + real
/// temp files; `FakeBackendClient` is the sanctioned double.
@MainActor
struct MemoTranscriptionTests {
    private struct Fixture {
        let store: LibraryStore
        let memo: Memo
        let context: ModelContext
        let root: URL
    }

    /// A persisted book/chapter/memo (real m4a bytes on disk) and a store whose backend
    /// transcribes through `onTranscribe`.
    private func makeFixture(
        onTranscribe: @escaping @Sendable (URL) async throws -> String
    ) throws -> Fixture {
        let container = try ModelContainer(
            for: Book.self, Chapter.self, Memo.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let root = FileManager.default.temporaryDirectory
            .appending(path: "MemoTranscriptionTests-\(UUID().uuidString)")
        let book = Book(title: "T", author: "A", epubPath: "Library/Books/x/book.epub")
        let chapter = Chapter(index: 0, title: "One")
        book.chapters = [chapter]
        context.insert(book)
        let memo = Memo(
            paragraphIndex: 1, positionMs: 1_500, audioPath: "Library/Books/x/memos/m1.m4a"
        )
        memo.chapter = chapter
        context.insert(memo)
        try context.save()
        let audioURL = root.appending(path: memo.audioPath)
        try FileManager.default.createDirectory(
            at: audioURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data("aac".utf8).write(to: audioURL)

        var backend = FakeBackendClient.returning()
        backend.onTranscribe = onTranscribe
        let store = LibraryStore(
            context: context, importer: EpubImporter(containerRoot: root), backend: backend
        )
        return Fixture(store: store, memo: memo, context: context, root: root)
    }

    @Test("a pending memo transcribes to ready with the backend's text")
    func pendingTranscribesToReady() async throws {
        let f = try makeFixture { url in
            #expect(url.lastPathComponent == "m1.m4a")
            return "  What a passage.  "
        }
        let task = try #require(f.store.transcribeMemo(f.memo))
        await task.value
        #expect(f.memo.status == .ready)
        #expect(f.memo.transcript == "What a passage.")   // whitespace trimmed
        #expect(f.memo.errorReason == nil)
    }

    @Test("backend failure marks error with a reason; audio + row are kept")
    func failureMarksError() async throws {
        let f = try makeFixture { _ in throw URLError(.cannotConnectToHost) }
        let task = try #require(f.store.transcribeMemo(f.memo))
        await task.value
        #expect(f.memo.status == .error)
        #expect(f.memo.errorReason != nil)
        #expect(f.memo.transcript == nil)
        #expect(FileManager.default.fileExists(
            atPath: f.root.appending(path: f.memo.audioPath).path
        ))
    }

    @Test("retry after error re-attempts and can succeed")
    func retryAfterError() async throws {
        let attempts = Atomic(0)
        let f = try makeFixture { _ in
            if attempts.increment() == 1 { throw URLError(.timedOut) }
            return "Second try."
        }
        await (try #require(f.store.transcribeMemo(f.memo))).value
        #expect(f.memo.status == .error)
        await (try #require(f.store.transcribeMemo(f.memo))).value
        #expect(f.memo.status == .ready)
        #expect(f.memo.transcript == "Second try.")
    }

    @Test("a ready memo is not re-transcribed")
    func readyIsNoOp() async throws {
        let f = try makeFixture { _ in "ignored" }
        f.memo.status = .ready
        f.memo.transcript = "Done already"
        #expect(f.store.transcribeMemo(f.memo) == nil)
        #expect(f.memo.transcript == "Done already")
    }

    @Test("a memo with an in-flight job is not double-submitted")
    func inFlightGuard() async throws {
        let f = try makeFixture { _ in
            try? await Task.sleep(for: .milliseconds(50))
            return "Once."
        }
        let first = try #require(f.store.transcribeMemo(f.memo))
        #expect(f.store.transcribeMemo(f.memo) == nil)     // second submit refused
        await first.value
        #expect(f.memo.status == .ready)
    }
}

/// A tiny sendable counter for closure-side attempt tracking.
nonisolated final class Atomic: @unchecked Sendable {
    private var value: Int
    private let lock = NSLock()
    init(_ value: Int) { self.value = value }
    func increment() -> Int {
        lock.lock(); defer { lock.unlock() }
        value += 1
        return value
    }
}
