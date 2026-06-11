#if os(iOS)
import Testing
import SwiftUI
import CoreGraphics
@testable import Vimarsha

/// V45 (ui-audit round 3): the glass control cluster rendered directly across the focused
/// cover's debossed label at XXXL rest. Renders the real `HardbackCoverView` with a dodge
/// band where the cluster sits and asserts the band interior holds NO title-ink pixels while
/// the rest of the label survives. iOS-only like the V44 fit test (the defect is a Dynamic
/// Type composition; macOS has no Dynamic Type).
@Suite("HardbackCoverView — deboss dodges the cluster band (V45)")
@MainActor
struct HardbackCoverDodgeSnapshotTests {
    /// The audit's geometry: the pink "Hey" seed, stack-like width, XXXL type.
    private let pad: CGFloat = 24
    private let scale: CGFloat = 2
    private let cardWidth: CGFloat = 275
    /// Mid-cover band ≈ where the cluster sat in the audit frame (cover is 137.5 tall).
    private let band = DebossDodge.Band(top: 55, bottom: 95, strength: 1)

    private func render(dodge: DebossDodge.Band?) -> CGImage? {
        let view = HardbackCoverView(book: ShelfBook.seeds[2], debossDodge: dodge)
            .frame(width: cardWidth)
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

    /// Count pixels near the seed's title ink (`ShelfBook.seeds[2].ink == 0xC97D9F`) in the
    /// given cover-local y range.
    private func inkPixels(
        in data: [UInt8], width: Int, coverYRange: Range<CGFloat>
    ) -> Int {
        let y0 = Int((pad + coverYRange.lowerBound) * scale)
        let y1 = Int((pad + coverYRange.upperBound) * scale)
        let x0 = Int((pad + 30) * scale)
        let x1 = width - Int((pad + 30) * scale)
        var count = 0
        for y in y0..<y1 {
            for x in stride(from: x0, to: x1, by: 2) {
                let i = (y * width + x) * 4
                let dist = abs(Int(data[i]) - 0xC9) + abs(Int(data[i + 1]) - 0x7D)
                    + abs(Int(data[i + 2]) - 0x9F)
                if dist < 35 { count += 1 }
            }
        }
        return count
    }

    @Test("the dodge clears every title-ink pixel inside the band; the label survives outside")
    func dodgeClearsTheBand() throws {
        // Guard against a vacuous pass: undodged, the XXXL deboss block DOES occupy the band.
        let plain = try #require(render(dodge: nil))
        let (plainData, plainWidth, _) = try #require(rgbaBytes(plain))
        let before = inkPixels(in: plainData, width: plainWidth, coverYRange: band.top..<band.bottom)
        #expect(before > 0, "expected the XXXL deboss block to reach the cluster band undodged")

        let dodged = try #require(render(dodge: band))
        let (data, width, _) = try #require(rgbaBytes(dodged))
        // Band interior is glyph-free…
        let inside = inkPixels(in: data, width: width, coverYRange: band.top..<band.bottom)
        #expect(inside == 0, "found \(inside) title-ink pixels under the cluster band")
        // …while the printed label still exists outside the feathered band.
        let above = inkPixels(in: data, width: width, coverYRange: 0..<(band.top - DebossDodge.feather))
        let below = inkPixels(
            in: data, width: width,
            coverYRange: (band.bottom + DebossDodge.feather)..<(cardWidth * CardGeometry.aspect)
        )
        #expect(above + below > 0, "the dodge must fade only the covered lines, not the label")
    }
}
#endif
