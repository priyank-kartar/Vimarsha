import base64
import sys
from pathlib import Path

# Make backend/serverless importable as a top-level module.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "serverless"))

import pytest  # noqa: E402

import rp_handler  # noqa: E402


@pytest.fixture(autouse=True)
def _clear_synth_cache():
    rp_handler._synth_cache.clear()
    yield
    rp_handler._synth_cache.clear()


def test_warm_worker_loads_synth_once_per_voice(monkeypatch):
    from tests.fakes import FakeSynth

    builds = {"n": 0}

    def _factory(engine):
        def make(voice=None):
            builds["n"] += 1
            return FakeSynth()
        return make

    monkeypatch.setattr(rp_handler, "synth_class", _factory)
    a = rp_handler.build_synth("chatterbox", "cb_steady")
    b = rp_handler.build_synth("chatterbox", "cb_steady")
    assert a is b               # same cached instance — model not reloaded
    assert builds["n"] == 1     # built exactly once for that voice


def test_handler_narrates_and_returns_bundle_audio(sample_epub, monkeypatch):
    from tests.fakes import FakeSynth

    # Sequential synth: synth_class(engine) -> a class whose () returns a FakeSynth.
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


def test_handler_uploads_out_of_band_when_callback_configured(sample_epub, monkeypatch):
    from tests.fakes import FakeSynth

    monkeypatch.setattr(rp_handler, "synth_class", lambda engine: (lambda voice=None: FakeSynth()))
    uploads = []
    monkeypatch.setattr(
        rp_handler, "_upload", lambda url, secret, name, data: uploads.append((url, secret, name, len(data)))
    )
    epub_b64 = base64.b64encode(Path(sample_epub).read_bytes()).decode()
    out = rp_handler.handler(
        {
            "input": {
                "epub_b64": epub_b64,
                "chapter_index": 0,
                "engine": "chatterbox",
                "voice": "cb_steady",
                "result_url": "https://host/upload",
                "ingest_secret": "sek",
            }
        }
    )
    # audio is NOT inlined (would hit the 10MB cap); it was uploaded out-of-band.
    assert "audio_b64" not in out
    assert out["bundle"]["audio"] == "chap1.mp3"
    names = {name for _, _, name, _ in uploads}
    assert "chap1.mp3" in names                              # audio uploaded
    assert any(n.endswith(".png") for n in names)            # figure image uploaded
    assert all(s == "sek" and u == "https://host/upload" for u, s, _, _ in uploads)


def test_upload_sets_user_agent(monkeypatch):
    # Cloudflare 403s urllib's default User-Agent, so _upload MUST send a real one.
    captured = {}

    class _Resp:
        def __enter__(self): return self
        def __exit__(self, *a): return False
        def read(self): return b""

    def _fake_urlopen(req, timeout=None):
        captured["ua"] = req.get_header("User-agent")
        captured["url"] = req.full_url
        captured["secret"] = req.get_header("X-ingest-secret")
        return _Resp()

    monkeypatch.setattr(rp_handler.urllib.request, "urlopen", _fake_urlopen)
    rp_handler._upload("https://host/upload", "sek", "chap1.mp3", b"DATA")
    assert captured["ua"] and "urllib" not in captured["ua"].lower()
    assert captured["url"] == "https://host/upload/chap1.mp3"
    assert captured["secret"] == "sek"


def test_handler_reports_bad_chapter_index(sample_epub):
    epub_b64 = base64.b64encode(Path(sample_epub).read_bytes()).decode()
    out = rp_handler.handler({"input": {"epub_b64": epub_b64, "chapter_index": 9, "voice": "cb_steady"}})
    assert "error" in out and "range" in out["error"]
