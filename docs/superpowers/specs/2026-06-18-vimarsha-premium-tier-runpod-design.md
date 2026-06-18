# Vimarsha — Premium Narration Tier (Chatterbox on RunPod serverless)

_Dated 2026-06-18. Backend (`backend/`) + native Swift client (`apple/`) + a new RunPod serverless worker._

## Goal

A **premium narration tier**: free narrates with local **Kokoro** (already wired); premium narrates
with **Chatterbox on RunPod serverless** ("flash"). Selected by picking a **premium voice** in the
catalog. Builds on the async job seam already merged (`/import` enqueues `_run_import_job` on a
thread → client polls `/import/status/{id}`).

## Decisions (locked in brainstorming)

| Question | Decision |
|---|---|
| Tier selection | A **premium voice** in the catalog (`engine=chatterbox` → routed remote; `engine=kokoro` → local). Reuses `?engine=`/`?voice=` + the Narrator picker. |
| The "few" premium voices | **Expressiveness presets** of Chatterbox's base voice (no audio assets, no cloning). |
| Worker scope | The worker runs the **full `narrate_bundle` pipeline** and returns bundle JSON + mp3 (+ figure images). |
| RunPod call style | Async **`/run` + poll `/status`**, nested inside our job seam (client polls us, we poll RunPod). |
| First slice | **Full vertical incl. a live RunPod serverless endpoint** + a real premium narration. |
| Billing/gating | **Deferred.** Premium voices are marked "Premium" but freely selectable; an entitlement check is a later flag. |
| `/speak` (Discuss replies) | **Out of scope** for this slice — replies stay on local Kokoro. |

## Architecture & data flow

The client's behavior is **unchanged**: it submits `/import?engine=chatterbox&voice=cb_storyteller`
and polls `/import/status/{id}`. Routing is **server-side**.

```
client ──POST /import (epub, engine=chatterbox, voice=cb_storyteller)──▶ backend
backend: create job(pending) → thread _run_import_job
   engine ∈ REMOTE_ENGINES?  ──no──▶ local synth pipeline (today's _do_import)
                              ──yes─▶ RemoteNarrator:
                                        POST  https://api.runpod.ai/v2/{endpoint}/run  {input:{epub_b64,chapter_index,voice}}
                                        poll  GET .../status/{rpJobId}  until COMPLETED|FAILED
                                        decode output → write mp3 + images to audio_dir → return bundle dict
backend: job → ready(bundle)
client poll /import/status/{id} ──▶ ready → bundle  (then GET /audio, /image as usual)
```

## Components

### 1. `ChatterboxSynth` expressiveness presets (`backend/src/vimarsha/tts.py`)
- A pure `chatterbox_preset(voice: str) -> dict` mapping a voice token → `generate` kwargs:
  - `cb_storyteller` → `{"exaggeration": 0.7, "cfg_weight": 0.3}` (dramatic)
  - `cb_steady` → `{"exaggeration": 0.35, "cfg_weight": 0.5}` (calm/neutral)
  - `cb_intimate` → `{"exaggeration": 0.5, "cfg_weight": 0.4}` (warm/measured)
  - unknown/blank → `{}` (Chatterbox defaults)
- `ChatterboxSynth.__init__` stores the resolved preset from its `voice`; `synthesize` passes those
  kwargs to `self._model.generate(text, **kwargs)`. (Values are starting points; tune later.)
- Generation runs **only on the worker** (GPU). The preset map is unit-tested locally (pure).

### 2. RunPod REST client + RemoteNarrator seam (`backend/src/vimarsha/runpod_client.py`)
- `RunPodClient(endpoint_id, api_key)`: `submit(input: dict) -> str` (POST `/v2/{id}/run`, returns
  RunPod job id), `poll(job_id) -> dict` (GET `/v2/{id}/status/{job}`), with `Authorization: Bearer`.
- `RemoteNarrator` protocol: `narrate(epub: bytes, chapter_index: int, engine: str, voice: str) ->
  RemoteResult` where `RemoteResult = {bundle: dict, audio: bytes, images: dict[str, bytes]}`.
  `RunPodNarrator` implements it over `RunPodClient` (base64 in/out, poll until terminal, raise on
  FAILED/timeout). A `FakeRemoteNarrator` (test-only) returns canned results — no network/GPU in
  unit tests.

### 3. Backend routing (`backend/src/vimarsha/server.py`)
- `REMOTE_ENGINES = {"chatterbox"}`. `_run_import_job` branches: remote engine → `RemoteNarrator`,
  write the returned mp3 + images into `app.state.audio_dir`, set job `ready` with the bundle;
  else the existing local `_do_import`.
- The `RemoteNarrator` is constructed from config (below); if a premium job arrives and the endpoint
  isn't configured, the job fails with a clear error ("premium narration not configured").
- The chapter range check + errors map to the job's `error` status exactly like the local path.

### 4. RunPod serverless worker (`backend/serverless/`)
- `rp_handler.py`: RunPod's `runpod.serverless.start({"handler": handler})`. `handler(event)` reads
  `event["input"] = {epub_b64, chapter_index, voice, engine}`, runs the **same import pipeline**
  (`read_chapters` → `ingest_epub` → `narrate_bundle` with `synth_class("chatterbox")(voice=voice)`
  → `extract_images`) into a temp dir, returns `{bundle, audio_b64, images: {name: b64}}`. Reuses
  the `vimarsha` package — the worker IS our pipeline with Chatterbox.
- `Dockerfile.serverless`: the existing CUDA + `[tts]` (Chatterbox) build, **plus** `runpod` SDK,
  with `CMD ["python", "-u", "serverless/rp_handler.py"]` instead of uvicorn.
- Unit-testable: `handler({"input": {...}})` with a `FakeSynth`-backed `synth_class` override →
  asserts output shape (bundle + non-empty audio_b64) with **no GPU**.

### 5. Live endpoint + config
- Build/push the serverless image; create a RunPod **serverless endpoint** (cost knobs: **1–2 max
  workers, idle timeout 5s, FlashBoot on, scale-to-zero, cheapest GPU that fits Chatterbox ~ a 16GB
  card** e.g. A4000/L4/4090). Capture the endpoint id.
- Backend config: `VIMARSHA_CHATTERBOX_ENDPOINT` (endpoint id) + `RUNPOD_API_KEY` (env, or read
  `~/.runpod/config.toml`). Secrets stay server-side — never sent to the client.
- Live verification: narrate a real chapter premium end-to-end through the app; record cold-start +
  warm latency and $/chapter into `plan/08-engineering/runpod-cost-and-buy-trigger.md`.

### 6. Client catalog (`apple/Vimarsha/Library/NarratorVoice.swift` + the picker)
- Generalize `NarratorVoice.kokoroVoice` → **`voiceToken`** (the `?voice=` value) and add
  `isPremium: Bool` (default false). Existing Kokoro entries: `engine="kokoro"`, `isPremium=false`.
- Add 3 premium entries: `engine="chatterbox"`, `isPremium=true`, tokens `cb_storyteller`/
  `cb_steady`/`cb_intimate`, names e.g. **Storyteller / Steady / Intimate**.
- `VoicePickerView` shows a small **"Premium"** badge on premium rows. No gating — selectable now.
- Routing is server-side, so `importChapter`/the async flow are **unchanged**. Preview clips: premium
  voices can reuse a bundled Chatterbox-rendered preview each (generated once like the Kokoro clips),
  or fall back to no preview in this slice — TBD-low, decided in the plan.

## Error handling

- RunPod FAILED / poll timeout / unreachable → our job `error` with a concise reason → the chapter
  row shows the error (existing path). Cold start adds latency (FlashBoot mitigates); the client's
  3-hour poll deadline covers it.
- Missing endpoint/key config → premium jobs fail fast with "premium narration not configured".

## Testing

- **Unit (no GPU/network):** `chatterbox_preset` map; `_run_import_job` routing (kokoro→local,
  chatterbox→`RemoteNarrator`) via `FakeRemoteNarrator`; the remote path writes audio+images and
  returns the bundle; `rp_handler` with a `FakeSynth`-backed synth (output shape); RunPod client
  request building (URL/headers/body) against a stub transport; client catalog integrity (premium
  flagged, `engine=chatterbox`, every voice has a token).
- **Live (step 4):** one real premium narration end-to-end; ledger entry.
- No new runtime stub modes; the RunPod client/RemoteNarrator is the one new seam (faked in units,
  real in the live step). Both suites + the macOS build stay green per chunk.

## Build order (for the plan)

1. **Presets** — `chatterbox_preset` + `ChatterboxSynth` wiring (+ pure test).
2. **Remote seam** — `runpod_client.py`, `RemoteNarrator`/`RunPodNarrator`/`FakeRemoteNarrator`,
   `_run_import_job` routing + config resolution (+ fake-remote tests).
3. **Worker** — `serverless/rp_handler.py` + `Dockerfile.serverless` (+ no-GPU handler test).
4. **Live** — build/push image, create endpoint, wire config, narrate a premium chapter, ledger.
5. **Client** — `voiceToken`/`isPremium` + 3 premium catalog entries + "Premium" badge (+ tests).

Each chunk lands on `main` via a `--no-ff` merge.

## Out of scope (explicit)

Billing/entitlement gating; premium `/speak` (Discuss replies); Chatterbox voice cloning; a settings
UI for the backend URL; multi-worker job-store durability (the in-process `_jobs` dict is unchanged).
