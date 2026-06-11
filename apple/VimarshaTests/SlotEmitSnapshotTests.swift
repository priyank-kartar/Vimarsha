#if os(macOS)
import Testing
import SwiftUI
@testable import Vimarsha

/// Renders a real `HardbackCoverView` with the `SlotEmit` transform applied at the shelf
/// anchor vs fully arrived, so the staircase fan-up (motion grammar #4) can be seen, not just
/// asserted. Asserts the rasters differ and writes both PNGs (path printed for the motion
/// review). macOS-only (`ImageRenderer` runs headless there).
@Suite("SlotEmit — fan-up snapshots")
@MainActor
struct SlotEmitSnapshotTests {
    private func render(_ emit: SlotEmit) -> CGImage? {
        let view = HardbackCoverView(book: ShelfBook.seeds[3])
            .frame(width: 220)
            .scaleEffect(emit.scale, anchor: .bottom)
            .opacity(emit.opacity)
            .offset(y: emit.yOffset)
            .frame(width: 320, height: 360)
            .background(Palette.canvas)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    private func pngData(_ image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    @Test("anchored vs arrived render to different rasters (the cover rises into view)")
    func anchoredAndArrivedDiffer() throws {
        // Anchor: a card at the viewport bottom edge. Arrived: a card on the front slot.
        let viewport: CGFloat = 1000
        let anchored = try #require(render(SlotEmit.at(midY: viewport, viewportHeight: viewport)))
        let arrived = try #require(render(SlotEmit.at(midY: viewport * StackTransform.frontSlot,
                                                      viewportHeight: viewport)))
        let anchoredPNG = try #require(pngData(anchored))
        let arrivedPNG = try #require(pngData(arrived))
        #expect(anchoredPNG != arrivedPNG)

        let base = FileManager.default.temporaryDirectory
        let anchoredURL = base.appendingPathComponent("08-slot-emit-anchored.png")
        let arrivedURL = base.appendingPathComponent("09-slot-emit-arrived.png")
        try anchoredPNG.write(to: anchoredURL)
        try arrivedPNG.write(to: arrivedURL)
        print("VIMARSHA_SNAPSHOT \(anchoredURL.path)")
        print("VIMARSHA_SNAPSHOT \(arrivedURL.path)")
    }
}
#endif
