from vimarsha.metadata import read_book_meta
from vimarsha.models import BookMeta


def test_reads_title_and_author(sample_epub):
    meta = read_book_meta(str(sample_epub))
    assert isinstance(meta, BookMeta)
    assert meta.title == "Test Book"
    assert meta.author == "Ada Lovelace"


def test_missing_author_is_empty_string(sample_epub_no_author):
    meta = read_book_meta(str(sample_epub_no_author))
    assert meta.title == "Test Book"
    assert meta.author == ""
