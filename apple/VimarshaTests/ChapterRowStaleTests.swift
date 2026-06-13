import Testing
@testable import Vimarsha

@Suite("Stale-open routing")
struct ChapterRowStaleTests {
    @Test func openingAStaleReadyChapterReRendersInsteadOfReading() {
        #expect(ChapterOpenRouting.action(status: .ready, isStale: true) == .rerender)
        #expect(ChapterOpenRouting.action(status: .ready, isStale: false) == .open)
        #expect(ChapterOpenRouting.action(status: .none, isStale: false) == .download)
        #expect(ChapterOpenRouting.action(status: .error, isStale: false) == .download)
    }
}
