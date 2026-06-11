#if os(macOS)
import CoreGraphics
import SwiftUI
import Testing
@testable import Vimarsha

/// V12 — real cover art renders on the hardback card (and the debossed title yields to
/// it). Renders a `ShelfBook` with a generated art image vs the same book without, and
/// asserts the rasters differ; PNGs land in the temp dir for the review capture.
/// macOS-only (`ImageRenderer` headless).
@Suite("HardbackCoverView — cover-art snapshots")
@MainActor
struct HardbackCoverArtSnapshotTests {
    /// A vivid two-tone art image, distinguishable from any cloth fill.
    private func makeArt() throws -> Image {
        let context = try #require(CGContext(
            data: nil, width: 64, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.95, green: 0.35, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        context.setFillColor(CGColor(red: 0.1, green: 0.6, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 32, y: 0, width: 32, height: 32))
        return Image(decorative: try #require(context.makeImage()), scale: 1)
    }

    private func render(cover: Image?) throws -> Data {
        var book = ShelfBook.seeds[0]
        book.cover = cover
        let view = HardbackCoverView(book: book)
            .frame(width: 275)
            .padding(24)
            .background(Palette.canvas)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        return try #require(
            NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        )
    }

    @Test("art vs cloth render to different rasters (real covers are visible)")
    func artAndClothDiffer() throws {
        let art = try render(cover: try makeArt())
        let cloth = try render(cover: nil)
        #expect(art != cloth)

        let base = FileManager.default.temporaryDirectory
        let artURL = base.appendingPathComponent("12-cover-real-art.png")
        let clothURL = base.appendingPathComponent("13-cover-cloth-fallback.png")
        try art.write(to: artURL)
        try cloth.write(to: clothURL)
        print("VIMARSHA_SNAPSHOT \(artURL.path)")
        print("VIMARSHA_SNAPSHOT \(clothURL.path)")
    }
}
#endif
