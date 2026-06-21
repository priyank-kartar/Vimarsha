import Foundation
import SwiftData
import SwiftUI

/// Drives playback of one cached chapter through the app-lifetime `AudioEngine`
/// (V16; the Flutter `PlayerController` design ported, not the code): load + resume,
/// play/pause/seek/skip/speed, and throttled progress persistence onto the `Chapter`
/// row. Paragraph/figure derivation from `paraTimings` is deliberately NOT here — that
/// is `TimingIndex`'s job (V18, app-architecture.md §Figure & timing flow).
///
/// The controller never disposes the engine — it pauses it (the shared-player rule).
@Observable
final class PlayerController {
    private let engine: any AudioEngine
    /// Lock-screen / Control-Center Now Playing + remote commands for the active chapter.
    private let nowPlaying = NowPlayingCenter()
    private let context: ModelContext
    private let containerRoot: URL

    private(set) var chapter: Chapter?
    private(set) var positionMs = 0
    private(set) var durationMs = 0
    private(set) var isPlaying = false
    private(set) var rate = 1.0

    /// The cached chapter content (V18) — the bundle JSON on disk is the source of
    /// truth; rows only hold state about it (data-model.md §Rules).
    private(set) var bundle: ChapterBundleDTO?
    private(set) var timing: TimingIndex?
    /// Cached figure images keyed by their source block id (`figureId` IS the image/figure
    /// block's id) — decoded downsampled off-main at load, never during scroll
    /// (apple/CLAUDE.md §Performance budget; the `LibraryStore.covers` precedent).
    private(set) var blockImages: [String: Image] = [:]

    /// The block being narrated at the current playhead — drives the reading highlight
    /// and auto-scroll (V18).
    var currentBlockId: String? {
        timing?.currentBlockId(atMs: positionMs)
    }

    /// Figures whose span contains the current playhead — drives the glass carrier's
    /// auto-pop at `startMs` / recede at `endMs` (V20). Unresolved (nil-ms) figures
    /// never activate.
    var activeFigures: [FigureDTO] {
        timing?.activeFigures(atMs: positionMs) ?? []
    }

    /// Every figure in the chapter regardless of timing — the Figures gallery's source
    /// (the reliable way to reach any figure, Flutter `FiguresGallery` parity).
    var allFigures: [FigureDTO] {
        bundle?.figureMap ?? []
    }

    private var lastSavedMs = 0
    private var ticker: Task<Void, Never>?

    /// Persist at most once per this much playhead movement (Flutter parity: 5s).
    static let saveIntervalMs = 5000
    /// UI/persistence refresh cadence while playing.
    static let tickInterval: Duration = .milliseconds(250)

    enum LoadError: Error { case chapterNotReady }

    init(engine: any AudioEngine, context: ModelContext, containerRoot: URL) {
        self.engine = engine
        self.context = context
        self.containerRoot = containerRoot
    }

    /// Load a `ready` chapter's cached audio + bundle, restore the saved position, and
    /// record the true duration on the row (the scrubber length). Playback starts paused.
    func load(_ chapter: Chapter) throws {
        guard chapter.status == .ready, let audioPath = chapter.audioPath,
              let bundlePath = chapter.bundlePath
        else { throw LoadError.chapterNotReady }
        stopTicker()
        let decoded = try JSONDecoder().decode(
            ChapterBundleDTO.self,
            from: Data(contentsOf: containerRoot.appending(path: bundlePath))
        )
        durationMs = try engine.load(url: containerRoot.appending(path: audioPath))
        bundle = decoded
        timing = TimingIndex(bundle: decoded)
        loadFigureImages(for: decoded, bundlePath: bundlePath)
        self.chapter = chapter
        let resume = min(max(chapter.progressMs, 0), durationMs)
        if resume > 0 { engine.seek(toMs: resume) }
        positionMs = resume
        lastSavedMs = resume
        isPlaying = false
        chapter.durationMs = durationMs
        try? context.save()
        engine.onFinish = { [weak self] in self?.handleFinish() }
        bindRemoteCommands()
        updateNowPlaying()
    }

    func play() {
        engine.play()
        isPlaying = engine.isPlaying
        if isPlaying { startTicker() }
        updateNowPlaying()
    }

    /// Pause and persist — leaving the surface or backgrounding goes through here; the
    /// shared engine itself stays alive.
    func pause() {
        engine.pause()
        isPlaying = false
        stopTicker()
        persist()
        updateNowPlaying()
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    /// Jump to an absolute position, clamped to `[0, durationMs]`.
    func seek(toMs ms: Int) {
        let clamped = min(max(ms, 0), durationMs)
        engine.seek(toMs: clamped)
        positionMs = clamped
        updateNowPlaying()
    }

    /// Seek forward/back by a delta, clamped.
    func skip(byMs delta: Int) {
        seek(toMs: positionMs + delta)
    }

    /// Tap-a-paragraph-to-seek (V19): jump to a block's narration start. Untimed blocks
    /// (figures, un-narrated headings) are not seek targets — no-op.
    func seekToBlock(_ id: String) {
        guard let startMs = timing?.startMs(forBlock: id) else { return }
        seek(toMs: startMs)
    }

    func setRate(_ newRate: Double) {
        engine.setRate(newRate)
        rate = newRate
        updateNowPlaying()
    }

    /// Wire the lock-screen / Control-Center transport to this controller (so commands keep
    /// app state in sync). Re-binding on each load points the controls at the live chapter.
    private func bindRemoteCommands() {
        nowPlaying.bind(
            play: { [weak self] in self?.play() },
            pause: { [weak self] in self?.pause() },
            toggle: { [weak self] in self?.togglePlayPause() },
            skip: { [weak self] secs in self?.skip(byMs: Int(secs * 1000)) },
            seek: { [weak self] secs in self?.seek(toMs: Int(secs * 1000)) }
        )
    }

    /// Refresh the lock-screen Now Playing metadata + transport state (title/book/author,
    /// duration, elapsed, rate). iOS extrapolates the moving scrubber from rate+elapsed, so
    /// this only needs calling on transport changes, not every tick.
    private func updateNowPlaying() {
        guard let chapter else { return }
        nowPlaying.update(
            title: chapter.title,
            album: chapter.book?.title ?? "",
            artist: chapter.book?.author ?? "",
            durationMs: durationMs,
            positionMs: positionMs,
            rate: rate,
            isPlaying: isPlaying
        )
    }

    /// Pull the playhead from the engine and persist when it has moved a save interval.
    /// Called by the ticker while playing; exposed so tests drive it directly.
    func tick() {
        positionMs = engine.positionMs
        if abs(positionMs - lastSavedMs) >= Self.saveIntervalMs { persist() }
    }

    /// Decode each cached figure image off the main actor; finished decodes land in
    /// `blockImages` and re-render the affected rows. Best-effort — a missing/broken
    /// image just renders its caption (the download already treated images that way).
    private func loadFigureImages(for bundle: ChapterBundleDTO, bundlePath: String) {
        blockImages = [:]
        let imagesDir = containerRoot
            .appending(path: bundlePath)
            .deletingLastPathComponent()
            .appending(path: "images")
        for figure in bundle.figureMap {
            guard let name = figure.image else { continue }
            let url = imagesDir.appending(path: URL(filePath: name).lastPathComponent)
            let blockId = figure.figureId
            Task { [weak self] in
                guard let image = await Task.detached(operation: { CoverArt.shelfImage(at: url) }).value
                else { return }
                self?.blockImages[blockId] = image
            }
        }
    }

    private func startTicker() {
        stopTicker()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.tickInterval)
                // Exit (don't just no-op) once the controller is gone or cancelled.
                guard let self, !Task.isCancelled else { return }
                self.tick()
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func handleFinish() {
        stopTicker()
        isPlaying = false
        positionMs = durationMs
        persist()
        updateNowPlaying()
    }

    private func persist() {
        lastSavedMs = positionMs
        guard let chapter else { return }
        chapter.progressMs = positionMs
        try? context.save()
    }
}
