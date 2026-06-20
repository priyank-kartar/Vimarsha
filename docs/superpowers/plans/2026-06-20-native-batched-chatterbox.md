# Native batched Chatterbox narration (the real ~Nx speedup) — Plan

> **Status:** PLANNED, not started (2026-06-20). Build when ready. Supersedes the abandoned
> vLLM-port batching (which mangled audio). Uses the OFFICIAL `chatterbox-tts` batch generate
> (PR #204): `model.generate(text=[list], ...)` → one waveform per text in a single forward pass.

**Goal:** Narrate a chapter's chunks in batches through the real Chatterbox model on the A40
worker, cutting GPU time ~Nx, with audio quality identical to the current sequential path.

**Why this is safe now (vs the vLLM disaster):** the vLLM port batched inside a re-implemented
decoder and produced garbled/padded audio. PR #204 batches the *official* model we already run
(and trust). Each text is still its own clean utterance — but the gate below proves it before we
ship.

## What already exists (reuse, don't rebuild)
- `BatchSynthesizer` protocol — `synthesize_batch(texts) -> [np.ndarray]` (`tts.py`).
- `narrate_bundle_batched(bundle, synth, out_dir, para_gap_ms, max_batch)` — flattens every
  narratable block into chunks, batches in slices of `max_batch`, regroups per block, and stitches
  via the shared `_finalize` → identical `paraTimings` + figure ms as the sequential path
  (`narrate.py`). Parity test already in `tests/test_narrate_batched.py`.
- `FakeBatchSynth` test double + `tests/test_batch_synth.py`.
- Dead code to delete: `VllmChatterboxSynth` (`tts.py:130`).

So the only genuinely new piece is **one `BatchSynthesizer` implementation**.

## Phase 0 — VALIDATE (the gate; do this first, on the A40)
The whole plan dies here if batched audio isn't clean. Do not wire anything until this passes.
1. Confirm the installed `chatterbox-tts` actually has PR #204 batch generate (current pin is
   **0.1.3** — verify `model.generate(text=[...])` returns a list; bump the version if not).
2. On the A40 worker (one-off script): take ~8 real chapter chunks. Generate them (a) one-by-one
   (current path) and (b) as a single batched `generate(text=[chunks], exaggeration=…,
   cfg_weight=…)`. For each chunk compare batched vs sequential: listen to several, and check
   numeric closeness (length within a few ms; correlation / RMS error small). Mixed batch lengths
   must not bleed (the #1 batching failure mode — short clips padded/repeated).
3. Record max batch size that fits A40 VRAM (48GB) without OOM, and the it/s vs sequential.
   **Gate:** audio indistinguishable from sequential AND a real speedup → proceed. Else stop.

## Phase 1 — `ChatterboxBatchSynth` (the one new class)
In `tts.py`, replace `VllmChatterboxSynth` with a real-Chatterbox batch synth:
```python
class ChatterboxBatchSynth:        # implements BatchSynthesizer
    def __init__(self, voice=None, audio_prompt_path=None):
        import torch
        from chatterbox.tts import ChatterboxTTS
        device = "cuda" if torch.cuda.is_available() else "cpu"
        self._model = ChatterboxTTS.from_pretrained(device=device)
        self.sample_rate = self._model.sr
        self._gen = chatterbox_preset(voice)      # exaggeration + cfg_weight, PER VOICE
        self._audio_prompt_path = audio_prompt_path
    def synthesize_batch(self, texts):
        kw = dict(self._gen)
        if self._audio_prompt_path: kw["audio_prompt_path"] = self._audio_prompt_path
        wavs = self._model.generate(text=list(texts), **kw)   # PR #204 batch
        out = []
        for w in wavs:
            a = w.squeeze(0) if hasattr(w, "squeeze") else w
            out.append(a.detach().cpu().numpy().astype("float32"))
        return out   # one waveform per input text, in order
```
- **Restore per-voice `cfg_weight`.** The real model takes `cfg_weight` per call (unlike the
  vLLM port, which forced the fixed-0.5 compromise) — so the original presets
  (`cb_storyteller` 0.3 / `cb_steady` 0.5 / `cb_intimate` 0.4) come back.
- Per-request memory release: keep the `torch.cuda.empty_cache()` discipline between batches.

## Phase 2 — worker uses the batched path
`serverless/rp_handler.py`: build a `ChatterboxBatchSynth` and call
`narrate_bundle_batched(bundle, synth, out_dir, max_batch=<tuned>)` instead of the sequential
`narrate_bundle`. Keep sequential reachable behind an env flag (e.g. `VIMARSHA_BATCH=0`) as a
one-switch rollback if a chapter ever misbehaves. Update `tests/test_rp_handler.py` to the batched
factory (mirrors the earlier `build_batch_synth` shape; drive it with `FakeBatchSynth`). All tests
stay GPU-free; the real batch is validated live (Phase 0 + a live chapter).

## Phase 3 — tune + measure (A40)
Calibrate `max_batch` to the largest that fits A40 VRAM with headroom. Narrate a real ~18k-char
chapter; record batched **$/chapter and realtime factor vs the sequential baseline** in
`plan/08-engineering/runpod-cost-and-buy-trigger.md`.

## Phase 4 — ship
Rebuild/push the worker image, roll the A40 endpoint, narrate Stolen Focus end-to-end, confirm
clean audio in the app, merge.

## Notes / risks
- **This obviates the multi-worker fan-out idea** — one A40 batching internally is simpler and
  cheaper than N workers + N cold starts.
- **Model still reloads per request** (`from_pretrained` each job) — a separate, orthogonal win
  (cache the model on the warm worker) worth doing alongside.
- **OOM on big batches** → `max_batch` cap (already a param). Start conservative.
- **Quality regression** is the only real risk and Phase 0 is the gate specifically for it.
- One voice per chapter → every chunk in a batch shares exaggeration/cfg → clean batching.
