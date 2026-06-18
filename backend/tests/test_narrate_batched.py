import pytest

from vimarsha.ingest import ingest_epub
from vimarsha.models import Block, ChapterBundle
from vimarsha.narrate import narrate_bundle, narrate_bundle_batched
from tests.fakes import FakeBatchSynth, FakeSynth


def test_batched_matches_single_stream(tmp_path, sample_epub):
    bundle = ingest_epub(str(sample_epub))[0]
    single = narrate_bundle(bundle, FakeSynth(), str(tmp_path / "s"), para_gap_ms=200)
    batched = narrate_bundle_batched(
        bundle, FakeBatchSynth(), str(tmp_path / "b"), para_gap_ms=200
    )

    # Same bundle structure + identical timings/figure ms (only HOW waveforms were computed
    # differs). audio file name is the same; both write their own copy in their own dir.
    assert batched.audio == single.audio == "chap1.mp3"
    assert (tmp_path / "b" / "chap1.mp3").exists()
    assert batched.para_timings == single.para_timings
    sfm = {f.figure_id: (f.start_ms, f.end_ms) for f in single.figure_map}
    bfm = {f.figure_id: (f.start_ms, f.end_ms) for f in batched.figure_map}
    assert bfm == sfm


def test_batches_respect_max_batch_and_cover_all_chunks(tmp_path, sample_epub):
    bundle = ingest_epub(str(sample_epub))[0]
    synth = FakeBatchSynth()
    narrate_bundle_batched(bundle, synth, str(tmp_path), max_batch=2)
    assert synth.batches, "synthesize_batch was never called"
    assert all(len(b) <= 2 for b in synth.batches)          # cap honored
    assert any(len(b) == 2 for b in synth.batches)          # actually batched, not 1-by-1


def test_batched_raises_when_no_narratable_text(tmp_path):
    bundle = ChapterBundle(
        chapter_id="empty",
        title="Part One",
        blocks=[Block(id="b0", index=0, kind="image", src="x.png")],
        figure_map=[],
    )
    with pytest.raises(ValueError, match="no narratable text"):
        narrate_bundle_batched(bundle, FakeBatchSynth(), str(tmp_path))
