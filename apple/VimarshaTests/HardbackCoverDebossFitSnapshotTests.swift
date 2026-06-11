#if os(iOS)
import Testing
import SwiftUI
import CoreGraphics
@testable import Vimarsha

/// V44 (ui-audit round 2): at XXXL the debossed title block outgrew the board face and its
/// bottom line ("OF DESIGN") rode into the fore-edge page-texture lines. Renders the real
/// `HardbackCoverView` at XXXL and asserts NO title-ink pixels appear in the card's bottom
/// fore-edge strip — the deboss block must fit (scale/truncate) inside the cover face.
/// iOS-only: macOS has no Dynamic Type, so `@ScaledMetric` never grows there and the
/// overflow cannot reproduce under the macOS destination.
@Suite("HardbackCoverView — deboss block fits the cover face at XXXL (V44)")
@MainActor
struct HardbackCoverDebossFitSnapshotTests {
    /// Rendered with the same geometry the audit hit: the blue "Design by Accident" seed
    /// (long subtitle), card-width ≈ the stack's, XXXL type.
    private let pad: CGFloat = 24
    private let scale: CGFloat = 2

    private func render() -> CGImage? {
        let view = HardbackCoverView(book: ShelfBook.seeds[3])
            .frame(width: 275)
            .padding(pad)
            .background(Palette.canvas)
            .environment(\.colorScheme, .dark)
            .environment(\.dynamicTypeSize, .xxxLarge)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.cgImage
    }

    /// Redraw into a known RGBA8 layout so sampling is byte-order safe.
    private func rgbaBytes(_ image: CGImage) -> (data: [UInt8], width: Int, height: Int)? {
        let w = image.width
        let h = image.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (data, w, h)
    }

    @Test("no title-ink pixels in the fore-edge strip at XXXL")
    func subtitleClearsForeEdge() throws {
        let image = try #require(render())
        let (data, width, height) = try #require(rgbaBytes(image))

        // The card's bottom edge sits `pad` points above the image bottom; the fore-edge
        // strip is the ~14 points above that (page capsules + the board's bottom padding).
        let cardBottom = height - Int(pad * scale)
        let stripTop = cardBottom - Int(14 * scale)
        // Sample the horizontal band where the deboss text lives (inset past the page
        // capsules' own horizontal padding).
        let x0 = Int((pad + 30) * scale)
        let x1 = width - Int((pad + 30) * scale)

        var inkPixels = 0
        for y in stripTop..<cardBottom {
            for x in stride(from: x0, to: x1, by: 2) {
                let i = (y * width + x) * 4
                // ShelfBook.seeds[3].ink == Color(hex: 0x2C4093)
                let dist = abs(Int(data[i]) - 0x2C) + abs(Int(data[i + 1]) - 0x40)
                    + abs(Int(data[i + 2]) - 0x93)
                if dist < 35 { inkPixels += 1 }
            }
        }
        #expect(inkPixels == 0, "found \(inkPixels) title-ink pixels riding the fore-edge strip")
    }
}
#endif
