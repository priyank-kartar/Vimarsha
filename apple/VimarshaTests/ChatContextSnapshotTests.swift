import Foundation
import Testing
@testable import Vimarsha

/// V32 — the grounding snapshot: live paragraph ± one text neighbor, active-figure
/// caption, honest fallbacks at the edges. Pure math over the bundle fixtures.
struct ChatContextSnapshotTests {
    private func make(
        bundle: ChapterBundleDTO = .timedFixture, atMs ms: Int
    ) -> ChatContextDTO {
        ChatContextSnapshot.make(
            bundle: bundle, timing: TimingIndex(bundle: bundle), positionMs: ms,
            bookTitle: "Book", chapterTitle: "Chapter"
        )
    }

    @Test func midChapterWindowsPrevCurrentNext() {
        // timedFixture: b1 "First." [0,1000], b2 "Second." [1000,2000], b3 "Third." [2000,3000]
        let context = make(atMs: 1_500)
        #expect(context.passage == "First.\n\nSecond.\n\nThird.")
        #expect(context.bookTitle == "Book")
        #expect(context.chapterTitle == "Chapter")
    }

    @Test func chapterStartClampsWindow() {
        let context = make(atMs: 0)
        #expect(context.passage == "First.\n\nSecond.")
    }

    @Test func chapterEndClampsWindow() {
        let context = make(atMs: 2_500)
        #expect(context.passage == "Second.\n\nThird.")
    }

    @Test func activeFigureContributesCaption() {
        // figuredFixture: figure f1 "A diagram" spans 500…2500; fig blocks have no text
        // so the passage stays paragraph-only.
        let context = make(bundle: .figuredFixture, atMs: 1_500)
        #expect(context.figureCaption == "A diagram")
        #expect(context.passage == "First.\n\nSecond.\n\nThird.")
    }

    @Test func noActiveFigureMeansNoCaption() {
        let context = make(bundle: .figuredFixture, atMs: 2_800)
        #expect(context.figureCaption == nil)
    }

    @Test func missingBundleYieldsEmptyPassage() {
        let context = ChatContextSnapshot.make(
            bundle: nil, timing: nil, positionMs: 0, bookTitle: "B", chapterTitle: "C"
        )
        #expect(context.passage.isEmpty)
        #expect(context.figureCaption == nil)
    }
}
