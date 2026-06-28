import AVFoundation
import Foundation

/// The book-reading session (single-live-surface, spec 2026-06-28): owns the objects that must
/// SURVIVE surface switches — the player keeps playing and the chat thread persists while the
/// reading VIEW is torn down for Discuss/Figures/Notes. Created when a chapter opens for
/// reading; `close`d when the book closes. Lifted from `LibraryStackView.openReadingSurface`
/// / `closeReadingSurface` so the wiring lives with the session, not the god-view.
@MainActor
final class BookSession {
    let context: ReadingContext
    let player: PlayerController
    /// Mic-backed, so absent when there is no recorder (previews/snapshots).
    let memoCapture: MemoCapture?
    let memoNotes: MemoNotes
    let chatStore: ChatStore
    let voiceInput: VoiceInput?
    let replySpeaker: ReplySpeaker

    private init(
        context: ReadingContext, player: PlayerController, memoCapture: MemoCapture?,
        memoNotes: MemoNotes, chatStore: ChatStore, voiceInput: VoiceInput?, replySpeaker: ReplySpeaker
    ) {
        self.context = context
        self.player = player
        self.memoCapture = memoCapture
        self.memoNotes = memoNotes
        self.chatStore = chatStore
        self.voiceInput = voiceInput
        self.replySpeaker = replySpeaker
    }

    /// Build a session for a `ready` chapter; `nil` when the chapter won't load (the next
    /// `LibraryStore.load()` self-heal catches a stale row). The ephemeral memo/speech engines
    /// are injectable so tests pass the audio-seam double; production gets a fresh
    /// `AVFoundationAudioEngine` per call (each ephemeral player keeps the chapter's MP3 loaded).
    static func open(
        store: LibraryStore,
        audioEngine: any AudioEngine,
        recorder: (any RecorderEngine)?,
        book: Book,
        chapter: Chapter,
        memoEngine: any AudioEngine = AVFoundationAudioEngine(),
        speechEngine: any AudioEngine = AVFoundationAudioEngine()
    ) -> BookSession? {
        let player = store.makePlayer(engine: audioEngine)
        guard (try? player.load(chapter)) != nil else { return nil }
        // Look-ahead: quietly narrate the next chapter so it's cached by the time the reader
        // reaches it (no-op if already ready / downloading).
        store.prefetch(after: chapter, count: 1)
        let memoCapture = recorder.map { store.makeMemoCapture(recorder: $0, player: player) }
        let memoNotes = store.makeMemoNotes(player: player, memoEngine: memoEngine)
        let chatStore = store.makeChatStore(player: player)
        let voiceInput = recorder.map { store.makeVoiceInput(recorder: $0, player: player) }
        let replySpeaker = store.makeReplySpeaker(player: player, speechEngine: speechEngine)
        let shelfBook = ShelfBook(book: book, cover: store.covers[book.id])
        store.markOpened(book)   // bubbles this book to the top of the shelf (most-recent first)
        let context = ReadingContext(book: book, chapter: chapter, shelfBook: shelfBook)
        return BookSession(
            context: context, player: player, memoCapture: memoCapture, memoNotes: memoNotes,
            chatStore: chatStore, voiceInput: voiceInput, replySpeaker: replySpeaker
        )
    }

    /// Teardown (lifted from `closeReadingSurface`): cancel holds, stop ephemeral playback,
    /// pause the chapter player (persists the resume position). The shared engine is never
    /// disposed — the shared-player rule.
    func close() {
        memoCapture?.cancelHold()
        memoNotes.stopPlayback()
        voiceInput?.cancelHold()
        replySpeaker.stop()
        player.pause()
    }
}
