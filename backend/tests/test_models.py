# backend/tests/test_models.py
import json
from vimarsha.models import Block, Figure, ChapterBundle


def test_block_roundtrip_uses_camelcase():
    b = Block(id="b0", index=0, kind="paragraph", text="Hello")
    data = b.model_dump(by_alias=True, exclude_none=True)
    assert data == {"id": "b0", "index": 0, "kind": "paragraph", "text": "Hello"}


def test_figure_camelcase_aliases():
    f = Figure(
        figure_id="b3", kind="diagram", asset="img/d.png",
        caption="Figure 3.2 The cycle", label="Figure 3.2",
        start_para="b3", end_para="b5",
    )
    data = f.model_dump(by_alias=True, exclude_none=True)
    assert data["figureId"] == "b3"
    assert data["startPara"] == "b3"
    assert data["endPara"] == "b5"
    assert "startMs" not in data  # ms filled later in Plan 2


def test_bundle_serializes_and_parses():
    bundle = ChapterBundle(
        chapter_id="ch1", title="Intro",
        blocks=[Block(id="b0", index=0, kind="heading", level=1, text="Intro")],
        figure_map=[],
    )
    s = bundle.model_dump_json(by_alias=True, exclude_none=True)
    parsed = ChapterBundle.model_validate_json(s)
    assert parsed.chapter_id == "ch1"
    assert json.loads(s)["chapterId"] == "ch1"
