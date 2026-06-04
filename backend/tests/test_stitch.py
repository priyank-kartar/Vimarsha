import numpy as np

from vimarsha.stitch import assemble, samples_to_ms


def test_samples_to_ms():
    assert samples_to_ms(16000, 16000) == 1000
    assert samples_to_ms(8000, 16000) == 500


def test_assemble_concatenates_with_gaps_and_records_timings():
    sr = 16000
    segs = [
        ("b0", np.ones(16000, dtype=np.float32)),  # 1000 ms
        ("b1", np.ones(8000, dtype=np.float32)),   # 500 ms
    ]
    wav, timings = assemble(segs, sample_rate=sr, para_gap_ms=200)
    # b0: 0..1000 ; gap 200 ; b1: 1200..1700
    assert timings["b0"] == [0, 1000]
    assert timings["b1"] == [1200, 1700]
    # total length = 16000 + 3200(gap) + 8000
    assert len(wav) == 16000 + 3200 + 8000


def test_assemble_no_trailing_gap_after_last_segment():
    sr = 16000
    segs = [("b0", np.ones(1600, dtype=np.float32))]
    wav, timings = assemble(segs, sample_rate=sr, para_gap_ms=500)
    assert len(wav) == 1600  # no gap appended after the only/last segment
    assert timings["b0"] == [0, 100]


def test_assemble_empty():
    wav, timings = assemble([], sample_rate=16000, para_gap_ms=200)
    assert len(wav) == 0 and timings == {}
