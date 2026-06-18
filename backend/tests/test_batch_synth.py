import numpy as np

from tests.fakes import FakeBatchSynth


def test_fake_batch_synth_returns_one_waveform_per_text_and_records_batches():
    synth = FakeBatchSynth(samples_per_char=100)
    out = synth.synthesize_batch(["ab", "cdef"])
    assert len(out) == 2
    assert all(isinstance(w, np.ndarray) and w.dtype == np.float32 for w in out)
    # duration scales with text length (2 chars -> 200 samples, 4 -> 400)
    assert out[0].shape[0] == 200
    assert out[1].shape[0] == 400
    # it recorded the batch it received (so tests can assert batching behavior)
    assert synth.batches == [["ab", "cdef"]]
    assert synth.sample_rate == 16000
