import Testing
import SwiftData
@testable import Vimarsha

@Suite("Voice persistence defaults")
@MainActor
struct VoicePersistenceTests {
    private func newContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Book.self, Chapter.self, Memo.self, ChatThread.self, ChatLine.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func newBookDefaultsToAria() throws {
        let ctx = try newContext()
        let book = Book(title: "T", author: "A", epubPath: "p")
        ctx.insert(book)
        #expect(book.voiceId == "Aria")
    }

    @Test func newChapterHasNoNarratedVoiceYet() throws {
        let ctx = try newContext()
        let ch = Chapter(index: 0, title: "Ch")
        ctx.insert(ch)
        #expect(ch.narratedVoiceId == nil)
    }
}
