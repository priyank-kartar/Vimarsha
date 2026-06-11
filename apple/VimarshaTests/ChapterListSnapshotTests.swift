#if os(macOS)
import SwiftData
import SwiftUI
import Testing
@testable import Vimarsha

/// Renders the real `ChapterListView` (V14) so the per-chapter lifecycle UI can be seen,
/// not just asserted: all four statuses on one plane vs an all-fresh list — the rasters
/// must differ (the status affordances are visible). macOS-only (`ImageRenderer` runs
/// headless there); Reduce Transparency opaque fallback — `ImageRenderer` can't composite
/// live Liquid Glass.
@Suite("ChapterList — status snapshots")
@MainActor
struct ChapterListSnapshotTests {
    /// A real (in-memory) SwiftData book — @Model relationships need a live context, and
    /// the container must outlive rendering (a released container invalidates its models),
    /// so it's returned alongside the book and held by the test.
    private func makeBook(
        statuses: [ChapterStatus]
    ) throws -> (container: ModelContainer, book: Book) {
        let container = try ModelContainer(
            for: Book.self, Chapter.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let book = Book(title: "A Sense of Place", author: "David Thulstrup", epubPath: "x")
        book.chapters = statuses.enumerated().map { index, status in
            let chapter = Chapter(index: index, title: "Chapter \(["One", "Two", "Three", "Four"][index % 4])")
            chapter.status = status
            if status == .error { chapter.errorReason = "Narration failed" }
            return chapter
        }
        container.mainContext.insert(book)
        // Save before rendering: an unsaved to-many relationship can momentarily read
        // back empty, which rendered BOTH variants as zero-row planes (flaky equality).
        try container.mainContext.save()
        return (container, book)
    }

    /// Renders the rows column directly — `ImageRenderer` doesn't rasterize the
    /// ScrollView content inside the full plane (it drew header-only, rows blank).
    private func render(_ book: Book) -> CGImage? {
        let view = ChapterRowsView(chapters: book.chapters.sorted { $0.index < $1.index })
            .frame(width: 380)
            .padding(20)
            .background(Palette.canvas)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    private func pngData(_ image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    @Test("all four lifecycle states render visibly different from an all-fresh list")
    func lifecycleStatesAreVisible() throws {
        let lifecycle = try makeBook(statuses: [.none, .pending, .ready, .error])
        let fresh = try makeBook(statuses: [.none, .none, .none, .none])
        let lifecycleImage = try #require(render(lifecycle.book))
        let freshImage = try #require(render(fresh.book))
        let lifecyclePNG = try #require(pngData(lifecycleImage))
        let freshPNG = try #require(pngData(freshImage))
        #expect(lifecyclePNG != freshPNG)

        let base = FileManager.default.temporaryDirectory
        let lifecycleURL = base.appendingPathComponent("08-chapters-lifecycle.png")
        let freshURL = base.appendingPathComponent("09-chapters-fresh.png")
        try lifecyclePNG.write(to: lifecycleURL)
        try freshPNG.write(to: freshURL)
        print("VIMARSHA_SNAPSHOT \(lifecycleURL.path)")
        print("VIMARSHA_SNAPSHOT \(freshURL.path)")
    }
}
#endif
