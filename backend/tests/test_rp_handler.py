import base64
import sys
from pathlib import Path

# Make backend/serverless importable as a top-level module.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "serverless"))

import rp_handler  # noqa: E402


def test_handler_narrates_and_returns_bundle_audio(sample_epub, monkeypatch):
    from tests.fakes import FakeBatchSynth

    monkeypatch.setattr(rp_handler, "build_batch_synth", lambda engine, voice: FakeBatchSynth())
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
