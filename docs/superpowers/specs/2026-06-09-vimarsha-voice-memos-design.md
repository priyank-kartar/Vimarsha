# Vimarsha — Voice Memos (Plan 5 Design)

**Design spec — 2026-06-09**

The Record button: while reading/listening, capture a voice memo pinned to the
current paragraph, transcribe it to searchable text, and review all memos on a
Notes screen. The deep-dive AI conversation (talking back) is **Plan 6** and is
out of scope here.

This is **Plan 5**, split into:
- **Plan 5a** — data + backend: `/transcribe` endpoint, recorder seam, `Memos`
  table, `MemoRepository`, mic entitlements. No new screens.
- **Plan 5b** — UI: the Record button in the player + the Notes screen.

Depends on Plans 1–4b (all merged).

---

## 1. Scope

In scope:
- Record an audio memo from the player (narration pauses while recording).
- A memo = recorded **audio** + **transcript** + **pin** (book, chapter,
  paragraph block id, ms position).
- Transcription via a **backend Whisper endpoint** (`faster-whisper`); recording
  itself is on-device and works offline.
- A top-level **Notes screen**: list all memos (grouped by book), play a memo,
  jump to its pinned spot, retry a failed transcript, delete.

Out of scope: on-device transcription (deferred; backend does it for now), the
deep-dive AI conversation (Plan 6), editing transcript text, memo sync/export.

---

## 2. Backend (Plan 5a)

**`POST /transcribe`** — accepts a `multipart` audio upload, runs Whisper, returns
`{"text": "..."}`. Implemented with **`faster-whisper`** loaded once
(module-level, like the TTS synth is per-request — but a small model: default
`base`, configurable). Lives behind a `get_transcriber()` dependency so tests
inject a fake (no model download / GPU in CI). Added to the `[tts]` optional
extra. Decodes the uploaded clip via the bundled ffmpeg.

The endpoint is stateless and independent of `/import`; it does not touch the
audio dir.

---

## 3. Client data layer (Plan 5a)

- **`RecorderHandler` interface** (the mic seam, mirrors `AudioHandler`):
  `Future<void> start(String filePath)`, `Future<String?> stop()`,
  `bool get isRecording`, `Future<void> dispose()`. Real impl
  `RecordRecorderHandler` wraps the `record` package (records AAC/m4a to a file);
  a `FakeRecorderHandler` drives tests.
- **`BackendClient.transcribe(File audio) → String`** (+ `FakeBackendClient`
  support, with a `throwOnTranscribe` hook).
- **`FileStore`**: `memoFile(memoId)` → `memos/<memoId>.m4a` (a flat per-book or
  global memos dir under the store root).
- **Drift `Memos` table**: `id` (uuid, pk), `bookId`, `chapterIndex`, `blockId`
  (nullable), `positionMs`, `audioPath`, `transcript` (nullable),
  `transcriptStatus` (`pending|done|error`, default `pending`), `createdAt`.
- **`MemoRepository`**:
  - `saveMemo({bookId, chapterIndex, blockId, positionMs, recordedFile}) →
    Future<String>`: move the recorded file into the memos dir, insert the row
    (`pending`), then attempt transcription (`_backend.transcribe`) and update
    `transcript`+`done`; on backend failure set `error` (memo + audio kept).
    Returns the memo id.
  - `retryTranscription(memoId)`: re-attempt for an `error`/`pending` memo.
  - `watchMemos()` (all, newest first), `watchMemosForBook(bookId)`.
  - `deleteMemo(memoId)`: remove row + audio file.
- **macOS entitlements**: add `com.apple.security.device.audio-input` to both
  Debug/Release entitlements, and `NSMicrophoneUsageDescription` to the macOS
  `Info.plist`.

---

## 4. UI (Plan 5b)

- **Record button** in the player chrome (the red ● from the original mockup) —
  **hold-to-record**:
  - **Press and hold** to start: narration **stops** first
    (`PlayerController.pause`), then recording begins (`RecorderHandler.start` to a
    temp path). Because playback is stopped, the reading view **freezes** — the
    paragraph highlight and auto-scroll do not move while recording (position
    isn't advancing). A recording indicator + elapsed timer shows while held.
  - **Release** to stop & save: `stop()` → if a valid clip, `MemoRepository.saveMemo(...)`
    with the current `bookId`/`index`/`currentBlockId`/`position.inMilliseconds`;
    a brief "saved · transcribing…" confirmation. (Implemented via a gesture's
    press-down → start, release/cancel → stop.)
  - On release, **playback auto-resumes** (`PlayerController.play`) so the reader
    picks up where they paused — but only if it was playing before recording
    started (don't start playback if the reader had it paused). A very
    short/empty recording is discarded.
- **Notes screen** (top-level; a notes icon in the Library app bar opens it):
  - `watchMemos()` stream, grouped by book (and chapter). Each memo row shows the
    transcript (or "Transcribing…" / "Transcription failed · Retry"), a **play**
    control (plays the memo audio), and an **"open at pin"** action →
    `context.push('/player/$bookId/$chapterIndex')` then seek to `positionMs`.
  - Delete via swipe/long-press.

---

## 5. Architecture & boundaries

- Two new seams behind interfaces: `RecorderHandler` (mic) and the existing
  `BackendClient` gains `transcribe`. Everything else (repo logic, storage) is
  real in tests.
- `MemoRepository` is the single place the record→store→transcribe flow lives;
  the player and Notes screen are consumers. Recording capture (start/stop) is a
  thin handler; orchestration is the repository.
- Memo audio playback on the Notes screen reuses the `AudioHandler` seam (a
  separate handler instance or a lightweight play call) — no new audio stack.

---

## 6. Error handling

- **Mic permission denied / unavailable:** surface a clear message; no recording,
  no crash.
- **Backend unreachable during transcribe:** memo + audio saved; status `error`
  (or `pending`); transcript shows a Retry affordance. Recording never depends on
  the backend.
- **Empty/too-short clip:** discarded, no row created.
- **`open at pin` for a chapter not downloaded:** the player shows its existing
  "no audio / download again" state (Plan 3c/4b behavior); the pin still resolves
  once downloaded.
- **Deleted/missing memo audio:** play is disabled; transcript still shown.

---

## 7. Testing

- **Backend (pytest):** `/transcribe` returns the fake transcriber's text for an
  uploaded clip (model mocked via `get_transcriber` override; no GPU/model in CI);
  rejects a missing file.
- **Client unit (5a):** `MemoRepository.saveMemo` caches audio + inserts a row +
  fills transcript via a fake `BackendClient`; backend-failure path keeps the memo
  with status `error`; `retryTranscription` updates it; `watchMemos*` stream
  ordering; `deleteMemo` removes row + file. Uses fake `RecorderHandler` + fake
  `BackendClient` + in-memory Drift + temp `FileStore`.
- **Client widget (5b):** holding the Record button starts recording and pauses
  playback; releasing stops and calls `saveMemo` (fake recorder returns a temp
  file); Notes screen lists memos
  from a controlled stream, "open at pin" navigates + seeks, Retry calls the repo.
  (Stream-provider overrides avoid the drift-watch fake-async hang; in-memory
  loadBundle pattern where a real controller is needed.)
- **Manual gate:** on macOS, grant mic permission, record a memo while reading,
  confirm it's pinned, transcribed (backend up), replayable, and that "open at
  pin" returns to the right spot.

---

## 8. Build order

**Plan 5a:** (1) backend `/transcribe` + fake transcriber seam; (2) `RecorderHandler`
interface + `RecordRecorderHandler` + fake; (3) `BackendClient.transcribe` +
`FileStore.memoFile` + mic entitlements; (4) `Memos` table + `MemoRepository`
(save/transcribe/retry/watch/delete).

**Plan 5b:** (5) Record button + recording state in the player; (6) Notes screen
(list, play, open-at-pin, retry, delete) + library entry point; (7) manual macOS
verification.
