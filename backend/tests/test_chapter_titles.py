"""Chapter titles must come from the EPUB's table of contents, not the filename.

Priority: TOC (nav/NCX) label → first in-page heading → humanized filename.
Regression for the chapter list showing `text00000.html` / `xhtml/Coyl_...` instead of
real chapter names.
"""
import zipfile
from pathlib import Path

import pytest

from vimarsha.epub_reader import _humanize_filename, read_chapters
from vimarsha.ingest import ingest_epub

_CONTAINER = """<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf"
    media-type="application/oebps-package+xml"/></rootfiles>
</container>
"""

_OPF = """<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="bookid">urn:uuid:title-test</dc:identifier>
    <dc:title>Title Test</dc:title>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="intro" href="intro.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="notes" href="notes.xhtml" media-type="application/xhtml+xml"/>
    <item id="back" href="back.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="intro"/>
    <itemref idref="ch1"/>
    <itemref idref="notes"/>
    <itemref idref="back"/>
  </spine>
</package>
"""

_NCX = """<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="urn:uuid:title-test"/></head>
  <docTitle><text>Title Test</text></docTitle>
  <navMap>
    <navPoint id="np1" playOrder="1"><navLabel><text>Introduction</text></navLabel>
      <content src="intro.xhtml"/></navPoint>
    <navPoint id="np2" playOrder="2"><navLabel><text>Chapter One</text></navLabel>
      <content src="ch1.xhtml"/></navPoint>
  </navMap>
</ncx>
"""


def _doc(body: str) -> str:
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Title Test</title></head>'
        f"<body>{body}</body></html>"
    )


@pytest.fixture
def titled_epub(tmp_path: Path) -> Path:
    path = tmp_path / "titled.epub"
    with zipfile.ZipFile(path, "w") as z:
        z.writestr("mimetype", "application/epub+zip", compress_type=zipfile.ZIP_STORED)
        z.writestr("META-INF/container.xml", _CONTAINER)
        z.writestr("OEBPS/content.opf", _OPF)
        z.writestr("OEBPS/toc.ncx", _NCX)
        z.writestr("OEBPS/intro.xhtml", _doc("<p>Welcome to the book.</p>"))
        z.writestr("OEBPS/ch1.xhtml", _doc("<h1>1</h1><p>The first chapter.</p>"))
        z.writestr("OEBPS/notes.xhtml", _doc("<h2>Notes</h2><p>Some notes.</p>"))
        z.writestr("OEBPS/back.xhtml", _doc("<p>Back matter.</p>"))
    return path


def test_titles_prefer_toc_then_heading_then_filename(titled_epub):
    titles = [b.title for b in ingest_epub(str(titled_epub))]
    assert titles == [
        "Introduction",   # from the TOC (no in-page heading on this page)
        "Chapter One",    # TOC label WINS over the in-page heading "1"
        "Notes",          # not in TOC → falls back to the in-page heading
        "Back",           # not in TOC, no heading → humanized filename
    ]


def test_read_chapters_exposes_toc_title(titled_epub):
    chapters = {c.chapter_id: c for c in read_chapters(str(titled_epub))}
    assert chapters["intro"].toc_title == "Introduction"
    assert chapters["ch1"].toc_title == "Chapter One"
    assert chapters["back"].toc_title is None   # not in the TOC


def test_humanize_filename_cleans_and_recognizes_front_matter():
    assert _humanize_filename("OEBPS/cover1.html") == "Cover"          # front-matter keyword
    assert _humanize_filename("text00000.html") == "Text00000"         # path + extension stripped
    assert ".html" not in _humanize_filename("xhtml/Coyl_epub3_cop_r1.xhtml")  # never a raw filename
