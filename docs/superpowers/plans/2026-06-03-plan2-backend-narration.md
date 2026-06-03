# Plan 2 — Backend Narration: TTS → Stitched Audio → Full Bundle (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the Plan 1 pipeline so a `ChapterBundle` gains real narration: synthesize narratable blocks with Chatterbox, stitch them into one chapter audio file, record per-paragraph time ranges, convert figure spans from paragraph ids to milliseconds, and expose the whole thing over a small FastAPI import endpoint.

**Architecture:** TTS lives behind a `Synthesizer` protocol so all logic is tested with a deterministic fake; the real `ChatterboxSynth` is a thin, lazily-imported adapter. Pure functions handle text chunking and waveform assembly (timing math); an `audio_io` module transcodes to MP3 via ffmpeg; `narrate_bundle` orchestrates and fills `audio` / `paraTimings` / figure `startMs`/`endMs`. A FastAPI `server` wires it into an HTTP import job and serves audio files.

**Tech Stack:** Builds on Plan 1 (Python 3.13, `uv`, `pydantic`, `pytest`). Adds `numpy`, `soundfile` (WAV I/O), ffmpeg (already installed, MP3 transcode), `fastapi` + `uvicorn` (service), `httpx` (TestClient). Real TTS via `chatterbox-tts` + `torch` behind an optional `[tts]` extra (not needed for the automated tests).

**Prerequisite:** Plan 1 complete and committed (models, ingest pipeline, `shared/bundle.schema.json`).

---

## File Structure

```
/backend
  src/vimarsha/tts.py          # Synthesizer protocol, chunk_text, ChatterboxSynth (lazy)
  src/vimarsha/stitch.py       # assemble(segments) -> waveform + paraTimings (pure)
  src/vimarsha/audio_io.py     # write_mp3(waveform, sr, path) via ffmpeg
  src/vimarsha/narrate.py      # narrate_bundle(bundle, synth, out_dir) -> full bundle
  src/vimarsha/server.py       # FastAPI: POST /import, GET /audio/{file}
  tests/fakes.py               # FakeSynth (deterministic, no ML)
  tests/test_chunk_text.py
  tests/test_stitch.py
  tests/test_audio_io.py
  tests/test_narrate.py
  tests/test_server.py
```

---

## Task 0: Add narration dependencies

**Files:** Modify `backend/pyproject.toml` (+ `uv.lock`)

- [ ] **Step 1: Add runtime + dev deps**

Run:
```bash
cd backend
uv add numpy soundfile fastapi "uvicorn[standard]"
uv add --dev httpx
```

- [ ] **Step 2: Declare the optional real-TTS extra in `backend/pyproject.toml`**

Add this section (the heavy ML deps stay optional so tests don't pull torch):

```toml
[project.optional-dependencies]
tts = ["chatterbox-tts", "torch", "torchaudio"]
```

- [ ] **Step 3: Verify imports**

Run: `cd backend && uv run python -c "import numpy, soundfile, fastapi, uvicorn, httpx; print('ok')"`
Expected: prints `ok`

- [ ] **Step 4: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add backend/pyproject.toml backend/uv.lock
git commit -m "chore: add narration deps (Plan 2 Task 0)"
```

---

## Task 1: Text chunking for the TTS length limit

Chatterbox handles short utterances; long paragraphs must be split on sentence boundaries into <= ~300-char chunks.

**Files:**
- Create: `backend/src/vimarsha/tts.py`
- Test: `backend/tests/test_chunk_text.py`

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_chunk_text.py
from vimarsha.tts import chunk_text


def test_short_text_is_one_chunk():
    assert chunk_text("Hello world.") == ["Hello world."]


def test_splits_on_sentence_boundaries_under_limit():
    text = "One sentence here. Two follows it. Three is last."
    chunks = chunk_text(text, max_chars=25)
    assert chunks == ["One sentence here.", "Two follows it.", "Three is last."]


def test_accumulates_until_limit():
    text = "A. B. C. D."
    # max_chars large enough to merge all
    assert chunk_text(text, max_chars=100) == ["A. B. C. D."]


def test_oversized_single_sentence_is_kept_whole():
    long = "word " * 100  # no sentence break
    chunks = chunk_text(long.strip(), max_chars=50)
    assert len(chunks) == 1
    assert chunks[0].startswith("word")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_chunk_text.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'vimarsha.tts'`

- [ ] **Step 3: Write `backend/src/vimarsha/tts.py`**

```python
from __future__ import annotations

import re
from typing import Protocol

import numpy as np

_SENTENCE_RE = re.compile(r".+?(?:[.!?](?=\s|$)|$)", re.DOTALL)


def chunk_text(text: str, max_chars: int = 300) -> list[str]:
    """Split text into <=max_chars chunks on sentence boundaries.

    A single sentence longer than max_chars is kept whole (TTS will handle it).
    """
    text = text.strip()
    if not text:
        return []
    sentences = [m.group(0).strip() for m in _SENTENCE_RE.finditer(text)]
    sentences = [s for s in sentences if s]
    chunks: list[str] = []
    current = ""
    for s in sentences:
        if not current:
            current = s
        elif len(current) + 1 + len(s) <= max_chars:
            current = f"{current} {s}"
        else:
            chunks.append(current)
            current = s
    if current:
        chunks.append(current)
    return chunks


class Synthesizer(Protocol):
    """Anything that turns text into a mono float32 waveform."""

    sample_rate: int

    def synthesize(self, text: str) -> np.ndarray:
        """Return a 1-D float32 numpy array of audio samples for `text`."""
        ...
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_chunk_text.py -v`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/tts.py backend/tests/test_chunk_text.py
git commit -m "feat: sentence-aware text chunking + Synthesizer protocol (Plan 2 Task 1)"
```

---

## Task 2: Deterministic FakeSynth (test infrastructure)

**Files:**
- Create: `backend/tests/fakes.py`

- [ ] **Step 1: Write `backend/tests/fakes.py`**

```python
import numpy as np


class FakeSynth:
    """Deterministic synthesizer for tests: duration scales with text length.

    100 samples per character at 16 kHz, so timings are predictable.
    """

    sample_rate = 16000

    def __init__(self, samples_per_char: int = 100):
        self.samples_per_char = samples_per_char

    def synthesize(self, text: str) -> np.ndarray:
        n = max(1, len(text) * self.samples_per_char)
        # low-amplitude noise so the waveform is non-silent but bounded
        return (np.ones(n, dtype=np.float32) * 0.01)
```

- [ ] **Step 2: Verify it imports and produces expected lengths**

Run:
```bash
cd backend && uv run python -c "
from tests.fakes import FakeSynth
s = FakeSynth()
print(len(s.synthesize('abc')), s.sample_rate)
"
```
Expected: prints `300 16000`

- [ ] **Step 3: Commit**

```bash
git add backend/tests/fakes.py
git commit -m "test: deterministic FakeSynth (Plan 2 Task 2)"
```

---

## Task 3: Waveform assembly + paragraph timings (pure)

**Files:**
- Create: `backend/src/vimarsha/stitch.py`
- Test: `backend/tests/test_stitch.py`

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_stitch.py
import numpy as np

from vimarsha.stitch import assemble, samples_to_ms


def test_samples_to_ms():
    assert samples_to_ms(16000, 16000) == 1000
    assert samples_to_ms(8000, 16000) == 500


def test_assemble_concatenates_with_gaps_and_records_timings():
    sr = 16000
    segs = [
        ("b0", np.ones(16000, dtype=np.float32)),  # 1000 ms
        ("b1", np.ones(8000, dtype=np.float32)),   # 500 ms
    ]
    wav, timings = assemble(segs, sample_rate=sr, para_gap_ms=200)
    # b0: 0..1000 ; gap 200 ; b1: 1200..1700
    assert timings["b0"] == [0, 1000]
    assert timings["b1"] == [1200, 1700]
    # total length = 16000 + 3200(gap) + 8000
    assert len(wav) == 16000 + 3200 + 8000


def test_assemble_no_trailing_gap_after_last_segment():
    sr = 16000
    segs = [("b0", np.ones(1600, dtype=np.float32))]
    wav, timings = assemble(segs, sample_rate=sr, para_gap_ms=500)
    assert len(wav) == 1600  # no gap appended after the only/last segment
    assert timings["b0"] == [0, 100]


def test_assemble_empty():
    wav, timings = assemble([], sample_rate=16000, para_gap_ms=200)
    assert len(wav) == 0 and timings == {}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_stitch.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'vimarsha.stitch'`

- [ ] **Step 3: Write `backend/src/vimarsha/stitch.py`**

```python
from __future__ import annotations

import numpy as np


def samples_to_ms(n_samples: int, sample_rate: int) -> int:
    return round(n_samples / sample_rate * 1000)


def assemble(
    segments: list[tuple[str, np.ndarray]],
    sample_rate: int,
    para_gap_ms: int,
) -> tuple[np.ndarray, dict[str, list[int]]]:
    """Concatenate per-paragraph waveforms with silence gaps between them.

    Returns the full waveform and {block_id: [start_ms, end_ms]} timings.
    """
    if not segments:
        return np.zeros(0, dtype=np.float32), {}

    gap_len = int(sample_rate * para_gap_ms / 1000)
    gap = np.zeros(gap_len, dtype=np.float32)

    parts: list[np.ndarray] = []
    timings: dict[str, list[int]] = {}
    cursor = 0
    last = len(segments) - 1
    for i, (block_id, wav) in enumerate(segments):
        start = cursor
        parts.append(wav)
        cursor += len(wav)
        timings[block_id] = [
            samples_to_ms(start, sample_rate),
            samples_to_ms(cursor, sample_rate),
        ]
        if i != last:
            parts.append(gap)
            cursor += gap_len

    return np.concatenate(parts), timings
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_stitch.py -v`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/stitch.py backend/tests/test_stitch.py
git commit -m "feat: waveform assembly with paragraph timings (Plan 2 Task 3)"
```

---

## Task 4: MP3 writer via ffmpeg

**Files:**
- Create: `backend/src/vimarsha/audio_io.py`
- Test: `backend/tests/test_audio_io.py`

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_audio_io.py
import subprocess

import numpy as np

from vimarsha.audio_io import write_mp3


def test_write_mp3_produces_a_playable_file(tmp_path):
    sr = 16000
    wav = (np.sin(np.linspace(0, 3.14 * 440, sr)) * 0.2).astype("float32")
    out = tmp_path / "clip.mp3"
    write_mp3(wav, sr, str(out))
    assert out.exists() and out.stat().st_size > 0
    # ffprobe reports an audio stream with a duration near 1s
    dur = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", str(out)],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    assert 0.8 < float(dur) < 1.3
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_audio_io.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'vimarsha.audio_io'`

- [ ] **Step 3: Write `backend/src/vimarsha/audio_io.py`**

```python
from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf


def write_mp3(waveform: np.ndarray, sample_rate: int, out_path: str) -> None:
    """Write a mono float32 waveform to an MP3 file via ffmpeg (libmp3lame)."""
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=True) as tmp:
        sf.write(tmp.name, waveform, sample_rate, subtype="PCM_16")
        subprocess.run(
            ["ffmpeg", "-y", "-i", tmp.name,
             "-codec:a", "libmp3lame", "-qscale:a", "2", out_path],
            check=True, capture_output=True,
        )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_audio_io.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/audio_io.py backend/tests/test_audio_io.py
git commit -m "feat: MP3 writer via ffmpeg (Plan 2 Task 4)"
```

---

## Task 5: Narrate a bundle — fill audio, timings, and figure ms

**Files:**
- Create: `backend/src/vimarsha/narrate.py`
- Test: `backend/tests/test_narrate.py`

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_narrate.py
from vimarsha.ingest import ingest_epub
from vimarsha.narrate import narrate_bundle, narratable_text
from vimarsha.models import Block
from tests.fakes import FakeSynth


def test_narratable_text_rules():
    assert narratable_text(Block(id="b0", index=0, kind="paragraph", text="Hi")) == "Hi"
    assert narratable_text(Block(id="b0", index=0, kind="heading", level=1, text="T")) == "T"
    # figure narrates its caption
    assert narratable_text(
        Block(id="b0", index=0, kind="figure", src="x.png", caption="Figure 1.")
    ) == "Figure 1."
    # pure image with no caption is skipped
    assert narratable_text(Block(id="b0", index=0, kind="image", src="x.png")) is None


def test_narrate_bundle_fills_audio_timings_and_figure_ms(tmp_path, sample_epub):
    bundle = ingest_epub(str(sample_epub))[0]
    out = narrate_bundle(bundle, FakeSynth(), str(tmp_path), para_gap_ms=200)

    # audio file written and referenced
    assert out.audio == "chap1.mp3"
    assert (tmp_path / "chap1.mp3").exists()

    # every narratable block has a timing; ordering is monotonic
    assert "b0" in out.para_timings  # heading
    assert "b1" in out.para_timings  # first paragraph
    starts = [out.para_timings[b.id][0] for b in out.blocks if b.id in out.para_timings]
    assert starts == sorted(starts)

    # figure ms derived from its span endpoints' paragraph timings
    fig1 = {f.figure_id: f for f in out.figure_map}["b2"]
    assert fig1.start_ms is not None and fig1.end_ms is not None
    assert fig1.start_ms == out.para_timings["b2"][0]   # span start = b2
    assert fig1.end_ms == out.para_timings["b3"][1]     # span end = b3
    assert fig1.end_ms > fig1.start_ms


def test_narrate_resolves_ms_for_unnarrated_span_endpoint(tmp_path):
    # A figure whose own block has no caption (not narrated): ms falls back to neighbors.
    from vimarsha.models import ChapterBundle, Figure
    blocks = [
        Block(id="b0", index=0, kind="paragraph", text="Intro paragraph here."),
        Block(id="b1", index=1, kind="image", src="x.png"),  # not narrated
        Block(id="b2", index=2, kind="paragraph", text="See the image above now."),
    ]
    fig = Figure(figure_id="b1", kind="figure", asset="x.png",
                 start_para="b1", end_para="b1")
    bundle = ChapterBundle(chapter_id="c", title="t", blocks=blocks, figure_map=[fig])
    out = narrate_bundle(bundle, FakeSynth(), str(tmp_path))
    f = out.figure_map[0]
    # b1 not narrated -> start falls back to prior narrated (b0 start), end to next (b2 end)
    assert f.start_ms == out.para_timings["b0"][0]
    assert f.end_ms == out.para_timings["b2"][1]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_narrate.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'vimarsha.narrate'`

- [ ] **Step 3: Write `backend/src/vimarsha/narrate.py`**

```python
from __future__ import annotations

from pathlib import Path
from typing import Optional

import numpy as np

from vimarsha.audio_io import write_mp3
from vimarsha.models import Block, ChapterBundle
from vimarsha.stitch import assemble
from vimarsha.tts import Synthesizer, chunk_text


def narratable_text(block: Block) -> Optional[str]:
    """Return the text to read for a block, or None to skip it."""
    if block.kind in ("heading", "paragraph", "blockquote", "pullquote", "list"):
        return block.text or None
    if block.kind in ("figure", "image", "table"):
        return block.caption or None
    return None


def _synthesize_block(text: str, synth: Synthesizer) -> np.ndarray:
    parts = [synth.synthesize(c) for c in chunk_text(text)]
    if not parts:
        return np.zeros(0, dtype=np.float32)
    return np.concatenate(parts)


def _resolve_ms(
    block_id: str, blocks: list[Block], timings: dict[str, list[int]], edge: str
) -> int:
    """Map a span endpoint block id to a millisecond position.

    If the block itself was narrated, use its own timing; otherwise fall back to
    the nearest narrated block (prior for 'start', following for 'end').
    """
    if block_id in timings:
        return timings[block_id][0 if edge == "start" else 1]
    index_of = {b.id: b.index for b in blocks}
    target = index_of[block_id]
    narrated = sorted((b.index, b.id) for b in blocks if b.id in timings)
    if not narrated:
        return 0
    if edge == "start":
        prior = [bid for (i, bid) in narrated if i <= target]
        chosen = prior[-1] if prior else narrated[0][1]
        return timings[chosen][0]
    after = [bid for (i, bid) in narrated if i >= target]
    chosen = after[0] if after else narrated[-1][1]
    return timings[chosen][1]


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

    waveform, timings = assemble(segments, synth.sample_rate, para_gap_ms)

    audio_name = f"{bundle.chapter_id}.mp3"
    write_mp3(waveform, synth.sample_rate, str(Path(out_dir) / audio_name))

    out = bundle.model_copy(deep=True)
    out.audio = audio_name
    out.para_timings = timings
    for fig in out.figure_map:
        fig.start_ms = _resolve_ms(fig.start_para, out.blocks, timings, "start")
        fig.end_ms = _resolve_ms(fig.end_para, out.blocks, timings, "end")
    return out
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_narrate.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/narrate.py backend/tests/test_narrate.py
git commit -m "feat: narrate_bundle fills audio, timings, figure ms (Plan 2 Task 5)"
```

---

## Task 6: Real Chatterbox adapter (lazy) + manual smoke test

This adapter is **not** exercised by the automated suite (it needs a GPU + the `[tts]` extra). It is imported lazily so the package works without torch installed.

**Files:**
- Modify: `backend/src/vimarsha/tts.py` (append the adapter)

- [ ] **Step 1: Append `ChatterboxSynth` to `backend/src/vimarsha/tts.py`**

```python
class ChatterboxSynth:
    """Real Chatterbox TTS adapter. Requires the `[tts]` extra and a GPU/MPS.

    Lazily imports torch/chatterbox so the rest of the package runs without them.
    """

    def __init__(self, device: str | None = None, audio_prompt_path: str | None = None):
        import torch
        from chatterbox.tts import ChatterboxTTS

        if device is None:
            device = (
                "cuda" if torch.cuda.is_available()
                else "mps" if torch.backends.mps.is_available()
                else "cpu"
            )
        self._model = ChatterboxTTS.from_pretrained(device=device)
        self.sample_rate = self._model.sr
        self._audio_prompt_path = audio_prompt_path

    def synthesize(self, text: str) -> np.ndarray:
        kwargs = {}
        if self._audio_prompt_path:
            kwargs["audio_prompt_path"] = self._audio_prompt_path
        wav = self._model.generate(text, **kwargs)  # torch tensor [1, N]
        return wav.squeeze(0).detach().cpu().numpy().astype("float32")
```

- [ ] **Step 2: Verify the package still imports without torch installed**

Run: `cd backend && uv run python -c "import vimarsha.tts; print('import ok')"`
Expected: prints `import ok` (no torch import error, because it's inside `__init__`).

- [ ] **Step 3: Document the manual smoke test (no automated run)**

Add a file `backend/docs/manual-tts-smoke.md`:

```markdown
# Manual Chatterbox smoke test (needs GPU/MPS)

    cd backend
    uv sync --extra tts
    uv run python - <<'PY'
    from vimarsha.tts import ChatterboxSynth
    from vimarsha.audio_io import write_mp3
    s = ChatterboxSynth()
    wav = s.synthesize("Hello from Chatterbox, reading your book aloud.")
    write_mp3(wav, s.sample_rate, "/tmp/chatterbox_smoke.mp3")
    print("wrote /tmp/chatterbox_smoke.mp3", s.sample_rate)
    PY

Listen to `/tmp/chatterbox_smoke.mp3`. Expect a clear spoken sentence.
```

- [ ] **Step 4: Commit**

```bash
git add backend/src/vimarsha/tts.py backend/docs/manual-tts-smoke.md
git commit -m "feat: lazy ChatterboxSynth adapter + manual smoke test (Plan 2 Task 6)"
```

---

## Task 7: FastAPI import service

Exposes the full pipeline over HTTP: upload an EPUB, narrate a chosen chapter, return the bundle JSON; serve generated audio. The synthesizer is a FastAPI dependency so tests inject `FakeSynth`.

**Files:**
- Create: `backend/src/vimarsha/server.py`
- Test: `backend/tests/test_server.py`

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_server.py
from fastapi.testclient import TestClient

from vimarsha.server import app, get_synth
from tests.fakes import FakeSynth


def _client(tmp_path):
    app.dependency_overrides[get_synth] = lambda: FakeSynth()
    app.state.audio_dir = str(tmp_path)
    return TestClient(app)


def test_import_returns_narrated_bundle_and_audio(tmp_path, sample_epub):
    client = _client(tmp_path)
    with open(sample_epub, "rb") as f:
        resp = client.post("/import?chapter_index=0",
                           files={"file": ("sample.epub", f, "application/epub+zip")})
    assert resp.status_code == 200
    data = resp.json()
    assert data["chapterId"] == "chap1"
    assert data["audio"] == "chap1.mp3"
    assert data["figureMap"][0]["startMs"] is not None
    assert "b0" in data["paraTimings"]

    # the audio file is downloadable
    audio = client.get("/audio/chap1.mp3")
    assert audio.status_code == 200
    assert audio.headers["content-type"] == "audio/mpeg"
    assert len(audio.content) > 0

    app.dependency_overrides.clear()


def test_import_bad_chapter_index_returns_404(tmp_path, sample_epub):
    client = _client(tmp_path)
    with open(sample_epub, "rb") as f:
        resp = client.post("/import?chapter_index=9",
                           files={"file": ("sample.epub", f, "application/epub+zip")})
    assert resp.status_code == 404
    app.dependency_overrides.clear()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_server.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'vimarsha.server'`

- [ ] **Step 3: Write `backend/src/vimarsha/server.py`**

```python
from __future__ import annotations

import tempfile
from pathlib import Path

from fastapi import Depends, FastAPI, File, HTTPException, UploadFile
from fastapi.responses import FileResponse

from vimarsha.ingest import ingest_epub
from vimarsha.narrate import narrate_bundle
from vimarsha.tts import ChatterboxSynth, Synthesizer

app = FastAPI(title="Vimarsha backend")
app.state.audio_dir = tempfile.mkdtemp(prefix="vimarsha-audio-")


def get_synth() -> Synthesizer:
    """Default to the real Chatterbox synth; overridden in tests."""
    return ChatterboxSynth()


@app.post("/import")
async def import_chapter(
    chapter_index: int = 0,
    file: UploadFile = File(...),
    synth: Synthesizer = Depends(get_synth),
):
    with tempfile.NamedTemporaryFile(suffix=".epub", delete=True) as tmp:
        tmp.write(await file.read())
        tmp.flush()
        bundles = ingest_epub(tmp.name)
    if not (0 <= chapter_index < len(bundles)):
        raise HTTPException(status_code=404, detail="chapter_index out of range")
    narrated = narrate_bundle(bundles[chapter_index], synth, app.state.audio_dir)
    return narrated.model_dump(by_alias=True, exclude_none=True)


@app.get("/audio/{name}")
def get_audio(name: str):
    path = Path(app.state.audio_dir) / name
    if not path.is_file():
        raise HTTPException(status_code=404, detail="audio not found")
    return FileResponse(str(path), media_type="audio/mpeg")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_server.py -v`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/server.py backend/tests/test_server.py
git commit -m "feat: FastAPI import service with injectable synth (Plan 2 Task 7)"
```

---

## Task 8: Full suite green + regenerate the shared fixture with audio fields

**Files:** Modify `shared/fixtures/sample-chapter.bundle.json`

- [ ] **Step 1: Run the entire suite**

Run: `cd backend && uv run pytest -v`
Expected: ALL pass (Plan 1 tests + chunk_text 4, stitch 4, audio_io 1, narrate 3, server 2).

- [ ] **Step 2: Regenerate the sample bundle with narration (FakeSynth) so the client plans have a complete example**

Run:
```bash
cd backend && uv run python - <<'PY'
import json, zipfile, tempfile, os
from pathlib import Path
from tests.conftest import CHAPTER_XHTML, CONTAINER_XML, CONTENT_OPF
from tests.fakes import FakeSynth
from vimarsha.ingest import ingest_epub
from vimarsha.narrate import narrate_bundle
d = tempfile.mkdtemp(); p = os.path.join(d, "s.epub")
with zipfile.ZipFile(p, "w") as z:
    z.writestr("mimetype", "application/epub+zip", compress_type=zipfile.ZIP_STORED)
    z.writestr("META-INF/container.xml", CONTAINER_XML)
    z.writestr("OEBPS/content.opf", CONTENT_OPF)
    z.writestr("OEBPS/chap1.xhtml", CHAPTER_XHTML)
b = ingest_epub(p)[0]
b = narrate_bundle(b, FakeSynth(), d)
out = Path("..") / "shared" / "fixtures" / "sample-chapter.bundle.json"
out.write_text(b.model_dump_json(by_alias=True, exclude_none=True, indent=2) + "\n")
print("wrote", out.resolve())
PY
```
Expected: prints the fixture path; the JSON now contains `audio`, `paraTimings`, and `startMs`/`endMs` on figures.

- [ ] **Step 3: Validate the enriched fixture against the schema**

Run:
```bash
cd backend && uv run python - <<'PY'
import json
from jsonschema import validate
schema = json.load(open("../shared/bundle.schema.json"))
data = json.load(open("../shared/fixtures/sample-chapter.bundle.json"))
validate(instance=data, schema=schema)
assert data["audio"] == "chap1.mp3"
assert data["figureMap"][0]["startMs"] is not None
print("valid + narrated")
PY
```
Expected: prints `valid + narrated`

- [ ] **Step 4: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add shared/fixtures/sample-chapter.bundle.json
git commit -m "test: enrich sample bundle fixture with narration fields (Plan 2 Task 8)"
```

---

## Self-Review

**Spec coverage (against §3 Steps 5–6, §2.2 import job, §8 of the design spec):**
- Step 5 narration synthesis (chunking + per-paragraph) → Tasks 1, 5, 6. ✅
- Step 5 stitching into one file + pauses → Tasks 3, 4. ✅
- Step 6 paraTimings + span→ms conversion + emit full bundle → Task 5. ✅
- §2.2 import job exposed → Task 7 (FastAPI). ✅
- §8 TTS segment failure handling → `narrate_bundle` synthesizes per chunk and concatenates; a failing chunk raises and is surfaced by the import endpoint (no silent corruption). Retry/silence-on-failure is a deliberate follow-up, noted here.
- §3 Step 4 LLM fallback for fuzzy mentions → deferred to Plan 6 (shares the LLM layer). Noted, not a Plan 2 gap.

**Placeholder scan:** none — every step has runnable code/commands and expected output.

**Type consistency:** `Synthesizer` protocol (`sample_rate`, `synthesize`) is implemented identically by `FakeSynth` and `ChatterboxSynth`. `assemble`, `samples_to_ms`, `chunk_text`, `narratable_text`, `narrate_bundle`, `write_mp3`, `get_synth` names match across tasks and tests. `paraTimings` values are `list[int]` `[start, end]` consistently in `models.py`, `stitch.py`, `narrate.py`, and the server test. Figure `startMs`/`endMs` aliases match Plan 1's `models.py`. ✅
