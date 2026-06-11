import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Vimarsha

/// V12 — cover-art decode is downsampled (bounded memory) and nil-safe on junk files.
struct CoverArtTests {
    /// A real PNG on disk (solid color), drawn with CoreGraphics.
    private func writePNG(width: Int, height: Int) throws -> URL {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.8, green: 0.3, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())

        let url = FileManager.default.temporaryDirectory
            .appending(path: "CoverArtTests-\(UUID().uuidString).png")
        let destination = try #require(CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    @Test func downsamplesLargeImagesToTheCap() throws {
        let url = try writePNG(width: 300, height: 600)
        defer { try? FileManager.default.removeItem(at: url) }

        let image = try #require(CoverArt.downsampled(at: url, maxPixelSize: 64))
        #expect(max(image.width, image.height) <= 64)
        // Aspect survives the downsample (1:2 → roughly 32×64).
        #expect(image.height > image.width)
    }

    @Test func junkFileReturnsNil() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "CoverArtTests-junk-\(UUID().uuidString).png")
        try Data("not an image".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(CoverArt.downsampled(at: url, maxPixelSize: 64) == nil)
        #expect(CoverArt.shelfImage(at: url) == nil)
    }
}
