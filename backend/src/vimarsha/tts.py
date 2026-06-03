from __future__ import annotations

import re
from typing import Protocol

import numpy as np

_SENTENCE_RE = re.compile(r".+?(?:[.!?](?=\s|$)|$)", re.DOTALL)


def chunk_text(text: str, max_chars: int = 300) -> list[str]:
    """Split text into <=max_chars chunks on sentence boundaries.

    A single sentence longer than max_chars is kept whole (TTS will handle it).
    """
    text = text.strip()
    if not text:
        return []
    sentences = [m.group(0).strip() for m in _SENTENCE_RE.finditer(text)]
    sentences = [s for s in sentences if s]
    chunks: list[str] = []
    current = ""
    for s in sentences:
        if not current:
            current = s
        elif len(current) + 1 + len(s) <= max_chars:
            current = f"{current} {s}"
        else:
            chunks.append(current)
            current = s
    if current:
        chunks.append(current)
    return chunks


class Synthesizer(Protocol):
    """Anything that turns text into a mono float32 waveform."""

    sample_rate: int

    def synthesize(self, text: str) -> np.ndarray:
        """Return a 1-D float32 numpy array of audio samples for `text`."""
        ...
