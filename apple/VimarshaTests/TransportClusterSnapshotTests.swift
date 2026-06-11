#if os(macOS)
import Testing
import SwiftUI
@testable import Vimarsha

/// V19 — renders the compact glass transport so play/pause + the progress line can be
/// seen, not just asserted. macOS-only (`ImageRenderer` headless; real glass is
/// photographed in the sim capture).
@Suite("TransportClusterView — snapshots")
@MainActor
struct TransportClusterSnapshotTests {
    private func render(positionMs: Int, isPlaying: Bool, rate: Double = 1.0) -> CGImage? {
        let view = TransportClusterView(
            positionMs: positionMs, durationMs: 1_475_000, isPlaying: isPlaying, rate: rate,
            reduceTransparency: true  // matte fallback rasterizes deterministically
        )
        .frame(width: 360)
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

    @Test("playing vs paused render different glyphs")
    func playPauseStatesDiffer() throws {
        let playing = try #require(render(positionMs: 161_000, isPlaying: true))
        let paused = try #require(render(positionMs: 161_000, isPlaying: false))
        let playingPNG = try #require(pngData(playing))
        let pausedPNG = try #require(pngData(paused))
        #expect(playingPNG != pausedPNG)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("19-transport-playing.png")
        try playingPNG.write(to: url)
        print("VIMARSHA_SNAPSHOT \(url.path)")
    }

    @Test("the playhead moving moves the butter progress line")
    func progressTracksThePlayhead() throws {
        let early = try #require(render(positionMs: 60_000, isPlaying: true))
        let late = try #require(render(positionMs: 1_200_000, isPlaying: true))
        let earlyPNG = try #require(pngData(early))
        let latePNG = try #require(pngData(late))
        #expect(earlyPNG != latePNG)
    }

    @Test("the rate chip renders the ladder label")
    func rateChipRenders() throws {
        let normal = try #require(render(positionMs: 0, isPlaying: false, rate: 1.0))
        let fast = try #require(render(positionMs: 0, isPlaying: false, rate: 1.5))
        let normalPNG = try #require(pngData(normal))
        let fastPNG = try #require(pngData(fast))
        #expect(normalPNG != fastPNG)
    }
}
#endif
