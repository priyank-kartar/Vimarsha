import Foundation
import SwiftData

/// Hold-to-record voice memos (V28; apple/CLAUDE.md §UI map state 5, behavioral
/// reference = the frozen Flutter Plan 5 spec): press-and-hold pauses narration first
/// (the reading view freezes — the pin can't drift), records through the mic seam,
/// and on release saves the clip into the book's container subtree with a SwiftData
/// `Memo` row pinned to the narrated paragraph. Playback auto-resumes only if it was
/// playing before the hold. Transcription (`POST /transcribe`) is V29 — rows save as
/// `.pending`.
@Observable
@MainActor
final class MemoCapture {
    /// `recording` shows the aqua waveform puck; `saved` the confirmation chip;
    /// `denied` the mic-permission guidance chip.
    enum Phase: Equatable {
        case idle, recording, saved, denied
    }

    private let recorder: any RecorderEngine
    private let player: PlayerController
    private let context: ModelContext
    private let containerRoot: URL

    private(set) var phase: Phase = .idle
    /// Recording clock for the puck's readout.
    private(set) var elapsedMs = 0
    /// Live mic level 0…1 for the puck's waveform.
    private(set) var level: CGFloat = 0

    private var wasPlaying = false
    private var holdActive = false
    private var tempURL: URL?
    private var recordingStarted: ContinuousClock.Instant?
    private var ticker: Task<Void, Never>?

    /// Clips shorter than this are discarded (the spec's "very short/empty recording").
    static let minSaveMs = 400
    /// Puck refresh cadence while recording.
    static let tickInterval: Duration = .milliseconds(100)
    /// How long the saved-confirmation chip lingers.
    static let savedChipDuration: Duration = .seconds(1.6)

    enum SaveError: Error { case noChapter }

    init(
        recorder: any RecorderEngine,
        player: PlayerController,
        context: ModelContext,
        containerRoot: URL
    ) {
        self.recorder = recorder
        self.player = player
        self.context = context
        self.containerRoot = containerRoot
    }

    /// Finger down: permission (the system prompt is the primer) → pause narration →
    /// record to a temp file. A release that lands while the permission prompt is up
    /// (`holdActive` cleared) must never start a recording.
    func beginHold() async {
        guard phase != .recording, player.chapter != nil else { return }
        holdActive = true
        guard await recorder.requestPermission() else {
            phase = .denied
            return
        }
        guard holdActive else { return }
        wasPlaying = player.isPlaying
        if wasPlaying { player.pause() }
        let url = FileManager.default.temporaryDirectory
            .appending(path: "memo-\(UUID().uuidString).m4a")
        do {
            try recorder.start(to: url)
        } catch {
            resumeIfNeeded()
            phase = .idle
            return
        }
        tempURL = url
        elapsedMs = 0
        level = recorder.level
        recordingStarted = ContinuousClock.now
        phase = .recording
        startTicker()
    }

    /// Finger up: stop, then save (≥ `minSaveMs`) or discard; narration resumes if it
    /// was playing before the hold either way.
    func endHold() {
        holdActive = false
        guard phase == .recording else { return }
        finishRecording(save: true)
    }

    /// Abandon the hold (surface closing mid-record): always discards.
    func cancelHold() {
        holdActive = false
        guard phase == .recording else { return }
        finishRecording(save: false)
    }

    private func finishRecording(save: Bool) {
        stopTicker()
        let recordedMs = recorder.stop()
        defer { resumeIfNeeded() }
        guard let tempURL else {
            phase = .idle
            return
        }
        self.tempURL = nil
        guard save, recordedMs >= Self.minSaveMs else {
            try? FileManager.default.removeItem(at: tempURL)
            phase = .idle
            return
        }
        do {
            try saveMemo(recordingAt: tempURL)
            phase = .saved
            scheduleSavedReset()
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            phase = .idle
        }
    }

    /// Move the clip into the book's container subtree (so book deletion sweeps it) and
    /// insert the pinned row. The pin is the paragraph being narrated at the hold.
    private func saveMemo(recordingAt url: URL) throws {
        guard let chapter = player.chapter, let book = chapter.book else {
            throw SaveError.noChapter
        }
        let memoId = UUID()
        let bookDir = (book.epubPath as NSString).deletingLastPathComponent
        let relativePath = "\(bookDir)/memos/\(memoId.uuidString).m4a"
        let destination = containerRoot.appending(path: relativePath)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try FileManager.default.moveItem(at: url, to: destination)
        let memo = Memo(
            id: memoId,
            paragraphIndex: currentParagraphIndex,
            positionMs: player.positionMs,
            audioPath: relativePath
        )
        memo.chapter = chapter
        context.insert(memo)
        try context.save()
    }

    /// The narrated block's reading-order index (0 before the first timed block).
    private var currentParagraphIndex: Int {
        guard let blockId = player.currentBlockId,
              let index = player.timing?.blockIndex(forId: blockId)
        else { return 0 }
        return index
    }

    private func resumeIfNeeded() {
        if wasPlaying { player.play() }
        wasPlaying = false
    }

    private func startTicker() {
        stopTicker()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.tickInterval)
                guard let self, !Task.isCancelled else { return }
                self.level = self.recorder.level
                if let started = self.recordingStarted {
                    self.elapsedMs = Int(started.duration(to: .now) / .milliseconds(1))
                }
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
        recordingStarted = nil
        level = 0
    }

    /// Let the saved chip linger, then fall back to idle (unless a new hold started).
    private func scheduleSavedReset() {
        Task { [weak self] in
            try? await Task.sleep(for: Self.savedChipDuration)
            guard let self, self.phase == .saved else { return }
            self.phase = .idle
        }
    }
}
