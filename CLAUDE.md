# Vimarsha — Agent Guide

Onboarding for the next coding agent. Read this first, then the spec in
`docs/superpowers/specs/` for full detail.

## What this is

Vimarsha is a **talking EPUB reader**: it narrates books aloud, intelligently
surfaces the right figure/diagram/quote on screen at the moment it's discussed,
and lets the reader record voice notes (and optionally hold a spoken AI
conversation) about the passage. Flutter client + local GPU Python backend.

## Repo layout

```
backend/        Python 3.13 FastAPI service (EPUB parsing, figure detection, Chatterbox TTS)
  src/vimarsha/ models.py epub_reader.py block_parser.py figure_registry.py
                mention_detector.py ingest.py tts.py stitch.py audio_io.py
                narrate.py metadata.py server.py
  tests/        pytest (TDD); tests/fakes.py = FakeSynth; conftest.py builds a fixture EPUB
  Dockerfile    CUDA image for RunPod; docs/runpod.md for run instructions
app/            Flutter app (macOS dev target; portable for a future phone client)
  lib/core/     models/ (freezed) backend/ audio/ db/ (drift) storage/ settings/ providers.dart
  lib/features/ library/ book/ player/  (each: repository + screen [+ controller])
  test/         widget + unit tests; test/support/ = fakes
  test_integration/  opt-in real-Chatterbox test (NOT run by `flutter test`)
shared/         bundle.schema.json (cross-language contract) + fixtures/ (sample.bundle.json, sample.epub)
docs/superpowers/  specs/ (designs) and plans/ (TDD implementation plans)
```

## Architecture (the essentials)

Two tiers; the client is offline-capable once a chapter is cached, the backend
is stateless and touched only at **import** and (later) **conversation**.

- **Ingestion (backend):** EPUB → ordered typed `Block`s → `Figure` registry →
  rule-based mention detection that widens each figure's paragraph **span**.
- **Narration (backend):** Chatterbox TTS synthesizes each narratable block,
  stitched into ONE `chapter.mp3`; paragraph→ms timings are recorded during
  concatenation (no forced alignment). Figure spans are converted paragraph→ms.
- **The contract:** `ChapterBundle` (see `backend/src/vimarsha/models.py` and
  `shared/bundle.schema.json`) — `{chapterId, title, blocks[], figureMap[]
  (with startMs/endMs), audio, paraTimings}`. The Flutter freezed models in
  `app/lib/core/models/` mirror it exactly (camelCase keys, no `@JsonKey`).
- **Client:** Riverpod + `just_audio` + Drift (SQLite). `LibraryRepository`
  (add book via `/toc`), `ChapterRepository` (lazy per-chapter download +
  status + progress), `PlayerController` (load/resume/transport, throttled
  progress save). Backend reached via `DioBackendClient`.
- **Backend stays stateless:** the client keeps the original EPUB and
  re-uploads it with a `chapter_index` to download each chapter on demand.

Endpoints: `POST /toc` (book meta + chapters, no audio, fast), `POST /import?chapter_index=N`
(narrate one chapter → full bundle), `GET /audio/{name}` (MP3 bytes).

## How to run

**Backend (real Chatterbox, Apple Silicon / MPS):**
```bash
cd backend
uv sync --extra tts          # first time: downloads Chatterbox model (~GBs, minutes)
uv run uvicorn vimarsha.server:app --port 8000
```
**App (macOS):** with the backend running,
```bash
cd app
flutter run -d macos         # or: open build/macos/Build/Products/Debug/vimarsha.app
```
Default backend URL is `http://localhost:8000` (`AppSettings`); repoint for LAN/RunPod.

**Tests:**
```bash
cd backend && uv run pytest          # ~46 tests, fast, no GPU (FakeSynth)
cd app && flutter analyze && flutter test   # ~41 tests; analyze must be clean
# Opt-in real pipeline (needs backend up with real Chatterbox):
cd app && flutter test test_integration/real_backend_test.dart
```

## Conventions

- **TDD always** (write failing test → minimal impl → green → commit). Frequent,
  small commits with the trailer `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **Workflow:** brainstorm → spec (`docs/superpowers/specs/`) → plan
  (`docs/superpowers/plans/`) → subagent-driven implementation with a two-stage
  (spec + code-quality) review gate. Plans are split into small, independently
  mergeable chunks; each lands on `main` via a `--no-ff` merge from a feature branch.
- **Test doubles are minimal and permanent test-only code** — exactly two seams:
  `BackendClient` (network) and `AudioHandler` (audio device). Everything else in
  tests uses real code (real in-memory Drift, real temp FileStore, real parsing).
  Do NOT add runtime stub modes to dodge real dependencies; use the **real**
  Chatterbox (local MPS is fine; a RunPod CUDA box is the option for heavy/CI runs).
- **Flutter codegen:** freezed v3 (`abstract class X with _$X`) + json_serializable
  + drift via `dart run build_runner build --delete-conflicting-outputs`. Generated
  `.freezed.dart`/`.g.dart`/`database.g.dart` are committed.

## Gotchas already hit (don't relearn these)

- **`setuptools<81` is pinned in the `[tts]` extra.** `chatterbox-tts → perth`
  needs the legacy `pkg_resources`, which setuptools 81+ removed; without the pin,
  every synth crashes with `'NoneType' object is not callable` on `PerthImplicitWatermarker`.
- **`freezed` is pinned to stable `3.2.5`** (not a `-dev` prerelease that `pub add` may grab).
- **drift `.watch()` does NOT emit under flutter_test's fake-async clock** — widget
  tests on screens hang on the loading spinner ("Timer still pending"). Test screens
  by **overriding the StreamProviders** (`booksStreamProvider`/`chaptersStreamProvider`)
  with `Stream.value(...)`, not by seeding drift. (One-shot `getSingleOrNull` is fine.)
- **`PlayerController.dispose()` must NOT dispose the shared `AudioHandler`** — it's a
  plain (app-lifetime) provider; the controller pauses instead. Disposing it broke the
  2nd playback. Stream listeners are guarded by `_disposed` to avoid post-dispose notify.
- **macOS sandbox:** the app needs `com.apple.security.network.client` and
  `com.apple.security.files.user-selected.read-only` entitlements (added to both
  Debug/Release) or it can't reach the backend or pick an EPUB.
- **`narrate_bundle` raises** for chapters with no narratable text (e.g. part-divider
  pages) so the client marks them `error` instead of caching an unplayable ~236-byte MP3.
- **Performance:** MPS synthesis is ~7–8× slower than real-time (a full ~20k-char chapter
  is many minutes). `get_synth()` currently reloads the model per `/import` request — a
  known inefficiency (and the reason memory balloons); caching the model is a good early win.

## Status & what's next

Done and merged to `main` (each verified + code-reviewed):
- **Plans 1–2** — backend ingestion + Chatterbox narration.
- **Plans 3a–3c** — full client core (library, lazy chapter download, player). Verified live.
- **Plans 4a–4b** — reading view (highlight + auto-scroll + tap-to-seek), figure
  overlay (synced floating card, stacked), Figures gallery, player chrome. Verified live.
- **Plans 5a–5b** — voice memos: hold-to-record → backend Whisper transcript → Notes
  screen (play / open-at-pin / retry / delete). Verified live.
- **Plan 6a** — deep-dive conversation **data layer**: `LlmClient` seam + `OllamaLlmClient`,
  `POST /chat` (grounded prompt) + `POST /speak` (Chatterbox TTS of text); client
  `ChatMessage`/`ChatContext`, `ChatThreads`/`ChatLines` (+ migration), `ChatRepository`
  (save-on-demand), `ChatController` (in-memory live chat).

Test counts on `main`: ~55 backend, ~85 app, `flutter analyze` clean.

Remaining (each its own spec → plan → implement cycle):
- **Plan 6b — Discuss UI (NEXT):** record-button dual gesture (long-press = memo,
  double-tap = open Discuss **without pausing playback**), the Discuss panel
  (keyboard-default input + hold-to-talk, text replies + speaker, **Save**), and the
  Conversations screen. Pause chapter audio (client-side) while a reply is spoken or
  the user voice-types. Needs **Ollama** for live testing (`ollama serve` +
  `ollama pull llama3.2:3b`).
- **Plan 7 — figure-mention LLM fallback:** reuse the `LlmClient` seam at import to
  resolve fuzzy figure references the rules miss (improves auto-pop accuracy).

Specs live in `docs/superpowers/specs/` (one per plan, dated); the matching
implementation plans are in `docs/superpowers/plans/`.

### Runtime gotchas worth knowing (beyond the build gotchas above)
- The backend needs **`uv sync --extra tts`** to pull `faster-whisper` + `chatterbox` +
  `setuptools<81`; a plain run 500s on `/transcribe`/`/import`/`/speak`.
- **Ollama** (Plan 6) is a separate process the user runs — not bundled.
- Drift is at **schemaVersion 3** (Books/Chapters → +Memos@2 → +ChatThreads/ChatLines@3),
  migrations tested by fabricating old DBs via the `sqlite3` package.
- Riverpod 3.x: **never use `ref` in `ConsumerState.dispose()`** — capture the object earlier.
- Widget tests can't drive drift `.watch()` or real `dart:io` under the fake clock —
  override stream providers with `Stream.value`, or use in-memory repo fakes.
