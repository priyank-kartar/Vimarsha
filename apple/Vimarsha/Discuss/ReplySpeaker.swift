import Foundation

/// Reads an assistant reply aloud (V35; spec §4): the reply text goes to `POST /speak`
/// (Chatterbox — the narrator's own voice, one persona) and plays on this controller's
/// OWN ephemeral engine, so the chapter's shared engine keeps its loaded MP3 and resume
/// position (the MemoNotes precedent). **Pause-on-audio-conflict:** narration keeps
/// playing while the audio is fetched (waiting is not a conflict — the V34 rule) and
/// pauses only when the spoken reply actually starts; it **resumes afterward if it was
/// playing** (unlike Notes review, Discuss returns you to listening — spec §4).
@Observable
@MainActor
final class ReplySpeaker {
    private let backend: any BackendClient
    private let speechEngine: any AudioEngine
    private let player: PlayerController

    /// The transcript index of the reply currently playing (nil = none).
    private(set) var speakingIndex: Int?
    /// The transcript index whose audio is being fetched (minutes-class on a dev
    /// backend — the speaker button shows the wait honestly).
    private(set) var fetchingIndex: Int?
    /// The transcript index whose fetch failed — a brief inline error, the text answer
    /// stays (spec §6).
    private(set) var failedIndex: Int?

    private var wasPlaying = false
    private var tempURL: URL?

    /// How long the failed mark lingers on the speaker button.
    static let failedResetDelay: Duration = .seconds(2.5)

    init(backend: any BackendClient, speechEngine: any AudioEngine, player: PlayerController) {
        self.backend = backend
        self.speechEngine = speechEngine
        self.player = player
        speechEngine.onFinish = { [weak self] in self?.finishSpeaking() }
    }

    /// Toggle speech for one reply: speaking it already → stop (and resume narration);
    /// otherwise fetch + play. One reply at a time; a second tap while another fetch
    /// or speech is live is ignored (no audio pile-up).
    func speak(_ text: String, at index: Int) async {
        if speakingIndex == index {
            stop()
            return
        }
        guard speakingIndex == nil, fetchingIndex == nil else { return }
        failedIndex = nil
        fetchingIndex = index
        do {
            let data = try await backend.speak(text: text)
            guard fetchingIndex == index else { return } // stopped/superseded meanwhile
            let url = FileManager.default.temporaryDirectory
                .appending(path: "spoken-reply-\(UUID().uuidString).mp3")
            try data.write(to: url)
            try speechEngine.load(url: url)
            tempURL = url
            fetchingIndex = nil
            // The conflict starts HERE — audio is about to overlap.
            wasPlaying = player.isPlaying
            if wasPlaying { player.pause() }
            speechEngine.play()
            speakingIndex = index
        } catch {
            fetchingIndex = nil
            failedIndex = index
            scheduleFailedReset()
        }
    }

    /// Stop a playing reply (toggle/panel close/book close): narration resumes if it
    /// was playing when the reply started.
    func stop() {
        fetchingIndex = nil
        guard speakingIndex != nil else { return }
        speechEngine.pause()
        finishSpeaking()
    }

    private func finishSpeaking() {
        speakingIndex = nil
        if let tempURL {
            try? FileManager.default.removeItem(at: tempURL)
            self.tempURL = nil
        }
        if wasPlaying { player.play() }
        wasPlaying = false
    }

    private func scheduleFailedReset() {
        Task { [weak self] in
            try? await Task.sleep(for: Self.failedResetDelay)
            guard let self, self.failedIndex != nil else { return }
            self.failedIndex = nil
        }
    }
}
