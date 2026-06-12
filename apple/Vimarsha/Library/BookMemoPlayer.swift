import Foundation

/// Playback for the book-level Voice notes archive (the library cluster's mic control).
/// A trimmed cousin of `MemoNotes`: no chapter player to pause and no open-at-pin (there
/// is no open chapter at the library surface), just play/stop one memo clip and delete.
/// Runs on its own ephemeral `AudioEngine`, like `MemoNotes`' memo engine.
@MainActor
@Observable
final class BookMemoPlayer {
    private let memoEngine: any AudioEngine
    private let store: LibraryStore
    private let containerRoot: URL
    private let book: Book

    /// The memo whose clip is playing, or nil.
    private(set) var playingMemoId: UUID?

    init(book: Book, memoEngine: any AudioEngine, store: LibraryStore, containerRoot: URL) {
        self.book = book
        self.memoEngine = memoEngine
        self.store = store
        self.containerRoot = containerRoot
        memoEngine.onFinish = { [weak self] in self?.playingMemoId = nil }
    }

    /// Every voice memo across the book's chapters, newest first.
    var memos: [Memo] {
        book.chapters.flatMap(\.memos).sorted { $0.createdAt > $1.createdAt }
    }

    /// Toggle playback: tapping the playing memo stops it, tapping another switches over.
    /// A missing/unreadable clip is a no-op (the row still shows its transcript).
    func play(_ memo: Memo) {
        if playingMemoId == memo.id {
            memoEngine.pause()
            playingMemoId = nil
            return
        }
        let url = containerRoot.appending(path: memo.audioPath)
        guard (try? memoEngine.load(url: url)) != nil else { return }
        memoEngine.play()
        playingMemoId = memo.id
    }

    func retry(_ memo: Memo) {
        store.transcribeMemo(memo)
    }

    func delete(_ memo: Memo) {
        if playingMemoId == memo.id { stop() }
        store.deleteMemo(memo)
    }

    /// Leaving the archive: stop any clip.
    func stop() {
        memoEngine.pause()
        playingMemoId = nil
    }
}
