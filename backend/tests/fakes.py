import numpy as np


class FakeSynth:
    """Deterministic synthesizer for tests: duration scales with text length.

    100 samples per character at 16 kHz, so timings are predictable.
    """

    sample_rate = 16000

    def __init__(self, samples_per_char: int = 100, voice: str | None = None):
        self.samples_per_char = samples_per_char
        self.voice = voice

    def synthesize(self, text: str) -> np.ndarray:
        n = max(1, len(text) * self.samples_per_char)
        # low-amplitude noise so the waveform is non-silent but bounded
        return (np.ones(n, dtype=np.float32) * 0.01)


class FakeBatchSynth:
    """Deterministic batched synthesizer for tests: duration scales with text length,
    identically to ``FakeSynth`` (100 samples/char @ 16 kHz), and records each batch so tests
    can assert batching behavior."""

    sample_rate = 16000

    def __init__(self, samples_per_char: int = 100):
        self.samples_per_char = samples_per_char
        self.batches: list[list[str]] = []

    def synthesize_batch(self, texts: list[str]) -> list[np.ndarray]:
        self.batches.append(list(texts))
        return [
            np.ones(max(1, len(t) * self.samples_per_char), dtype=np.float32) * 0.01
            for t in texts
        ]
