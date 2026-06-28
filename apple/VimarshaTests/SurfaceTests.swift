import Testing
@testable import Vimarsha

/// `Surface` (single-live-surface, spec 2026-06-28): the one source of truth for which
/// surface is live. `returnTarget` makes "close" a derived transition.
@MainActor
struct SurfaceTests {
    @Test func readingLevelPlanesReturnToReading() {
        #expect(Surface.discuss.returnTarget == .reading)
        #expect(Surface.figures.returnTarget == .reading)
        #expect(Surface.notes.returnTarget == .reading)
    }

    @Test func readingReturnsToLibrary() {
        #expect(Surface.reading.returnTarget == .library)
    }

    @Test func libraryIsTerminal() {
        #expect(Surface.library.returnTarget == .library)
    }
}
