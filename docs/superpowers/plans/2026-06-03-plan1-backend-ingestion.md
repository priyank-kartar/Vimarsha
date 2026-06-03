# Plan 1 — Shared Contract + Backend Ingestion Core (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn an EPUB into a validated `ChapterBundle` JSON (typed block model + figure map with paragraph-range spans), with zero ML dependencies, fully tested against EPUB fixtures.

**Architecture:** A small Python package `vimarsha` exposing a pure pipeline: `read_chapters` (EPUB → ordered chapter HTML) → `parse_blocks` (XHTML → typed blocks) → `build_registry` (blocks → figure entries) → `detect_spans` (rule-based reference matching → paragraph spans) → `ingest_chapter` (assemble a `ChapterBundle`). Pydantic models define the shared contract; a script exports it to `/shared/bundle.schema.json` for the Flutter client.

**Tech Stack:** Python 3.13, `uv` (env + deps), `pydantic` v2 (models/schema), `ebooklib` (EPUB container/spine), `beautifulsoup4` + `lxml` (XHTML), `pytest`.

---

## File Structure

```
/backend
  pyproject.toml                 # uv project, deps, pytest config
  src/vimarsha/__init__.py
  src/vimarsha/models.py         # Block, Figure, ChapterBundle (pydantic, camelCase JSON)
  src/vimarsha/epub_reader.py    # EPUB -> ordered Chapter(html) list
  src/vimarsha/block_parser.py   # chapter HTML -> list[Block]
  src/vimarsha/figure_registry.py# blocks -> list[Figure] (asset/caption/label/kind)
  src/vimarsha/mention_detector.py # blocks+figures -> figures with paragraph spans
  src/vimarsha/ingest.py         # orchestrate -> ChapterBundle ; ingest_epub()
  scripts/export_schema.py       # ChapterBundle JSON Schema -> /shared/bundle.schema.json
  tests/conftest.py              # builds a minimal EPUB fixture on the fly
  tests/test_models.py
  tests/test_epub_reader.py
  tests/test_block_parser.py
  tests/test_figure_registry.py
  tests/test_mention_detector.py
  tests/test_ingest.py
/shared
  bundle.schema.json             # generated; the cross-language contract
```

Each module has one responsibility. `models.py` is the only place types are defined; every other module imports from it.

---

## Task 0: Project scaffold

**Files:**
- Create: `backend/pyproject.toml`, `backend/src/vimarsha/__init__.py`, `.gitignore`

- [ ] **Step 1: Initialize git + backend project**

Run from repo root `/Users/sachmeet/Documents/Kartar3/Vimarsha`:

```bash
git init
cd backend
uv init --package --name vimarsha --python 3.13 .
uv add pydantic ebooklib beautifulsoup4 lxml
uv add --dev pytest
```

- [ ] **Step 2: Configure pytest + package layout in `backend/pyproject.toml`**

Ensure these sections exist (merge with what `uv init` produced; keep the generated `[project]` name = `vimarsha`):

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-q"

[tool.hatch.build.targets.wheel]
packages = ["src/vimarsha"]
```

- [ ] **Step 3: Create `.gitignore` at repo root**

```gitignore
# Python
backend/.venv/
__pycache__/
*.pyc
.pytest_cache/

# Brainstorm companion
.superpowers/

# Build output
backend/dist/
```

- [ ] **Step 4: Verify the toolchain runs**

Run: `cd backend && uv run python -c "import pydantic, ebooklib, bs4, lxml; print('ok')"`
Expected: prints `ok`

- [ ] **Step 5: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add -A
git commit -m "chore: scaffold backend python project (Plan 1 Task 0)"
```

---

## Task 1: Shared data models

**Files:**
- Create: `backend/src/vimarsha/models.py`
- Test: `backend/tests/test_models.py`

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_models.py
import json
from vimarsha.models import Block, Figure, ChapterBundle


def test_block_roundtrip_uses_camelcase():
    b = Block(id="b0", index=0, kind="paragraph", text="Hello")
    data = b.model_dump(by_alias=True, exclude_none=True)
    assert data == {"id": "b0", "index": 0, "kind": "paragraph", "text": "Hello"}


def test_figure_camelcase_aliases():
    f = Figure(
        figure_id="b3", kind="diagram", asset="img/d.png",
        caption="Figure 3.2 The cycle", label="Figure 3.2",
        start_para="b3", end_para="b5",
    )
    data = f.model_dump(by_alias=True, exclude_none=True)
    assert data["figureId"] == "b3"
    assert data["startPara"] == "b3"
    assert data["endPara"] == "b5"
    assert "startMs" not in data  # ms filled later in Plan 2


def test_bundle_serializes_and_parses():
    bundle = ChapterBundle(
        chapter_id="ch1", title="Intro",
        blocks=[Block(id="b0", index=0, kind="heading", level=1, text="Intro")],
        figure_map=[],
    )
    s = bundle.model_dump_json(by_alias=True, exclude_none=True)
    parsed = ChapterBundle.model_validate_json(s)
    assert parsed.chapter_id == "ch1"
    assert json.loads(s)["chapterId"] == "ch1"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_models.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'vimarsha.models'`

- [ ] **Step 3: Write `backend/src/vimarsha/models.py`**

```python
from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

BlockKind = Literal[
    "heading", "paragraph", "image", "figure",
    "blockquote", "pullquote", "table", "list",
]
FigureKind = Literal["figure", "diagram", "table", "pullquote"]


class Block(BaseModel):
    """One ordered, typed unit of a chapter in reading order."""
    model_config = ConfigDict(populate_by_name=True)

    id: str
    index: int
    kind: BlockKind
    text: Optional[str] = None
    level: Optional[int] = None          # heading level 1-6
    src: Optional[str] = None            # image/figure asset href
    alt: Optional[str] = None
    caption: Optional[str] = None
    html: Optional[str] = None           # raw html for table/list


class Figure(BaseModel):
    """A visual/special-display element and the paragraph span it belongs to."""
    model_config = ConfigDict(populate_by_name=True)

    figure_id: str = Field(alias="figureId")
    kind: FigureKind
    asset: Optional[str] = None          # None for pullquote
    caption: Optional[str] = None
    label: Optional[str] = None          # e.g. "Figure 3.2"
    start_para: str = Field(alias="startPara")
    end_para: str = Field(alias="endPara")
    start_ms: Optional[int] = Field(default=None, alias="startMs")  # filled in Plan 2
    end_ms: Optional[int] = Field(default=None, alias="endMs")      # filled in Plan 2


class ChapterBundle(BaseModel):
    """The cross-language contract between backend and Flutter client."""
    model_config = ConfigDict(populate_by_name=True)

    chapter_id: str = Field(alias="chapterId")
    title: str
    blocks: list[Block]
    figure_map: list[Figure] = Field(alias="figureMap")
    audio: Optional[str] = None                                     # filled in Plan 2
    para_timings: dict[str, list[int]] = Field(                     # filled in Plan 2
        default_factory=dict, alias="paraTimings"
    )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_models.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/models.py backend/tests/test_models.py
git commit -m "feat: shared ChapterBundle/Block/Figure models (Plan 1 Task 1)"
```

---

## Task 2: EPUB fixture builder (test infrastructure)

A real EPUB is a zip with `mimetype`, `META-INF/container.xml`, an OPF (spine), and XHTML files. This fixture is reused by later tests. The chapter deliberately contains: a heading, paragraphs, a `<figure>` with `<figcaption>` labeled "Figure 1", a textual reference to it, a second figure referenced later, and a pull-quote.

**Files:**
- Create: `backend/tests/conftest.py`

- [ ] **Step 1: Write `backend/tests/conftest.py`**

```python
import zipfile
from pathlib import Path

import pytest

CHAPTER_XHTML = """<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml"
      xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>The Engine</title></head>
<body>
  <h1>The Engine</h1>
  <p>The principle is simple and elegant.</p>
  <figure>
    <img src="images/cycle.png" alt="four stroke cycle"/>
    <figcaption>Figure 1. The four-stroke cycle.</figcaption>
  </figure>
  <p>As shown in Figure 1, each stroke drives the next.</p>
  <p>The crankshaft then converts linear motion into rotation.</p>
  <blockquote epub:type="pullquote">Simplicity is the soul of efficiency.</blockquote>
  <p>Later designs improved on this; see Figure 2 for the variant.</p>
  <p>That variant fires every revolution.</p>
  <figure>
    <img src="images/variant.png" alt="two stroke variant"/>
    <figcaption>Figure 2. The two-stroke variant.</figcaption>
  </figure>
</body>
</html>
"""

CONTAINER_XML = """<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
"""

CONTENT_OPF = """<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="bookid">urn:uuid:test-book-1</dc:identifier>
    <dc:title>Test Book</dc:title>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="chap1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="chap1"/>
  </spine>
</package>
"""


@pytest.fixture
def sample_epub(tmp_path: Path) -> Path:
    """Write a minimal, valid single-chapter EPUB and return its path."""
    path = tmp_path / "sample.epub"
    with zipfile.ZipFile(path, "w") as z:
        # mimetype must be first and stored (uncompressed)
        z.writestr("mimetype", "application/epub+zip", compress_type=zipfile.ZIP_STORED)
        z.writestr("META-INF/container.xml", CONTAINER_XML)
        z.writestr("OEBPS/content.opf", CONTENT_OPF)
        z.writestr("OEBPS/chap1.xhtml", CHAPTER_XHTML)
    return path
```

- [ ] **Step 2: Verify the fixture loads in ebooklib**

Run:
```bash
cd backend && uv run python - <<'PY'
import zipfile, tempfile, os
from tests.conftest import CHAPTER_XHTML, CONTAINER_XML, CONTENT_OPF
import ebooklib
from ebooklib import epub
d = tempfile.mkdtemp(); p = os.path.join(d, "s.epub")
with zipfile.ZipFile(p, "w") as z:
    z.writestr("mimetype", "application/epub+zip", compress_type=zipfile.ZIP_STORED)
    z.writestr("META-INF/container.xml", CONTAINER_XML)
    z.writestr("OEBPS/content.opf", CONTENT_OPF)
    z.writestr("OEBPS/chap1.xhtml", CHAPTER_XHTML)
b = epub.read_epub(p)
print("spine:", b.spine)
PY
```
Expected: prints a spine list containing `('chap1', ...)` with no exception.

- [ ] **Step 3: Commit**

```bash
git add backend/tests/conftest.py
git commit -m "test: minimal EPUB fixture builder (Plan 1 Task 2)"
```

---

## Task 3: EPUB reader — ordered chapters

**Files:**
- Create: `backend/src/vimarsha/epub_reader.py`
- Test: `backend/tests/test_epub_reader.py`

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_epub_reader.py
from vimarsha.epub_reader import read_chapters


def test_read_chapters_returns_spine_order_with_html(sample_epub):
    chapters = read_chapters(str(sample_epub))
    assert len(chapters) == 1
    ch = chapters[0]
    assert ch.chapter_id == "chap1"
    assert "<h1>The Engine</h1>" in ch.html
    assert "Figure 1" in ch.html
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_epub_reader.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'vimarsha.epub_reader'`

- [ ] **Step 3: Write `backend/src/vimarsha/epub_reader.py`**

```python
from __future__ import annotations

from dataclasses import dataclass

import ebooklib
from ebooklib import epub


@dataclass
class Chapter:
    chapter_id: str
    title: str
    html: str


def read_chapters(epub_path: str) -> list[Chapter]:
    """Read an EPUB and return its document chapters in spine (reading) order."""
    book = epub.read_epub(epub_path)
    chapters: list[Chapter] = []
    for idref, _linear in book.spine:
        item = book.get_item_with_id(idref)
        if item is None or item.get_type() != ebooklib.ITEM_DOCUMENT:
            continue
        html = item.get_content().decode("utf-8")
        chapters.append(
            Chapter(chapter_id=idref, title=item.get_name(), html=html)
        )
    return chapters
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_epub_reader.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/epub_reader.py backend/tests/test_epub_reader.py
git commit -m "feat: EPUB reader returns chapters in spine order (Plan 1 Task 3)"
```

---

## Task 4: Block parser — XHTML to typed blocks

**Files:**
- Create: `backend/src/vimarsha/block_parser.py`
- Test: `backend/tests/test_block_parser.py`

- [ ] **Step 1: Write the failing test**

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_block_parser.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'vimarsha.block_parser'`

- [ ] **Step 3: Write `backend/src/vimarsha/block_parser.py`**

```python
from __future__ import annotations

import itertools
from typing import Optional

from bs4 import BeautifulSoup, Tag

from vimarsha.models import Block

_HEADINGS = {"h1", "h2", "h3", "h4", "h5", "h6"}
# Container tags we descend INTO without emitting a block of their own.
_CONTAINERS = {"body", "section", "div", "main", "article", "header", "footer"}


def _classify(el: Tag) -> Optional[str]:
    """Return a BlockKind for a recognized block element, else None."""
    etype = (el.get("epub:type") or "").lower()
    classes = " ".join(el.get("class", [])).lower()
    if any(k in etype or k in classes for k in ("pullquote", "epigraph")):
        return "pullquote"
    name = el.name
    if name in _HEADINGS:
        return "heading"
    if name == "p":
        return "paragraph"
    if name == "figure":
        return "figure"
    if name == "img":
        return "image"
    if name == "blockquote":
        return "blockquote"
    if name == "table":
        return "table"
    if name in ("ul", "ol"):
        return "list"
    return None


def _make_block(el: Tag, kind: str, idx: int) -> Block:
    bid = f"b{idx}"
    if kind == "heading":
        return Block(id=bid, index=idx, kind="heading",
                     level=int(el.name[1]), text=el.get_text(" ", strip=True))
    if kind == "paragraph":
        return Block(id=bid, index=idx, kind="paragraph",
                     text=el.get_text(" ", strip=True))
    if kind == "image":
        return Block(id=bid, index=idx, kind="image",
                     src=el.get("src"), alt=el.get("alt"))
    if kind == "figure":
        img = el.find("img")
        cap = el.find("figcaption")
        return Block(
            id=bid, index=idx, kind="figure",
            src=img.get("src") if img else None,
            alt=img.get("alt") if img else None,
            caption=cap.get_text(" ", strip=True) if cap else None,
        )
    if kind in ("blockquote", "pullquote"):
        return Block(id=bid, index=idx, kind=kind, text=el.get_text(" ", strip=True))
    if kind == "table":
        cap = el.find("caption")
        return Block(id=bid, index=idx, kind="table", html=str(el),
                     caption=cap.get_text(" ", strip=True) if cap else None)
    # list
    return Block(id=bid, index=idx, kind="list", html=str(el),
                 text=el.get_text(" ", strip=True))


def _walk(node: Tag, blocks: list[Block], counter: "itertools.count") -> None:
    for child in node.children:
        if not isinstance(child, Tag):
            continue
        kind = _classify(child)
        if kind is None:
            if child.name in _CONTAINERS:
                _walk(child, blocks, counter)
            continue
        blocks.append(_make_block(child, kind, next(counter)))


def parse_blocks(html: str) -> list[Block]:
    """Parse chapter XHTML into typed blocks in document (reading) order."""
    soup = BeautifulSoup(html, "lxml")
    root = soup.body or soup
    blocks: list[Block] = []
    _walk(root, blocks, itertools.count())
    return blocks
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_block_parser.py -v`
Expected: PASS (5 passed)

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/block_parser.py backend/tests/test_block_parser.py
git commit -m "feat: XHTML block parser with figure/pullquote detection (Plan 1 Task 4)"
```

---

## Task 5: Figure registry

Builds `Figure` entries from visual/special blocks. Each entry's span defaults to its own block (`start_para == end_para == block.id`); Task 6 widens spans from textual references.

**Files:**
- Create: `backend/src/vimarsha/figure_registry.py`
- Test: `backend/tests/test_figure_registry.py`

- [ ] **Step 1: Write the failing test**

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_figure_registry.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'vimarsha.figure_registry'`

- [ ] **Step 3: Write `backend/src/vimarsha/figure_registry.py`**

```python
from __future__ import annotations

import re
from typing import Optional

from vimarsha.models import Block, Figure

# Captures a label in a caption: "Figure 3.2", "Fig. 4", "Table 4", "Diagram 1".
_LABEL_RE = re.compile(
    r"\b(fig(?:ure)?|table|diagram|chart|plate)\.?\s*([0-9]+(?:\.[0-9]+)?)",
    re.IGNORECASE,
)

# Display canonicalization: the word as shown to the user.
_DISPLAY = {
    "fig": "Figure", "figure": "Figure", "table": "Table",
    "diagram": "Diagram", "chart": "Chart", "plate": "Plate",
}


def extract_label(caption: Optional[str]) -> Optional[str]:
    """Return a normalized display label like 'Figure 3.2', or None."""
    if not caption:
        return None
    m = _LABEL_RE.search(caption)
    if not m:
        return None
    word = _DISPLAY[m.group(1).lower()]
    return f"{word} {m.group(2)}"


def _figure_kind(block: Block) -> str:
    if block.kind == "table":
        return "table"
    if block.kind in ("pullquote", "blockquote"):
        return "pullquote"
    text = (block.caption or block.alt or "").lower()
    if any(w in text for w in ("diagram", "chart", "graph")):
        return "diagram"
    return "figure"


def build_registry(blocks: list[Block]) -> list[Figure]:
    """Build Figure entries from visual/special-display blocks.

    Spans default to the block's own id; the mention detector widens them.
    """
    figures: list[Figure] = []
    for b in blocks:
        if b.kind not in ("image", "figure", "table", "pullquote", "blockquote"):
            continue
        figures.append(
            Figure(
                figure_id=b.id,
                kind=_figure_kind(b),
                asset=b.src,
                caption=b.caption or (b.text if b.kind in ("pullquote", "blockquote") else None),
                label=extract_label(b.caption),
                start_para=b.id,
                end_para=b.id,
            )
        )
    return figures
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_figure_registry.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/figure_registry.py backend/tests/test_figure_registry.py
git commit -m "feat: figure registry with label/kind extraction (Plan 1 Task 5)"
```

---

## Task 6: Mention detector — paragraph spans from references

Scans paragraph text for references ("Figure 1", "see Figure 2"), matches them to labeled registry entries, and widens each figure's `[start_para, end_para]` to cover from first to last reference (capped by a window).

**Files:**
- Create: `backend/src/vimarsha/mention_detector.py`
- Test: `backend/tests/test_mention_detector.py`

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_mention_detector.py
from vimarsha.block_parser import parse_blocks
from vimarsha.figure_registry import build_registry
from vimarsha.mention_detector import detect_spans, MAX_SPAN_BLOCKS
from vimarsha.models import Block, Figure
from tests.conftest import CHAPTER_XHTML


def test_reference_widens_span_to_mention_paragraph():
    blocks = parse_blocks(CHAPTER_XHTML)
    figures = detect_spans(blocks, build_registry(blocks))
    by_id = {f.figure_id: f for f in figures}
    # Figure 1 is block b2; it is referenced in b3 ("As shown in Figure 1").
    fig1 = by_id["b2"]
    assert fig1.start_para == "b2"   # own block (earlier than the mention)
    assert fig1.end_para == "b3"     # widened to the referencing paragraph


def test_figure_referenced_before_it_appears():
    # Figure 2 is block b8 but referenced earlier in b6 ("see Figure 2").
    blocks = parse_blocks(CHAPTER_XHTML)
    figures = detect_spans(blocks, build_registry(blocks))
    fig2 = {f.figure_id: f for f in figures}["b8"]
    assert fig2.start_para == "b6"   # widened back to the earlier mention
    assert fig2.end_para == "b8"


def test_span_is_capped_by_window():
    blocks = [Block(id="b0", index=0, kind="figure", src="x.png",
                    caption="Figure 1.")]
    blocks += [Block(id=f"b{i}", index=i, kind="paragraph",
                     text="filler") for i in range(1, 30)]
    # a far-away mention
    blocks.append(Block(id="b30", index=30, kind="paragraph",
                        text="finally, see Figure 1 again"))
    figs = [Figure(figure_id="b0", kind="figure", caption="Figure 1.",
                   label="Figure 1", start_para="b0", end_para="b0")]
    out = detect_spans(blocks, figs)
    end_index = int(out[0].end_para[1:])
    assert end_index <= 0 + MAX_SPAN_BLOCKS
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_mention_detector.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'vimarsha.mention_detector'`

- [ ] **Step 3: Write `backend/src/vimarsha/mention_detector.py`**

```python
from __future__ import annotations

import re
from typing import Optional

from vimarsha.models import Block, Figure

MAX_SPAN_BLOCKS = 8

# A reference in prose: "Figure 1", "see Fig. 3.2", "Table 4" (optional plural).
_REF_RE = re.compile(
    r"\b(fig(?:ure)?|table|diagram|chart|plate)s?\.?\s*([0-9]+(?:\.[0-9]+)?)",
    re.IGNORECASE,
)

_CANON = {
    "fig": "figure", "figure": "figure", "table": "table",
    "diagram": "diagram", "chart": "chart", "plate": "plate",
}


def _canon_key(word: str, number: str) -> tuple[str, str]:
    return (_CANON[word.lower()], number)


def _label_key(label: Optional[str]) -> Optional[tuple[str, str]]:
    if not label:
        return None
    m = _REF_RE.search(label)
    if not m:
        return None
    return _canon_key(m.group(1), m.group(2))


def detect_spans(blocks: list[Block], figures: list[Figure]) -> list[Figure]:
    """Widen each figure's paragraph span to cover its textual references."""
    label_index: dict[tuple[str, str], Figure] = {}
    for f in figures:
        key = _label_key(f.label)
        if key is not None:
            label_index[key] = f

    block_index = {b.id: b.index for b in blocks}
    # Collect reference block-indices per figure.
    refs: dict[str, list[int]] = {}
    for b in blocks:
        if b.kind != "paragraph" or not b.text:
            continue
        for m in _REF_RE.finditer(b.text):
            fig = label_index.get(_canon_key(m.group(1), m.group(2)))
            if fig is not None:
                refs.setdefault(fig.figure_id, []).append(b.index)

    by_id = {f.figure_id: f for f in figures}
    index_to_id = {b.index: b.id for b in blocks}
    for fid, idxs in refs.items():
        fig = by_id[fid]
        own = block_index[fid]
        start_idx = min(idxs + [own])
        end_idx = max(idxs + [own])
        end_idx = min(end_idx, start_idx + MAX_SPAN_BLOCKS)
        fig.start_para = index_to_id[start_idx]
        fig.end_para = index_to_id[end_idx]
    return figures
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_mention_detector.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/mention_detector.py backend/tests/test_mention_detector.py
git commit -m "feat: rule-based mention detection and span widening (Plan 1 Task 6)"
```

---

## Task 7: Ingest orchestration

**Files:**
- Create: `backend/src/vimarsha/ingest.py`
- Test: `backend/tests/test_ingest.py`

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_ingest.py
from vimarsha.ingest import ingest_epub
from vimarsha.models import ChapterBundle


def test_ingest_epub_returns_validated_bundles(sample_epub):
    bundles = ingest_epub(str(sample_epub))
    assert len(bundles) == 1
    bundle = bundles[0]
    assert isinstance(bundle, ChapterBundle)
    assert bundle.chapter_id == "chap1"
    assert len(bundle.blocks) == 9
    # three special/visual elements registered
    assert len(bundle.figure_map) == 3
    # spans were computed (Figure 1 widened to its reference)
    fig1 = {f.figure_id: f for f in bundle.figure_map}["b2"]
    assert fig1.end_para == "b3"
    # no audio yet — that is Plan 2
    assert bundle.audio is None
    assert bundle.para_timings == {}


def test_bundle_json_is_camelcase(sample_epub):
    bundle = ingest_epub(str(sample_epub))[0]
    import json
    data = json.loads(bundle.model_dump_json(by_alias=True, exclude_none=True))
    assert data["chapterId"] == "chap1"
    assert data["figureMap"][0]["startPara"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_ingest.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'vimarsha.ingest'`

- [ ] **Step 3: Write `backend/src/vimarsha/ingest.py`**

```python
from __future__ import annotations

from vimarsha.block_parser import parse_blocks
from vimarsha.epub_reader import Chapter, read_chapters
from vimarsha.figure_registry import build_registry
from vimarsha.mention_detector import detect_spans
from vimarsha.models import ChapterBundle


def ingest_chapter(chapter: Chapter) -> ChapterBundle:
    """Run the full no-ML pipeline on one chapter."""
    blocks = parse_blocks(chapter.html)
    figures = detect_spans(blocks, build_registry(blocks))
    return ChapterBundle(
        chapter_id=chapter.chapter_id,
        title=chapter.title,
        blocks=blocks,
        figure_map=figures,
    )


def ingest_epub(epub_path: str) -> list[ChapterBundle]:
    """Ingest every chapter of an EPUB into pre-audio ChapterBundles."""
    return [ingest_chapter(c) for c in read_chapters(epub_path)]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_ingest.py -v`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/ingest.py backend/tests/test_ingest.py
git commit -m "feat: ingest pipeline assembles ChapterBundle (Plan 1 Task 7)"
```

---

## Task 8: Export the shared JSON Schema

**Files:**
- Create: `backend/scripts/export_schema.py`, `shared/bundle.schema.json`

- [ ] **Step 1: Write `backend/scripts/export_schema.py`**

```python
"""Export the ChapterBundle JSON Schema to /shared for the Flutter client."""
from __future__ import annotations

import json
from pathlib import Path

from vimarsha.models import ChapterBundle


def main() -> None:
    schema = ChapterBundle.model_json_schema(by_alias=True)
    out = Path(__file__).resolve().parents[2] / "shared" / "bundle.schema.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(schema, indent=2) + "\n")
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Generate the schema**

Run: `cd backend && uv run python scripts/export_schema.py`
Expected: prints `wrote .../shared/bundle.schema.json`

- [ ] **Step 3: Verify the schema has the camelCase contract**

Run:
```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
uv run --project backend python -c "import json; s=json.load(open('shared/bundle.schema.json')); print('chapterId' in s['properties'], 'figureMap' in s['properties'])"
```
Expected: prints `True True`

- [ ] **Step 4: Commit**

```bash
git add backend/scripts/export_schema.py shared/bundle.schema.json
git commit -m "feat: export shared ChapterBundle JSON schema (Plan 1 Task 8)"
```

---

## Task 9: Full suite green + a committed sample bundle fixture

**Files:**
- Create: `shared/fixtures/sample-chapter.bundle.json` (used by the Flutter client plans)

- [ ] **Step 1: Run the entire test suite**

Run: `cd backend && uv run pytest -v`
Expected: ALL pass (test_models 3, test_epub_reader 1, test_block_parser 5, test_figure_registry 3, test_mention_detector 3, test_ingest 2).

- [ ] **Step 2: Generate a sample bundle fixture from the test EPUB**

Run:
```bash
cd backend && uv run python - <<'PY'
import json, zipfile, tempfile, os
from pathlib import Path
from tests.conftest import CHAPTER_XHTML, CONTAINER_XML, CONTENT_OPF
from vimarsha.ingest import ingest_epub
d = tempfile.mkdtemp(); p = os.path.join(d, "s.epub")
with zipfile.ZipFile(p, "w") as z:
    z.writestr("mimetype", "application/epub+zip", compress_type=zipfile.ZIP_STORED)
    z.writestr("META-INF/container.xml", CONTAINER_XML)
    z.writestr("OEBPS/content.opf", CONTENT_OPF)
    z.writestr("OEBPS/chap1.xhtml", CHAPTER_XHTML)
b = ingest_epub(p)[0]
out = Path("..") / "shared" / "fixtures" / "sample-chapter.bundle.json"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(b.model_dump_json(by_alias=True, exclude_none=True, indent=2) + "\n")
print("wrote", out.resolve())
PY
```
Expected: prints the path to `shared/fixtures/sample-chapter.bundle.json`.

- [ ] **Step 3: Sanity-check the fixture validates against the schema**

Run:
```bash
cd backend && uv add --dev jsonschema && uv run python - <<'PY'
import json
from jsonschema import validate
schema = json.load(open("../shared/bundle.schema.json"))
data = json.load(open("../shared/fixtures/sample-chapter.bundle.json"))
validate(instance=data, schema=schema)
print("valid")
PY
```
Expected: prints `valid`

- [ ] **Step 4: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add backend/pyproject.toml backend/uv.lock shared/fixtures/sample-chapter.bundle.json
git commit -m "test: committed sample chapter bundle fixture (Plan 1 Task 9)"
```

---

## Self-Review

**Spec coverage (against §3 Steps 1–4, §7 of the design spec):**
- Step 1 parse → block model → Task 4. ✅
- Step 2 figure registry (incl. pull-quote/special display) → Task 5. ✅
- Step 3 rule-based mention detection + span → Task 6. ✅
- Step 4 LLM fallback → **intentionally deferred** to Plan 2 (needs the model layer); rules cover the fixture cases now. Noted, not a gap.
- Steps 5–6 (TTS, stitching, ms conversion) → Plan 2. ✅ (out of scope here)
- §7 shared contract → Tasks 1 & 8 (models + exported schema). ✅

**Placeholder scan:** none — every step has runnable code/commands and expected output.

**Type consistency:** `Block`, `Figure`, `ChapterBundle` defined once in Task 1 and imported everywhere. `build_registry`, `detect_spans`, `parse_blocks`, `read_chapters`, `ingest_chapter`, `ingest_epub`, `extract_label`, `MAX_SPAN_BLOCKS` names are consistent across tasks and tests. Field names (`figure_id`/`figureId`, `start_para`/`startPara`) consistent. ✅
