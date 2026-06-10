#if os(macOS)
import Testing
import SwiftUI
@testable import Vimarsha

/// Renders the lensing puck over a cover so the drop is seen, not just asserted: a
/// puck-present raster must differ from the puck-absent one. Uses the Reduce Transparency
/// opaque fallback because `ImageRenderer` runs headless and does NOT composite real Liquid
/// Glass refraction — the live glass lens look is captured on device in the V09 motion
/// review, not here. macOS-only.
@Suite("LensingPuck — overlay snapshots")
@MainActor
struct LensingPuckSnapshotTests {
    private func render(_ puck: LensingPuck) -> CGImage? {
        let view = ZStack {
            Palette.canvas
            HardbackCoverView(book: BookSeed.shelf[3])
                .frame(width: 220)
            // Opaque fallback so the drop actually rasterizes headless.
            LensingPuckView(puck: puck, reduceTransparency: true)
        }
        .frame(width: 320, height: 480)
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    private func pngData(_ image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    @Test("puck-present vs puck-absent render to different rasters (the drop is visible)")
    func presentAndAbsentDiffer() throws {
        let absent = try #require(render(.hidden))
        let present = try #require(
            render(.at(location: CGPoint(x: 160, y: 240), dragSpeed: 240, in: CGSize(width: 320, height: 480)))
        )
        let absentPNG = try #require(pngData(absent))
        let presentPNG = try #require(pngData(present))
        #expect(absentPNG != presentPNG)

        let base = FileManager.default.temporaryDirectory
        let absentURL = base.appendingPathComponent("01-puck-absent.png")
        let presentURL = base.appendingPathComponent("02-puck-present.png")
        try absentPNG.write(to: absentURL)
        try presentPNG.write(to: presentURL)
        print("VIMARSHA_SNAPSHOT \(absentURL.path)")
        print("VIMARSHA_SNAPSHOT \(presentURL.path)")
    }
}
#endif
