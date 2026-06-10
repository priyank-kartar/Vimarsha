# Data Model (client)

> **Status:** Draft · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). SwiftData schema + cache layout. Mirrors the
> proven Drift lineage from the frozen Flutter client (Books/Chapters → +Memos →
> +ChatThreads/ChatLines); exact attributes finalize in V12/P4/P5.

## SwiftData models (v1 slice — V12)

```
Book
  id (UUID) · title · author · epubPath (container-relative) · coverPath?
  addedAt · lastOpenedAt? · chapters → [Chapter]

Chapter
  id · book → Book · index (the backend chapter_index) · title
  status: none | pending | ready | error   · errorReason?
  bundlePath? · audioPath?                 (set when ready)
  progressMs · durationMs?                 (resume + scrubber)
```

Later (P4/P5, additive — mirrors Flutter schema v2/v3):

```
Memo        id · chapter · paragraphIndex · audioPath · transcript? ·
            status: pending|ready|error · createdAt
ChatThread  id · book · chapter · paragraphIndex · title · createdAt
ChatLine    id · thread · role: user|assistant · text · createdAt
```

## Cache layout (app container)

```
Library/Books/<bookId>/book.epub
Library/Books/<bookId>/cover.<ext>            (V11 extraction output)
Library/Books/<bookId>/chapters/<index>/bundle.json
Library/Books/<bookId>/chapters/<index>/chapter.mp3
Library/Books/<bookId>/chapters/<index>/images/<name>
```

Paths in SwiftData are container-relative (the container moves between
installs/devices); a missing file with `status == ready` self-heals to `none`.

## Rules

- **The bundle JSON is the source of truth for chapter content** (blocks, figureMap,
  paraTimings) — never decompose it into SwiftData rows; the DB holds *state about*
  chapters, not their content.
- **Migration policy:** additive when possible; any breaking change ships with a migration
  + a fabricated-old-store test (the Flutter repo's standard, kept).
- **Deletion:** removing a book removes its container subtree + cascade-deletes rows;
  memos/threads warn (user content).
- **No cloud sync in v1.** iCloud/CloudKit sync of progress/memos is a post-M5 question —
  add to open-questions when someone actually asks for it.
