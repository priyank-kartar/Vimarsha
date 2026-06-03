from __future__ import annotations

from vimarsha.block_parser import parse_blocks
from vimarsha.epub_reader import Chapter, read_chapters
from vimarsha.figure_registry import build_registry
from vimarsha.mention_detector import detect_spans
from vimarsha.models import ChapterBundle


def ingest_chapter(chapter: Chapter) -> ChapterBundle:
    """Run the full no-ML pipeline on one chapter."""
    blocks = parse_blocks(chapter.html)
    figures = detect_spans(blocks, build_registry(blocks))
    # Use the first heading block's text as the chapter title; fall back to the
    # chapter name (which is typically the xhtml filename from the epub manifest).
    first_heading = next((b for b in blocks if b.kind == "heading"), None)
    title = first_heading.text if first_heading and first_heading.text else chapter.title
    return ChapterBundle(
        chapter_id=chapter.chapter_id,
        title=title,
        blocks=blocks,
        figure_map=figures,
    )


def ingest_epub(epub_path: str) -> list[ChapterBundle]:
    """Ingest every chapter of an EPUB into pre-audio ChapterBundles."""
    return [ingest_chapter(c) for c in read_chapters(epub_path)]
