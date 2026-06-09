from __future__ import annotations

from typing import Optional, Protocol


class Transcriber(Protocol):
    def transcribe(self, audio_path: str) -> str:
        """Return the transcript text for an audio file."""
        ...


class FasterWhisperTranscriber:
    """Real transcriber. Requires the `[tts]` extra (faster-whisper). CPU + int8
    by default (works on Apple Silicon; CTranslate2 has no MPS backend)."""

    def __init__(
        self,
        model_size: str = "base",
        device: str = "cpu",
        compute_type: str = "int8",
    ):
        from faster_whisper import WhisperModel

        self._model = WhisperModel(model_size, device=device, compute_type=compute_type)

    def transcribe(self, audio_path: str) -> str:
        segments, _info = self._model.transcribe(audio_path)
        return "".join(seg.text for seg in segments).strip()
