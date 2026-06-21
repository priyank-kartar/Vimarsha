"""The backend audio/image files are a transient cache: the app downloads each once and keeps
its own copy (stateless backend), so the server deletes a file right after serving it to keep
the host disk from filling up. Mirrors the existing /speak delete-after-serve behavior."""
from fastapi.testclient import TestClient

from vimarsha.server import app, get_synth
from tests.conftest import import_and_wait
from tests.fakes import FakeSynth


def _client(tmp_path):
    app.dependency_overrides[get_synth] = lambda: FakeSynth()
    app.state.audio_dir = str(tmp_path)
    return TestClient(app)


def test_audio_is_deleted_after_it_is_served(tmp_path, sample_epub):
    client = _client(tmp_path)
    body = import_and_wait(client, "?chapter_index=0", sample_epub)
    name = body["bundle"]["audio"]

    first = client.get(f"/audio/{name}")
    assert first.status_code == 200 and first.content  # served once
    assert client.get(f"/audio/{name}").status_code == 404  # purged after serving
    app.dependency_overrides.clear()


def test_image_is_deleted_after_it_is_served(tmp_path, sample_epub):
    client = _client(tmp_path)
    body = import_and_wait(client, "?chapter_index=0", sample_epub)
    name = next(f["image"] for f in body["bundle"]["figureMap"] if f.get("image"))

    assert client.get(f"/image/{name}").status_code == 200  # served once
    assert client.get(f"/image/{name}").status_code == 404   # purged after serving
    app.dependency_overrides.clear()
