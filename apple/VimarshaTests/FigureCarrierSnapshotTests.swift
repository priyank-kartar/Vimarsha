#if os(macOS)
import Testing
import SwiftUI
@testable import Vimarsha

/// V20 — renders the figure carrier so the card, its matte content, and the stacked
/// pager can be seen, not just asserted. macOS-only (`ImageRenderer` headless; real
/// glass is photographed in the sim capture).
@Suite("FigureCarrierView — snapshots")
@MainActor
struct FigureCarrierSnapshotTests {
    private func fig(_ id: String, caption: String, label: String?) -> FigureDTO {
        FigureDTO(
            figureId: id, kind: "figure", asset: nil, caption: caption, label: label,
            startPara: "p1", endPara: "p2", startMs: 0, endMs: 1000, image: nil
        )
    }

    /// A deterministic stand-in for a cached figure image.
    private var paperImage: Image {
        Image(size: CGSize(width: 240, height: 150)) { ctx in
            ctx.fill(Path(CGRect(x: 0, y: 0, width: 240, height: 150)), with: .color(.gray))
            ctx.fill(Path(ellipseIn: CGRect(x: 60, y: 30, width: 120, height: 90)),
                     with: .color(.white))
        }
    }

    private func render(
        figures: [FigureDTO], selectedIndex: Int = 0, images: [String: Image] = [:]
    ) -> CGImage? {
        let view = FigureCarrierView(
            figures: figures, selectedIndex: selectedIndex, images: images,
            reduceTransparency: true  // matte fallback rasterizes deterministically
        )
        .frame(width: 360)
        .padding(28)
        .background(Palette.canvas)
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    private func pngData(_ image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    @Test("cached image renders matte in the frame; caption-only differs")
    func imageVersusCaptionOnlyDiffer() throws {
        let single = [fig("f1", caption: "The mill", label: "Figure 1")]
        let withImage = try #require(render(figures: single, images: ["f1": paperImage]))
        let captionOnly = try #require(render(figures: single))
        let withImagePNG = try #require(pngData(withImage))
        let captionPNG = try #require(pngData(captionOnly))
        #expect(withImagePNG != captionPNG)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("20-carrier-image.png")
        try withImagePNG.write(to: url)
        print("VIMARSHA_SNAPSHOT \(url.path)")
    }

    @Test("overlapping spans stack: pager + backing edges appear")
    func stackedSpansRenderThePager() throws {
        let one = [fig("f1", caption: "The mill", label: "Figure 1")]
        let two = one + [fig("f2", caption: "The store", label: "Figure 2")]
        let single = try #require(render(figures: one))
        let stacked = try #require(render(figures: two))
        let singlePNG = try #require(pngData(single))
        let stackedPNG = try #require(pngData(stacked))
        #expect(singlePNG != stackedPNG)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("20-carrier-stacked.png")
        try stackedPNG.write(to: url)
        print("VIMARSHA_SNAPSHOT \(url.path)")
    }

    @Test("paging swaps the top card")
    func pagingSwapsTheTopCard() throws {
        let two = [
            fig("f1", caption: "The mill", label: "Figure 1"),
            fig("f2", caption: "The store", label: "Figure 2"),
        ]
        let firstImage = try #require(render(figures: two, selectedIndex: 0))
        let secondImage = try #require(render(figures: two, selectedIndex: 1))
        let first = try #require(pngData(firstImage))
        let second = try #require(pngData(secondImage))
        #expect(first != second)
    }
}
#endif
