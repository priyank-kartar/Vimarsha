# Block-batched Chatterbox narration (the ~10× cost lever) — Design

**Date:** 2026-06-18
**Status:** approved (brainstorm) → ready for implementation plan
**Scope owner:** backend / RunPod serverless worker

## Problem

Premium narration runs Chatterbox on a RunPod serverless GPU. The current pipeline
(`narrate_bundle` → per-block `synthesize` → `model.generate(text)`) is **single-stream**:
the autoregressive T3 decode processes one utterance at a time at a fraction of GPU
utilization. The live benchmark (2026-06-13, A40) measured ~$0.06/18k-char chapter,
~$2/book — already cheap, but the cost ledger flags **block batching as the ~10× lever**
that moves every $/chapter number. This design implements it.

## Quality invariant (why this is safe)

Narration is **paragraph-based and stitched**: each block is synthesized as an independent
utterance, and per-paragraph→ms timings are recorded *during concatenation* of those
separate clips (`stitch.assemble`). That is the source of figure auto-pop and reading-highlight
granularity.

This design **batches independent utterances through the model in parallel** — it does NOT
merge paragraphs into one `generate` call. Each block remains its own clip; we only change
*how* the waveforms are computed (concurrently instead of serially), not *what* they are.
Therefore audio quality, `paraTimings`, and figure `startMs`/`endMs` are structurally
unchanged. Merging paragraphs into a single utterance is explicitly rejected: it would alter
cross-boundary prosody and destroy the per-paragraph ms boundaries the contract depends on.

## Approach

Adopt [`randombk/chatterbox-vllm`](https://github.com/randombk/chatterbox-vllm), a vLLM port
of Chatterbox whose `generate(prompts=[...])` runs a genuine batched forward pass (its
benchmarks: ~4× unbatched, >10× batched). It is **CUDA-only** and pins **vLLM 0.9.2**
(pre-1.0 internal APIs). Both constraints are acceptable: the premium tier is already
**remote-only** (`REMOTE_ENGINES = {"chatterbox"}`), so Chatterbox only ever runs on the
RunPod CUDA worker — never on the dev Mac (MPS) or in CI.

### Components

1. **`BatchSynthesizer` seam** (`backend/src/vimarsha/tts.py`, alongside `Synthesizer`):
   ```python
   class BatchSynthesizer(Protocol):
       sample_rate: int
       def synthesize_batch(self, texts: list[str]) -> list[np.ndarray]: ...
   ```
   Independent texts in; one mono float32 waveform per text out, in input order. The existing
   single-stream `Synthesizer` protocol is untouched (Kokoro/local keep using it).

2. **`narrate_bundle_batched`** (`backend/src/vimarsha/narrate.py`, beside `narrate_bundle`):
   - Build a flat list of `(block_id, chunk)` pairs across all narratable blocks, using the
     unchanged `narratable_text` + `chunk_text`.
   - Synthesize chunks via `synth.synthesize_batch`, in slices capped at `max_batch`
     (default e.g. 32; GPU-memory bound, tunable).
   - **Regroup** each block's chunk waveforms and `np.concatenate` them → the exact same
     `segments: list[tuple[block_id, waveform]]` that `narrate_bundle` builds today.
   - Call the **same** `assemble(segments, sample_rate, para_gap_ms)`; fill `audio`,
     `para_timings`, and figure `start_ms`/`end_ms` identically (reuse `_resolve_ms`).
   - Same empty-chapter guard: raise `ValueError` when no narratable text.
   - `narrate_bundle` (single-stream) stays as-is for the local path and existing tests.
   - Shared internals (`narratable_text`, `_resolve_ms`, the assemble/figure-fill tail) are
     factored so the two functions don't duplicate the timing/figure logic.

3. **`VllmChatterboxSynth`** (CUDA-only `BatchSynthesizer`; in the `serverless` extra):
   - Lazily imports `chatterbox_vllm`; loads the model once (`from_pretrained`).
   - `synthesize_batch(texts)` → `model.generate(prompts=texts, exaggeration=<preset>,
     audio_prompt_path=<optional>)`; convert each returned tensor to mono float32 numpy.
   - cfg is process-global (see below); set once at construction.
   - Not unit-tested (loads a GPU model) — verified live on the worker, exactly like
     `ChatterboxSynth`. The base `ChatterboxSynth` remains in `tts.py` (harmless; unused now
     that the worker batches).

4. **Worker wiring** (`backend/serverless/rp_handler.py`):
   - Use `narrate_bundle_batched` + `VllmChatterboxSynth` for the narration step.
   - `pyproject.toml` `serverless` extra + `Dockerfile.serverless` gain `chatterbox-vllm`
     (and its pinned vLLM 0.9.2). The handler stays unit-testable by monkeypatching the
     synth factory to a `FakeBatchSynth` (the `chatterbox_vllm`/`runpod` imports remain
     lazy / under `__main__`).

### Premium presets under vLLM (cfg decision)

The port exposes `exaggeration` **per-request** but `cfg_scale` **process-global**
(env/config, not per-call). Decision: **fix cfg = 0.5 for all premium voices and differentiate
only by `exaggeration`.** `exaggeration` is the dominant expressiveness knob, so the three
voices stay clearly distinct, batches may freely mix voices, and warm-worker cfg reloads are
avoided. Updated preset intent:

| voice | exaggeration | cfg (fixed) |
|---|---|---|
| `cb_storyteller` | 0.7 | 0.5 |
| `cb_steady` | 0.35 | 0.5 |
| `cb_intimate` | 0.5 | 0.5 |

`chatterbox_preset` keeps returning a dict; the worker reads `exaggeration` from it and applies
the fixed cfg. (The local `ChatterboxSynth` may keep its existing `cfg_weight` handling — it is
no longer on the live path, so this is cosmetic and not load-bearing.)

## Testing

- **`narrate_bundle_batched` unit tests** (GPU-free), driven by a new `FakeBatchSynth` in
  `tests/fakes.py` (deterministic: duration ∝ text length, records each batch it receives):
  1. **Parity** — on the same blocks, `narrate_bundle_batched` yields the same bundle
     structure as `narrate_bundle` with an equivalent `FakeSynth`: identical `chapterId`,
     `audio` name, the same `paraTimings` keys/order, and the same figure `startMs`/`endMs`.
  2. **It actually batches** — assert `FakeBatchSynth` saw all chunks and that no batch
     exceeded `max_batch` (and >1 chunk per batch when input allows).
  3. **Empty chapter** raises `ValueError` (same as `narrate_bundle`).
- **`rp_handler` test** — monkeypatch the synth factory to return a `FakeBatchSynth`; assert
  it returns the bundle + base64 audio + figure images (mirrors the existing handler test).
- `VllmChatterboxSynth` and the vLLM image are **not** unit-tested — validated live on the
  worker (Chunk-D-style live step), recorded in the cost ledger.

## Out of scope

Kokoro batching; changing the local/dev narration path; `/speak` batching; any client change;
GPU-side micro-optimizations beyond adopting the port.

## Risks / notes

- **Dependency risk:** vLLM 0.9.2 pinned, port uses pre-1.0 internal APIs. Isolated to the
  serverless image; the rest of the backend never imports it. Revisit on port updates.
- **Batch size** is GPU-memory bound; `max_batch` is a tunable constant, calibrated live on
  the chosen serverless card. Start conservative.
- The vLLM image is larger and cold-start is heavier; FlashBoot + scale-to-zero still apply.
  Re-derive $/chapter in `plan/08-engineering/runpod-cost-and-buy-trigger.md` after the first
  live batched run.
