import numpy as np


class FakeSynth:
    """Deterministic synthesizer for tests: duration scales with text length.

    100 samples per character at 16 kHz, so timings are predictable.
    """

    sample_rate = 16000

    def __init__(self, samples_per_char: int = 100):
        self.samples_per_char = samples_per_char

    def synthesize(self, text: str) -> np.ndarray:
        n = max(1, len(text) * self.samples_per_char)
        # low-amplitude noise so the waveform is non-silent but bounded
        return (np.ones(n, dtype=np.float32) * 0.01)
