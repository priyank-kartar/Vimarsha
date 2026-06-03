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
