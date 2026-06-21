"""The backend audio/image files are a transient cache, but must NOT be deleted on serve: a
client that lost focus mid-download (or retries) would miss the file and report "narration
failed" even though narration succeeded. So a served file is RETAINED (re-fetchable), and stale
files are reaped by `_sweep_cache` (opportunistically, on import) to keep host storage bounded."""
import os
import time
from pathlib import Path

from fastapi.testclient import TestClient

from vimarsha.server import app, get_synth, _sweep_cache
from tests.conftest import import_and_wait
from tests.fakes import FakeSynth


def _client(tmp_path):
    app.dependency_overrides[get_synth] = lambda: FakeSynth()
    app.state.audio_dir = str(tmp_path)
    return TestClient(app)


def test_audio_is_retained_after_serving(tmp_path, sample_epub):
    client = _client(tmp_path)
    body = import_and_wait(client, "?chapter_index=0", sample_epub)
    name = body["bundle"]["audio"]

    first = client.get(f"/audio/{name}")
    assert first.status_code == 200 and first.content
    # Re-fetchable: a backgrounded/retrying client must not miss the file.
    assert client.get(f"/audio/{name}").status_code == 200
    app.dependency_overrides.clear()


def test_image_is_retained_after_serving(tmp_path, sample_epub):
    client = _client(tmp_path)
    body = import_and_wait(client, "?chapter_index=0", sample_epub)
    name = next(f["image"] for f in body["bundle"]["figureMap"] if f.get("image"))

    assert client.get(f"/image/{name}").status_code == 200
    assert client.get(f"/image/{name}").status_code == 200  # retained
    app.dependency_overrides.clear()


def test_sweep_removes_stale_files_but_keeps_fresh(tmp_path):
    app.state.audio_dir = str(tmp_path)
    stale = Path(tmp_path) / "old.mp3"
    fresh = Path(tmp_path) / "new.mp3"
    stale.write_bytes(b"x")
    fresh.write_bytes(b"y")
    old = time.time() - 7200  # 2h ago
    os.utime(stale, (old, old))

    _sweep_cache(ttl_seconds=3600)  # 1h TTL

    assert not stale.exists()   # older than the TTL → reaped
    assert fresh.exists()       # within the TTL → kept (re-fetchable)
