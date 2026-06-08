from __future__ import annotations

from dataclasses import dataclass

import ebooklib
from ebooklib import epub


@dataclass
class Chapter:
    chapter_id: str
    title: str
    html: str
    href: str = ""


def read_chapters(epub_path: str) -> list[Chapter]:
    """Read an EPUB and return its document chapters in spine (reading) order."""
    book = epub.read_epub(epub_path)
    chapters: list[Chapter] = []
    for idref, _linear in book.spine:
        item = book.get_item_with_id(idref)
        if item is None or item.get_type() != ebooklib.ITEM_DOCUMENT:
            continue
        html = item.get_content().decode("utf-8")
        chapters.append(
            Chapter(
                chapter_id=idref,
                title=item.get_name(),
                html=html,
                href=item.get_name(),
            )
        )
    return chapters
