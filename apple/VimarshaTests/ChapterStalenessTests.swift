import Testing
import SwiftData
@testable import Vimarsha

@Suite("Chapter staleness vs selected voice")
struct ChapterStalenessTests {
    /// The `Chapter.isStaleForBookVoice` convenience guards on the owning book — an orphaned
    /// chapter (book deleted before the view updates) must never read as stale.
    @MainActor
    @Test func chapterWithNoBookIsNeverStale() throws {
        let container = try ModelContainer(
            for: Book.self, Chapter.self, Memo.self, ChatThread.self, ChatLine.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = ModelContext(container)
        let chapter = Chapter(index: 0, title: "Orphan")
        chapter.status = .ready
        chapter.narratedVoiceId = "Aria"
        ctx.insert(chapter)
        #expect(!chapter.isStaleForBookVoice)   // no book → not stale
    }

    @Test func readyChapterIsStaleWhenVoiceDiffers() {
        #expect(ChapterStaleness.isStale(status: .ready, narratedVoiceId: "Aria", bookVoiceId: "Milo"))
        #expect(!ChapterStaleness.isStale(status: .ready, narratedVoiceId: "Milo", bookVoiceId: "Milo"))
    }
    @Test func nonReadyChaptersAreNeverStale() {
        #expect(!ChapterStaleness.isStale(status: .none, narratedVoiceId: nil, bookVoiceId: "Milo"))
        #expect(!ChapterStaleness.isStale(status: .pending, narratedVoiceId: "Aria", bookVoiceId: "Milo"))
        #expect(!ChapterStaleness.isStale(status: .error, narratedVoiceId: "Aria", bookVoiceId: "Milo"))
    }
    @Test func readyWithNilNarratedVoiceIsNotStale() {
        #expect(!ChapterStaleness.isStale(status: .ready, narratedVoiceId: nil, bookVoiceId: "Milo"))
    }
}
