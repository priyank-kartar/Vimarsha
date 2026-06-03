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
