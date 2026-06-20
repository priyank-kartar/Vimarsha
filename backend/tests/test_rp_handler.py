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


def test_handler_reports_bad_chapter_index(sample_epub):
    epub_b64 = base64.b64encode(Path(sample_epub).read_bytes()).decode()
    out = rp_handler.handler({"input": {"epub_b64": epub_b64, "chapter_index": 9, "voice": "cb_steady"}})
    assert "error" in out and "range" in out["error"]
