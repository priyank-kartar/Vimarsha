from vimarsha.ingest import ingest_epub
from vimarsha.narrate import narrate_bundle, narratable_text
from vimarsha.models import Block
from tests.fakes import FakeSynth


def test_narratable_text_rules():
    assert narratable_text(Block(id="b0", index=0, kind="paragraph", text="Hi")) == "Hi"
    assert narratable_text(Block(id="b0", index=0, kind="heading", level=1, text="T")) == "T"
    # figure narrates its caption
    assert narratable_text(
        Block(id="b0", index=0, kind="figure", src="x.png", caption="Figure 1.")
    ) == "Figure 1."
    # pure image with no caption is skipped
    assert narratable_text(Block(id="b0", index=0, kind="image", src="x.png")) is None


def test_narrate_bundle_fills_audio_timings_and_figure_ms(tmp_path, sample_epub):
    bundle = ingest_epub(str(sample_epub))[0]
    out = narrate_bundle(bundle, FakeSynth(), str(tmp_path), para_gap_ms=200)

    # audio file written and referenced
    assert out.audio == "chap1.mp3"
    assert (tmp_path / "chap1.mp3").exists()

    # every narratable block has a timing; ordering is monotonic
    assert "b0" in out.para_timings  # heading
    assert "b1" in out.para_timings  # first paragraph
    starts = [out.para_timings[b.id][0] for b in out.blocks if b.id in out.para_timings]
    assert starts == sorted(starts)

    # figure ms derived from its span endpoints' paragraph timings
    fig1 = {f.figure_id: f for f in out.figure_map}["b2"]
    assert fig1.start_ms is not None and fig1.end_ms is not None
    assert fig1.start_ms == out.para_timings["b2"][0]   # span start = b2
    assert fig1.end_ms == out.para_timings["b3"][1]     # span end = b3
    assert fig1.end_ms > fig1.start_ms


def test_narrate_bundle_missing_span_endpoint_id_does_not_raise(tmp_path):
    """If a Figure's start_para/end_para references a block id not in blocks, return 0."""
    from vimarsha.models import ChapterBundle, Figure
    blocks = [
        Block(id="b0", index=0, kind="paragraph", text="Hello world text here."),
    ]
    fig = Figure(figure_id="bX_fig", kind="figure", asset="img.png",
                 start_para="bX", end_para="bX")  # "bX" is NOT in blocks
    bundle = ChapterBundle(chapter_id="c", title="t", blocks=blocks, figure_map=[fig])
    out = narrate_bundle(bundle, FakeSynth(), str(tmp_path))
    f = out.figure_map[0]
    assert isinstance(f.start_ms, int)
    assert isinstance(f.end_ms, int)


def test_narrate_resolves_ms_for_unnarrated_span_endpoint(tmp_path):
    # A figure whose own block has no caption (not narrated): ms falls back to neighbors.
    from vimarsha.models import ChapterBundle, Figure
    blocks = [
        Block(id="b0", index=0, kind="paragraph", text="Intro paragraph here."),
        Block(id="b1", index=1, kind="image", src="x.png"),  # not narrated
        Block(id="b2", index=2, kind="paragraph", text="See the image above now."),
    ]
    fig = Figure(figure_id="b1", kind="figure", asset="x.png",
                 start_para="b1", end_para="b1")
    bundle = ChapterBundle(chapter_id="c", title="t", blocks=blocks, figure_map=[fig])
    out = narrate_bundle(bundle, FakeSynth(), str(tmp_path))
    f = out.figure_map[0]
    # b1 not narrated -> start falls back to prior narrated (b0 start), end to next (b2 end)
    assert f.start_ms == out.para_timings["b0"][0]
    assert f.end_ms == out.para_timings["b2"][1]
