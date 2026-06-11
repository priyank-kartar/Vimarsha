import AVFoundation
import Foundation

/// The audio seam — the second of exactly two sanctioned test doubles in the client
/// (apple/CLAUDE.md §Seams; the other is `BackendClient`). One local audio file loaded at
/// a time; ONE app-lifetime instance owns the device. Controllers pause it, they never
/// dispose it — the Flutter `AudioHandler` lesson (root CLAUDE.md gotchas).
///
/// All positions are integer milliseconds, the contract's unit (`paraTimings`,
/// `startMs/endMs`, `Chapter.progressMs`).
@MainActor
protocol AudioEngine: AnyObject {
    /// Load a local audio file, replacing any current one; playback is left paused at 0.
    /// Returns the file's duration in milliseconds.
    @discardableResult
    func load(url: URL) throws -> Int

    func play()
    func pause()
    /// Jump to an absolute position; safe while playing or paused.
    func seek(toMs ms: Int)
    /// Playback rate (1.0 = natural); persists across loads and play/pause.
    func setRate(_ rate: Double)

    var positionMs: Int { get }
    var durationMs: Int { get }
    var isPlaying: Bool { get }

    /// Fired once when the loaded file plays through its natural end.
    var onFinish: (() -> Void)? { get set }
}

/// The real impl: `AVAudioPlayer` over the cached `chapter.mp3` (local files only —
/// downloads happen in `ChapterDownloader`, never here).
final class AVFoundationAudioEngine: NSObject, AudioEngine {
    private var player: AVAudioPlayer?
    private var rate: Double = 1.0
    var onFinish: (() -> Void)?

    @discardableResult
    func load(url: URL) throws -> Int {
        player?.stop()
        let loaded = try AVAudioPlayer(contentsOf: url)
        loaded.enableRate = true
        loaded.rate = Float(rate)
        loaded.delegate = self
        loaded.prepareToPlay()
        player = loaded
        #if os(iOS)
        // Long-form spoken audio; without the session category the simulator/device
        // routes nothing.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        return Int((loaded.duration * 1000).rounded())
    }

    func play() { player?.play() }

    func pause() { player?.pause() }

    func seek(toMs ms: Int) {
        guard let player else { return }
        player.currentTime = Double(ms) / 1000
    }

    func setRate(_ rate: Double) {
        self.rate = rate
        player?.rate = Float(rate)
    }

    var positionMs: Int { Int(((player?.currentTime ?? 0) * 1000).rounded()) }
    var durationMs: Int { Int(((player?.duration ?? 0) * 1000).rounded()) }
    var isPlaying: Bool { player?.isPlaying ?? false }
}

extension AVFoundationAudioEngine: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // The delegate thread is unspecified; hop to the engine's actor before touching state.
        Task { @MainActor in self.onFinish?() }
    }
}
