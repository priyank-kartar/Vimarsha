from __future__ import annotations

import numpy as np


def samples_to_ms(n_samples: int, sample_rate: int) -> int:
    return round(n_samples / sample_rate * 1000)


def assemble(
    segments: list[tuple[str, np.ndarray]],
    sample_rate: int,
    para_gap_ms: int,
) -> tuple[np.ndarray, dict[str, list[int]]]:
    """Concatenate per-paragraph waveforms with silence gaps between them.

    Returns the full waveform and {block_id: [start_ms, end_ms]} timings.
    """
    if not segments:
        return np.zeros(0, dtype=np.float32), {}

    gap_len = int(sample_rate * para_gap_ms / 1000)
    gap = np.zeros(gap_len, dtype=np.float32)

    parts: list[np.ndarray] = []
    timings: dict[str, list[int]] = {}
    cursor = 0
    last = len(segments) - 1
    for i, (block_id, wav) in enumerate(segments):
        start = cursor
        parts.append(wav)
        cursor += len(wav)
        timings[block_id] = [
            samples_to_ms(start, sample_rate),
            samples_to_ms(cursor, sample_rate),
        ]
        if i != last:
            parts.append(gap)
            cursor += gap_len

    return np.concatenate(parts), timings
