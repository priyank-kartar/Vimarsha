# Vimarsha — Session Handoff

A resume-here note for the next agent. Read **`CLAUDE.md`** for architecture,
conventions, and the full gotcha list; this file is "where we are + what to do next."

_Last updated: 2026-06-12 (session 2, end) · `fix/import-crash-narration-stability-cluster`
merged to `main` + pushed._

## ⚠️ RESUME HERE (next session) — buy a RunPod instance, check narration speed live

The native client loop works end-to-end locally; the bottleneck is **narration speed on
MPS** (M4 is ~7–8× slower than realtime; a big chapter like Bohm ch01 = 64k chars takes a
long while). **Next session's goal: stand up the CUDA backend on RunPod and measure real
speed**, then decide on hardware (see `plan/08-engineering/runpod-cost-and-buy-trigger.md`).

**First steps next time:**
1. **Build + push the Docker image** (`cd backend && docker build -t <registry>/vimarsha-backend . && docker push …`) — the CUDA image is ready and already includes the model-cache + per-block `empty_cache` fixes. See `backend/docs/runpod.md`.
2. **Create a RunPod pod** from that image, expose port 8000.
3. **Point the client at it** — ⚠️ the Swift client **hardcodes `baseURL = http://localhost:8000`** in `apple/Vimarsha/Backend/BackendClient.swift`; there's NO settings UI yet. Either change that line or add a minimal backend-URL setting first (small task).
4. **Narrate a chapter on RunPod and capture: it/s, chapter-min/wall-min, $/chapter.** Use a SMALL chapter to iterate fast — Wholeness **INTRODUCTION (app idx 6, ~18k chars)**, or front-matter (idx 1/5, ~0.5k chars) for a smoke test. ch01 (idx 7) is one of the biggest.
5. Feed RunPod usage into the cost ledger; re-check the buy-trigger.
6. **Then** (own branch `feat/batched-narration`) prototype block batching in `narrate_bundle` — biggest single lever on $/chapter (~10×); safe plan = additive `synthesize_batch` seam + sequential fallback + TDD vs current output, real GPU batching gated off.

---

## Session 2 (2026-06-12) — what shipped (merged to `main`)

First end-to-end run of the `apple/` client against the real backend. Got the whole flow
working: **import a book → focus (tap) → Play → chapter list → download/narrate → reading
surface → Discuss**. Several real bugs found and fixed; **all merged to `main`** on branch
`fix/import-crash-narration-stability-cluster` (7 commits).

**Fixes this session (committed):**
1. **Import crash** — `VimarshaApp.init` kept only `container.mainContext` and let the
   `ModelContainer` deallocate; `mainContext`'s back-reference is WEAK, so the next
   `context.insert` trapped in SwiftData. Fixed by holding the container in a `static`.
   (Root-caused under lldb: `swift_weakLoadStrong → nil → brk`.)
2. **Backend memory** — `get_synth()` reloaded the model per request (now cached, like
   `get_transcriber`); and per-block MPS tensors weren't freed (now `empty_cache` per block
   in `ChatterboxSynth.synthesize`). These were the memory/disk balloon.
3. **Narration timeout** — client request timeout was 30 min; `/import` is silent for the
   whole narration, so long chapters tripped it → "Narration failed" even though the backend
   returned 200. Raised to 3 h (`BackendClient.narrationSession`).
4. **Tap-to-focus** — small libraries can't scroll a cover onto the 0.72 front slot, so the
   control cluster never emerged; tapping a cover now pins focus.
5. **Cluster redesign** — library cluster is now **Play · Voice notes · Saved discussions**
   (book-level archives across all chapters); Figures stays reading-surface-only (and only
   when the chapter has figures); live Discuss stays in the reading surface.

**Verified this session:** rebooted (cleared ~50 GB stale swap that had slowed TTS ~150×);
backend restarted with the fixes; a chapter began narrating at full speed with **flat
memory** (backend RSS ~0.3 GB, swap not climbing) — the memory fixes hold. Full app +
backend test suites green; macOS build clean. Merged to `main`.

**Carry-over notes (not blockers):**
- **Serialize chapter downloads** (one `/import` at a time) — recommended, NOT done. Concurrent
  imports narrate on one shared model and multiply memory (what blew up swap). Small client win.
- **Discuss needs Ollama:** `/chat` 500s with `:11434 404` until `ollama serve` +
  `ollama pull llama3.2:3b`. "No Reply" in the panel = Ollama not running.
- Freed ~33 GB of unrelated HF models earlier (kept only `chatterbox` + `faster-whisper`).
- Swift client backend URL is hardcoded (no settings UI) — see step 3 of RESUME HERE.

Everything below predates this session (Flutter-era plan notes); architecture/conventions in
`CLAUDE.md` and `apple/CLAUDE.md` are still current.

---

_Earlier handoff (2026-06-10):_

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

## NEW (2026-06-11): the planning knowledge base — start there

**`plan/`** is now the single source of truth for vision, decisions (ADRs), roadmap, and
the agent-runnable build items. **To do the next piece of work:** read
[`plan/README.md`](plan/README.md), then run the next V-item from
[`plan/08-engineering/build-roadmap.md`](plan/08-engineering/build-roadmap.md) (next up:
**Phase P1 — the living library**, V04–V09). Log evidence in
`plan/08-engineering/_progress-A.md`.

Context: the client is rebuilt **native Swift (SwiftUI), iOS 26 + macOS 26, Liquid Glass**
under `apple/` (UI bible: **`apple/CLAUDE.md`**; reference-video analysis:
`apple/docs/reference/`). The scaffold is live on `main` (P0 ✅ — depth-stack library with
static books, tests green both platforms). **The Flutter client is FROZEN** (ADR-007): it
stays green as the behavioral reference; all new feature work is Swift-only. Ambition is
**App Store product** (ADR-008) with a **hosted GPU narration service** in final scope
(ADR-009).

## Superseded: Plan 6b — the Discuss UI (now roadmap bucket P5, built natively)

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

- ~~**`get_synth()` reloads the Chatterbox model per `/import` request**~~ — **FIXED
  2026-06-12** (cached + per-block `empty_cache`; see the resume-here block at top).
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
