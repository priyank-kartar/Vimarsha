from __future__ import annotations

import posixpath
from pathlib import Path

from ebooklib import epub

from vimarsha.models import Figure


def _resolve(chapter_href: str, asset: str) -> str:
    """Resolve an image src that is relative to the chapter document."""
    base = posixpath.dirname(chapter_href)
    return posixpath.normpath(posixpath.join(base, asset))


def extract_images(
    epub_path: str,
    chapter_id: str,
    chapter_href: str,
    figures: list[Figure],
    out_dir: str,
) -> list[Figure]:
    """For each figure with an asset, copy its EPUB image into out_dir under a
    stable name and set figure.image. Unresolvable assets are skipped (image
    stays None). Returns the same figures (mutated in place)."""
    book = epub.read_epub(epub_path)
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    for fig in figures:
        if not fig.asset:
            continue
        href = _resolve(chapter_href, fig.asset)
        item = book.get_item_with_href(href)
        if item is None:
            continue
        ext = posixpath.splitext(href)[1] or ".img"
        name = f"{chapter_id}_{fig.figure_id}{ext}"
        (out / name).write_bytes(item.get_content())
        fig.image = name
    return figures
