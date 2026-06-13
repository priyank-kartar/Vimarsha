from __future__ import annotations

import re
from dataclasses import dataclass

import ebooklib
from ebooklib import epub


@dataclass
class Chapter:
    chapter_id: str
    title: str
    html: str
    href: str = ""
    # The label for this document in the EPUB's table of contents (nav/NCX), if any.
    # Authoritative chapter title — preferred over headings/filenames during ingest.
    toc_title: str | None = None


# Friendly labels for common front-matter whose filename carries no real title and which
# the table of contents usually omits (so the only signal is the filename).
_FRONT_MATTER = {
    "cover": "Cover",
    "title": "Title Page",
    "titlepage": "Title Page",
    "halftitle": "Title Page",
    "copyright": "Copyright",
    "toc": "Contents",
    "contents": "Contents",
    "nav": "Contents",
    "index": "Index",
    "acknowledgments": "Acknowledgments",
    "acknowledgements": "Acknowledgements",
    "dedication": "Dedication",
    "epigraph": "Epigraph",
    "foreword": "Foreword",
    "preface": "Preface",
    "glossary": "Glossary",
    "bibliography": "Bibliography",
    "notes": "Notes",
    "appendix": "Appendix",
}


# Generic stub words EPUB toolchains use for auto-named documents; on their own they carry no
# real title, so a page named only with one of these (plus digits) gets a graceful placeholder.
_GENERIC_STEMS = {
    "text", "page", "part", "split", "item", "section", "body", "content", "doc",
    "document", "file", "leaf", "chap", "chapter", "ch", "pg", "id", "index", "html",
    "xhtml", "untitled", "blank",
}

_UNTITLED = "Untitled"


def _humanize_filename(name: str) -> str:
    """A readable last-resort label from a document filename (no TOC entry, no heading).

    Recognizes common front-matter names (``cover1.html`` → ``Cover``); for auto-generated
    names with no real title (``text00000.html``, ``part0007``, ``…epub3_p001_r1``) returns a
    graceful ``Untitled`` rather than the ugly stem; otherwise title-cases a real-word stem
    (``back.xhtml`` → ``Back``). Never returns a raw ``.html`` filename.
    """
    base = name.rsplit("/", 1)[-1]
    stem = base.rsplit(".", 1)[0]
    key = re.sub(r"[^a-z]", "", stem.lower())  # letters only, for keyword matching
    if key in _FRONT_MATTER:
        return _FRONT_MATTER[key]
    # Generic generated name: a stub word (optionally with digits), or any token carrying a run
    # of 2+ consecutive digits (page numbers, ISBNs, split indices) — no title to recover.
    flat = re.sub(r"[_\-\s]+", "", stem.lower())
    if not flat or key in _GENERIC_STEMS or re.search(r"\d{2,}", flat):
        return _UNTITLED
    cleaned = re.sub(r"[_\-]+", " ", stem).strip()
    return cleaned.title() if cleaned else _UNTITLED


def _add_toc_entry(mapping: dict[str, str], href: object, title: object) -> None:
    if not isinstance(href, str) or not isinstance(title, str):
        return
    path = href.split("#", 1)[0].strip()  # drop in-document fragment
    label = title.strip()
    if not path or not label:
        return
    # Key by the manifest-relative path AND by basename — TOC hrefs and item names sometimes
    # differ only by a leading directory. First entry wins (TOC reading order).
    mapping.setdefault(path, label)
    mapping.setdefault(path.rsplit("/", 1)[-1], label)


def _toc_title_map(book: epub.EpubBook) -> dict[str, str]:
    """Flatten the EPUB table of contents into ``{href_or_basename: label}``.

    Handles the nested shape ebooklib returns: a list of ``epub.Link`` and
    ``(epub.Section, [children])`` tuples.
    """
    mapping: dict[str, str] = {}

    def walk(items: object) -> None:
        for entry in items or []:  # type: ignore[union-attr]
            if isinstance(entry, (list, tuple)):
                section = entry[0]
                children = entry[1] if len(entry) > 1 else []
                _add_toc_entry(
                    mapping, getattr(section, "href", None), getattr(section, "title", None)
                )
                walk(children)
            else:
                _add_toc_entry(
                    mapping, getattr(entry, "href", None), getattr(entry, "title", None)
                )

    walk(getattr(book, "toc", None))
    return mapping


def _resolve_toc_title(name: str, mapping: dict[str, str]) -> str | None:
    """Look up a spine document's TOC label by full manifest path, then basename."""
    if name in mapping:
        return mapping[name]
    return mapping.get(name.rsplit("/", 1)[-1])


def read_chapters(epub_path: str) -> list[Chapter]:
    """Read an EPUB and return its document chapters in spine (reading) order.

    Each chapter carries its TOC label (``toc_title``) when the book's nav/NCX lists it, plus
    a humanized-filename ``title`` as the last-resort fallback.
    """
    book = epub.read_epub(epub_path)
    toc_map = _toc_title_map(book)
    chapters: list[Chapter] = []
    for idref, _linear in book.spine:
        item = book.get_item_with_id(idref)
        if item is None or item.get_type() != ebooklib.ITEM_DOCUMENT:
            continue
        html = item.get_content().decode("utf-8")
        name = item.get_name()
        chapters.append(
            Chapter(
                chapter_id=idref,
                title=_humanize_filename(name),
                html=html,
                href=name,
                toc_title=_resolve_toc_title(name, toc_map),
            )
        )
    return chapters
