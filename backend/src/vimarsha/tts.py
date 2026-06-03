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


class ChatterboxSynth:
    """Real Chatterbox TTS adapter. Requires the `[tts]` extra and a GPU/MPS.

    Lazily imports torch/chatterbox so the rest of the package runs without them.
    """

    def __init__(self, device: str | None = None, audio_prompt_path: str | None = None):
        import torch
        from chatterbox.tts import ChatterboxTTS

        if device is None:
            device = (
                "cuda" if torch.cuda.is_available()
                else "mps" if torch.backends.mps.is_available()
                else "cpu"
            )
        self._model = ChatterboxTTS.from_pretrained(device=device)
        self.sample_rate = self._model.sr
        self._audio_prompt_path = audio_prompt_path

    def synthesize(self, text: str) -> np.ndarray:
        kwargs = {}
        if self._audio_prompt_path:
            kwargs["audio_prompt_path"] = self._audio_prompt_path
        wav = self._model.generate(text, **kwargs)  # torch tensor [1, N]
        return wav.squeeze(0).detach().cpu().numpy().astype("float32")
