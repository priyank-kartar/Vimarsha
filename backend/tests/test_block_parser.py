# backend/tests/test_block_parser.py
from vimarsha.block_parser import parse_blocks
from tests.conftest import CHAPTER_XHTML


def test_parse_blocks_kinds_in_order():
    blocks = parse_blocks(CHAPTER_XHTML)
    kinds = [b.kind for b in blocks]
    assert kinds == [
        "heading", "paragraph", "figure", "paragraph", "paragraph",
        "pullquote", "paragraph", "paragraph", "figure",
    ]


def test_parse_blocks_ids_are_sequential_and_indexed():
    blocks = parse_blocks(CHAPTER_XHTML)
    assert [b.id for b in blocks[:3]] == ["b0", "b1", "b2"]
    assert [b.index for b in blocks[:3]] == [0, 1, 2]


def test_figure_block_captures_src_and_caption():
    blocks = parse_blocks(CHAPTER_XHTML)
    fig = blocks[2]
    assert fig.kind == "figure"
    assert fig.src == "images/cycle.png"
    assert fig.alt == "four stroke cycle"
    assert fig.caption == "Figure 1. The four-stroke cycle."


def test_heading_has_level_and_text():
    blocks = parse_blocks(CHAPTER_XHTML)
    assert blocks[0].kind == "heading"
    assert blocks[0].level == 1
    assert blocks[0].text == "The Engine"


def test_pullquote_detected_from_epub_type():
    blocks = parse_blocks(CHAPTER_XHTML)
    pq = blocks[5]
    assert pq.kind == "pullquote"
    assert "Simplicity is the soul" in pq.text
