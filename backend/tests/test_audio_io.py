import subprocess

import numpy as np
import pytest

from vimarsha.audio_io import write_mp3


def test_write_mp3_ffmpeg_failure_raises_runtime_error(tmp_path):
    """If ffmpeg can't write the output, a RuntimeError with 'ffmpeg' in the message is raised."""
    sr = 16000
    wav = (np.sin(np.linspace(0, 3.14 * 440, sr)) * 0.2).astype("float32")
    # Use an extension with no encoder so ffmpeg exits non-zero
    bad_out = str(tmp_path / "clip.unknownext")
    with pytest.raises(RuntimeError, match="ffmpeg"):
        write_mp3(wav, sr, bad_out)


def test_write_mp3_produces_a_playable_file(tmp_path):
    sr = 16000
    wav = (np.sin(np.linspace(0, 3.14 * 440, sr)) * 0.2).astype("float32")
    out = tmp_path / "clip.mp3"
    write_mp3(wav, sr, str(out))
    assert out.exists() and out.stat().st_size > 0
    # ffprobe reports an audio stream with a duration near 1s
    dur = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", str(out)],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    assert 0.8 < float(dur) < 1.3
