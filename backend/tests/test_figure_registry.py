# backend/tests/test_figure_registry.py
from vimarsha.block_parser import parse_blocks
from vimarsha.figure_registry import build_registry, extract_label
from tests.conftest import CHAPTER_XHTML


def test_extract_label_variants():
    assert extract_label("Figure 1. The four-stroke cycle.") == "Figure 1"
    assert extract_label("Fig. 3.2 the cycle") == "Figure 3.2"
    assert extract_label("Table 4: results") == "Table 4"
    assert extract_label("no label here") is None


def test_build_registry_picks_visual_and_special_blocks():
    blocks = parse_blocks(CHAPTER_XHTML)
    figures = build_registry(blocks)
    # two figures + one pullquote
    kinds = sorted(f.kind for f in figures)
    assert kinds == ["figure", "figure", "pullquote"]


def test_registry_entry_fields():
    blocks = parse_blocks(CHAPTER_XHTML)
    figures = build_registry(blocks)
    by_id = {f.figure_id: f for f in figures}
    fig1 = by_id["b2"]  # first <figure> block
    assert fig1.asset == "images/cycle.png"
    assert fig1.label == "Figure 1"
    assert fig1.caption == "Figure 1. The four-stroke cycle."
    # default span is its own block until mentions widen it
    assert fig1.start_para == "b2" and fig1.end_para == "b2"
    pq = by_id["b5"]
    assert pq.kind == "pullquote"
    assert pq.asset is None
