# backend/tests/test_epub_reader.py
from vimarsha.epub_reader import read_chapters


def test_read_chapters_returns_spine_order_with_html(sample_epub):
    chapters = read_chapters(str(sample_epub))
    assert len(chapters) == 1
    ch = chapters[0]
    assert ch.chapter_id == "chap1"
    assert "<h1>The Engine</h1>" in ch.html
    assert "Figure 1" in ch.html
