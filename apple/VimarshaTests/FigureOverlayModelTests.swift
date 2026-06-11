import Testing
@testable import Vimarsha

/// The pure selection rules over the stack of simultaneously-active figures
/// (glass moment #8 — "stacked when spans overlap"; the Flutter
/// `FigureOverlay._reconcile` design ported, not the code).
struct FigureOverlayModelTests {
    private func figure(_ id: String) -> FigureDTO {
        FigureDTO(
            figureId: id, kind: "figure", asset: nil, caption: "Caption \(id)",
            label: "Figure \(id)", startPara: "p1", endPara: "p2",
            startMs: 0, endMs: 1000, image: nil
        )
    }

    @Test func emptyActiveSetSelectsNothing() {
        #expect(FigureOverlaySelection.reconciled(nil, with: []) == nil)
        let prior = FigureOverlaySelection(key: "f1", index: 0)
        #expect(FigureOverlaySelection.reconciled(prior, with: []) == nil)
    }

    @Test func freshSetStartsAtTheFirstFigure() {
        let sel = FigureOverlaySelection.reconciled(nil, with: [figure("f1"), figure("f2")])
        #expect(sel == FigureOverlaySelection(key: "f1,f2", index: 0))
    }

    @Test func sameSetPreservesTheUsersPaging() {
        let figs = [figure("f1"), figure("f2")]
        let paged = FigureOverlaySelection(key: "f1,f2", index: 1)
        #expect(FigureOverlaySelection.reconciled(paged, with: figs) == paged)
    }

    @Test func changedSetResetsPagingToZero() {
        let paged = FigureOverlaySelection(key: "f1,f2", index: 1)
        let sel = FigureOverlaySelection.reconciled(paged, with: [figure("f2"), figure("f3")])
        #expect(sel == FigureOverlaySelection(key: "f2,f3", index: 0))
    }

    @Test func outOfRangeIndexRecoversToZero() {
        // Defensive (Flutter parity): a stale index past the set's end snaps home.
        let stale = FigureOverlaySelection(key: "f1", index: 5)
        let sel = FigureOverlaySelection.reconciled(stale, with: [figure("f1")])
        #expect(sel == FigureOverlaySelection(key: "f1", index: 0))
    }

    @Test func nextAndPreviousWrapAroundTheStack() {
        var sel = FigureOverlaySelection(key: "a,b,c", index: 2)
        sel = sel.next(count: 3)
        #expect(sel.index == 0)
        sel = sel.previous(count: 3)
        #expect(sel.index == 2)
        sel = sel.previous(count: 3)
        #expect(sel.index == 1)
    }
}
