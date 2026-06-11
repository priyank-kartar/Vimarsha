#if os(macOS)
import Testing
import SwiftUI
@testable import Vimarsha

/// Renders the V28 memo affordances so the recording state can be seen, not just
/// asserted: the aqua waveform puck at low vs high level (the waveform must visibly
/// react) and the mic control idle vs recording. macOS-only (`ImageRenderer` runs
/// headless there) with the Reduce Transparency matte fallback — `ImageRenderer`
/// can't composite live Liquid Glass (the cluster-snapshot precedent).
@Suite("Memo record — puck + mic snapshots")
@MainActor
struct MemoPuckSnapshotTests {
    private func renderPuck(level: CGFloat, elapsedMs: Int) -> CGImage? {
        let view = MemoPuckView(level: level, elapsedMs: elapsedMs, reduceTransparency: true)
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

    @Test("the waveform reacts to level (quiet vs loud render differently)")
    func waveformReactsToLevel() throws {
        let quietImage = try #require(renderPuck(level: 0.1, elapsedMs: 5_000))
        let loudImage = try #require(renderPuck(level: 1.0, elapsedMs: 5_000))
        let quiet = try #require(pngData(quietImage))
        let loud = try #require(pngData(loudImage))
        #expect(quiet != loud)

        let base = FileManager.default.temporaryDirectory
        let quietURL = base.appendingPathComponent("memo-puck-quiet.png")
        let loudURL = base.appendingPathComponent("memo-puck-loud.png")
        try quiet.write(to: quietURL)
        try loud.write(to: loudURL)
        print("VIMARSHA_SNAPSHOT \(quietURL.path)")
        print("VIMARSHA_SNAPSHOT \(loudURL.path)")
    }

    @Test("mic control renders distinctly idle vs recording (aqua takes over)")
    func micControlStates() throws {
        func render(_ recording: Bool) -> CGImage? {
            let view = MemoRecordControl(isRecording: recording, reduceTransparency: true)
                .padding(24)
                .background(Palette.canvas)
                .environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            return renderer.cgImage
        }
        let idleImage = try #require(render(false))
        let recordingImage = try #require(render(true))
        let idle = try #require(pngData(idleImage))
        let recording = try #require(pngData(recordingImage))
        #expect(idle != recording)
    }
}
#endif
