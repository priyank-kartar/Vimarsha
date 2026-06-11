import ImageIO
import SwiftUI

/// Cover-art decode for the shelf: downsampled once when the library loads — never
/// during scroll (apple/CLAUDE.md §Performance budget: covers are pre-rendered/
/// downsampled into textures; never decode images during scroll).
nonisolated enum CoverArt {
    /// Card width caps at 460pt (ADR-011); 2× for Retina with headroom.
    static let shelfMaxPixelSize: CGFloat = 920

    /// A downsampled SwiftUI image of the file, or `nil` if it isn't a decodable image.
    static func shelfImage(at url: URL) -> Image? {
        downsampled(at: url, maxPixelSize: shelfMaxPixelSize)
            .map { Image(decorative: $0, scale: 1) }
    }

    /// ImageIO thumbnail decode — bounded memory regardless of source dimensions.
    static func downsampled(at url: URL, maxPixelSize: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
