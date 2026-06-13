import Testing
@testable import Vimarsha

@Suite("Chapter staleness vs selected voice")
struct ChapterStalenessTests {
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
