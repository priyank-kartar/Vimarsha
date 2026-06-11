import AVFoundation
import Foundation

/// The mic half of the audio/mic seam (apple/CLAUDE.md §Seams — "AVFoundation impl:
/// playback + record"; the playback half is `AudioEngine`). One recording at a time;
/// ONE app-lifetime instance owns the input device, like the playback engine owns output.
///
/// Durations are integer milliseconds, the contract's unit throughout the client.
@MainActor
protocol RecorderEngine: AnyObject {
    /// Ask for (or confirm) microphone permission — the system prompt carries the
    /// usage-description primer. Idempotent; `false` = denied.
    func requestPermission() async -> Bool
    /// Begin recording to `url` (AAC m4a), replacing any current recording.
    func start(to url: URL) throws
    /// Stop and finalize the file. Returns the recorded duration in milliseconds
    /// (0 when nothing was recording).
    @discardableResult
    func stop() -> Int
    var isRecording: Bool { get }
    /// Live input level 0…1 — drives the aqua waveform puck while recording.
    var level: CGFloat { get }
}

/// The real impl: `AVAudioRecorder` to a local m4a, metering enabled for the puck.
final class AVAudioRecorderEngine: RecorderEngine {
    private var recorder: AVAudioRecorder?

    enum RecordError: Error { case cannotStart }

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start(to url: URL) throws {
        #if os(iOS)
        // Recording needs the record-capable category; narration is paused while the
        // memo is held, so hijacking the session here is safe.
        try? AVAudioSession.sharedInstance().setCategory(
            .playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        let candidate = try AVAudioRecorder(url: url, settings: settings)
        candidate.isMeteringEnabled = true
        guard candidate.record() else { throw RecordError.cannotStart }
        recorder = candidate
    }

    @discardableResult
    func stop() -> Int {
        guard let recorder else { return 0 }
        let recordedMs = Int((recorder.currentTime * 1000).rounded())
        recorder.stop()
        self.recorder = nil
        #if os(iOS)
        // Hand the session back to playback so resumed narration routes at full volume.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        #endif
        return recordedMs
    }

    var isRecording: Bool { recorder?.isRecording ?? false }

    /// Average input power mapped from dBFS (−50…0 is the useful speech band) to 0…1.
    var level: CGFloat {
        guard let recorder, recorder.isRecording else { return 0 }
        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0)
        return CGFloat(max(0, min(1, (db + 50) / 50)))
    }
}
