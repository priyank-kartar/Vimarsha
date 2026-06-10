import subprocess

from fastapi.testclient import TestClient

from vimarsha.server import app, get_synth
from tests.fakes import FakeSynth


def test_speak_returns_mp3(tmp_path):
    app.dependency_overrides[get_synth] = lambda: FakeSynth()
    client = TestClient(app)
    resp = client.post("/speak", json={"text": "Hello there, reader."})
    assert resp.status_code == 200
    assert resp.headers["content-type"] == "audio/mpeg"
    out = tmp_path / "reply.mp3"
    out.write_bytes(resp.content)
    dur = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", str(out)],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    assert float(dur) > 0
    app.dependency_overrides.clear()


def test_speak_rejects_empty_text():
    app.dependency_overrides[get_synth] = lambda: FakeSynth()
    client = TestClient(app)
    assert client.post("/speak", json={"text": "   "}).status_code == 400
    app.dependency_overrides.clear()


class _BoomSynth:
    sample_rate = 16000

    def synthesize(self, text):  # noqa: ARG002
        raise RuntimeError("synthesis failed")


def test_speak_failure_returns_500_and_leaks_no_temp_file():
    import glob
    import tempfile

    app.dependency_overrides[get_synth] = lambda: _BoomSynth()
    client = TestClient(app, raise_server_exceptions=False)
    before = set(glob.glob(f"{tempfile.gettempdir()}/*.mp3"))
    resp = client.post("/speak", json={"text": "hello"})
    assert resp.status_code == 500
    after = set(glob.glob(f"{tempfile.gettempdir()}/*.mp3"))
    assert after == before  # the temp mp3 was cleaned up on failure
    app.dependency_overrides.clear()
