#if os(macOS)
import Testing
import SwiftUI
@testable import Vimarsha

/// V20 — renders the Figures-gallery grid (extracted `FigureGridView`; `ImageRenderer`
/// doesn't rasterize ScrollView content — the V14 gotcha) so the matte cards can be
/// seen, not just asserted.
@Suite("FiguresGallery — snapshots")
@MainActor
struct FiguresGallerySnapshotTests {
    private func fig(
        _ id: String, caption: String, label: String?, timed: Bool = true
    ) -> FigureDTO {
        FigureDTO(
            figureId: id, kind: "figure", asset: nil, caption: caption, label: label,
            startPara: "p1", endPara: "p2",
            startMs: timed ? 0 : nil, endMs: timed ? 1000 : nil, image: nil
        )
    }

    private var paperImage: Image {
        Image(size: CGSize(width: 220, height: 140)) { ctx in
            ctx.fill(Path(CGRect(x: 0, y: 0, width: 220, height: 140)), with: .color(.gray))
        }
    }

    private func render(figures: [FigureDTO], images: [String: Image] = [:]) -> CGImage? {
        let view = FigureGridView(figures: figures, images: images)
            .frame(width: 380)
            .padding(24)
            .background(Palette.canvas)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    private func pngData(_ image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    @Test("figure cards render as a grid — image vs caption tiles differ")
    func gridRendersCards() throws {
        let figures = [
            fig("f1", caption: "The mill", label: "Figure 1"),
            fig("f2", caption: "The store, holding a thousand numbers.", label: "Figure 2",
                timed: false),
        ]
        let withImage = try #require(render(figures: figures, images: ["f1": paperImage]))
        let captionsOnly = try #require(render(figures: figures))
        let withImagePNG = try #require(pngData(withImage))
        let captionsPNG = try #require(pngData(captionsOnly))
        #expect(withImagePNG != captionsPNG)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("20-gallery-grid.png")
        try withImagePNG.write(to: url)
        print("VIMARSHA_SNAPSHOT \(url.path)")
    }

    @Test("no figures renders the honest empty line")
    func emptyStateRenders() throws {
        let empty = try #require(render(figures: []))
        let grid = try #require(render(figures: [fig("f1", caption: "C", label: "L")]))
        let emptyPNG = try #require(pngData(empty))
        let gridPNG = try #require(pngData(grid))
        #expect(emptyPNG != gridPNG)
    }
}
#endif
