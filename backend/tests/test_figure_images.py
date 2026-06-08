from vimarsha.epub_reader import read_chapters
from vimarsha.ingest import ingest_epub
from vimarsha.figure_images import extract_images
from vimarsha.models import Figure


def test_extract_writes_images_and_sets_image_field(sample_epub, tmp_path):
    bundle = ingest_epub(str(sample_epub))[0]
    href = read_chapters(str(sample_epub))[0].href
    figs = extract_images(
        str(sample_epub), bundle.chapter_id, href, bundle.figure_map, str(tmp_path)
    )
    by_id = {f.figure_id: f for f in figs}
    # the two <figure> blocks (b2, b8) get image files; pullquote (b5) does not
    assert by_id["b2"].image is not None
    assert by_id["b8"].image is not None
    assert by_id["b5"].image is None
    assert (tmp_path / by_id["b2"].image).is_file()
    assert (tmp_path / by_id["b2"].image).read_bytes()[:4] == b"\x89PNG"


def test_missing_asset_leaves_image_none(sample_epub, tmp_path):
    fig = Figure(figure_id="bX", kind="figure", asset="images/missing.png",
                 start_para="bX", end_para="bX")
    out = extract_images(str(sample_epub), "chap1", "chap1.xhtml", [fig], str(tmp_path))
    assert out[0].image is None  # unresolved asset is skipped, no error
