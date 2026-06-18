from fastapi.testclient import TestClient

from vimarsha.server import app, get_synth
from tests.conftest import import_and_wait
from tests.fakes import FakeSynth


def _client(tmp_path):
    app.dependency_overrides[get_synth] = lambda: FakeSynth()
    app.state.audio_dir = str(tmp_path)
    return TestClient(app)


def test_import_job_narrates_bundle_and_audio(tmp_path, sample_epub):
    client = _client(tmp_path)
    body = import_and_wait(client, "?chapter_index=0", sample_epub)
    assert body["status"] == "ready"
    data = body["bundle"]
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


def test_import_bad_chapter_index_fails_the_job(tmp_path, sample_epub):
    client = _client(tmp_path)
    body = import_and_wait(client, "?chapter_index=9", sample_epub)
    assert body["status"] == "error"
    assert "range" in body["error"]
    app.dependency_overrides.clear()


def test_import_status_unknown_job_is_404(tmp_path):
    client = _client(tmp_path)
    assert client.get("/import/status/does-not-exist").status_code == 404
    app.dependency_overrides.clear()
