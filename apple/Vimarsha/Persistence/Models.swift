import Foundation
import SwiftData

/// SwiftData v1 slice (V12) — mirrors the proven Drift lineage from the frozen Flutter
/// client (plan/04-architecture/data-model.md). Rows hold *state about* chapters; the
/// bundle JSON (cached on disk) stays the source of truth for chapter content. All paths
/// are container-relative (the container moves between installs).
@Model
final class Book {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    /// `Library/Books/<id>/book.epub`
    var epubPath: String
    /// `Library/Books/<id>/cover.<ext>` — V11 extraction output; nil = generated cloth cover.
    var coverPath: String?
    var addedAt: Date
    var lastOpenedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \Chapter.book)
    var chapters: [Chapter] = []
    @Relationship(deleteRule: .cascade, inverse: \ChatThread.book)
    var chatThreads: [ChatThread] = []

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        epubPath: String,
        coverPath: String? = nil,
        addedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.epubPath = epubPath
        self.coverPath = coverPath
        self.addedAt = addedAt
    }
}

/// Chapter narration lifecycle: `none → pending (job running) → ready (cached) → error
/// (retryable)` — survives relaunch; offline = ready chapters only (app-architecture.md).
enum ChapterStatus: String, Codable, Sendable {
    case none, pending, ready, error
}

@Model
final class Chapter {
    @Attribute(.unique) var id: UUID
    var book: Book?
    /// The backend `chapter_index` (`POST /import?chapter_index=N`).
    var index: Int
    var title: String
    /// Raw storage for `status` — a plain string column migrates painlessly.
    private var statusRaw: String
    var errorReason: String?
    /// Set when `ready`: `Library/Books/<bookId>/chapters/<index>/bundle.json` / `chapter.mp3`.
    var bundlePath: String?
    var audioPath: String?
    /// Resume position + scrubber length.
    var progressMs: Int
    var durationMs: Int?
    @Relationship(deleteRule: .cascade, inverse: \Memo.chapter)
    var memos: [Memo] = []

    var status: ChapterStatus {
        get { ChapterStatus(rawValue: statusRaw) ?? .none }
        set { statusRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), index: Int, title: String) {
        self.id = id
        self.index = index
        self.title = title
        self.statusRaw = ChapterStatus.none.rawValue
        self.progressMs = 0
    }
}

/// Memo transcription lifecycle (V28/V29): `pending` (recorded, transcript not yet
/// fetched) → `ready` / `error` (retryable) — the chapter-status pattern, minus `none`
/// (a memo exists only once recorded).
enum MemoStatus: String, Codable, Sendable {
    case pending, ready, error
}

/// A voice note pinned to the paragraph being narrated when it was recorded (P4;
/// data-model.md "Later" slice). The audio lives in the book's container subtree so
/// deleting the book removes it with everything else.
@Model
final class Memo {
    @Attribute(.unique) var id: UUID
    var chapter: Chapter?
    /// Reading-order index of the pinned block in the chapter bundle's `blocks`.
    var paragraphIndex: Int
    /// The narration playhead at recording start — open-at-pin's precise seek target.
    var positionMs: Int
    /// `Library/Books/<bookId>/memos/<id>.m4a`
    var audioPath: String
    var transcript: String?
    /// Raw storage for `status` — a plain string column migrates painlessly.
    private var statusRaw: String
    var errorReason: String?
    var createdAt: Date

    var status: MemoStatus {
        get { MemoStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        paragraphIndex: Int,
        positionMs: Int,
        audioPath: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.paragraphIndex = paragraphIndex
        self.positionMs = positionMs
        self.audioPath = audioPath
        self.statusRaw = MemoStatus.pending.rawValue
        self.createdAt = createdAt
    }
}

/// A saved Discuss conversation (V32; data-model.md "Later" slice, mirroring the Flutter
/// `ChatThreads` lineage). Threads exist ONLY by explicit Save — each Save inserts a new
/// thread (multiple per chapter allowed); a conversation never saved never lands here.
@Model
final class ChatThread {
    @Attribute(.unique) var id: UUID
    var book: Book?
    /// The backend `chapter_index` the conversation belongs to. A plain Int (not a
    /// `Chapter` relationship) — threads are user content and outlive chapter cache
    /// resets, like the Flutter `(bookId, chapterIndex)` key.
    var chapterIndex: Int
    /// The block being narrated when Discuss was opened — for reference; grounding
    /// itself was snapshotted per send and lives in the lines.
    var anchorBlockId: String?
    var title: String?
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \ChatLine.thread)
    var lines: [ChatLine] = []

    init(
        id: UUID = UUID(),
        chapterIndex: Int,
        anchorBlockId: String? = nil,
        title: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.chapterIndex = chapterIndex
        self.anchorBlockId = anchorBlockId
        self.title = title
        self.createdAt = createdAt
    }
}

/// One saved conversation turn. `index` is the turn's position in the thread —
/// explicit ordering (createdAt alone can tie inside one Save's transaction).
@Model
final class ChatLine {
    @Attribute(.unique) var id: UUID
    var thread: ChatThread?
    /// `user` | `assistant` — the wire role, stored raw.
    var role: String
    var text: String
    var index: Int
    var createdAt: Date

    init(id: UUID = UUID(), role: String, text: String, index: Int, createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.text = text
        self.index = index
        self.createdAt = createdAt
    }
}
