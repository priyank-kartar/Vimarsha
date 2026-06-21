import Foundation
import SwiftData
import SwiftUI

/// The library's store (app-architecture.md layering: view → store → seams): owns the
/// persisted `Book` rows and the import flow (V10 copy → V11 cover → V12 row). UI-facing
/// and `@Observable`; file IO runs detached off the main actor.
@MainActor
@Observable
final class LibraryStore {
    private let context: ModelContext
    private let importer: EpubImporter
    private let backend: any BackendClient

    /// All books, oldest-first (the shelf reads bottom-up like the reference stack).
    private(set) var books: [Book] = []
    /// Pre-downsampled cover art per book (decoded off-main at load, never during
    /// scroll — apple/CLAUDE.md §Performance budget).
    private(set) var covers: [UUID: Image] = [:]
    /// Honest error posture: the last failed import, surfaced as a status line on the
    /// surface (not an alert); cleared on the next attempt.
    var importError: String?
    /// In-flight chapter downloads, keyed by chapter id — owned by the store so leaving a
    /// screen never orphans a narration job (app-architecture.md §Concurrency model);
    /// deleting a book cancels its downloads.
    private var downloadTasks: [UUID: Task<Void, Never>] = [:]
    /// In-flight memo transcriptions, keyed by memo id (V29) — store-owned for the same
    /// reason: closing the reading surface must not kill the transcript fetch.
    private var transcriptionTasks: [UUID: Task<Void, Never>] = [:]
    /// Whole-book downloads in flight, keyed by book id — serial per book (one warm worker).
    private var bookDownloadTasks: [UUID: Task<Void, Never>] = [:]
    /// Books currently downloading all chapters — drives the cluster control's progress state.
    private(set) var downloadingBooks: Set<UUID> = []

    init(
        context: ModelContext,
        importer: EpubImporter = .live,
        backend: any BackendClient = URLSessionBackendClient()
    ) {
        self.context = context
        self.importer = importer
        self.backend = backend
        load()
    }

    /// What the shelf shows: persisted books when any exist; the static seeds as the
    /// empty-state/demo path (V12 — the seed shelf stops being the only library).
    var shelf: [ShelfBook] {
        books.isEmpty
            ? ShelfBook.seeds
            : books.map { ShelfBook(book: $0, cover: covers[$0.id]) }
    }

    func load() {
        books = sortedByRecency((try? context.fetch(FetchDescriptor<Book>())) ?? [])
        healChapterStates()
        loadMissingCovers()
    }

    /// Most-recent activity first: the last-listened book leads, falling back to add time for
    /// books never opened (so a freshly imported book still surfaces near the top).
    private func sortedByRecency(_ books: [Book]) -> [Book] {
        books.sorted { ($0.lastOpenedAt ?? $0.addedAt) > ($1.lastOpenedAt ?? $1.addedAt) }
    }

    /// Record that a book was just opened and re-order the shelf so it rises to the top.
    func markOpened(_ book: Book) {
        book.lastOpenedAt = .now
        try? context.save()
        books = sortedByRecency(books)
    }

    /// Self-heal stale chapter rows (data-model.md §Rules): `ready` with missing cache
    /// files → `none` (the container moved or files were purged); `pending` with no live
    /// task → `none` (a relaunch orphaned the job — honest state, the user re-requests).
    private func healChapterStates() {
        var healed = false
        for chapter in books.flatMap(\.chapters) {
            switch chapter.status {
            case .pending where downloadTasks[chapter.id] == nil:
                chapter.status = .none
                healed = true
            case .ready where !cacheFilesExist(for: chapter):
                chapter.status = .none
                chapter.bundlePath = nil
                chapter.audioPath = nil
                healed = true
            default:
                break
            }
        }
        if healed { try? context.save() }
    }

    private func cacheFilesExist(for chapter: Chapter) -> Bool {
        guard let bundlePath = chapter.bundlePath, let audioPath = chapter.audioPath
        else { return false }
        let fm = FileManager.default
        return fm.fileExists(atPath: importer.containerRoot.appending(path: bundlePath).path)
            && fm.fileExists(atPath: importer.containerRoot.appending(path: audioPath).path)
    }

    /// Decode (downsampled) any cover art not yet cached, off the main actor; each
    /// finished decode updates `covers` and re-renders the shelf.
    private func loadMissingCovers() {
        for book in books where covers[book.id] == nil {
            guard let coverPath = book.coverPath else { continue }
            let url = importer.containerRoot.appending(path: coverPath)
            let id = book.id
            Task { [weak self] in
                guard let image = await Task.detached(operation: { CoverArt.shelfImage(at: url) }).value
                else { return }
                self?.covers[id] = image
            }
        }
    }

    /// Import a picked EPUB: container copy + cover extraction off-main, `POST /toc`
    /// through the seam (V13), then persist the book + its chapter rows in one go.
    /// All-or-nothing (Flutter `LibraryRepository` parity): if the backend can't read the
    /// book, the copied files are rolled back and nothing lands. The backend's meta is
    /// the authority; the OPF-read `EpubInfo` fills any blanks (last resort: filename).
    func addBook(from pickedURL: URL) async {
        importError = nil
        let importer = self.importer
        let backend = self.backend
        do {
            let (imported, info, toc) = try await Task.detached {
                () -> (ImportedEpub, EpubInfo.Metadata?, TocResponse) in
                let imported = try importer.importEpub(at: pickedURL)
                let stored = importer.containerRoot.appending(path: imported.relativePath)
                do {
                    let toc = try await backend.fetchToc(epubAt: stored)
                    return (imported, EpubInfo.extract(fromEpubAt: stored), toc)
                } catch {
                    // No half-state: a book the backend can't serve never lands.
                    try? FileManager.default.removeItem(at: stored.deletingLastPathComponent())
                    throw error
                }
            }.value
            let fallbackTitle = info?.title ?? pickedURL.deletingPathExtension().lastPathComponent
            let book = Book(
                id: imported.bookId,
                title: toc.book.title.isEmpty ? fallbackTitle : toc.book.title,
                author: toc.book.author.isEmpty ? (info?.author ?? "") : toc.book.author,
                epubPath: imported.relativePath,
                coverPath: imported.coverRelativePath
            )
            book.chapters = toc.chapters.map { Chapter(index: $0.index, title: $0.title) }
            context.insert(book)
            try context.save()
            load()
        } catch {
            importError = Self.importErrorMessage(for: error)
        }
    }

    /// Honest error posture (the store's stated design): name the cause so the user can
    /// act on it. The dominant real-world failure is the backend being unreachable — the
    /// import flow needs `POST /toc` — which a generic "Couldn't import book" hid.
    static func importErrorMessage(for error: any Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost,
                 .notConnectedToInternet, .timedOut:
                return "Can't reach the backend — is it running on localhost:8000?"
            default:
                return "Network error: \(urlError.localizedDescription)"
            }
        }
        if case BackendError.badStatus(let code) = error {
            return "Backend rejected the book (HTTP \(code))"
        }
        return "Couldn't import book: \(error.localizedDescription)"
    }

    /// Lazily narrate + cache one chapter (V14): `none/error → pending → ready/error`.
    /// The job is a cancellable task owned by the store; the heavy IO runs off-main in
    /// `ChapterDownloader`. Returns the task (for awaiting/tests), or nil when the
    /// chapter is already pending/ready.
    @discardableResult
    func downloadChapter(_ chapter: Chapter) -> Task<Void, Never>? {
        guard chapter.status == .none || chapter.status == .error,
              let book = chapter.book
        else { return nil }
        chapter.status = .pending
        chapter.errorReason = nil
        try? context.save()
        return narrate(chapter, book: book)
    }

    /// Download every not-yet-ready chapter of `book`, in document order, ONE AT A TIME.
    /// The premium worker narrates a single chapter at a time anyway (one warm GPU); firing
    /// concurrent jobs would just queue on the backend and multiply cost, so this awaits each
    /// chapter before starting the next. Cancellable; calling again while running is a no-op.
    /// While chapter audio is playing the app stays alive (audio background mode), so this
    /// keeps draining the queue even when backgrounded/locked.
    @discardableResult
    func downloadBook(_ book: Book) -> Task<Void, Never>? {
        guard bookDownloadTasks[book.id] == nil else { return nil }
        let bookId = book.id
        downloadingBooks.insert(bookId)
        let task = Task { [weak self] in
            guard let self else { return }
            for chapter in book.chapters.sorted(by: { $0.index < $1.index }) {
                if Task.isCancelled { break }
                guard chapter.status == .none || chapter.status == .error else { continue }
                chapter.status = .pending
                chapter.errorReason = nil
                try? self.context.save()
                await self.narrate(chapter, book: book).value
            }
            self.downloadingBooks.remove(bookId)
            self.bookDownloadTasks[bookId] = nil
        }
        bookDownloadTasks[bookId] = task
        return task
    }

    /// Stop an in-flight whole-book download (the current chapter finishes; the rest are left
    /// for a later request). Per-chapter jobs already cached stay cached.
    func cancelBookDownload(_ book: Book) {
        bookDownloadTasks[book.id]?.cancel()
        bookDownloadTasks[book.id] = nil
        downloadingBooks.remove(book.id)
    }

    func isDownloadingBook(_ book: Book) -> Bool { downloadingBooks.contains(book.id) }

    /// Prefetch the next `count` not-yet-narrated chapters after `chapter` so they're cached
    /// by the time the reader reaches them. Small look-ahead — the backend serializes anyway.
    func prefetch(after chapter: Chapter, count: Int = 1) {
        guard let book = chapter.book else { return }
        let upcoming = book.chapters
            .filter { $0.index > chapter.index && $0.status == .none }
            .sorted { $0.index < $1.index }
            .prefix(count)
        for next in upcoming { _ = downloadChapter(next) }
    }

    /// Persist pending model edits (e.g. a voice change made in the UI).
    func saveContext() throws { try context.save() }

    /// Re-narrate a chapter in the book's CURRENT voice, regardless of its present status
    /// (hold-to-re-render, or a stale chapter opened). Cancels any in-flight job for it first.
    @discardableResult
    func rerenderChapter(_ chapter: Chapter) -> Task<Void, Never>? {
        guard let book = chapter.book else { return nil }
        downloadTasks[chapter.id]?.cancel()
        chapter.status = .pending
        chapter.errorReason = nil
        try? context.save()
        return narrate(chapter, book: book)
    }

    /// Shared narration job: download `chapter` in `book`'s current voice, cache it, and stamp
    /// the row (`.ready` + `narratedVoiceId`, or `.error`). The caller owns the entry guard and
    /// the `.pending` transition; this owns the download task + its registration/cleanup.
    @discardableResult
    private func narrate(_ chapter: Chapter, book: Book) -> Task<Void, Never> {
        let downloader = ChapterDownloader(containerRoot: importer.containerRoot, backend: backend)
        let voice = VoiceCatalog.voice(id: book.voiceId)
        let (epubPath, bookId, index, chapterId, voiceId, kokoroVoice, engine) =
            (book.epubPath, book.id, chapter.index, chapter.id, book.voiceId, voice.voiceToken, voice.engine)
        let task = Task { [weak self] in
            do {
                let cached = try await downloader.download(
                    epubRelativePath: epubPath, bookId: bookId, chapterIndex: index,
                    engine: engine, voice: kokoroVoice
                )
                guard let self, !Task.isCancelled else { return }
                chapter.bundlePath = cached.bundleRelativePath
                chapter.audioPath = cached.audioRelativePath
                chapter.narratedVoiceId = voiceId
                chapter.status = .ready
                try? self.context.save()
            } catch {
                // A cancelled job (book deleted / app teardown, or a re-render superseding this
                // one) must not touch the row — it may already be gone or owned by a newer job.
                guard let self, !Task.isCancelled, !(error is CancellationError) else { return }
                chapter.status = .error
                chapter.errorReason = "Narration failed"
                try? self.context.save()
            }
            self?.downloadTasks[chapterId] = nil
        }
        downloadTasks[chapterId] = task
        return task
    }

    /// A player for one ready chapter's reading surface (V18) — same context/container
    /// as the library; the engine is the app-lifetime device owner handed down from
    /// `VimarshaApp` (the controller pauses it, never disposes it).
    func makePlayer(engine: any AudioEngine) -> PlayerController {
        PlayerController(engine: engine, context: context, containerRoot: importer.containerRoot)
    }

    /// Hold-to-record memos for one open chapter (V28) — same context/container as the
    /// library; the recorder is the app-lifetime mic owner (the audio-engine rule). A
    /// saved memo flows straight into transcription (V29).
    func makeMemoCapture(recorder: any RecorderEngine, player: PlayerController) -> MemoCapture {
        let capture = MemoCapture(
            recorder: recorder, player: player,
            context: context, containerRoot: importer.containerRoot
        )
        capture.onSaved = { [weak self] memo in self?.transcribeMemo(memo) }
        return capture
    }

    /// The Notes state's controller for one open chapter (V30) — memo playback on its
    /// own ephemeral engine so the chapter's shared engine keeps its loaded MP3.
    func makeMemoNotes(player: PlayerController, memoEngine: any AudioEngine) -> MemoNotes {
        MemoNotes(
            player: player, memoEngine: memoEngine,
            store: self, containerRoot: importer.containerRoot
        )
    }

    /// A live Discuss conversation for one open chapter (V32) — in-memory until saved.
    /// Grounding is snapshotted from the player at EACH send (the passage being narrated
    /// then); the anchor is pinned later, when the panel actually opens (V33).
    func makeChatStore(player: PlayerController) -> ChatStore {
        let bookTitle = player.chapter?.book?.title ?? ""
        let chapterTitle = player.chapter?.title ?? ""
        return ChatStore(
            backend: backend,
            contextSnapshot: { [weak player] in
                ChatContextSnapshot.make(
                    bundle: player?.bundle,
                    timing: player?.timing,
                    positionMs: player?.positionMs ?? 0,
                    bookTitle: bookTitle,
                    chapterTitle: chapterTitle
                )
            }
        )
    }

    /// Hold-to-talk for the Discuss panel (V34) — records through the shared mic seam,
    /// transcribes through the backend seam; pause-on-audio-conflict rides the player.
    func makeVoiceInput(recorder: any RecorderEngine, player: PlayerController) -> VoiceInput {
        VoiceInput(recorder: recorder, backend: backend, player: player)
    }

    /// Spoken replies for the Discuss panel (V35) — /speak audio on its own ephemeral
    /// engine so the chapter's shared engine keeps its loaded MP3 (the MemoNotes rule).
    func makeReplySpeaker(player: PlayerController, speechEngine: any AudioEngine) -> ReplySpeaker {
        ReplySpeaker(backend: backend, speechEngine: speechEngine, player: player)
    }

    /// Persist one conversation as a NEW thread (V32; save-on-demand — each Save
    /// inserts, never updates). Empty conversations are refused (spec §6: Save needs
    /// at least one exchange; the UI disables earlier, this is the backstop).
    @discardableResult
    func saveChatThread(
        book: Book,
        chapterIndex: Int,
        anchorBlockId: String?,
        title: String?,
        messages: [ChatMessageDTO]
    ) -> ChatThread? {
        guard !messages.isEmpty else { return nil }
        let thread = ChatThread(
            chapterIndex: chapterIndex, anchorBlockId: anchorBlockId, title: title
        )
        thread.book = book
        context.insert(thread)
        thread.lines = messages.enumerated().map { index, message in
            ChatLine(role: message.role, text: message.text, index: index)
        }
        try? context.save()
        return thread
    }

    /// One chapter's saved conversations, newest first (the Conversations state's list).
    func chatThreads(for book: Book, chapterIndex: Int) -> [ChatThread] {
        book.chatThreads
            .filter { $0.chapterIndex == chapterIndex }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// The whole book's saved conversations across every chapter, newest first — the
    /// library cluster's "Saved discussions" archive.
    func bookChatThreads(_ book: Book) -> [ChatThread] {
        book.chatThreads.sorted { $0.createdAt > $1.createdAt }
    }

    /// A playback controller for the book-level Voice notes archive (V-library cluster) —
    /// same container as the library; an ephemeral engine so nothing else's loaded clip is
    /// disturbed (the MemoNotes precedent).
    func makeBookMemoPlayer(for book: Book, memoEngine: any AudioEngine) -> BookMemoPlayer {
        BookMemoPlayer(
            book: book, memoEngine: memoEngine,
            store: self, containerRoot: importer.containerRoot
        )
    }

    /// Remove one saved conversation (lines cascade; the confirm lives in the UI —
    /// threads are user content, data-model.md §Rules).
    func deleteChatThread(_ thread: ChatThread) {
        context.delete(thread)
        try? context.save()
    }

    /// Transcribe one memo's audio through the seam (V29): `pending → ready/error`,
    /// mirroring the chapter-status pattern. Also the retry path — error (or stranded
    /// pending) rows re-submit; `ready` rows and in-flight jobs are refused. Recording
    /// never depends on the backend: failure keeps the memo + audio with a reason.
    @discardableResult
    func transcribeMemo(_ memo: Memo) -> Task<Void, Never>? {
        guard memo.status != .ready, transcriptionTasks[memo.id] == nil else { return nil }
        memo.status = .pending
        memo.errorReason = nil
        try? context.save()

        let backend = self.backend
        let audioURL = importer.containerRoot.appending(path: memo.audioPath)
        let memoId = memo.id
        let task = Task { [weak self] in
            do {
                let text = try await backend.transcribe(audioAt: audioURL)
                guard let self, !Task.isCancelled else { return }
                memo.transcript = text.trimmingCharacters(in: .whitespacesAndNewlines)
                memo.status = .ready
                try? self.context.save()
            } catch {
                guard let self, !Task.isCancelled, !(error is CancellationError) else { return }
                memo.status = .error
                memo.errorReason = "Transcription failed"
                try? self.context.save()
            }
            self?.transcriptionTasks[memoId] = nil
        }
        transcriptionTasks[memoId] = task
        return task
    }

    /// Remove one memo (V30): cancel any in-flight transcription, sweep the audio file,
    /// delete the row (data-model.md §Rules — memos are user content; the confirm lives
    /// in the UI).
    func deleteMemo(_ memo: Memo) {
        transcriptionTasks[memo.id]?.cancel()
        transcriptionTasks[memo.id] = nil
        let audioURL = importer.containerRoot.appending(path: memo.audioPath)
        try? FileManager.default.removeItem(at: audioURL)
        context.delete(memo)
        try? context.save()
    }

    /// Remove the book row (cascades to chapters) and its container subtree
    /// (data-model.md §Rules — deletion); in-flight chapter downloads are cancelled.
    func deleteBook(_ book: Book) {
        for chapter in book.chapters {
            downloadTasks[chapter.id]?.cancel()
            downloadTasks[chapter.id] = nil
        }
        let bookDir = importer.containerRoot
            .appending(path: book.epubPath)
            .deletingLastPathComponent()
        try? FileManager.default.removeItem(at: bookDir)
        context.delete(book)
        try? context.save()
        load()
    }
}
