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
