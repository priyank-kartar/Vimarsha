from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf


def write_mp3(waveform: np.ndarray, sample_rate: int, out_path: str) -> None:
    """Write a mono float32 waveform to an MP3 file via ffmpeg (libmp3lame)."""
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=True) as tmp:
        sf.write(tmp.name, waveform, sample_rate, subtype="PCM_16")
        subprocess.run(
            ["ffmpeg", "-y", "-i", tmp.name,
             "-codec:a", "libmp3lame", "-qscale:a", "2", out_path],
            check=True, capture_output=True,
        )
