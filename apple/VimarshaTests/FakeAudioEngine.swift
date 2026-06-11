import Foundation
@testable import Vimarsha

/// The audio seam's test double — the second of exactly two sanctioned doubles in the
/// repo (the other is `FakeBackendClient`). Permanent test-only code: tests advance the
/// playhead by hand (`advance`/`finish`) instead of waiting on a real clock.
@MainActor
final class FakeAudioEngine: AudioEngine {
    var stubbedDurationMs = 60_000
    var loadError: Error?

    private(set) var loadedURL: URL?
    private(set) var seeks: [Int] = []
    private(set) var rate = 1.0
    var positionMs = 0
    var durationMs = 0
    var isPlaying = false
    var onFinish: (() -> Void)?

    @discardableResult
    func load(url: URL) throws -> Int {
        if let loadError { throw loadError }
        loadedURL = url
        durationMs = stubbedDurationMs
        positionMs = 0
        isPlaying = false
        return durationMs
    }

    func play() { isPlaying = true }
    func pause() { isPlaying = false }

    func seek(toMs ms: Int) {
        seeks.append(ms)
        positionMs = ms
    }

    func setRate(_ rate: Double) { self.rate = rate }

    /// Simulate playback progressing (clamped to the end).
    func advance(byMs ms: Int) {
        positionMs = min(positionMs + ms, durationMs)
    }

    /// Simulate the file playing through its natural end.
    func finish() {
        positionMs = durationMs
        isPlaying = false
        onFinish?()
    }
}
