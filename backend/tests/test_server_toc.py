from fastapi.testclient import TestClient

from vimarsha.server import app


def test_toc_returns_book_meta_and_chapters(sample_epub):
    client = TestClient(app)
    with open(sample_epub, "rb") as f:
        resp = client.post(
            "/toc",
            files={"file": ("sample.epub", f, "application/epub+zip")},
        )
    assert resp.status_code == 200
    data = resp.json()
    assert data["book"] == {"title": "Test Book", "author": "Ada Lovelace"}
    assert data["chapters"] == [
        {"index": 0, "chapterId": "chap1", "title": "The Engine"}
    ]


def test_toc_does_not_require_a_synth(sample_epub):
    # /toc must not construct ChatterboxSynth (no GPU in CI). No dependency override here;
    # if it tried to build the real synth, this test would error on import/torch.
    client = TestClient(app)
    with open(sample_epub, "rb") as f:
        resp = client.post("/toc", files={"file": ("s.epub", f, "application/epub+zip")})
    assert resp.status_code == 200
