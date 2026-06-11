import Foundation
import SwiftData

/// The Notes state's controller (V30; apple/CLAUDE.md §UI map state 5 — "Notes list is
/// a morphed list state"): the open chapter's voice memos — play each clip, jump
/// narration to the pin, retry a failed transcript, delete.
///
/// Memo playback rides its OWN ephemeral engine (the Flutter spec's sanctioned
/// "separate handler instance"): the chapter's shared engine keeps its loaded MP3 and
/// resume position untouched. Playing a memo pauses narration (audio-conflict rule,
/// sound-design.md) and does not auto-resume it — the reader is reviewing notes.
@Observable
@MainActor
final class MemoNotes {
    private let player: PlayerController
    private let memoEngine: any AudioEngine
    private let store: LibraryStore
    private let containerRoot: URL

    /// The memo currently playing through the memo engine (nil = none).
    private(set) var playingMemoId: UUID?

    init(
        player: PlayerController,
        memoEngine: any AudioEngine,
        store: LibraryStore,
        containerRoot: URL
    ) {
        self.player = player
        self.memoEngine = memoEngine
        self.store = store
        self.containerRoot = containerRoot
        memoEngine.onFinish = { [weak self] in self?.playingMemoId = nil }
    }

    /// The open chapter's memos, newest first (the Flutter `watchMemos` ordering).
    var memos: [Memo] {
        (player.chapter?.memos ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    /// Toggle playback of one memo: narration pauses (audio conflict); tapping the
    /// playing memo stops it; tapping another switches over. A missing/unreadable clip
    /// is a no-op (the row still shows its transcript — Flutter parity).
    func play(_ memo: Memo) {
        if playingMemoId == memo.id {
            memoEngine.pause()
            playingMemoId = nil
            return
        }
        let url = containerRoot.appending(path: memo.audioPath)
        guard (try? memoEngine.load(url: url)) != nil else { return }
        if player.isPlaying { player.pause() }
        memoEngine.play()
        playingMemoId = memo.id
    }

    /// Jump narration to the memo's pinned position (the precise ms inside its
    /// paragraph); memo playback stops. The view morphs back to reading.
    func openAtPin(_ memo: Memo) {
        stopPlayback()
        player.seek(toMs: memo.positionMs)
    }

    /// Re-attempt a failed (or stranded-pending) transcript through the store (V29).
    func retry(_ memo: Memo) {
        store.transcribeMemo(memo)
    }

    /// Remove the memo (row + audio, in-flight transcript cancelled) via the store.
    func delete(_ memo: Memo) {
        if playingMemoId == memo.id { stopPlayback() }
        store.deleteMemo(memo)
    }

    /// Leaving the Notes state / closing the surface: stop any memo clip.
    func stopPlayback() {
        if playingMemoId != nil {
            memoEngine.pause()
            playingMemoId = nil
        }
    }
}
