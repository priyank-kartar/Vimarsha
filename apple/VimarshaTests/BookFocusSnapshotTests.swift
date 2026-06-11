#if os(macOS)
import Testing
import SwiftUI
@testable import Vimarsha

/// Renders the real `FocusMetadataView` hidden vs revealed so the focused-book metadata
/// reveal (motion grammar #2) can be seen, not just asserted. Asserts the rasters differ and
/// writes both PNGs to the temp dir (path printed for the motion-review capture). macOS-only
/// (`ImageRenderer` runs headless there).
@Suite("BookFocus — metadata-reveal snapshots")
@MainActor
struct BookFocusSnapshotTests {
    private func render(_ reveal: CGFloat) -> CGImage? {
        let view = FocusMetadataView(book: ShelfBook.seeds[3], reveal: reveal)
            .frame(width: 393, height: 90)
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

    @Test("hidden vs revealed render to different rasters (the reveal is visible)")
    func hiddenAndRevealedDiffer() throws {
        let hidden = try #require(render(0))
        let revealed = try #require(render(1))
        let hiddenPNG = try #require(pngData(hidden))
        let revealedPNG = try #require(pngData(revealed))
        #expect(hiddenPNG != revealedPNG)

        let base = FileManager.default.temporaryDirectory
        let hiddenURL = base.appendingPathComponent("04-focus-hidden.png")
        let revealedURL = base.appendingPathComponent("05-focus-revealed.png")
        try hiddenPNG.write(to: hiddenURL)
        try revealedPNG.write(to: revealedURL)
        print("VIMARSHA_SNAPSHOT \(hiddenURL.path)")
        print("VIMARSHA_SNAPSHOT \(revealedURL.path)")
    }
}
#endif
