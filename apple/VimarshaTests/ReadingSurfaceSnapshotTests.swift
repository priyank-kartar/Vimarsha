#if os(macOS)
import Testing
import SwiftUI
@testable import Vimarsha

/// V17 — renders the reading-surface shell (cover plate + chapter masthead + ready mark)
/// so the opened-book state can be seen, not just asserted. Asserts distinct chapters
/// render distinct rasters and writes PNGs for the review capture. macOS-only
/// (`ImageRenderer` headless).
@Suite("ReadingSurfaceView — snapshots")
@MainActor
struct ReadingSurfaceSnapshotTests {
    private func render(chapterIndex: Int, title: String) -> CGImage? {
        let view = ReadingSurfaceView(
            book: ShelfBook.seeds[3], chapterIndex: chapterIndex, chapterTitle: title
        )
        .frame(width: 390, height: 760)
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    private func pngData(_ image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    @Test("two chapters render to different rasters (masthead carries the chapter)")
    func chaptersDiffer() throws {
        let one = try #require(render(chapterIndex: 0, title: "The Shape of Accidents"))
        let two = try #require(render(chapterIndex: 6, title: "A Completely Different Title"))
        let onePNG = try #require(pngData(one))
        let twoPNG = try #require(pngData(two))
        #expect(onePNG != twoPNG)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("17-reading-surface.png")
        try onePNG.write(to: url)
        print("VIMARSHA_SNAPSHOT \(url.path)")
    }
}
#endif
