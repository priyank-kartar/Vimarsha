# Vimarsha — Flutter Client Core (Phase 3 Design)

**Design spec — 2026-06-05**

The client core: a Flutter app that imports an EPUB through the backend, lists a
library, shows a per-book chapter index with download badges, downloads a
chapter's narrated bundle + audio lazily, and plays it with full transport
(play/pause, seek, speed, resume). Figure overlay, voice memos, and the
deep-dive conversation are later phases (Plans 4–6) and are out of scope here.

This is **Plan 3** of the Vimarsha decomposition. It depends on the backend
(Plans 1–2) and the shared bundle contract (`shared/bundle.schema.json`,
`shared/fixtures/sample-chapter.bundle.json`).

---

## 1. Scope (Phase 3)

In scope:
- Flutter app targeting **macOS desktop** for dev (code kept portable for a
  future phone client).
- **Add book**: pick an EPUB, fetch its table of contents from the backend,
  store it in the library with **title + author**.
- **Library screen**: list books (title + author), add a book.
- **Book screen**: chapter index with per-chapter **download badges**
  (`none → downloading → ready → error`).
- **Lazy chapter download**: re-upload the stored EPUB with a `chapter_index`,
  receive the narrated bundle + audio, cache both locally.
- **Player**: single-file playback via `just_audio` — play/pause, scrub seek,
  speed (0.75×–2×), and **resume** from the last position.
- Two small **backend additions**: a book-metadata extractor and a `POST /toc`
  endpoint.
- A **Dockerfile + RunPod run notes** for the backend so a real CUDA box is a
  documented path; local MPS is the default.

Out of scope (later plans): figure overlay/sync (Plan 4), voice memos + STT
(Plan 5), deep-dive conversation + LLM (Plan 6), MOBI/PDF.

---

## 2. Architecture

Feature-first Flutter app, **Riverpod** for state/DI. Every genuinely external
dependency sits behind an interface so the app's logic is tested without
hardware or network.

### 2.1 Project structure (`/app`)

```
lib/
  app.dart                          # MaterialApp + go_router
  core/
    models/                         # freezed mirrors of the shared contract
      block.dart, figure.dart, chapter_bundle.dart, chapter_summary.dart, book_meta.dart
    backend/
      backend_client.dart           # interface: toc(), importChapter(), audioUrl()
      dio_backend_client.dart       # real Dio implementation
    audio/
      audio_handler.dart            # interface over just_audio (play/pause/seek/speed/position$/duration)
      just_audio_handler.dart       # real implementation
    db/database.dart                # Drift: Books, Chapters tables
    storage/file_store.dart         # app-docs paths: epub / bundle.json / audio.mp3
    settings/settings.dart          # backend base URL (default http://localhost:8000)
  features/
    library/                        # library_repository, providers, screen, add_book_flow
    book/                           # chapter_repository, providers, screen
    player/                         # player_controller, providers, screen
```

### 2.2 Interface seams (the only two test doubles)

- **`BackendClient`** — wraps the network. Real impl `DioBackendClient`. Tested
  via a Dio mock HTTP adapter; a fake impl is injected into repository tests.
- **`AudioHandler`** — wraps `just_audio` (the audio device). Real impl
  `JustAudioHandler`. A fake impl drives player-controller tests.

Everything else in tests uses real code: real Drift (in-memory), real
`FileStore` (temp dir), real freezed models, real JSON parsing. There are no
other fakes and no runtime stubs.

### 2.3 Persistence

- **Files** (`FileStore`, under app documents dir): the original `book.epub`,
  each chapter's `bundle.json`, and `audio.mp3`.
- **Drift (SQLite)** metadata:
  - `Books`: `id` (uuid), `title`, `author`, `epubPath`, `createdAt`
  - `Chapters`: `bookId`, `index`, `chapterId`, `title`,
    `downloadStatus` (`none|downloading|ready|error`), `bundlePath`,
    `audioPath`, `durationMs`, `positionMs`

---

## 3. Backend additions (Python, TDD in the existing pytest suite)

1. **Book metadata extractor** — read `dc:title` and `dc:creator` from the OPF,
   returning `{title, author}` (author may be empty). Lives in `epub_reader` (or
   a small `metadata.py`).
2. **`POST /toc`** — accept an EPUB upload; run the cheap, no-audio `ingest_epub`
   over all chapters; return:
   ```json
   {
     "book": {"title": "...", "author": "..."},
     "chapters": [{"index": 0, "chapterId": "chap1", "title": "The Engine"}]
   }
   ```
   No narration, so it is fast and GPU-free.

`POST /import` and `GET /audio/{name}` are unchanged from Plan 2. The backend
stays stateless; the client re-uploads the EPUB per chapter download.

---

## 4. Data flow

**Add book**
1. `file_picker` selects a `.epub`.
2. Copy it into the file store (`books/<bookId>/book.epub`).
3. `POST /toc` → book `{title, author}` + chapter list.
4. Insert one `Books` row and N `Chapters` rows (status `none`).

**Open book** — render the chapter index from `Chapters`; each row's badge
reflects `downloadStatus`.

**Download a chapter (lazy)**
1. Set the chapter row to `downloading`.
2. `POST /import` with the stored EPUB + `chapter_index`.
3. Save the returned bundle JSON to `bundle.json`.
4. `GET /audio/{bundle.audio}` → save `audio.mp3`.
5. Update the row: `bundlePath`, `audioPath`, `durationMs`, status `ready`.
6. On any failure: status `error`, surfaced in the badge with a retry affordance.

**Play a chapter**
1. Load `audioPath` into the `AudioHandler`.
2. Restore `positionMs` from the row.
3. Transport: play/pause, scrub (seek), speed 0.75×–2×.
4. Persist `positionMs` periodically (e.g. every few seconds) and on pause/leave,
   so resume works across sessions.

---

## 5. Error handling

- **Backend unreachable / 5xx during `/toc`**: surface a clear "couldn't reach
  backend" message; the book is not added (no half-state).
- **Download failure** (`/import` or `/audio`): chapter row → `error`, badge
  shows retry; partial files are cleaned up so a retry is clean.
- **Corrupt/oversized EPUB**: backend returns an error; client shows it without
  crashing.
- **Audio load failure**: player shows an error state; the cached files can be
  re-downloaded.
- **Schema drift** (a bundle field the client can't parse): model parsing fails
  loudly in dev; the model tests against the shared fixture guard against this.

---

## 6. Testing strategy

- **Models** (`test/core/models/`): parse `shared/fixtures/sample-chapter.bundle.json`
  → assert fields; freezed `toJson`/`fromJson` round-trip. Cross-language
  contract guard.
- **`DioBackendClient`**: Dio mock HTTP adapter → assert request shape (multipart
  upload, `chapter_index` query) and response parsing for `/toc`, `/import`,
  audio URL building.
- **Repositories** (`LibraryRepository`, `ChapterRepository`): real in-memory
  Drift + fake `BackendClient` + temp `FileStore` → add-book inserts rows,
  download flips status `none→downloading→ready`, error path → `error` + cleanup,
  progress persistence.
- **Player controller**: fake `AudioHandler` → play/pause/seek/speed, resume
  restore from `positionMs`, periodic + on-pause progress save.
- **Widgets**: library lists title+author; book screen renders correct badges
  per status; player buttons invoke the controller. `ProviderScope` overrides
  inject fakes.
- **Backend** (pytest): `/toc` returns book metadata (incl. author) + ordered
  chapters; metadata extractor reads `dc:title`/`dc:creator`; add an EPUB fixture
  with author metadata.
- **Integration (opt-in)**: a real Flutter↔backend run with **real Chatterbox**
  (local MPS by default, RunPod URL via settings) that imports a chapter and
  plays the produced audio. Not part of the fast unit suite.

---

## 7. Deployment note (RunPod)

A minimal `backend/Dockerfile` (Python 3.13 + ffmpeg + the `[tts]` extra) plus
`backend/docs/runpod.md` with run instructions. Local MPS remains the default
dev backend; RunPod is the documented real-CUDA option. The client targets
whichever via the configurable base URL.

---

## 8. Build order (high level)

1. Backend: metadata extractor + `/toc` (TDD).
2. Flutter scaffold (`app/`, macOS enabled) + freezed models + fixture tests.
3. `FileStore` + Drift `database` (in-memory tests).
4. `BackendClient` interface + `DioBackendClient` (mock-adapter tests).
5. `AudioHandler` interface + `JustAudioHandler`.
6. `LibraryRepository` + add-book flow + library screen.
7. `ChapterRepository` (lazy download + status) + book screen with badges.
8. `PlayerController` + player screen (transport, resume).
9. Backend `Dockerfile` + RunPod notes.
10. Opt-in integration test (real Chatterbox).
