# Vimarsha — Session Handoff

A resume-here note for the next agent. Read **`CLAUDE.md`** for architecture,
conventions, and the full gotcha list; this file is "where we are + what to do next."

_Last updated: 2026-06-10 · `main` @ commit `ab66218` (local == GitHub remote)._

## What Vimarsha is

A talking EPUB reader (Flutter client + local Python/FastAPI GPU backend): narrates
books aloud, surfaces the right figure/diagram/quote on screen as it's discussed,
lets you record voice notes, and (in progress) discuss the passage with a local LLM.
Repo: private **`kartar-sachmeet/Vimarsha`** (push with the `kartar-sachmeet` gh
account — `gh auth switch --user kartar-sachmeet`).

## Status (all merged to `main` + pushed, each reviewed + mostly verified live)

| Plan | What | State |
|---|---|---|
| 1–2 | Backend: EPUB ingest → figures/spans; Chatterbox narration (`/import`, `/audio`) | ✅ |
| 3a–3c | Client core: library, lazy chapter download, player (seek/speed/resume) | ✅ live |
| 4a–4b | Reading view (highlight + auto-scroll + tap-seek), synced figure overlay, Figures gallery, player chrome | ✅ live |
| 5a–5b | Voice memos: hold-to-record → backend Whisper transcript → Notes screen | ✅ live |
| 6a | Deep-dive **data layer**: `LlmClient`/Ollama + `/chat` + `/speak`; `ChatRepository`, `ChatController` | ✅ |

Tests on `main`: ~55 backend (pytest), ~85 app (flutter test), `flutter analyze` clean.

## Do next: Plan 6b — the Discuss UI

- **Spec:** `docs/superpowers/specs/2026-06-10-vimarsha-deep-dive-conversation-design.md`
  (read §4 UI + the pause-on-audio-conflict note).
- **Not yet written:** Plan 6b's implementation plan. Start by running
  `superpowers:writing-plans` against the spec's §8 "Plan 6b" build order:
  1. Record button **dual gesture** — switch hold-to-record to
     `onLongPressStart/onLongPressEnd` so it coexists with **`onDoubleTap` → open
     the Discuss panel** (double-tap must NOT pause playback).
  2. **Discuss panel** — keyboard-default `TextField` + Send, secondary
     hold-to-talk mic (→ `/transcribe`), assistant replies text-first with a
     **speaker** button (→ `/speak`, played on `memoAudioHandlerProvider`), and a
     **Save** button (→ `ChatRepository.saveThread`). Built on `ChatController`
     (already exists) constructed with a live `ChatContext` snapshot from the player.
  3. **Conversations screen** — top-level (library app-bar icon next to Notes);
     lists saved threads (`watchThreads`), reopen read-only (`watchMessages`), delete.
  4. **Pause-on-audio-conflict (client-side):** while a reply is being spoken OR
     the user is voice-typing, pause the chapter (`PlayerController`) and resume if
     it was playing. (Opening the panel itself does not pause.)
- The data layer it builds on is done: `ChatController`, `ChatRepository`,
  `BackendClient.chat/speak`, `chatRepositoryProvider`, `memoAudioHandlerProvider`.

## Then: Plan 7 — figure-mention LLM fallback

Reuse the `LlmClient` seam at **import time** to resolve fuzzy figure references the
rule-based `mention_detector` misses ("the chart below", unlabeled images),
improving auto-pop accuracy. The spec's "reliability stance" treats current
auto-pop as best-effort; this is where it improves. Own spec → plan → implement.

## How we work here (follow this)

`brainstorm → spec (docs/superpowers/specs) → plan (docs/superpowers/plans) →
subagent-driven implementation`. Per plan: branch off `main`; dispatch ONE
implementer subagent for the plan's tasks (TDD, commit per task); then **verify
the suites yourself** and dispatch an **opus code-quality review** subagent on the
diff; loop fixes; `git merge --no-ff` to `main`; push. The reviews have caught real
bugs every plan — keep them. Plans are split into small mergeable chunks (Na/Nb).
Minimize test doubles (only the network + audio/mic + LLM seams); use the **real**
Chatterbox/Whisper/Ollama for integration, not stubs.

## Running it

```bash
# Backend (real models): first run downloads Chatterbox + faster-whisper
cd backend && uv sync --extra tts && uv run uvicorn vimarsha.server:app --port 8000
# For Plan 6 conversation, also:  ollama serve   &&   ollama pull llama3.2:3b
# App (macOS):
cd app && flutter run -d macos      # or: open build/macos/Build/Products/Debug/vimarsha.app
# Tests:
cd backend && uv run pytest                         # ~55, no GPU (fakes)
cd app && flutter analyze && flutter test           # ~85
cd app && flutter test test_integration/real_backend_test.dart  # opt-in, real Chatterbox
```

## Known issues / deferred improvements (good follow-ups)

- **`get_synth()` reloads the Chatterbox model per `/import` request** — the main
  cause of memory ballooning + latency. Caching it (like `get_transcriber`/`get_llm`)
  is a cheap, high-value win.
- **Local narration is heavy on this Mac:** MPS synthesis ~7–8× slower than realtime;
  a full chapter is many minutes and large temp files. `backend/Dockerfile` +
  `backend/docs/runpod.md` exist for offloading heavy synth to a RunPod CUDA box.
- **Disk pressure is real** — narrating full books filled the disk once and crashed
  the backend. Watch `~/.cache/huggingface` and orphaned `hub/tmp*` download fragments.
- **Memo playback** has no stop control and only `error` (not `pending`) memos show
  Retry — minor v1 gaps noted in the Plan 5 review.
- **Figure auto-pop timing is heuristic** (rules only until Plan 7); the Figures
  gallery is the reliable way to reach any figure.

## Pointers

- Architecture, conventions, full gotchas: **`CLAUDE.md`**.
- The original full vision: `docs/superpowers/specs/2026-06-03-vimarsha-ebook-reader-design.md`.
- Persistent agent memory for this project also lives in the Claude Code memory dir
  (`vimarsha-phasing`, `vimarsha-testing-preferences`, `vimarsha-github`).
