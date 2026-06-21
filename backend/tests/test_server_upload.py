"""The worker→backend out-of-band upload (`PUT /upload/{name}`) that bypasses RunPod's 10MB
job-result cap: the remote worker streams the chapter mp3 + figure images here instead of
inlining base64 in the job result. Secret-gated, basename-sanitized, writes to audio_dir."""
from fastapi.testclient import TestClient

import vimarsha.server as srv


def _client(monkeypatch, tmp_path, secret="s3cret"):
    monkeypatch.setenv("VIMARSHA_INGEST_SECRET", secret)
    srv.app.state.audio_dir = str(tmp_path)
    return TestClient(srv.app)


def test_upload_writes_file_with_valid_secret(monkeypatch, tmp_path):
    c = _client(monkeypatch, tmp_path)
    r = c.put("/upload/chap1.mp3", content=b"MP3BYTES", headers={"X-Ingest-Secret": "s3cret"})
    assert r.status_code == 200
    assert (tmp_path / "chap1.mp3").read_bytes() == b"MP3BYTES"


def test_upload_rejects_bad_secret(monkeypatch, tmp_path):
    c = _client(monkeypatch, tmp_path)
    r = c.put("/upload/chap1.mp3", content=b"x", headers={"X-Ingest-Secret": "wrong"})
    assert r.status_code == 403
    assert not (tmp_path / "chap1.mp3").exists()


def test_upload_503_when_secret_unset(monkeypatch, tmp_path):
    monkeypatch.delenv("VIMARSHA_INGEST_SECRET", raising=False)
    srv.app.state.audio_dir = str(tmp_path)
    c = TestClient(srv.app)
    r = c.put("/upload/chap1.mp3", content=b"x", headers={"X-Ingest-Secret": "anything"})
    assert r.status_code == 503


def test_upload_basenames_path_traversal(monkeypatch, tmp_path):
    c = _client(monkeypatch, tmp_path)
    # a name with path separators is reduced to its basename — never escapes audio_dir
    r = c.put("/upload/sub/dir/evil.mp3", content=b"x", headers={"X-Ingest-Secret": "s3cret"})
    assert r.status_code == 200
    assert (tmp_path / "evil.mp3").read_bytes() == b"x"
