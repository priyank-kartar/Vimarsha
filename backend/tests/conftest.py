import zipfile
from pathlib import Path

import pytest

CHAPTER_XHTML = """<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml"
      xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>The Engine</title></head>
<body>
  <h1>The Engine</h1>
  <p>The principle is simple and elegant.</p>
  <figure>
    <img src="images/cycle.png" alt="four stroke cycle"/>
    <figcaption>Figure 1. The four-stroke cycle.</figcaption>
  </figure>
  <p>As shown in Figure 1, each stroke drives the next.</p>
  <p>The crankshaft then converts linear motion into rotation.</p>
  <blockquote epub:type="pullquote">Simplicity is the soul of efficiency.</blockquote>
  <p>Later designs improved on this; see Figure 2 for the variant.</p>
  <p>That variant fires every revolution.</p>
  <figure>
    <img src="images/variant.png" alt="two stroke variant"/>
    <figcaption>Figure 2. The two-stroke variant.</figcaption>
  </figure>
</body>
</html>
"""

CONTAINER_XML = """<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
"""

CONTENT_OPF = """<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="bookid">urn:uuid:test-book-1</dc:identifier>
    <dc:title>Test Book</dc:title>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="chap1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="chap1"/>
  </spine>
</package>
"""


@pytest.fixture
def sample_epub(tmp_path: Path) -> Path:
    """Write a minimal, valid single-chapter EPUB and return its path."""
    path = tmp_path / "sample.epub"
    with zipfile.ZipFile(path, "w") as z:
        # mimetype must be first and stored (uncompressed)
        z.writestr("mimetype", "application/epub+zip", compress_type=zipfile.ZIP_STORED)
        z.writestr("META-INF/container.xml", CONTAINER_XML)
        z.writestr("OEBPS/content.opf", CONTENT_OPF)
        z.writestr("OEBPS/chap1.xhtml", CHAPTER_XHTML)
    return path
