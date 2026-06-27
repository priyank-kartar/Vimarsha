import Foundation

/// Hold-to-talk for the Discuss panel (V34; spec §4 — the secondary input affordance):
/// press-and-hold records a spoken question through the mic seam, release sends it to
/// `POST /transcribe` and drops the text into the input field for review/send — never
/// auto-sent. **Pause-on-audio-conflict:** narration pauses while the mic is open and
/// resumes the moment recording stops (if it was playing) — the transcription wait is
/// not an audio conflict. A failure falls back to typing (spec §6: no lost panel state).
@Observable
@MainActor
final class VoiceInput {
    /// `recording` drives the listening indicator; `transcribing` the interim row;
    /// `denied`/`failed` the guidance captions (type instead).
    enum Phase: Equatable {
        case idle, recording, transcribing, denied, failed
    }

    private let recorder: any RecorderEngine
    private let backend: any BackendClient
    private let player: PlayerController

    private(set) var phase: Phase = .idle
    /// Recording clock for the listening indicator.
    private(set) var elapsedMs = 0
    /// Live mic level 0…1 for the listening indicator.
    private(set) var level: CGFloat = 0
    /// Fired with each successful transcript (the panel fills the input field).
    var onTranscript: ((String) -> Void)?

    private var wasPlaying = false
    private var holdActive = false
    /// Guards `toggle()` against re-entrancy — a fast double-tap must not run `beginHold`
    /// twice concurrently (which churned the recorder start/stop and could crash).
    private var transitioning = false
    private var tempURL: URL?
    private var recordingStarted: ContinuousClock.Instant?
    private var ticker: Task<Void, Never>?

    /// Holds shorter than this are discarded without a backend round-trip (the
    /// MemoCapture rule — an accidental tap is not a question).
    static let minTranscribeMs = 400
    /// Indicator refresh cadence while recording.
    static let tickInterval: Duration = .milliseconds(100)
    /// How long the failed-guidance caption lingers before falling back to idle.
    static let failedResetDelay: Duration = .seconds(2.5)

    init(recorder: any RecorderEngine, backend: any BackendClient, player: PlayerController) {
        self.recorder = recorder
        self.backend = backend
        self.player = player
    }

    /// Tap-to-toggle voice input: a tap starts recording (the timer counts up until the next
    /// tap), a second tap stops and transcribes. Re-entrancy-guarded so a rapid double-tap
    /// can't start two recordings at once. Taps during transcription are ignored.
    func toggle() async {
        guard !transitioning else { return }
        transitioning = true
        defer { transitioning = false }
        switch phase {
        case .recording:
            endHold()                 // stop + transcribe
        case .transcribing:
            break                     // busy — ignore
        case .idle, .denied, .failed:
            await beginHold()         // start
        }
    }

    /// Finger down: permission (the system prompt is the primer) → pause narration
    /// (audio conflict) → record to a temp file. A release that lands while the
    /// permission prompt is up must never start a recording (the MemoCapture race).
    func beginHold() async {
        guard phase != .recording, phase != .transcribing else { return }
        holdActive = true
        guard await recorder.requestPermission() else {
            phase = .denied
            return
        }
        guard holdActive else { return }
        wasPlaying = player.isPlaying
        if wasPlaying { player.pause() }
        let url = FileManager.default.temporaryDirectory
            .appending(path: "voice-question-\(UUID().uuidString).m4a")
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

    /// Finger up: stop, resume narration (the conflict is over), then transcribe
    /// (≥ `minTranscribeMs`) into the input field — or discard a tap-length hold.
    func endHold() {
        holdActive = false
        guard phase == .recording else { return }
        stopTicker()
        let recordedMs = recorder.stop()
        resumeIfNeeded()
        guard let tempURL else {
            phase = .idle
            return
        }
        self.tempURL = nil
        guard recordedMs >= Self.minTranscribeMs else {
            try? FileManager.default.removeItem(at: tempURL)
            phase = .idle
            return
        }
        phase = .transcribing
        Task { [weak self] in
            defer { try? FileManager.default.removeItem(at: tempURL) }
            do {
                let text = try await self?.backend.transcribe(audioAt: tempURL) ?? ""
                guard let self, self.phase == .transcribing else { return }
                self.phase = .idle
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { self.onTranscript?(trimmed) }
            } catch {
                guard let self, self.phase == .transcribing else { return }
                self.phase = .failed
                self.scheduleFailedReset()
            }
        }
    }

    /// Abandon the hold (panel/surface closing mid-record): discard; narration still
    /// resumes if it was playing before the hold.
    func cancelHold() {
        holdActive = false
        guard phase == .recording else { return }
        stopTicker()
        recorder.stop()
        resumeIfNeeded()
        if let tempURL {
            try? FileManager.default.removeItem(at: tempURL)
            self.tempURL = nil
        }
        phase = .idle
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

    /// Let the failed caption linger as guidance, then fall back to typing-ready idle.
    private func scheduleFailedReset() {
        Task { [weak self] in
            try? await Task.sleep(for: Self.failedResetDelay)
            guard let self, self.phase == .failed else { return }
            self.phase = .idle
        }
    }
}
