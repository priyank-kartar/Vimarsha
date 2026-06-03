# backend/tests/test_block_parser.py
import warnings

from bs4 import XMLParsedAsHTMLWarning

from vimarsha.block_parser import parse_blocks
from tests.conftest import CHAPTER_XHTML

# ---------------------------------------------------------------------------
# Regression: <figure> nested inside <p> must not be lost
# ---------------------------------------------------------------------------

_NESTED_FIGURE_XHTML = """<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<body>
  <h1>Chapter One</h1>
  <p>Some text.</p>
  <p><figure>
    <img src="images/nested.png" alt="nested alt"/>
    <figcaption>Figure 3. A nested figure.</figcaption>
  </figure></p>
  <p>After.</p>
</body>
</html>"""

_SELF_CLOSED_IMG_XHTML = """<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<body>
  <figure>
    <img src="x.png"/>
    <figcaption>Caption.</figcaption>
  </figure>
</body>
</html>"""

_CLASS_PULLQUOTE_XHTML = """<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<body>
  <p>Normal paragraph.</p>
  <blockquote class="pullquote">A classy pullquote.</blockquote>
</body>
</html>"""


def test_figure_nested_inside_p_is_preserved():
    blocks = parse_blocks(_NESTED_FIGURE_XHTML)
    kinds = [b.kind for b in blocks]
    assert "figure" in kinds, f"no figure block found; got kinds={kinds}"
    fig = next(b for b in blocks if b.kind == "figure")
    assert fig.src == "images/nested.png"
    assert fig.caption == "Figure 3. A nested figure."


def test_self_closed_img_in_figure_captures_src():
    blocks = parse_blocks(_SELF_CLOSED_IMG_XHTML)
    fig = next((b for b in blocks if b.kind == "figure"), None)
    assert fig is not None, "figure block not found"
    assert fig.src == "x.png"


def test_pullquote_detected_from_class():
    blocks = parse_blocks(_CLASS_PULLQUOTE_XHTML)
    pq = next((b for b in blocks if b.kind == "pullquote"), None)
    assert pq is not None, "no pullquote block found"
    assert "classy pullquote" in pq.text


def test_no_xml_parsed_as_html_warning():
    """parse_blocks must not trigger XMLParsedAsHTMLWarning."""
    with warnings.catch_warnings():
        warnings.simplefilter("error", XMLParsedAsHTMLWarning)
        parse_blocks(CHAPTER_XHTML)  # should not raise


# ---------------------------------------------------------------------------
# Original tests
# ---------------------------------------------------------------------------

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
