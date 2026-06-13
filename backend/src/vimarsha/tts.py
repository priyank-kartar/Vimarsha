from __future__ import annotations

import re
import threading
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

    def __init__(
        self,
        voice: str | None = None,  # accepted for a uniform factory; Chatterbox has one voice
        device: str | None = None,
        audio_prompt_path: str | None = None,
    ):
        import torch
        from chatterbox.tts import ChatterboxTTS

        if device is None:
            device = (
                "cuda" if torch.cuda.is_available()
                else "mps" if torch.backends.mps.is_available()
                else "cpu"
            )
        self._model = ChatterboxTTS.from_pretrained(device=device)
        self._device = device
        self.sample_rate = self._model.sr
        self._audio_prompt_path = audio_prompt_path

    def synthesize(self, text: str) -> np.ndarray:
        import torch

        kwargs = {}
        if self._audio_prompt_path:
            kwargs["audio_prompt_path"] = self._audio_prompt_path
        wav = self._model.generate(text, **kwargs)  # torch tensor [1, N]
        out = wav.squeeze(0).detach().cpu().numpy().astype("float32")
        # Bound memory across a long chapter: the MPS/CUDA allocator caches the
        # per-call generation tensors, so without releasing them hundreds of blocks
        # climb into tens of GB and push the machine into swap (disk then fills →
        # OSError 28). Drop the tensor and hand the device's cached blocks back each
        # block so peak memory stays flat regardless of chapter length.
        del wav
        if self._device == "mps":
            torch.mps.empty_cache()
        elif self._device == "cuda":
            torch.cuda.empty_cache()
        return out


def _pick_device(device: str | None) -> str:
    """Resolve cuda > mps > cpu unless an explicit device is given."""
    if device is not None:
        return device
    import torch

    if torch.cuda.is_available():
        return "cuda"
    if torch.backends.mps.is_available():
        return "mps"
    return "cpu"


def kokoro_lang(voice: str) -> str:
    """Kokoro encodes language in the voice prefix: 'b*' = British English, everything
    else = American English. (See Kokoro voice naming: <lang><gender>_<name>.)"""
    return "b" if voice[:1].lower() == "b" else "a"


class KokoroSynth:
    """Kokoro-82M TTS adapter (StyleTTS2-based) — far faster than autoregressive Chatterbox.

    Same ``Synthesizer`` contract (mono float32 @ ``sample_rate``); swappable per-request via
    ``VIMARSHA_TTS=kokoro``. Requires the ``[kokoro]`` extra. Lazily imports ``kokoro`` so the
    rest of the package runs without it. Kokoro renders at 24 kHz.
    """

    sample_rate = 24000
    # Shared KPipeline per (device, lang) — the model loads once per language, not per voice,
    # so the server can cache a cheap KokoroSynth per (engine, voice).
    _pipelines: dict[tuple[str, str], object] = {}
    _pipelines_lock = threading.Lock()

    def __init__(
        self,
        voice: str = "af_heart",
        device: str | None = None,
        speed: float = 1.0,
    ):
        from kokoro import KPipeline

        resolved = _pick_device(device)
        # Kokoro's iSTFT vocoder calls ``aten::angle``, which Apple's MPS backend doesn't
        # implement (pytorch#141287) — it crashes there. Kokoro-82M is small, so on MPS we run
        # on CPU (still near real-time). CUDA, the production target, is unaffected.
        if resolved == "mps":
            resolved = "cpu"
        self._device = resolved
        self._voice = voice
        self._speed = speed
        lang_code = kokoro_lang(voice)
        key = (resolved, lang_code)
        with KokoroSynth._pipelines_lock:
            pipe = KokoroSynth._pipelines.get(key)
            if pipe is None:
                pipe = KPipeline(lang_code=lang_code, device=resolved)
                KokoroSynth._pipelines[key] = pipe
        self._pipeline = pipe

    def synthesize(self, text: str) -> np.ndarray:
        if not text.strip():
            return np.zeros(0, dtype=np.float32)
        parts: list[np.ndarray] = []
        # Kokoro yields one (graphemes, phonemes, audio) tuple per internal split; concatenate
        # them so a block maps to one contiguous waveform, exactly like the Chatterbox path.
        for _gs, _ps, audio in self._pipeline(text, voice=self._voice, speed=self._speed):
            if hasattr(audio, "detach"):  # torch tensor
                arr = audio.detach().cpu().numpy().astype("float32")
            else:
                arr = np.asarray(audio, dtype="float32")
            parts.append(arr)
        if not parts:
            return np.zeros(0, dtype=np.float32)
        return np.concatenate(parts)


# Pluggable engine registry: name -> Synthesizer class (constructed lazily by the server so
# selecting an engine never loads a model until it's actually used).
_ENGINES: dict[str, type] = {
    "chatterbox": ChatterboxSynth,
    "kokoro": KokoroSynth,
}
_DEFAULT_ENGINE = "chatterbox"


def synth_class(name: str | None) -> type:
    """Resolve a TTS engine name to its ``Synthesizer`` class (no instantiation).

    Case-insensitive, whitespace-trimmed; ``None``/empty selects the default (Chatterbox, so
    existing deployments are unchanged). Unknown names raise ``ValueError``.
    """
    key = (name or "").strip().lower()
    if not key:
        key = _DEFAULT_ENGINE
    try:
        return _ENGINES[key]
    except KeyError:
        raise ValueError(
            f"unknown TTS engine {name!r}; choose one of {sorted(_ENGINES)}"
        ) from None
