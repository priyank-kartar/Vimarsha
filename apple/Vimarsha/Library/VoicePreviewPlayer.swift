import Foundation

/// Plays a bundled voice-preview clip through an `AudioEngine`. A lightweight, ephemeral
/// player owned by the voice panel — distinct from the chapter player. The caller pauses
/// chapter narration around a preview (the memo-playback courtesy).
@MainActor
final class VoicePreviewPlayer {
    private let engine: any AudioEngine

    init(engine: any AudioEngine) {
        self.engine = engine
    }

    enum PreviewError: Error { case missingClip(String) }

    /// Load and play the bundled clip for `voice`. Throws if the resource is missing (which
    /// the bundled-resource test prevents in release).
    func preview(_ voice: NarratorVoice) throws {
        let url = Bundle.main.url(
            forResource: voice.previewResource, withExtension: "mp3", subdirectory: "VoicePreviews"
        ) ?? Bundle.main.url(forResource: voice.previewResource, withExtension: "mp3")
        guard let url else { throw PreviewError.missingClip(voice.previewResource) }
        _ = try engine.load(url: url)
        engine.play()
    }

    /// Stop the preview (the protocol has no stop — pause halts the AVAudioPlayer).
    func stop() { engine.pause() }
}
