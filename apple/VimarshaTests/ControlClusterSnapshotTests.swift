#if os(macOS)
import Testing
import SwiftUI
@testable import Vimarsha

/// Renders the real `ControlClusterView` absorbed vs emerged so the glass control cluster
/// (glass moment #5) can be seen, not just asserted. Asserts the rasters differ and writes
/// both PNGs (path printed for the motion-review capture). macOS-only (`ImageRenderer` runs
/// headless there) and uses the Reduce Transparency opaque fallback — `ImageRenderer` can't
/// composite live Liquid Glass refraction (same as the lensing-puck snapshot).
@Suite("ControlCluster — emerge snapshots")
@MainActor
struct ControlClusterSnapshotTests {
    private func render(_ emerge: CGFloat) -> CGImage? {
        let view = ControlClusterView(
            cluster: ControlCluster(emerge: emerge),
            reduceTransparency: true
        )
        .frame(width: 393, height: 120)
        .background(Palette.canvas)
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    private func pngData(_ image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    @Test("absorbed vs emerged render to different rasters (the cluster is visible)")
    func absorbedAndEmergedDiffer() throws {
        let absorbed = try #require(render(0))
        let emerged = try #require(render(1))
        let absorbedPNG = try #require(pngData(absorbed))
        let emergedPNG = try #require(pngData(emerged))
        #expect(absorbedPNG != emergedPNG)

        let base = FileManager.default.temporaryDirectory
        let absorbedURL = base.appendingPathComponent("06-cluster-absorbed.png")
        let emergedURL = base.appendingPathComponent("07-cluster-emerged.png")
        try absorbedPNG.write(to: absorbedURL)
        try emergedPNG.write(to: emergedURL)
        print("VIMARSHA_SNAPSHOT \(absorbedURL.path)")
        print("VIMARSHA_SNAPSHOT \(emergedURL.path)")
    }
}
#endif
