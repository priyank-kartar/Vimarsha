#if os(macOS)
import Testing
import SwiftUI
@testable import Vimarsha

/// V18 — renders the chapter body (heading + paragraphs + quote + captioned figure) with
/// and without an active narration highlight so the wash can be seen, not just asserted.
/// macOS-only (`ImageRenderer` headless).
@Suite("ReadingBlocksView — snapshots")
@MainActor
struct ReadingBlocksSnapshotTests {
    private static let blocks = [
        BlockDTO(id: "h1", index: 0, kind: "heading", text: "The Shape of Accidents", level: 1),
        BlockDTO(
            id: "b1", index: 1, kind: "paragraph",
            text: "Design history is usually told as a parade of intentions, yet the most "
                + "durable objects around us arrived sideways, by accident."
        ),
        BlockDTO(
            id: "q1", index: 2, kind: "blockquote",
            text: "Every tool carries the fingerprints of the mistake that made it."
        ),
        BlockDTO(
            id: "f1", index: 3, kind: "figure",
            caption: "Figure 1 — The first accidental prototype."
        ),
        BlockDTO(
            id: "b2", index: 4, kind: "paragraph",
            text: "What follows is a history of those sideways arrivals."
        ),
    ]

    private func render(activeBlockId: String?) -> CGImage? {
        let view = ReadingBlocksView(blocks: Self.blocks, activeBlockId: activeBlockId)
            .frame(width: 390)
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

    @Test("active narration highlight renders visibly (rasters differ)")
    func highlightIsVisible() throws {
        let quiet = try #require(render(activeBlockId: nil))
        let live = try #require(render(activeBlockId: "b1"))
        let quietPNG = try #require(pngData(quiet))
        let livePNG = try #require(pngData(live))
        #expect(quietPNG != livePNG)

        let base = FileManager.default.temporaryDirectory
        let liveURL = base.appendingPathComponent("18-reading-blocks-live.png")
        try livePNG.write(to: liveURL)
        print("VIMARSHA_SNAPSHOT \(liveURL.path)")
    }

    @Test("the live block moving moves the wash (b1 vs b2 rasters differ)")
    func highlightTracksTheBlock() throws {
        let firstImage = try #require(render(activeBlockId: "b1"))
        let secondImage = try #require(render(activeBlockId: "b2"))
        let first = try #require(pngData(firstImage))
        let second = try #require(pngData(secondImage))
        #expect(first != second)
    }
}
#endif
