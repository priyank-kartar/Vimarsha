# backend/tests/test_mention_detector.py
from vimarsha.block_parser import parse_blocks
from vimarsha.figure_registry import build_registry
from vimarsha.mention_detector import detect_spans, MAX_SPAN_BLOCKS
from vimarsha.models import Block, Figure
from tests.conftest import CHAPTER_XHTML


def test_reference_widens_span_to_mention_paragraph():
    blocks = parse_blocks(CHAPTER_XHTML)
    figures = detect_spans(blocks, build_registry(blocks))
    by_id = {f.figure_id: f for f in figures}
    # Figure 1 is block b2; it is referenced in b3 ("As shown in Figure 1").
    fig1 = by_id["b2"]
    assert fig1.start_para == "b2"   # own block (earlier than the mention)
    assert fig1.end_para == "b3"     # widened to the referencing paragraph


def test_figure_referenced_before_it_appears():
    # Figure 2 is block b8 but referenced earlier in b6 ("see Figure 2").
    blocks = parse_blocks(CHAPTER_XHTML)
    figures = detect_spans(blocks, build_registry(blocks))
    fig2 = {f.figure_id: f for f in figures}["b8"]
    assert fig2.start_para == "b6"   # widened back to the earlier mention
    assert fig2.end_para == "b8"


def test_span_is_capped_by_window():
    blocks = [Block(id="b0", index=0, kind="figure", src="x.png",
                    caption="Figure 1.")]
    blocks += [Block(id=f"b{i}", index=i, kind="paragraph",
                     text="filler") for i in range(1, 30)]
    # a far-away mention
    blocks.append(Block(id="b30", index=30, kind="paragraph",
                        text="finally, see Figure 1 again"))
    figs = [Figure(figure_id="b0", kind="figure", caption="Figure 1.",
                   label="Figure 1", start_para="b0", end_para="b0")]
    out = detect_spans(blocks, figs)
    end_index = int(out[0].end_para[1:])
    assert end_index <= 0 + MAX_SPAN_BLOCKS
