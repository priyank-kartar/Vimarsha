import Foundation
import SwiftData
import Testing
@testable import Vimarsha

/// V34 — hold-to-talk for Discuss: recording pauses narration (pause-on-audio-conflict)
/// and resumes it the moment the mic closes (the transcription wait is not a conflict);
/// the transcript drops into the field via `onTranscript`, never auto-sent; failures
/// fall back to typing with the conversation state intact. Real player over the fake
/// engine; fakes for the recorder and backend (the two sanctioned seams).
@MainActor
struct VoiceInputTests {
    private struct Fixture {
        let voice: VoiceInput
        let player: PlayerController
        let audio: FakeAudioEngine
        let recorder: FakeRecorderEngine
        let transcripts: Transcripts
    }

    /// Reference box for the closure-captured results.
    final class Transcripts {
        var received: [String] = []
    }

    private func makeFixture(
        transcribe: @escaping @Sendable (URL) async throws -> String = { _ in "A question" }
    ) throws -> Fixture {
        let container = try ModelContainer(
            for: Book.self, Chapter.self, Memo.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let root = FileManager.default.temporaryDirectory
            .appending(path: "VoiceInputTests-\(UUID().uuidString)")
        let book = Book(title: "T", author: "A", epubPath: "Library/Books/x/book.epub")
        let chapter = Chapter(index: 0, title: "One")
        chapter.status = .ready
        chapter.audioPath = "Library/Books/x/chapters/0/chapter.mp3"
        chapter.bundlePath = "Library/Books/x/chapters/0/bundle.json"
        let bundleURL = root.appending(path: chapter.bundlePath!)
        try FileManager.default.createDirectory(
            at: bundleURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(ChapterBundleDTO.timedFixture).write(to: bundleURL)
        book.chapters = [chapter]
        context.insert(book)
        try context.save()

        let audio = FakeAudioEngine()
        let player = PlayerController(engine: audio, context: context, containerRoot: root)
        try player.load(chapter)
        let recorder = FakeRecorderEngine()
        var backend = FakeBackendClient.returning()
        backend.onTranscribe = transcribe
        let voice = VoiceInput(recorder: recorder, backend: backend, player: player)
        let transcripts = Transcripts()
        voice.onTranscript = { transcripts.received.append($0) }
        return Fixture(
            voice: voice, player: player, audio: audio, recorder: recorder,
            transcripts: transcripts
        )
    }

    /// Spin the main actor until the async transcription lands (bounded ~400ms).
    private func settle(until done: () -> Bool) async {
        for _ in 0..<200 where !done() {
            try? await Task.sleep(for: .milliseconds(2))
        }
    }

    @Test("hold pauses playing narration and records")
    func holdPausesAndRecords() async throws {
        let f = try makeFixture()
        f.player.play()
        await f.voice.beginHold()
        #expect(f.voice.phase == .recording)
        #expect(f.recorder.isRecording)
        #expect(!f.player.isPlaying)
    }

    @Test("release resumes narration immediately and the transcript fills the field")
    func releaseResumesAndTranscribes() async throws {
        let f = try makeFixture()
        f.player.play()
        await f.voice.beginHold()
        f.voice.endHold()

        // The conflict ends at mic close — narration is back BEFORE the transcript.
        #expect(f.player.isPlaying)
        #expect(f.voice.phase == .transcribing)

        await settle { f.voice.phase == .idle }
        #expect(f.transcripts.received == ["A question"])
        #expect(f.voice.phase == .idle)
    }

    @Test("paused narration stays paused after the hold")
    func pausedStaysPaused() async throws {
        let f = try makeFixture()
        await f.voice.beginHold()
        f.voice.endHold()
        #expect(!f.player.isPlaying)
        await settle { f.voice.phase == .idle }
        #expect(!f.player.isPlaying)
    }

    @Test("denied permission guides without touching playback")
    func deniedPermission() async throws {
        let f = try makeFixture()
        f.recorder.stubbedPermission = false
        f.player.play()
        await f.voice.beginHold()
        #expect(f.voice.phase == .denied)
        #expect(f.player.isPlaying)
        #expect(f.recorder.startedURL == nil)
    }

    @Test("a tap-length hold is discarded without a backend round-trip")
    func tooShortDiscards() async throws {
        let f = try makeFixture(transcribe: { _ in
            Issue.record("transcribe must not be called for a too-short hold")
            return ""
        })
        f.recorder.stubbedRecordedMs = 200
        f.player.play()
        await f.voice.beginHold()
        f.voice.endHold()
        #expect(f.voice.phase == .idle)
        #expect(f.player.isPlaying)
        await settle { false } // give a wrong async call the chance to surface
        #expect(f.transcripts.received.isEmpty)
    }

    @Test("transcription failure falls back to typing; narration already resumed")
    func transcribeFailureFallsBack() async throws {
        let f = try makeFixture(transcribe: { _ in throw URLError(.cannotConnectToHost) })
        f.player.play()
        await f.voice.beginHold()
        f.voice.endHold()
        #expect(f.player.isPlaying)
        await settle { f.voice.phase == .failed }
        #expect(f.voice.phase == .failed)
        #expect(f.transcripts.received.isEmpty)
    }

    @Test("recorder start failure resumes narration and stays idle")
    func startFailureResumes() async throws {
        let f = try makeFixture()
        f.recorder.startError = URLError(.unknown)
        f.player.play()
        await f.voice.beginHold()
        #expect(f.voice.phase == .idle)
        #expect(f.player.isPlaying)
    }

    @Test("a release during the permission prompt never starts a recording")
    func releaseDuringPermissionPrompt() async throws {
        let f = try makeFixture()
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        f.recorder.permissionGate = {
            for await granted in stream { return granted }
            return false
        }
        let hold = Task { await f.voice.beginHold() }
        await Task.yield()
        f.voice.endHold() // finger up while the prompt is showing
        continuation.yield(true)
        await hold.value
        #expect(f.voice.phase != .recording)
        #expect(f.recorder.startedURL == nil)
    }

    @Test("cancel mid-record discards and resumes")
    func cancelDiscards() async throws {
        let f = try makeFixture(transcribe: { _ in
            Issue.record("transcribe must not be called after cancel")
            return ""
        })
        f.player.play()
        await f.voice.beginHold()
        f.voice.cancelHold()
        #expect(f.voice.phase == .idle)
        #expect(f.player.isPlaying)
        #expect(!f.recorder.isRecording)
    }
}
