# Block-batched Chatterbox Narration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make premium (Chatterbox) narration batch independent paragraph-chunks through the GPU in one forward pass — the ~10× cost lever — without changing audio quality, paragraph→ms timings, or figure sync.

**Architecture:** Add a `BatchSynthesizer` seam (`synthesize_batch(texts) -> [waveform]`) alongside the existing single-stream `Synthesizer`. A new `narrate_bundle_batched` flattens every narratable block into chunks, synthesizes them in capped batches, regroups per block, and reuses the **same** `assemble`/figure-fill tail as `narrate_bundle` (so the bundle is structurally identical). The RunPod worker swaps to this path with a CUDA-only `VllmChatterboxSynth` backed by `chatterbox-vllm`. The rest of the backend never imports vLLM.

**Tech Stack:** Python 3.13 / pytest (TDD) / numpy / `chatterbox-vllm` (vLLM 0.9.2, CUDA-only, serverless image only).

**Source spec:** `docs/superpowers/specs/2026-06-18-chatterbox-batched-narration-design.md`

**Conventions:** TDD. Frequent small commits with the trailer `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. Backend tests: `cd backend && uv run pytest`. Each chunk ends with a `--no-ff` merge to `main` + push. **Chunk C is a live/manual deploy step** (rebuilds the worker image, spends money) and is **gated on the premium serverless endpoint existing** (the `2026-06-18-premium-tier-runpod.md` plan's Chunk D).

**File structure:**
- `backend/src/vimarsha/tts.py` — add `BatchSynthesizer` protocol; add `VllmChatterboxSynth`.
- `backend/src/vimarsha/narrate.py` — extract `_finalize` tail; add `narrate_bundle_batched`.
- `backend/tests/fakes.py` — add `FakeBatchSynth`.
- `backend/tests/test_narrate_batched.py` — new; parity + batching + empty tests.
- `backend/serverless/rp_handler.py` — use the batched path via a monkeypatchable synth factory.
- `backend/tests/test_rp_handler.py` — point the handler test at `FakeBatchSynth`.
- `backend/pyproject.toml` + `backend/Dockerfile.serverless` — add `chatterbox-vllm`.

**Branch for chunk A:** `git checkout main && git pull && git checkout -b feat/batched-narration`

---

## Chunk A — Batched narration core (GPU-free, fully tested)

### Task A1: `BatchSynthesizer` seam + `FakeBatchSynth`

**Files:**
- Modify: `backend/src/vimarsha/tts.py`
- Modify: `backend/tests/fakes.py`
- Test: `backend/tests/test_batch_synth.py`

- [ ] **Step 1: Write the failing test** — create `backend/tests/test_batch_synth.py`:

```python
import numpy as np

from tests.fakes import FakeBatchSynth


def test_fake_batch_synth_returns_one_waveform_per_text_and_records_batches():
    synth = FakeBatchSynth(samples_per_char=100)
    out = synth.synthesize_batch(["ab", "cdef"])
    assert len(out) == 2
    assert all(isinstance(w, np.ndarray) and w.dtype == np.float32 for w in out)
    # duration scales with text length (2 chars -> 200 samples, 4 -> 400)
    assert out[0].shape[0] == 200
    assert out[1].shape[0] == 400
    # it recorded the batch it received (so tests can assert batching behavior)
    assert synth.batches == [["ab", "cdef"]]
    assert synth.sample_rate == 16000
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_batch_synth.py -q`
Expected: FAIL — `ImportError: cannot import name 'FakeBatchSynth'`.

- [ ] **Step 3: Add the `BatchSynthesizer` protocol** — in `backend/src/vimarsha/tts.py`, directly below the existing `Synthesizer` protocol (after its `synthesize` method), add:

```python
class BatchSynthesizer(Protocol):
    """Anything that turns a list of texts into one mono float32 waveform each, in order.

    The batched analogue of ``Synthesizer`` — independent utterances synthesized together so a
    GPU can decode them in parallel. Each text is its own utterance (we never merge them), so
    downstream stitching/timings are identical to the single-stream path.
    """

    sample_rate: int

    def synthesize_batch(self, texts: list[str]) -> list[np.ndarray]:
        """Return one 1-D float32 array per input text, in the same order."""
        ...
```

- [ ] **Step 4: Add `FakeBatchSynth`** — in `backend/tests/fakes.py`, append:

```python
class FakeBatchSynth:
    """Deterministic batched synthesizer for tests: duration scales with text length,
    identically to ``FakeSynth`` (100 samples/char @ 16 kHz), and records each batch so tests
    can assert batching behavior."""

    sample_rate = 16000

    def __init__(self, samples_per_char: int = 100):
        self.samples_per_char = samples_per_char
        self.batches: list[list[str]] = []

    def synthesize_batch(self, texts: list[str]) -> list[np.ndarray]:
        self.batches.append(list(texts))
        return [
            np.ones(max(1, len(t) * self.samples_per_char), dtype=np.float32) * 0.01
            for t in texts
        ]
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_batch_synth.py -q`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/src/vimarsha/tts.py backend/tests/fakes.py backend/tests/test_batch_synth.py
git commit -m "feat(backend): BatchSynthesizer seam + FakeBatchSynth test double

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task A2: `narrate_bundle_batched` (+ extract shared `_finalize` tail)

**Files:**
- Modify: `backend/src/vimarsha/narrate.py`
- Test: `backend/tests/test_narrate_batched.py`

> The parity test is the heart of this plan: `FakeSynth(100)` and `FakeBatchSynth(100)`
> produce identical per-chunk lengths, so the batched path must yield the **same**
> `para_timings` and figure ms as the single-stream path.

- [ ] **Step 1: Write the failing test** — create `backend/tests/test_narrate_batched.py`:

```python
import pytest

from vimarsha.ingest import ingest_epub
from vimarsha.models import Block, ChapterBundle
from vimarsha.narrate import narrate_bundle, narrate_bundle_batched
from tests.fakes import FakeBatchSynth, FakeSynth


def test_batched_matches_single_stream(tmp_path, sample_epub):
    bundle = ingest_epub(str(sample_epub))[0]
    single = narrate_bundle(bundle, FakeSynth(), str(tmp_path / "s"), para_gap_ms=200)
    batched = narrate_bundle_batched(
        bundle, FakeBatchSynth(), str(tmp_path / "b"), para_gap_ms=200
    )

    # Same bundle structure + identical timings/figure ms (only HOW waveforms were computed
    # differs). audio file name is the same; both write their own copy in their own dir.
    assert batched.audio == single.audio == "chap1.mp3"
    assert (tmp_path / "b" / "chap1.mp3").exists()
    assert batched.para_timings == single.para_timings
    sfm = {f.figure_id: (f.start_ms, f.end_ms) for f in single.figure_map}
    bfm = {f.figure_id: (f.start_ms, f.end_ms) for f in batched.figure_map}
    assert bfm == sfm


def test_batches_respect_max_batch_and_cover_all_chunks(tmp_path, sample_epub):
    bundle = ingest_epub(str(sample_epub))[0]
    synth = FakeBatchSynth()
    narrate_bundle_batched(bundle, synth, str(tmp_path), max_batch=2)
    assert synth.batches, "synthesize_batch was never called"
    assert all(len(b) <= 2 for b in synth.batches)          # cap honored
    assert any(len(b) == 2 for b in synth.batches)          # actually batched, not 1-by-1


def test_batched_raises_when_no_narratable_text(tmp_path):
    bundle = ChapterBundle(
        chapter_id="empty",
        title="Part One",
        blocks=[Block(id="b0", index=0, kind="image", src="x.png")],
        figure_map=[],
    )
    with pytest.raises(ValueError, match="no narratable text"):
        narrate_bundle_batched(bundle, FakeBatchSynth(), str(tmp_path))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_narrate_batched.py -q`
Expected: FAIL — `ImportError: cannot import name 'narrate_bundle_batched'`.

- [ ] **Step 3: Extract the shared tail** — in `backend/src/vimarsha/narrate.py`, add this helper directly above `def narrate_bundle(`:

```python
def _finalize(
    bundle: ChapterBundle,
    segments: list[tuple[str, np.ndarray]],
    sample_rate: int,
    out_dir: str,
    para_gap_ms: int,
) -> ChapterBundle:
    """Stitch block segments → mp3 + timings, then fill audio/para_timings/figure ms.
    Shared by the single-stream and batched narration paths."""
    waveform, timings = assemble(segments, sample_rate, para_gap_ms)
    audio_name = f"{bundle.chapter_id}.mp3"
    write_mp3(waveform, sample_rate, str(Path(out_dir) / audio_name))

    out = bundle.model_copy(deep=True)
    out.audio = audio_name
    out.para_timings = timings
    for fig in out.figure_map:
        fig.start_ms = _resolve_ms(fig.start_para, out.blocks, timings, "start")
        fig.end_ms = _resolve_ms(fig.end_para, out.blocks, timings, "end")
    return out
```

- [ ] **Step 4: Refactor `narrate_bundle` to use `_finalize`** — replace the body of
`narrate_bundle` (everything after the `segments` loop) so it reads:

```python
def narrate_bundle(
    bundle: ChapterBundle,
    synth: Synthesizer,
    out_dir: str,
    para_gap_ms: int = 400,
) -> ChapterBundle:
    """Synthesize narration, stitch audio, and fill audio/timings/figure ms."""
    segments: list[tuple[str, np.ndarray]] = []
    for b in bundle.blocks:
        text = narratable_text(b)
        if text is None:
            continue
        segments.append((b.id, _synthesize_block(text, synth)))

    if not segments:
        # Nothing to read (e.g. a part-divider page that is only an image).
        raise ValueError(f"chapter {bundle.chapter_id} has no narratable text")

    return _finalize(bundle, segments, synth.sample_rate, out_dir, para_gap_ms)
```

- [ ] **Step 5: Add `narrate_bundle_batched`** — append to `backend/src/vimarsha/narrate.py`:

```python
def narrate_bundle_batched(
    bundle: ChapterBundle,
    synth: BatchSynthesizer,
    out_dir: str,
    para_gap_ms: int = 400,
    max_batch: int = 32,
) -> ChapterBundle:
    """Batched narration: flatten every narratable block into chunks, synthesize them in
    batches of ``max_batch`` (GPU-memory bound), regroup per block, then stitch identically to
    ``narrate_bundle``. Each chunk is an independent utterance — quality/timings are unchanged."""
    # (block_id, [chunks]) for each narratable block, in document order.
    block_chunks: list[tuple[str, list[str]]] = []
    for b in bundle.blocks:
        text = narratable_text(b)
        if text is None:
            continue
        block_chunks.append((b.id, chunk_text(text)))

    if not block_chunks:
        raise ValueError(f"chapter {bundle.chapter_id} has no narratable text")

    # Flatten to (block_position, chunk), synthesize in capped batches, keep order.
    flat: list[tuple[int, str]] = [
        (pos, chunk) for pos, (_bid, chunks) in enumerate(block_chunks) for chunk in chunks
    ]
    waves: list[np.ndarray] = []
    for i in range(0, len(flat), max_batch):
        waves.extend(synth.synthesize_batch([chunk for (_pos, chunk) in flat[i : i + max_batch]]))

    # Regroup each block's chunk waveforms and concatenate → the same segments as the
    # single-stream path.
    per_block: list[list[np.ndarray]] = [[] for _ in block_chunks]
    for (pos, _chunk), wav in zip(flat, waves):
        per_block[pos].append(wav)

    segments: list[tuple[str, np.ndarray]] = []
    for (bid, _chunks), parts in zip(block_chunks, per_block):
        joined = np.concatenate(parts) if parts else np.zeros(0, dtype=np.float32)
        segments.append((bid, joined))

    return _finalize(bundle, segments, synth.sample_rate, out_dir, para_gap_ms)
```

- [ ] **Step 6: Add the import** — at the top of `backend/src/vimarsha/narrate.py`, change the
existing tts import line:

```python
from vimarsha.tts import Synthesizer, chunk_text
```

to:

```python
from vimarsha.tts import BatchSynthesizer, Synthesizer, chunk_text
```

- [ ] **Step 7: Run the new tests to verify they pass**

Run: `cd backend && uv run pytest tests/test_narrate_batched.py -q`
Expected: PASS (3 tests).

- [ ] **Step 8: Run the full suite (no regressions in the refactored single path)**

Run: `cd backend && uv run pytest -q`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add backend/src/vimarsha/narrate.py backend/tests/test_narrate_batched.py
git commit -m "feat(backend): narrate_bundle_batched (batched chunks, same stitch/timings)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task A3: Merge chunk A

- [ ] **Step 1:** `cd backend && uv run pytest -q` → PASS.
- [ ] **Step 2:**

```bash
git checkout main && git pull --ff-only
git merge --no-ff feat/batched-narration -m "Merge: batched narration core (BatchSynthesizer + narrate_bundle_batched)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push origin main
```

---

## Chunk B — vLLM backend + worker wiring + image deps

**Branch:** `git checkout -b feat/batched-worker`

### Task B1: `VllmChatterboxSynth` (CUDA-only batched backend)

**Files:**
- Modify: `backend/src/vimarsha/tts.py`

> Loads a GPU model, so it is **not** unit-tested — validated live on the worker (Chunk C),
> exactly like `ChatterboxSynth`. `chatterbox_vllm` is imported lazily so importing `tts.py`
> never requires vLLM. cfg is fixed at 0.5 (the port's `cfg_scale` is process-global); voices
> differ only by `exaggeration` (read from the existing `chatterbox_preset`).

- [ ] **Step 1: Implement** — in `backend/src/vimarsha/tts.py`, add below `ChatterboxSynth`
(it reuses `chatterbox_preset` already defined above it):

```python
# Premium narration runs batched on the RunPod CUDA worker via the chatterbox-vllm port
# (cfg is process-global there, so we fix it and vary only exaggeration per voice — see
# docs/superpowers/specs/2026-06-18-chatterbox-batched-narration-design.md).
_VLLM_CFG_SCALE = "0.5"


class VllmChatterboxSynth:
    """Batched Chatterbox via the vLLM port. CUDA-only; constructed only on the worker.

    Implements ``BatchSynthesizer``. Lazily imports ``chatterbox_vllm`` so the rest of the
    package runs without vLLM. cfg is fixed (``_VLLM_CFG_SCALE``); ``exaggeration`` comes from
    the voice preset.
    """

    def __init__(self, voice: str | None = None, audio_prompt_path: str | None = None,
                 gpu_memory_utilization: float = 0.4, max_model_len: int = 1000):
        import os

        os.environ["CHATTERBOX_CFG_SCALE"] = _VLLM_CFG_SCALE
        from chatterbox_vllm.tts import ChatterboxTTS

        self._model = ChatterboxTTS.from_pretrained(
            gpu_memory_utilization=gpu_memory_utilization,
            max_model_len=max_model_len,
            enforce_eager=True,
        )
        self.sample_rate = self._model.sr
        self._audio_prompt_path = audio_prompt_path
        self._exaggeration = chatterbox_preset(voice).get("exaggeration", 0.5)

    def synthesize_batch(self, texts: list[str]) -> list[np.ndarray]:
        if not texts:
            return []
        kwargs: dict = {"exaggeration": self._exaggeration}
        if self._audio_prompt_path:
            kwargs["audio_prompt_path"] = self._audio_prompt_path
        audios = self._model.generate(prompts=list(texts), **kwargs)
        out: list[np.ndarray] = []
        for wav in audios:
            arr = wav.squeeze(0) if hasattr(wav, "squeeze") else wav
            out.append(arr.detach().cpu().numpy().astype("float32"))
        return out
```

- [ ] **Step 2: Verify the package still imports without vLLM** (the import must stay lazy)

Run: `cd backend && uv run python -c "import vimarsha.tts; print('ok')"`
Expected: prints `ok` (no `ModuleNotFoundError: chatterbox_vllm`).

- [ ] **Step 3: Run the full suite (nothing references the new class yet)**

Run: `cd backend && uv run pytest -q`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add backend/src/vimarsha/tts.py
git commit -m "feat(backend): VllmChatterboxSynth (batched, CUDA-only, cfg fixed at 0.5)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task B2: Worker uses the batched path

**Files:**
- Modify: `backend/serverless/rp_handler.py`
- Modify: `backend/tests/test_rp_handler.py`

> The handler builds its synth through a module-level factory so tests can monkeypatch a
> `FakeBatchSynth` (mirrors how the old test monkeypatched `synth_class`). The
> `VllmChatterboxSynth`/`runpod` imports stay lazy / under `__main__`.

- [ ] **Step 1: Update the handler test** — replace the body of
`test_handler_narrates_and_returns_bundle_audio` in `backend/tests/test_rp_handler.py` so it
patches the batched factory instead of `synth_class`:

```python
def test_handler_narrates_and_returns_bundle_audio(sample_epub, monkeypatch):
    from tests.fakes import FakeBatchSynth

    monkeypatch.setattr(rp_handler, "build_batch_synth", lambda engine, voice: FakeBatchSynth())
    epub_b64 = base64.b64encode(Path(sample_epub).read_bytes()).decode()
    out = rp_handler.handler(
        {"input": {"epub_b64": epub_b64, "chapter_index": 0, "engine": "chatterbox", "voice": "cb_steady"}}
    )
    assert out["bundle"]["chapterId"] == "chap1"
    assert out["bundle"]["audio"] == "chap1.mp3"
    assert len(base64.b64decode(out["audio_b64"])) > 0
    assert any(name.endswith(".png") for name in out["images"])
```

(The unused `FakeSynth` import at the top of the file can stay or be removed; leaving it is
harmless. `test_handler_reports_bad_chapter_index` is unchanged — bad index returns before any
synth is built.)

- [ ] **Step 2: Run the handler test to verify it fails**

Run: `cd backend && uv run pytest tests/test_rp_handler.py -q`
Expected: FAIL — `AttributeError: ... has no attribute 'build_batch_synth'`.

- [ ] **Step 3: Rewire the handler** — in `backend/serverless/rp_handler.py`, change the imports
block to use the batched API:

```python
from vimarsha.epub_reader import read_chapters
from vimarsha.figure_images import extract_images
from vimarsha.ingest import ingest_epub
from vimarsha.narrate import narrate_bundle_batched
from vimarsha.tts import VllmChatterboxSynth
```

Add a factory directly above `def handler(`:

```python
def build_batch_synth(engine: str, voice: str | None):
    """The worker's batched synthesizer (overridable in tests). Premium narration is Chatterbox
    via vLLM regardless of ``engine``; ``engine`` is accepted for symmetry with the API."""
    return VllmChatterboxSynth(voice=voice)
```

Then, inside `handler`, replace the two lines:

```python
        synth = synth_class(engine)(voice=voice)
        narrated = narrate_bundle(bundles[chapter_index], synth, out_dir)
```

with:

```python
        synth = build_batch_synth(engine, voice)
        narrated = narrate_bundle_batched(bundles[chapter_index], synth, out_dir)
```

- [ ] **Step 4: Run the handler tests to verify they pass**

Run: `cd backend && uv run pytest tests/test_rp_handler.py -q`
Expected: PASS (2 tests).

- [ ] **Step 5: Run the full suite**

Run: `cd backend && uv run pytest -q`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/serverless/rp_handler.py backend/tests/test_rp_handler.py
git commit -m "feat(backend): worker narrates via narrate_bundle_batched + VllmChatterboxSynth

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task B3: Add `chatterbox-vllm` to the serverless image

**Files:**
- Modify: `backend/pyproject.toml`
- Modify: `backend/Dockerfile.serverless`

> vLLM is CUDA-only and large; it goes ONLY in the `serverless` extra (the worker image),
> never in `tts`/`kokoro`. Pin per the port's requirement (vLLM 0.9.2).

- [ ] **Step 1: Add the dep** — in `backend/pyproject.toml`, in the `serverless` optional-deps
list, add the `chatterbox-vllm` git dependency and the vLLM pin. The list becomes:

```toml
serverless = [
    "chatterbox-tts",
    "setuptools<81",
    "torch",
    "torchaudio",
    "runpod>=1.6",
    "vllm==0.9.2",
    "chatterbox-vllm",
]

[tool.uv.sources]
chatterbox-vllm = { git = "https://github.com/randombk/chatterbox-vllm" }
```

(If a `[tool.uv.sources]` table already exists, add the `chatterbox-vllm` line to it rather than
creating a second table.)

- [ ] **Step 2: Resolve the lock (do not install locally — vLLM is CUDA-only)**

Run: `cd backend && uv lock`
Expected: exits 0; `uv.lock` now contains `chatterbox-vllm` and `vllm`.

Run: `grep -c 'name = "chatterbox-vllm"' uv.lock`
Expected: `1`.

- [ ] **Step 3: Confirm the local env is unaffected** (vLLM not installed; tests still green)

Run: `cd backend && uv run pytest -q`
Expected: PASS (the worker code paths are faked; nothing imports vLLM at test time).

- [ ] **Step 4: Note the image already installs the extra** — `backend/Dockerfile.serverless`
already runs `uv sync --extra serverless --frozen`, so vLLM is pulled into the image with no
Dockerfile change. Verify nothing else needs editing:

Run: `cd backend && grep -c "extra serverless" Dockerfile.serverless`
Expected: `1`.

- [ ] **Step 5: Commit**

```bash
git add backend/pyproject.toml backend/uv.lock
git commit -m "build(backend): add chatterbox-vllm (vLLM 0.9.2) to the serverless extra

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task B4: Merge chunk B

- [ ] **Step 1:** `cd backend && uv run pytest -q` → PASS.
- [ ] **Step 2:**

```bash
git checkout main && git pull --ff-only
git merge --no-ff feat/batched-worker -m "Merge: batched Chatterbox worker (vLLM backend + image dep)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push origin main
```

---

## Chunk C — Live batched narration (MANUAL / spends money)

> Not unit-tested. **Gated on the premium serverless endpoint existing** (the
> `2026-06-18-premium-tier-runpod.md` plan, Chunk D). Requires Docker running + the RunPod
> account. **Confirm with the user before the build/push and endpoint-update steps (they cost
> money / push to a registry).** Re-uses the registry namespace chosen in that plan.

**Branch:** `git checkout -b feat/batched-live`

### Task C1: Rebuild + push the worker image (now with vLLM)

- [ ] **Step 1: Ensure Docker is running** — `docker version --format '{{.Server.Version}}'`
prints a version (else start Docker Desktop).

- [ ] **Step 2: Build the amd64 image** (slower now — vLLM is large):

Run: `cd backend && docker buildx build --platform linux/amd64 -f Dockerfile.serverless -t ghcr.io/kartar-sachmeet/vimarsha-worker:latest --load .`
Expected: `naming to ...vimarsha-worker:latest`, exit 0.

- [ ] **Step 3: Push** (logged in per the premium plan's GHCR step):

Run: `docker push ghcr.io/kartar-sachmeet/vimarsha-worker:latest`
Expected: `latest: digest: sha256:… size: …`.

### Task C2: Roll the endpoint + narrate a chapter batched

- [ ] **Step 1: Update the endpoint to the new image** (RunPod console → the endpoint → release
the new `:latest` digest, or recreate). Keep FlashBoot ON, scale-to-zero, a **24GB GPU**
(vLLM needs more headroom than the unbatched 16GB card — e.g. 4090/L4 24GB).

- [ ] **Step 2: Narrate a real chapter through the tunnel + poll** (same flow as the premium
plan's live step), picking a premium voice:

```bash
BASE=https://vimarsha-dev.kartar.ai
JID=$(curl -s -X POST "$BASE/import?chapter_index=0&engine=chatterbox&voice=cb_storyteller" \
  -F "file=@shared/fixtures/sample.epub;type=application/epub+zip" | python3 -c "import json,sys;print(json.load(sys.stdin)['jobId'])")
for i in $(seq 1 120); do sleep 5; S=$(curl -s "$BASE/import/status/$JID"); echo "$S" | python3 -c "import json,sys;print(json.load(sys.stdin)['status'])"; echo "$S" | grep -q '"status": *"ready"' && break; echo "$S" | grep -q '"status": *"error"' && { echo "$S"; break; }; done
```
Expected: `ready` with a bundle whose `audio` downloads and plays in the Chatterbox voice.

- [ ] **Step 3: Tune `max_batch` if needed** — if the worker OOMs, lower `max_batch` (it
defaults to 32 in `narrate_bundle_batched`; the handler can pass a smaller value). Re-narrate
until stable, noting the largest batch that fits the chosen card.

### Task C3: Record the new cost + merge

- [ ] **Step 1: Append a batched-throughput row** to
`plan/08-engineering/runpod-cost-and-buy-trigger.md`: GPU type, `max_batch`, cold-start
seconds, **batched $/chapter vs the 2026-06-13 unbatched baseline**, and the realtime factor.
Commit:

```bash
git add plan/08-engineering/runpod-cost-and-buy-trigger.md
git commit -m "docs(plan): batched narration live — \$/chapter vs unbatched baseline

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 2: Merge**

```bash
git checkout main && git pull --ff-only
git merge --no-ff feat/batched-live -m "Merge: live batched narration + cost ledger update

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push origin main
```

---

## Self-review notes (resolved)

- **Spec coverage:** `BatchSynthesizer` seam (A1) · `narrate_bundle_batched` flatten→batch→
  regroup→shared `_finalize` tail (A2) · quality/timing parity asserted via `FakeBatchSynth`
  parity test (A2) · `VllmChatterboxSynth` CUDA-only lazy-import backend (B1) · cfg=0.5 fixed,
  exaggeration per-voice (B1) · worker wiring via monkeypatchable factory + handler test (B2) ·
  `chatterbox-vllm` only in the `serverless` extra (B3) · live rebuild/redeploy + ledger (C).
  Kokoro/`/speak`/client explicitly out of scope. All present.
- **Type consistency:** `BatchSynthesizer.synthesize_batch(texts) -> list[np.ndarray]`,
  `FakeBatchSynth.synthesize_batch`/`.batches`/`.sample_rate`, `narrate_bundle_batched(bundle,
  synth, out_dir, para_gap_ms=400, max_batch=32)`, `_finalize(bundle, segments, sample_rate,
  out_dir, para_gap_ms)`, `VllmChatterboxSynth(voice=…)`, `rp_handler.build_batch_synth(engine,
  voice)` are used consistently across tasks.
- **Confirm at execution time:** the `chatterbox-vllm` source URL resolves under `uv lock`;
  `VllmChatterboxSynth.generate` kwarg names (`prompts`, `exaggeration`, `audio_prompt_path`)
  and the returned tensor shape match the installed port version (verify the squeeze/`.sr`
  against the actual API on the worker — adjust the thin adapter in B1 if the port differs);
  the 24GB card choice and `max_batch` are calibrated live in C2.
```
