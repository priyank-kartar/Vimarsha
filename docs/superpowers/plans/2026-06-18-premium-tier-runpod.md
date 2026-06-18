# Premium Narration Tier (Chatterbox on RunPod serverless) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a premium narration tier — picking a premium voice (`engine=chatterbox`) routes the narration job, server-side, to Chatterbox on a RunPod serverless endpoint; free voices stay on local Kokoro.

**Architecture:** Reuses the async job seam already merged. `/import` enqueues `_run_import_job`; for a *remote* engine the job calls a `RemoteNarrator` (RunPod `/run` + poll `/status`) instead of a local synth, writes the returned mp3/images into `audio_dir`, and returns the bundle. The RunPod worker runs the **same** `narrate_bundle` pipeline with Chatterbox. Premium voices = expressiveness presets of Chatterbox's base voice. The client is unchanged except for adding premium catalog entries + a badge.

**Tech Stack:** Python 3.13 / FastAPI / httpx / pytest / RunPod serverless SDK (backend + worker); Swift 6 / SwiftUI / Swift Testing (client).

**Source spec:** `docs/superpowers/specs/2026-06-18-vimarsha-premium-tier-runpod-design.md`

**Conventions:** TDD. 5 chunks (A–E); each ends with a `--no-ff` merge to `main` + push. Backend tests: `cd backend && uv run pytest`. Client tests: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' test`. Commit trailer on every commit: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. **Chunk D is a live/manual deploy step** (spends money; not unit-testable).

**Branch for chunk A:** `git checkout main && git pull && git checkout -b feat/premium-presets`

---

## Chunk A — Chatterbox expressiveness presets

### Task A1: `chatterbox_preset` pure map + `ChatterboxSynth` wiring

**Files:**
- Modify: `backend/src/vimarsha/tts.py`
- Test: `backend/tests/test_chatterbox_preset.py`

> `ChatterboxSynth.__init__` loads the model (GPU) so it isn't unit-tested; only the pure
> `chatterbox_preset` map is tested. The `synthesize` wiring is verified live on the worker (Chunk D).

- [ ] **Step 1: Write the failing test** — create `backend/tests/test_chatterbox_preset.py`:

```python
from vimarsha.tts import chatterbox_preset


def test_known_presets_map_to_generate_kwargs():
    assert chatterbox_preset("cb_storyteller") == {"exaggeration": 0.7, "cfg_weight": 0.3}
    assert chatterbox_preset("cb_steady") == {"exaggeration": 0.35, "cfg_weight": 0.5}
    assert chatterbox_preset("cb_intimate") == {"exaggeration": 0.5, "cfg_weight": 0.4}


def test_unknown_or_blank_voice_uses_chatterbox_defaults():
    assert chatterbox_preset("") == {}
    assert chatterbox_preset(None) == {}        # type: ignore[arg-type]
    assert chatterbox_preset("nope") == {}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_chatterbox_preset.py -q`
Expected: FAIL — `ImportError: cannot import name 'chatterbox_preset'`.

- [ ] **Step 3: Add the map** — in `backend/src/vimarsha/tts.py`, ABOVE `class ChatterboxSynth`:

```python
# Premium voices are expressiveness presets of Chatterbox's one base voice — different
# `generate` settings, no audio assets. Tune by ear once the worker is live.
_CHATTERBOX_PRESETS: dict[str, dict] = {
    "cb_storyteller": {"exaggeration": 0.7, "cfg_weight": 0.3},   # dramatic
    "cb_steady": {"exaggeration": 0.35, "cfg_weight": 0.5},        # calm / neutral
    "cb_intimate": {"exaggeration": 0.5, "cfg_weight": 0.4},       # warm / measured
}


def chatterbox_preset(voice: str | None) -> dict:
    """Map a premium voice token to Chatterbox ``generate`` kwargs; unknown/blank → defaults."""
    return dict(_CHATTERBOX_PRESETS.get((voice or "").strip(), {}))
```

- [ ] **Step 4: Wire it into `ChatterboxSynth`** — change `__init__` to store the preset and
`synthesize` to apply it. Replace the `self._audio_prompt_path = audio_prompt_path` line in
`__init__` with:

```python
        self._audio_prompt_path = audio_prompt_path
        self._gen_kwargs = chatterbox_preset(voice)
```

and replace the `kwargs = {}` block in `synthesize` (the lines building `kwargs` before
`self._model.generate`) with:

```python
        kwargs = dict(self._gen_kwargs)
        if self._audio_prompt_path:
            kwargs["audio_prompt_path"] = self._audio_prompt_path
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_chatterbox_preset.py -q`
Expected: PASS.

- [ ] **Step 6: Run the full backend suite** (no regressions; no test loads ChatterboxSynth)

Run: `cd backend && uv run pytest -q`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add backend/src/vimarsha/tts.py backend/tests/test_chatterbox_preset.py
git commit -m "feat(backend): Chatterbox expressiveness presets (premium voices)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task A2: Merge chunk A

- [ ] **Step 1:** `cd backend && uv run pytest -q` → PASS.
- [ ] **Step 2:**

```bash
git checkout main
git merge --no-ff feat/premium-presets -m "Merge: Chatterbox expressiveness presets

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push origin main
```

---

## Chunk B — Remote narrator seam + RunPod client + routing

**Branch:** `git checkout -b feat/premium-remote`

### Task B1: `httpx` dependency + RunPod REST client

**Files:**
- Modify: `backend/pyproject.toml` (add `httpx` to `dependencies`)
- Create: `backend/src/vimarsha/runpod_client.py`
- Test: `backend/tests/test_runpod_client.py`

- [ ] **Step 1: Add httpx to runtime deps** — in `backend/pyproject.toml`, in the
`[project] dependencies = [ ... ]` list, add the line `"httpx>=0.28.1",` (it's currently only a
dev dep). Then `cd backend && uv sync` (no extra needed — httpx is light, pure-Python).

- [ ] **Step 2: Write the failing test** — create `backend/tests/test_runpod_client.py`:

```python
import httpx

from vimarsha.runpod_client import RunPodClient


def _client_with(handler):
    transport = httpx.MockTransport(handler)
    http = httpx.Client(transport=transport)
    return RunPodClient(endpoint_id="ep123", api_key="rpa_test", http=http)


def test_submit_posts_to_run_with_bearer_and_input():
    seen = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen["url"] = str(request.url)
        seen["auth"] = request.headers.get("authorization")
        seen["body"] = request.read().decode()
        return httpx.Response(200, json={"id": "rpjob-1", "status": "IN_QUEUE"})

    rp = _client_with(handler)
    job_id = rp.submit({"epub_b64": "AAA", "chapter_index": 0})
    assert job_id == "rpjob-1"
    assert seen["url"] == "https://api.runpod.ai/v2/ep123/run"
    assert seen["auth"] == "Bearer rpa_test"
    assert '"input"' in seen["body"] and '"epub_b64"' in seen["body"]


def test_status_gets_status_endpoint():
    def handler(request: httpx.Request) -> httpx.Response:
        assert str(request.url) == "https://api.runpod.ai/v2/ep123/status/rpjob-1"
        return httpx.Response(200, json={"status": "COMPLETED", "output": {"ok": True}})

    rp = _client_with(handler)
    body = rp.status("rpjob-1")
    assert body["status"] == "COMPLETED"
    assert body["output"] == {"ok": True}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_runpod_client.py -q`
Expected: FAIL — `ModuleNotFoundError: vimarsha.runpod_client`.

- [ ] **Step 4: Implement** — create `backend/src/vimarsha/runpod_client.py`:

```python
from __future__ import annotations

import httpx


class RunPodClient:
    """Minimal RunPod serverless REST client: submit a job and poll its status.

    https://docs.runpod.io/serverless/endpoints/job-operations — POST /v2/{id}/run,
    GET /v2/{id}/status/{job}. ``http`` is injectable so tests use ``httpx.MockTransport``.
    """

    def __init__(
        self,
        endpoint_id: str,
        api_key: str,
        http: httpx.Client | None = None,
        base_url: str = "https://api.runpod.ai/v2",
    ):
        self._base = f"{base_url}/{endpoint_id}"
        self._headers = {"Authorization": f"Bearer {api_key}"}
        self._http = http or httpx.Client(timeout=60.0)

    def submit(self, payload: dict) -> str:
        resp = self._http.post(f"{self._base}/run", json={"input": payload}, headers=self._headers)
        resp.raise_for_status()
        return resp.json()["id"]

    def status(self, job_id: str) -> dict:
        resp = self._http.get(f"{self._base}/status/{job_id}", headers=self._headers)
        resp.raise_for_status()
        return resp.json()
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_runpod_client.py -q`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/pyproject.toml backend/uv.lock backend/src/vimarsha/runpod_client.py backend/tests/test_runpod_client.py
git commit -m "feat(backend): RunPod serverless REST client (submit + status)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task B2: `RemoteNarrator` seam (`RunPodNarrator` + `FakeRemoteNarrator`)

**Files:**
- Create: `backend/src/vimarsha/remote_narrator.py`
- Test: `backend/tests/test_remote_narrator.py`

- [ ] **Step 1: Write the failing test** — create `backend/tests/test_remote_narrator.py`:

```python
import base64

from vimarsha.remote_narrator import RemoteResult, RunPodNarrator


class _StubClient:
    """Stands in for RunPodClient: returns queued → completed with a canned output."""

    def __init__(self, output):
        self._output = output
        self._polls = 0

    def submit(self, payload):
        self.payload = payload
        return "rpjob-1"

    def status(self, job_id):
        self._polls += 1
        if self._polls < 2:
            return {"status": "IN_PROGRESS"}
        return {"status": "COMPLETED", "output": self._output}


def test_runpod_narrator_returns_decoded_result():
    output = {
        "bundle": {"chapterId": "c1", "audio": "c1.mp3"},
        "audio_b64": base64.b64encode(b"MP3BYTES").decode(),
        "images": {"fig.png": base64.b64encode(b"\x89PNG").decode()},
    }
    stub = _StubClient(output)
    narrator = RunPodNarrator(stub, poll_interval=0.0)
    result = narrator.narrate(b"EPUBDATA", chapter_index=0, engine="chatterbox", voice="cb_steady")
    assert isinstance(result, RemoteResult)
    assert result.bundle["chapterId"] == "c1"
    assert result.audio == b"MP3BYTES"
    assert result.images["fig.png"] == b"\x89PNG"
    # epub was base64-encoded into the submit payload
    assert base64.b64decode(stub.payload["epub_b64"]) == b"EPUBDATA"
    assert stub.payload["voice"] == "cb_steady"


def test_runpod_narrator_raises_on_failed():
    class _Failing(_StubClient):
        def status(self, job_id):
            return {"status": "FAILED", "error": "boom"}

    narrator = RunPodNarrator(_Failing(None), poll_interval=0.0)
    try:
        narrator.narrate(b"x", 0, "chatterbox", "cb_steady")
        raise AssertionError("expected failure")
    except RuntimeError as exc:
        assert "boom" in str(exc)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_remote_narrator.py -q`
Expected: FAIL — module missing.

- [ ] **Step 3: Implement** — create `backend/src/vimarsha/remote_narrator.py`:

```python
from __future__ import annotations

import base64
import time
from dataclasses import dataclass
from typing import Protocol


@dataclass
class RemoteResult:
    """What a remote narration returns: the bundle dict + the mp3 + figure-image bytes."""

    bundle: dict
    audio: bytes
    images: dict[str, bytes]


class RemoteNarrator(Protocol):
    """Narrate one chapter remotely (premium tier). Mirrors the local pipeline's output."""

    def narrate(
        self, epub: bytes, chapter_index: int, engine: str, voice: str | None
    ) -> RemoteResult: ...


class RunPodNarrator:
    """RemoteNarrator over a RunPodClient: submit a job, poll until terminal, decode the output."""

    _TERMINAL_OK = "COMPLETED"
    _TERMINAL_FAIL = {"FAILED", "CANCELLED", "TIMED_OUT"}

    def __init__(self, client, poll_interval: float = 3.0, timeout_s: float = 3 * 60 * 60):
        self._client = client
        self._poll_interval = poll_interval
        self._timeout_s = timeout_s

    def narrate(
        self, epub: bytes, chapter_index: int, engine: str, voice: str | None
    ) -> RemoteResult:
        job_id = self._client.submit(
            {
                "epub_b64": base64.b64encode(epub).decode(),
                "chapter_index": chapter_index,
                "engine": engine,
                "voice": voice,
            }
        )
        deadline = time.monotonic() + self._timeout_s
        while time.monotonic() < deadline:
            body = self._client.status(job_id)
            status = body.get("status")
            if status == self._TERMINAL_OK:
                out = body.get("output") or {}
                return RemoteResult(
                    bundle=out["bundle"],
                    audio=base64.b64decode(out["audio_b64"]),
                    images={k: base64.b64decode(v) for k, v in (out.get("images") or {}).items()},
                )
            if status in self._TERMINAL_FAIL:
                raise RuntimeError(body.get("error") or f"remote narration {status}")
            time.sleep(self._poll_interval)
        raise TimeoutError("remote narration timed out")


class FakeRemoteNarrator:
    """Test double: returns a canned ``RemoteResult`` and records the call."""

    def __init__(self, result: RemoteResult):
        self._result = result
        self.calls: list[tuple] = []

    def narrate(self, epub, chapter_index, engine, voice) -> RemoteResult:
        self.calls.append((epub, chapter_index, engine, voice))
        return self._result
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_remote_narrator.py -q`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/remote_narrator.py backend/tests/test_remote_narrator.py
git commit -m "feat(backend): RemoteNarrator seam (RunPodNarrator + fake)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task B3: Route premium imports to the remote narrator (`server.py`)

**Files:**
- Modify: `backend/src/vimarsha/server.py`
- Test: `backend/tests/test_premium_routing.py`

- [ ] **Step 1: Write the failing test** — create `backend/tests/test_premium_routing.py`:

```python
import base64

from fastapi.testclient import TestClient

import vimarsha.server as server
from vimarsha.remote_narrator import FakeRemoteNarrator, RemoteResult
from tests.conftest import import_and_wait
from tests.fakes import FakeSynth


def _client(tmp_path):
    server.app.dependency_overrides[server.get_synth] = lambda: FakeSynth()
    server.app.state.audio_dir = str(tmp_path)
    return TestClient(server.app)


def test_premium_import_routes_to_remote_and_serves_audio(tmp_path, sample_epub, monkeypatch):
    fake = FakeRemoteNarrator(
        RemoteResult(
            bundle={"chapterId": "c1", "title": "T", "blocks": [], "figureMap": [],
                    "audio": "c1.mp3", "paraTimings": {}},
            audio=b"ID3-FAKE-MP3",
            images={},
        )
    )
    monkeypatch.setattr(server, "_resolve_remote_narrator", lambda engine: fake)
    client = _client(tmp_path)

    body = import_and_wait(client, "?chapter_index=0&engine=chatterbox&voice=cb_steady", sample_epub)
    assert body["status"] == "ready"
    assert body["bundle"]["audio"] == "c1.mp3"
    assert fake.calls and fake.calls[0][2] == "chatterbox"  # engine
    # the remote mp3 was written into audio_dir and is downloadable
    audio = client.get("/audio/c1.mp3")
    assert audio.status_code == 200 and audio.content == b"ID3-FAKE-MP3"
    server.app.dependency_overrides.clear()


def test_free_import_still_uses_local_synth(tmp_path, sample_epub):
    client = _client(tmp_path)
    body = import_and_wait(client, "?chapter_index=0&engine=kokoro&voice=af_heart", sample_epub)
    assert body["status"] == "ready"
    assert body["bundle"]["chapterId"] == "chap1"  # local pipeline ran
    server.app.dependency_overrides.clear()


def test_premium_without_endpoint_configured_errors(tmp_path, sample_epub, monkeypatch):
    monkeypatch.delenv("VIMARSHA_CHATTERBOX_ENDPOINT", raising=False)
    monkeypatch.delenv("RUNPOD_API_KEY", raising=False)
    client = _client(tmp_path)
    with open(sample_epub, "rb") as f:
        resp = client.post("/import?engine=chatterbox&voice=cb_steady",
                           files={"file": ("s.epub", f, "application/epub+zip")})
    assert resp.status_code == 503
    server.app.dependency_overrides.clear()
```

> Note: `engine=kokoro` resolves the dependency-overridden `FakeSynth`, so the free path
> doesn't need a real Kokoro. The premium path is fully faked via `_resolve_remote_narrator`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_premium_routing.py -q`
Expected: FAIL — `_resolve_remote_narrator` doesn't exist; premium isn't routed.

- [ ] **Step 3a: Add routing + config resolution** — in `backend/src/vimarsha/server.py`, add near
the imports: `import base64` is NOT needed here. Add these imports at the top with the others:

```python
from vimarsha.remote_narrator import RemoteNarrator, RunPodNarrator
from vimarsha.runpod_client import RunPodClient
```

Add, just above `def _do_import(`:

```python
# Engines that are NOT run locally — narration is dispatched to a RunPod serverless worker
# (premium tier). `chatterbox` runs remotely even though it's also a local Synthesizer class.
REMOTE_ENGINES = {"chatterbox"}


def _runpod_api_key() -> str | None:
    key = os.environ.get("RUNPOD_API_KEY")
    if key:
        return key
    # Fall back to the cloudflared-style local config the CLI writes.
    cfg = Path.home() / ".runpod" / "config.toml"
    if cfg.is_file():
        import re

        m = re.search(r"apikey\s*=\s*'([^']+)'", cfg.read_text())
        if m:
            return m.group(1)
    return None


def _resolve_remote_narrator(engine: str) -> RemoteNarrator:
    """Build the RunPod narrator from config, or 503 if the premium endpoint isn't set up."""
    endpoint = os.environ.get("VIMARSHA_CHATTERBOX_ENDPOINT")
    key = _runpod_api_key()
    if not endpoint or not key:
        raise HTTPException(status_code=503, detail="premium narration not configured")
    return RunPodNarrator(RunPodClient(endpoint_id=endpoint, api_key=key))


def _do_import_remote(
    data: bytes, chapter_index: int, engine: str, voice: str | None, narrator: RemoteNarrator
) -> dict:
    """Narrate remotely and land the returned mp3 + figure images in the local audio dir."""
    result = narrator.narrate(data, chapter_index, engine, voice)
    out_dir = Path(app.state.audio_dir)
    (out_dir / result.bundle["audio"]).write_bytes(result.audio)
    for name, blob in result.images.items():
        safe = Path(name).name  # never a path
        if safe:
            (out_dir / safe).write_bytes(blob)
    return result.bundle
```

- [ ] **Step 3b: Branch the job + submit** — replace `_run_import_job` and the body of
`import_chapter` in `backend/src/vimarsha/server.py` with:

```python
def _run_import_job(
    job_id: str,
    data: bytes,
    chapter_index: int,
    engine: str | None,
    voice: str | None,
    synth: Synthesizer | None,
    narrator: RemoteNarrator | None,
) -> None:
    try:
        if narrator is not None:
            bundle = _do_import_remote(data, chapter_index, engine or "", voice, narrator)
        else:
            bundle = _do_import(data, chapter_index, synth)
        with _jobs_lock:
            _jobs[job_id] = {"status": "ready", "bundle": bundle}
    except Exception as exc:  # noqa: BLE001 — surfaced to the client as the job's error
        with _jobs_lock:
            _jobs[job_id] = {"status": "error", "error": str(exc)}


@app.post("/import")
async def import_chapter(
    chapter_index: int = 0,
    engine: str | None = None,
    voice: str | None = None,
    file: UploadFile = File(...),
    synth: Synthesizer = Depends(get_synth),
):
    """Enqueue narration of one chapter; returns a job id to poll. Premium engines route to a
    RunPod serverless worker; free engines narrate locally. Validation (engine / premium config)
    happens here synchronously; the heavy work runs on a background thread."""
    is_remote = (engine or "").strip().lower() in REMOTE_ENGINES
    if is_remote:
        narrator: RemoteNarrator | None = _resolve_remote_narrator(engine or "")  # 503 if unset
        synth_for_job: Synthesizer | None = None
    else:
        narrator = None
        synth_for_job = _resolve_synth(engine, voice, synth)  # validates engine → 400
    data = await file.read()
    job_id = uuid.uuid4().hex
    with _jobs_lock:
        _jobs[job_id] = {"status": "pending"}
    threading.Thread(
        target=_run_import_job,
        args=(job_id, data, chapter_index, engine, voice, synth_for_job, narrator),
        daemon=True,
    ).start()
    return {"jobId": job_id, "status": "pending"}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_premium_routing.py -q`
Expected: PASS.

- [ ] **Step 5: Run full backend suite**

Run: `cd backend && uv run pytest -q`
Expected: PASS (existing `/import` tests still green — free path unchanged).

- [ ] **Step 6: Commit**

```bash
git add backend/src/vimarsha/server.py backend/tests/test_premium_routing.py
git commit -m "feat(backend): route premium (chatterbox) imports to RunPod RemoteNarrator

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task B4: Merge chunk B

- [ ] **Step 1:** `cd backend && uv run pytest -q` → PASS.
- [ ] **Step 2:**

```bash
git checkout main
git merge --no-ff feat/premium-remote -m "Merge: premium remote-narrator seam + routing

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push origin main
```

---

## Chunk C — RunPod serverless worker (handler + image)

**Branch:** `git checkout -b feat/premium-worker`

### Task C1: `rp_handler.py` (the serverless handler)

**Files:**
- Create: `backend/serverless/rp_handler.py`
- Test: `backend/tests/test_rp_handler.py`

> `import runpod` is done only under `__main__`, so the handler is unit-testable without the
> RunPod SDK. The test monkeypatches `synth_class` to a `FakeSynth` factory — no GPU needed.

- [ ] **Step 1: Write the failing test** — create `backend/tests/test_rp_handler.py`:

```python
import base64
import sys
from pathlib import Path

# Make backend/serverless importable as a top-level module.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "serverless"))

import rp_handler  # noqa: E402
from tests.fakes import FakeSynth  # noqa: E402


def test_handler_narrates_and_returns_bundle_audio(sample_epub, monkeypatch):
    monkeypatch.setattr(rp_handler, "synth_class", lambda engine: (lambda voice=None: FakeSynth()))
    epub_b64 = base64.b64encode(Path(sample_epub).read_bytes()).decode()
    out = rp_handler.handler(
        {"input": {"epub_b64": epub_b64, "chapter_index": 0, "engine": "chatterbox", "voice": "cb_steady"}}
    )
    assert out["bundle"]["chapterId"] == "chap1"
    assert out["bundle"]["audio"] == "chap1.mp3"
    assert len(base64.b64decode(out["audio_b64"])) > 0
    # figure images for chap1 are returned, base64
    assert any(name.endswith(".png") for name in out["images"])


def test_handler_reports_bad_chapter_index(sample_epub):
    epub_b64 = base64.b64encode(Path(sample_epub).read_bytes()).decode()
    out = rp_handler.handler({"input": {"epub_b64": epub_b64, "chapter_index": 9, "voice": "cb_steady"}})
    assert "error" in out and "range" in out["error"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_rp_handler.py -q`
Expected: FAIL — `serverless/rp_handler.py` missing.

- [ ] **Step 3: Implement** — create `backend/serverless/rp_handler.py`:

```python
"""RunPod serverless handler — narrates one chapter with Chatterbox and returns the bundle.

Reuses the `vimarsha` package (installed in the image), so the worker IS the import pipeline
with Chatterbox. `runpod` is imported only under __main__ so this module is unit-testable.
"""
from __future__ import annotations

import base64
import tempfile
from pathlib import Path

from vimarsha.epub_reader import read_chapters
from vimarsha.figure_images import extract_images
from vimarsha.ingest import ingest_epub
from vimarsha.narrate import narrate_bundle
from vimarsha.tts import synth_class


def handler(event: dict) -> dict:
    inp = event.get("input") or {}
    data = base64.b64decode(inp["epub_b64"])
    chapter_index = int(inp.get("chapter_index", 0))
    engine = inp.get("engine") or "chatterbox"
    voice = inp.get("voice")

    out_dir = tempfile.mkdtemp(prefix="rp-audio-")
    with tempfile.NamedTemporaryFile(suffix=".epub", delete=False) as tmp:
        tmp.write(data)
        tmp.flush()
        epub_path = tmp.name
    try:
        chapters = read_chapters(epub_path)
        bundles = ingest_epub(epub_path)
        if not (0 <= chapter_index < len(bundles)):
            return {"error": "chapter_index out of range"}
        synth = synth_class(engine)(voice=voice)
        narrated = narrate_bundle(bundles[chapter_index], synth, out_dir)
        extract_images(
            epub_path, narrated.chapter_id, chapters[chapter_index].href,
            narrated.figure_map, out_dir,
        )
        bundle = narrated.model_dump(by_alias=True, exclude_none=True)
        audio_b64 = base64.b64encode((Path(out_dir) / bundle["audio"]).read_bytes()).decode()
        images: dict[str, str] = {}
        for fig in bundle.get("figureMap", []):
            name = fig.get("image")
            if name and (Path(out_dir) / name).is_file():
                images[name] = base64.b64encode((Path(out_dir) / name).read_bytes()).decode()
        return {"bundle": bundle, "audio_b64": audio_b64, "images": images}
    finally:
        Path(epub_path).unlink(missing_ok=True)


if __name__ == "__main__":
    import runpod  # only needed when actually running as a worker

    runpod.serverless.start({"handler": handler})
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_rp_handler.py -q`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/serverless/rp_handler.py backend/tests/test_rp_handler.py
git commit -m "feat(backend): RunPod serverless handler (chatterbox narration)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task C2: Serverless extra + Dockerfile

**Files:**
- Modify: `backend/pyproject.toml` (add a `serverless` optional-dependency extra)
- Create: `backend/Dockerfile.serverless`

- [ ] **Step 1: Add the extra** — in `backend/pyproject.toml`, under
`[project.optional-dependencies]`, add:

```toml
serverless = [
    "chatterbox-tts",
    "setuptools<81",
    "torch",
    "torchaudio",
    "runpod>=1.6",
]
```

Then `cd backend && uv sync` (lock update only; don't need to install runpod locally for tests).

- [ ] **Step 2: Create the worker image** — `backend/Dockerfile.serverless` (mirrors
`backend/Dockerfile` but installs the `serverless` extra and runs the handler, not uvicorn):

```dockerfile
# Vimarsha premium narration worker — Chatterbox on RunPod serverless.
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg git curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

WORKDIR /app
COPY pyproject.toml uv.lock .python-version ./
COPY src ./src
COPY serverless ./serverless
RUN uv python install 3.13 && uv sync --extra serverless --frozen

# RunPod invokes the handler; uv run gives it the project venv (with the vimarsha package).
CMD ["uv", "run", "python", "serverless/rp_handler.py"]
```

- [ ] **Step 3: Sanity-check the Dockerfile parses** (no Docker build here — that's Chunk D):

Run: `cd backend && grep -c "rp_handler.py" Dockerfile.serverless`
Expected: `1`.

- [ ] **Step 4: Commit**

```bash
git add backend/pyproject.toml backend/uv.lock backend/Dockerfile.serverless
git commit -m "build(backend): serverless extra + Dockerfile.serverless for the RunPod worker

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task C3: Merge chunk C

- [ ] **Step 1:** `cd backend && uv run pytest -q` → PASS.
- [ ] **Step 2:**

```bash
git checkout main
git merge --no-ff feat/premium-worker -m "Merge: RunPod serverless worker (handler + image)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push origin main
```

---

## Chunk D — Live endpoint deploy + premium narration (MANUAL / spends money)

> Not unit-tested. Requires Docker (daemon running) + the RunPod account (`~/.runpod/config.toml`).
> Each step is a real action with an expected observable result. **Confirm with the user before
> the build/push and endpoint-create steps (they cost money / push to a registry).**

**Branch:** `git checkout -b feat/premium-live`

### Task D1: Build + push the worker image

- [ ] **Step 1: Ensure Docker is running** — `docker version --format '{{.Server.Version}}'`
should print a version. If "Cannot connect to the Docker daemon", start Docker Desktop first.

- [ ] **Step 2: Build the amd64 image** (RunPod is x86_64; build cross-arch on Apple Silicon):

Run: `cd backend && docker buildx build --platform linux/amd64 -f Dockerfile.serverless -t ghcr.io/kartar-sachmeet/vimarsha-worker:latest --load .`
Expected: `naming to ...vimarsha-worker:latest` and exit 0. (This is slow — torch/chatterbox.)

- [ ] **Step 3: Push to a registry** — log in (`echo $GHCR_TOKEN | docker login ghcr.io -u kartar-sachmeet --password-stdin`, using a GitHub PAT with `write:packages`), then:

Run: `docker push ghcr.io/kartar-sachmeet/vimarsha-worker:latest`
Expected: `latest: digest: sha256:… size: …`.

### Task D2: Create the RunPod serverless endpoint

- [ ] **Step 1: Create the endpoint** from the pushed image, GPU = a 16GB card (e.g. RTX A4000 /
L4 / 4090), **1–2 max workers, idle timeout 5s, FlashBoot ON, scale-to-zero (0 min workers)**.
Easiest is the RunPod console (Serverless → New Endpoint → custom image). Or:

Run: `runpodctl create endpoint --name vimarsha-premium --image ghcr.io/kartar-sachmeet/vimarsha-worker:latest --gpu-type "NVIDIA RTX A4000" 2>&1 | tail -10`
(If `runpodctl` lacks endpoint-create, use the console.) Capture the **endpoint id**.

- [ ] **Step 2: Verify the worker boots** — RunPod console → the endpoint → send a test request
with `{"input": {"epub_b64": "<base64 of shared/fixtures/sample.epub>", "chapter_index": 0, "voice": "cb_steady"}}` and confirm it returns `{"bundle": …, "audio_b64": …}` (first run is a cold start — minutes; warm runs are fast).

### Task D3: Wire the backend + narrate a premium chapter end-to-end

- [ ] **Step 1: Point the backend at the endpoint** — restart the local backend with the env set:

Run: `cd backend && pkill -f "uvicorn vimarsha.server"; VIMARSHA_TTS=kokoro VIMARSHA_CHATTERBOX_ENDPOINT=<endpoint_id> RUNPOD_API_KEY=$(grep apikey ~/.runpod/config.toml | sed "s/.*'\(.*\)'.*/\1/") uv run uvicorn vimarsha.server:app --port 8000 &`
Expected: "Application startup complete".

- [ ] **Step 2: Submit a premium import through the tunnel + poll** (small fixture):

Run:
```bash
BASE=https://vimarsha-dev.kartar.ai
JID=$(curl -s -X POST "$BASE/import?chapter_index=0&engine=chatterbox&voice=cb_storyteller" \
  -F "file=@shared/fixtures/sample.epub;type=application/epub+zip" | python3 -c "import json,sys;print(json.load(sys.stdin)['jobId'])")
for i in $(seq 1 120); do sleep 5; S=$(curl -s "$BASE/import/status/$JID"); echo "$S" | python3 -c "import json,sys;print(json.load(sys.stdin)['status'])"; echo "$S" | grep -q '"status": *"ready"' && break; echo "$S" | grep -q '"status": *"error"' && { echo "$S"; break; }; done
```
Expected: `pending` … then `ready` with a bundle whose `audio` downloads via `$BASE/audio/<name>` and plays (Chatterbox voice).

- [ ] **Step 3: Record cost/latency** — append a row to
`plan/08-engineering/runpod-cost-and-buy-trigger.md` with: GPU type, cold-start seconds, warm
$/chapter, and a note that premium narration is live. Commit:

```bash
git add plan/08-engineering/runpod-cost-and-buy-trigger.md
git commit -m "docs(plan): premium serverless endpoint live — cold-start + \$/chapter

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task D4: Merge chunk D

- [ ] **Step 1:**

```bash
git checkout main
git merge --no-ff feat/premium-live -m "Merge: live premium RunPod endpoint + ledger

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push origin main
```

---

## Chunk E — Client: premium voices in the catalog + badge

**Branch:** `git checkout -b feat/premium-client`

### Task E1: Generalize `NarratorVoice` (`kokoroVoice` → `voiceToken`) + `isPremium`

**Files:**
- Modify: `apple/Vimarsha/Library/NarratorVoice.swift`
- Modify: `apple/Vimarsha/Library/LibraryStore.swift:199` (the `voice.kokoroVoice` reference)
- Modify: `apple/VimarshaTests/NarratorVoiceTests.swift:16`
- Test: `apple/VimarshaTests/NarratorVoiceTests.swift`

- [ ] **Step 1: Update the failing test** — in `apple/VimarshaTests/NarratorVoiceTests.swift`,
change the line `#expect(VoiceCatalog.voice(id: "Imogen").kokoroVoice == "bf_emma")` to
`#expect(VoiceCatalog.voice(id: "Imogen").voiceToken == "bf_emma")`, and add a new test:

```swift
    @Test func premiumVoicesAreChatterboxAndFlagged() {
        let premium = VoiceCatalog.all.filter(\.isPremium)
        #expect(premium.count == 3)
        #expect(premium.allSatisfy { $0.engine == "chatterbox" })
        #expect(Set(premium.map(\.voiceToken)) == ["cb_storyteller", "cb_steady", "cb_intimate"])
        // free voices stay kokoro + not premium
        #expect(VoiceCatalog.all.filter { !$0.isPremium }.allSatisfy { $0.engine == "kokoro" })
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' -only-testing:VimarshaTests/NarratorVoiceTests test 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"`
Expected: build error — `voiceToken` / `isPremium` not found.

- [ ] **Step 3: Update `NarratorVoice.swift`** — replace the whole file with:

```swift
import Foundation

/// One selectable narrator voice. Display name (`id`) is the global name the reader sees;
/// `voiceToken` is the backend voice value sent as `?voice=`; `engine` selects the tier/route
/// (`kokoro` = local/free, `chatterbox` = premium on RunPod). `isPremium` flags the premium tier.
nonisolated struct NarratorVoice: Identifiable, Equatable, Sendable {
    let id: String          // e.g. "Aria"
    let voiceToken: String  // backend ?voice= value, e.g. "af_heart" / "cb_storyteller"
    let engine: String      // "kokoro" | "chatterbox"
    var isPremium: Bool = false

    /// `Resources/VoicePreviews/<voiceToken>.mp3` — keyed on the stable backend token so a
    /// rename of the display name never orphans a clip. (Premium voices have no bundled clip
    /// in this slice — the picker hides their preview button.)
    var previewResource: String { voiceToken }
}

/// The curated, client-owned catalog (the single source of truth for names + default).
nonisolated enum VoiceCatalog {
    static let all: [NarratorVoice] = [
        NarratorVoice(id: "Aria",   voiceToken: "af_heart",   engine: "kokoro"),
        NarratorVoice(id: "Stella", voiceToken: "af_bella",   engine: "kokoro"),
        NarratorVoice(id: "Milo",   voiceToken: "am_michael", engine: "kokoro"),
        NarratorVoice(id: "Imogen", voiceToken: "bf_emma",    engine: "kokoro"),
        NarratorVoice(id: "Edmund", voiceToken: "bm_george",  engine: "kokoro"),
        NarratorVoice(id: "Storyteller", voiceToken: "cb_storyteller", engine: "chatterbox", isPremium: true),
        NarratorVoice(id: "Steady",      voiceToken: "cb_steady",      engine: "chatterbox", isPremium: true),
        NarratorVoice(id: "Intimate",    voiceToken: "cb_intimate",    engine: "chatterbox", isPremium: true),
    ]
    static let defaultId = "Aria"
    static func voice(id: String) -> NarratorVoice {
        all.first { $0.id == id } ?? all.first { $0.id == defaultId } ?? all[0]
    }
}
```

- [ ] **Step 4: Fix the `LibraryStore` reference** — in `apple/Vimarsha/Library/LibraryStore.swift`
line ~199, change `voice.kokoroVoice` to `voice.voiceToken` (the tuple element feeding
`download(... voice: kokoroVoice)` — the local var name can stay `kokoroVoice` or be renamed; the
member access is what changes). Concretely the line:

```swift
            (book.epubPath, book.id, chapter.index, chapter.id, book.voiceId, voice.voiceToken, voice.engine)
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' -only-testing:VimarshaTests/NarratorVoiceTests test 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"`
Expected: `** TEST SUCCEEDED **`. (The `VoicePreviewResourceTests` still passes — premium voices have no clip but that test only iterates… see Step 6.)

- [ ] **Step 6: Keep the preview-resource test honest** — `VoicePreviewResourceTests` asserts every
catalog voice has a bundled clip, which is now false for premium. In
`apple/VimarshaTests/VoicePreviewResourceTests.swift`, scope the loop to non-premium voices:
change `for voice in VoiceCatalog.all {` to `for voice in VoiceCatalog.all where !voice.isPremium {`.

- [ ] **Step 7: Run the full suite + commit**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' test 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)"`
Expected: `** TEST SUCCEEDED **`.

```bash
git add apple/Vimarsha/Library/NarratorVoice.swift apple/Vimarsha/Library/LibraryStore.swift apple/VimarshaTests/NarratorVoiceTests.swift apple/VimarshaTests/VoicePreviewResourceTests.swift
git commit -m "feat(apple): voiceToken + isPremium; 3 premium Chatterbox voices in the catalog

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task E2: "Premium" badge in the voice picker; hide preview for premium

**Files:**
- Modify: `apple/Vimarsha/Library/VoicePickerView.swift`

- [ ] **Step 1: Add the badge + gate the preview button** — in `VoicePickerView.swift`'s
`row(_:)`, between the name `Text(voice.id)` and the trailing `Spacer`, add a badge for premium
voices, and wrap the preview `Button` so it only shows for non-premium voices. Replace the row's
`HStack { … }` body so it reads:

```swift
        HStack(spacing: 14) {
            Image(systemName: voice.id == currentVoiceId ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 19))
                .foregroundStyle(voice.id == currentVoiceId ? Palette.aqua.opacity(0.9) : Palette.textPrimary.opacity(0.3))
            Text(voice.id)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(Palette.textPrimary)
            if voice.isPremium {
                Text("PREMIUM")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(Palette.butter)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Palette.butter.opacity(0.16)))
            }
            Spacer(minLength: 12)
            if !voice.isPremium {
                Button { onPreview(voice) } label: {
                    Image(systemName: "play.circle").font(.system(size: 19)).foregroundStyle(Palette.sky)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Preview \(voice.id)")
            }
        }
```

(If `Palette.butter` isn't a defined token, use `Palette.sky` — confirm against `Palette.swift`.)

- [ ] **Step 2: Build to verify**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' build 2>&1 | grep -E "error:|\*\* BUILD"`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add apple/Vimarsha/Library/VoicePickerView.swift
git commit -m "feat(apple): Premium badge in the voice picker; no preview for premium voices

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task E3: Merge chunk E + live smoke

- [ ] **Step 1:** `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' test 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)"` → SUCCEEDED.
- [ ] **Step 2: Live smoke** (endpoint from Chunk D live): in the app, open Narrator, pick a
**Premium** voice (badge shown, no preview), narrate a chapter, confirm it comes back in the
Chatterbox voice (routed through RunPod).
- [ ] **Step 3:**

```bash
git checkout main
git merge --no-ff feat/premium-client -m "Merge: premium voices in the client catalog + badge

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push origin main
```

---

## Self-review notes (resolved)

- **Spec coverage:** presets (A1) · `engine=chatterbox`→remote routing + REMOTE_ENGINES (B3) ·
  RunPod `/run`+poll client/narrator (B1–B2) · worker full-pipeline handler + image (C1–C2) ·
  config (endpoint+key, 503 when unset) (B3) · live endpoint + ledger (D) · premium catalog voices +
  badge, no-gating (E) · `/speak` premium and billing explicitly out of scope. All present.
- **Type consistency:** `RemoteResult{bundle,audio,images}`, `RemoteNarrator.narrate(epub,chapter_index,engine,voice)`,
  `RunPodClient.submit/status`, `_resolve_remote_narrator(engine)`, `_do_import_remote(...)`,
  `chatterbox_preset(voice)`, `NarratorVoice.voiceToken/isPremium`, `cb_storyteller/cb_steady/cb_intimate`
  are used consistently across tasks and match the backend preset keys.
- **Confirm at execution time (not placeholders — verify against current code):** `Palette` has a
  `butter` token (else use `sky`); the exact `VoicePreviewResourceTests` loop line; `runpodctl`
  endpoint-create capability (fall back to the console); GHCR namespace/registry of your choice.
```
