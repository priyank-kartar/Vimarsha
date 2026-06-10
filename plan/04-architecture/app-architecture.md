# App Architecture (Swift client)

> **Status:** Reviewed · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). The client's shape. The Flutter client
> (`app/lib/`) is the proven design to mirror — port the *design*, not the code.

## Layering

```
Views (states of one surface)          LibraryStackView · ReadingSurface · overlays…
  │  observe
Stores / Controllers (@Observable)     LibraryStore · PlayerController · ChatController…
  │  use
Repositories                           BookRepository · ChapterRepository · MemoRepository…
  │  use                                          │
Seams (protocols w/ test doubles)      BackendClient ── audio/mic engine
  │  real impls                                   │
URLSession · SwiftData · AVFoundation · FileManager (caches)
```

- **Exactly two client seams** get test doubles: `BackendClient` (network) and the
  audio/mic engine (AVFoundation). Everything else tests real (in-memory SwiftData, real
  temp files, real parsing) — the repo's standing test philosophy
  ([CLAUDE.md §Conventions](../../CLAUDE.md)).
- Stores are `@Observable`, owned per-surface-state; the **audio engine is app-lifetime** —
  controllers pause it, never dispose it (hard-won Flutter lesson, see root CLAUDE.md
  gotchas).

## Data & caching

- **SwiftData**: Books, Chapters (status + progress), later Memos/ChatThreads/ChatLines
  ([data-model](data-model.md)).
- **File cache** in the app container: per-chapter `bundle.json` + `chapter.mp3`
  (+ figure images via `GET /image/{name}`); the EPUB itself is copied in at import
  (security-scoped origin released after copy).
- **Chapter lifecycle:** `none → pending (job running) → ready (cached) → error (retryable)`
  — mirrors the Flutter `ChapterRepository` design; survives relaunch; offline = ready
  chapters only.

## Concurrency model

MainActor-default isolation (project setting); repositories/services that do IO are
`nonisolated` with async APIs; the narration "job" (upload → poll/await → cache) is a
cancellable `Task` owned by the store so leaving the screen doesn't orphan downloads.

## Figure & timing flow (consume-side)

`paraTimings` drive: live-paragraph computation (current ms → paragraph index), auto-scroll
targets, tap-to-seek (paragraph → ms), and figure span activation (`startMs/endMs` windows →
overlay state). One `TimingIndex` utility owns all four lookups — never four parallel
implementations (V18 builds it with tests).

## Error posture

Honest states over silent retries: narration failures mark the chapter `error` with a
user-facing reason (the backend already raises for un-narratable chapters rather than
caching junk); network errors surface as status, not alerts, on the one surface.
