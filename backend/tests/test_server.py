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
