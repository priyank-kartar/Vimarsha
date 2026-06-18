from fastapi.testclient import TestClient

from vimarsha.server import app, get_synth
from tests.conftest import import_and_wait
from tests.fakes import FakeSynth


def _client(tmp_path):
    app.dependency_overrides[get_synth] = lambda: FakeSynth()
    app.state.audio_dir = str(tmp_path)
    return TestClient(app)


def test_import_fills_figure_image_and_serves_it(tmp_path, sample_epub):
    client = _client(tmp_path)
    body = import_and_wait(client, "?chapter_index=0", sample_epub)
    assert body["status"] == "ready"
    figures = body["bundle"]["figureMap"]
    img = next(fig for fig in figures if fig["figureId"] == "b2")
    assert img["image"]  # filename present

    got = client.get(f"/image/{img['image']}")
    assert got.status_code == 200
    assert got.content[:4] == b"\x89PNG"
    app.dependency_overrides.clear()


def test_image_path_traversal_is_rejected(tmp_path):
    client = _client(tmp_path)
    assert client.get("/image/..%2f..%2fetc%2fpasswd").status_code == 404
    app.dependency_overrides.clear()
