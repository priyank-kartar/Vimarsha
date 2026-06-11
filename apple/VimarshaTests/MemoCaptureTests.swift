import Foundation
import SwiftData
import Testing
@testable import Vimarsha

/// V28 — hold-to-record voice memos: the capture controller orchestrates pause-while-
/// recording, the container save + SwiftData pin, and resume-if-was-playing. Real
/// in-memory SwiftData + real temp-file IO; the two sanctioned doubles (FakeAudioEngine,
/// FakeRecorderEngine) stand in for the device.
@MainActor
struct MemoCaptureTests {
    private struct Fixture {
        let capture: MemoCapture
        let player: PlayerController
        let audio: FakeAudioEngine
        let recorder: FakeRecorderEngine
        let chapter: Chapter
        let book: Book
        let context: ModelContext
        let root: URL
    }

    /// A persisted book + ready chapter (real cached bundle.json), a loaded player on the
    /// fake audio engine, and a capture controller on the fake recorder.
    private func makeFixture() throws -> Fixture {
        let container = try ModelContainer(
            for: Book.self, Chapter.self, Memo.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let root = FileManager.default.temporaryDirectory
            .appending(path: "MemoCaptureTests-\(UUID().uuidString)")
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
        let capture = MemoCapture(
            recorder: recorder, player: player, context: context, containerRoot: root
        )
        return Fixture(
            capture: capture, player: player, audio: audio, recorder: recorder,
            chapter: chapter, book: book, context: context, root: root
        )
    }

    private func memos(in context: ModelContext) throws -> [Memo] {
        try context.fetch(FetchDescriptor<Memo>())
    }

    @Test("hold pauses playing narration and starts the recorder")
    func holdPausesAndRecords() async throws {
        let f = try makeFixture()
        f.player.play()
        await f.capture.beginHold()
        #expect(f.capture.phase == .recording)
        #expect(f.recorder.isRecording)
        #expect(!f.player.isPlaying)        // the reading view freezes while recording
    }

    @Test("release saves the memo: file in the container, row pinned to the narrated paragraph")
    func releaseSavesPinnedMemo() async throws {
        let f = try makeFixture()
        f.player.play()
        f.audio.advance(byMs: 1_500)        // mid "b2" (index 1) in the timed fixture
        f.player.tick()
        await f.capture.beginHold()
        f.capture.endHold()

        let saved = try #require(try memos(in: f.context).first)
        #expect(saved.chapter?.id == f.chapter.id)
        #expect(saved.paragraphIndex == 1)
        #expect(saved.positionMs == 1_500)
        #expect(saved.status == .pending)   // transcription is V29
        #expect(saved.audioPath.hasPrefix("Library/Books/x/memos/"))
        #expect(FileManager.default.fileExists(
            atPath: f.root.appending(path: saved.audioPath).path
        ))
    }

    @Test("release resumes narration only if it was playing before the hold")
    func resumeFollowsPriorState() async throws {
        let f = try makeFixture()
        f.player.play()
        await f.capture.beginHold()
        f.capture.endHold()
        #expect(f.player.isPlaying)         // was playing → resumes

        let paused = try makeFixture()
        await paused.capture.beginHold()
        paused.capture.endHold()
        #expect(!paused.player.isPlaying)   // was paused → stays paused
    }

    @Test("a too-short clip is discarded: no row, no file, still resumes")
    func shortClipDiscarded() async throws {
        let f = try makeFixture()
        f.player.play()
        f.recorder.stubbedRecordedMs = MemoCapture.minSaveMs - 1
        await f.capture.beginHold()
        let tempURL = try #require(f.recorder.startedURL)
        f.capture.endHold()
        #expect(try memos(in: f.context).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: tempURL.path))
        #expect(f.capture.phase == .idle)
        #expect(f.player.isPlaying)
    }

    @Test("denied mic permission: no recording, playback untouched, denied phase")
    func deniedPermission() async throws {
        let f = try makeFixture()
        f.player.play()
        f.recorder.stubbedPermission = false
        await f.capture.beginHold()
        #expect(f.capture.phase == .denied)
        #expect(f.recorder.startedURL == nil)
        #expect(f.player.isPlaying)         // never paused — nothing recorded
    }

    @Test("recorder failure on start: back to idle and narration resumes")
    func startFailureRecovers() async throws {
        let f = try makeFixture()
        f.player.play()
        f.recorder.startError = NSError(domain: "mic", code: 1)
        await f.capture.beginHold()
        #expect(f.capture.phase == .idle)
        #expect(f.player.isPlaying)
    }

    @Test("releasing while the permission prompt is up never starts a recording")
    func releaseDuringPermissionPrompt() async throws {
        let f = try makeFixture()
        f.player.play()
        f.recorder.permissionGate = { await Task.yield(); return true }
        async let begin: Void = f.capture.beginHold()
        await Task.yield()                  // let beginHold reach the permission await
        f.capture.endHold()                 // finger lifted during the system prompt
        await begin
        #expect(f.capture.phase != .recording)
        #expect(f.recorder.startedURL == nil)
        #expect(f.player.isPlaying)
    }

    @Test("cancel discards the clip and resumes")
    func cancelDiscards() async throws {
        let f = try makeFixture()
        f.player.play()
        await f.capture.beginHold()
        f.capture.cancelHold()
        #expect(try memos(in: f.context).isEmpty)
        #expect(f.capture.phase == .idle)
        #expect(f.player.isPlaying)
    }

    @Test("saved phase reports after a successful save (the confirmation chip)")
    func savedPhase() async throws {
        let f = try makeFixture()
        await f.capture.beginHold()
        f.capture.endHold()
        #expect(f.capture.phase == .saved)
    }

    @Test("deleting the chapter cascades its memos (user-content cleanup)")
    func cascadeDelete() async throws {
        let f = try makeFixture()
        await f.capture.beginHold()
        f.capture.endHold()
        #expect(try memos(in: f.context).count == 1)
        f.context.delete(f.chapter)
        try f.context.save()
        #expect(try memos(in: f.context).isEmpty)
    }
}
