#if os(macOS)
import Testing
import SwiftUI
@testable import Vimarsha

/// Renders a real `HardbackCoverView` with its debossed title fully printed vs faded so the
/// V24 double-title fix (the focused cover dims its printed title while the metadata reveal
/// rises) can be seen, not just asserted. Asserts the rasters differ and writes both PNGs to
/// the temp dir (path printed for the review capture). macOS-only (`ImageRenderer` headless).
@Suite("HardbackCoverView — title-fade snapshots")
@MainActor
struct HardbackCoverTitleFadeSnapshotTests {
    private func render(titleOpacity: CGFloat) -> CGImage? {
        let view = HardbackCoverView(book: BookSeed.shelf[3], titleOpacity: titleOpacity)
            .frame(width: 275)
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

    @Test("printed vs faded title render to different rasters (the fade is visible)")
    func printedAndFadedDiffer() throws {
        let printed = try #require(render(titleOpacity: 1))
        let faded = try #require(render(titleOpacity: 0))
        let printedPNG = try #require(pngData(printed))
        let fadedPNG = try #require(pngData(faded))
        #expect(printedPNG != fadedPNG)

        let base = FileManager.default.temporaryDirectory
        let printedURL = base.appendingPathComponent("10-cover-title-printed.png")
        let fadedURL = base.appendingPathComponent("11-cover-title-faded.png")
        try printedPNG.write(to: printedURL)
        try fadedPNG.write(to: fadedURL)
        print("VIMARSHA_SNAPSHOT \(printedURL.path)")
        print("VIMARSHA_SNAPSHOT \(fadedURL.path)")
    }
}
#endif
