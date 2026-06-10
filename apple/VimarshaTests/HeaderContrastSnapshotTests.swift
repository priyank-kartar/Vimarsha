#if os(macOS)
import Testing
import SwiftUI
@testable import Vimarsha

/// Renders the real `LibraryHeader` at rest vs scrolled-away so the settle contrast shift
/// can be seen, not just asserted. Asserts the rasters differ and writes both PNGs to the
/// temp dir (path printed for the motion-review capture). macOS-only (`ImageRenderer` runs
/// headless there).
@Suite("HeaderContrast — settle-shift snapshots")
@MainActor
struct HeaderContrastSnapshotTests {
    private func render(_ contrast: HeaderContrast) -> CGImage? {
        let view = LibraryHeader(contrast: contrast)
            .frame(width: 393, height: 220)
            .background(Palette.canvas)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    private func pngData(_ image: CGImage) -> Data? {
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .png, properties: [:])
    }

    @Test("rest vs scrolled render to different rasters (the shift is visible)")
    func restAndScrolledDiffer() throws {
        let rest = try #require(render(.rest))
        let scrolled = try #require(
            render(.at(distanceToRest: 600, viewportHeight: 800))
        )
        let restPNG = try #require(pngData(rest))
        let scrolledPNG = try #require(pngData(scrolled))
        #expect(restPNG != scrolledPNG)

        let base = FileManager.default.temporaryDirectory
        let restURL = base.appendingPathComponent("02-header-rest.png")
        let scrolledURL = base.appendingPathComponent("03-header-scrolled.png")
        try restPNG.write(to: restURL)
        try scrolledPNG.write(to: scrolledURL)
        print("VIMARSHA_SNAPSHOT \(restURL.path)")
        print("VIMARSHA_SNAPSHOT \(scrolledURL.path)")
    }
}
#endif
