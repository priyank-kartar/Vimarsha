import Testing
import Foundation
@testable import Vimarsha

@Suite("Voice preview player")
@MainActor
struct VoicePreviewPlayerTests {
    final class FakeEngine: AudioEngine {
        var loadedURL: URL?
        var played = false
        var onFinish: (() -> Void)?
        func load(url: URL) throws -> Int { loadedURL = url; return 1000 }
        func play() { played = true }
        func pause() {}
        func seek(toMs ms: Int) {}
        func setRate(_ rate: Double) {}
        var positionMs: Int { 0 }
        var durationMs: Int { 1000 }
        var isPlaying: Bool { played }
    }

    @Test func previewLoadsTheBundledClipForTheVoice() throws {
        let engine = FakeEngine()
        let player = VoicePreviewPlayer(engine: engine)
        try player.preview(VoiceCatalog.voice(id: "Aria"))
        #expect(engine.loadedURL?.lastPathComponent == "af_heart.mp3")
        #expect(engine.played)
    }
}
