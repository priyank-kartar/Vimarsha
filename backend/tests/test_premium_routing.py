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
    assert fake.calls and fake.calls[0][2] == "chatterbox"
    audio = client.get("/audio/c1.mp3")
    assert audio.status_code == 200 and audio.content == b"ID3-FAKE-MP3"
    server.app.dependency_overrides.clear()


def test_free_import_still_uses_local_synth(tmp_path, sample_epub, monkeypatch):
    # A free engine maps to a local Synthesizer (FakeSynth here) — no remote dispatch.
    server._synth_cache.clear()
    monkeypatch.setattr(server, "synth_class", lambda name: FakeSynth)
    client = _client(tmp_path)
    body = import_and_wait(client, "?chapter_index=0&engine=kokoro&voice=af_heart", sample_epub)
    assert body["status"] == "ready"
    assert body["bundle"]["chapterId"] == "chap1"
    server.app.dependency_overrides.clear()
    server._synth_cache.clear()


def test_premium_import_does_not_construct_local_synth(tmp_path, sample_epub, monkeypatch):
    # A premium (remote) import must never load a local TTS model — a premium-only backend has
    # none installed. The injected default synth is a _LazySynth whose factory explodes if used.
    fake = FakeRemoteNarrator(
        RemoteResult(
            bundle={"chapterId": "c1", "title": "T", "blocks": [], "figureMap": [],
                    "audio": "c1.mp3", "paraTimings": {}},
            audio=b"ID3", images={},
        )
    )
    monkeypatch.setattr(server, "_resolve_remote_narrator", lambda engine: fake)

    def _boom():
        raise RuntimeError("local TTS must not load for a premium import")

    server.app.dependency_overrides[server.get_synth] = lambda: server._LazySynth(_boom)
    server.app.state.audio_dir = str(tmp_path)
    client = TestClient(server.app)
    body = import_and_wait(client, "?chapter_index=0&engine=chatterbox&voice=cb_steady", sample_epub)
    assert body["status"] == "ready"  # never raised → the local synth factory was never called
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
