# backend/tests/test_ingest.py
from vimarsha.ingest import ingest_epub
from vimarsha.models import ChapterBundle


def test_ingest_epub_returns_validated_bundles(sample_epub):
    bundles = ingest_epub(str(sample_epub))
    assert len(bundles) == 1
    bundle = bundles[0]
    assert isinstance(bundle, ChapterBundle)
    assert bundle.chapter_id == "chap1"
    assert len(bundle.blocks) == 9
    # three special/visual elements registered
    assert len(bundle.figure_map) == 3
    # spans were computed (Figure 1 widened to its reference)
    fig1 = {f.figure_id: f for f in bundle.figure_map}["b2"]
    assert fig1.end_para == "b3"
    # no audio yet — that is Plan 2
    assert bundle.audio is None
    assert bundle.para_timings == {}


def test_bundle_json_is_camelcase(sample_epub):
    bundle = ingest_epub(str(sample_epub))[0]
    import json
    data = json.loads(bundle.model_dump_json(by_alias=True, exclude_none=True))
    assert data["chapterId"] == "chap1"
    assert data["figureMap"][0]["startPara"]
