from __future__ import annotations

from ebooklib import epub

from vimarsha.models import BookMeta


def _first(values) -> str:
    """ebooklib metadata is a list of (value, attrs) tuples; take the first value."""
    if values:
        return values[0][0] or ""
    return ""


def read_book_meta(epub_path: str) -> BookMeta:
    """Read book-level title and author (creator) from the EPUB OPF."""
    book = epub.read_epub(epub_path)
    title = _first(book.get_metadata("DC", "title"))
    author = _first(book.get_metadata("DC", "creator"))
    return BookMeta(title=title, author=author)
