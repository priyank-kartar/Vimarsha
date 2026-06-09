from fastapi.testclient import TestClient

from vimarsha.server import app, get_transcriber


class _FakeTranscriber:
    def transcribe(self, audio_path: str) -> str:
        return "hello from the test"


def test_transcribe_returns_text(tmp_path):
    app.dependency_overrides[get_transcriber] = lambda: _FakeTranscriber()
    clip = tmp_path / "memo.m4a"
    clip.write_bytes(b"\x00\x01\x02\x03")
    client = TestClient(app)
    with open(clip, "rb") as f:
        resp = client.post("/transcribe", files={"file": ("memo.m4a", f, "audio/m4a")})
    assert resp.status_code == 200
    assert resp.json() == {"text": "hello from the test"}
    app.dependency_overrides.clear()
