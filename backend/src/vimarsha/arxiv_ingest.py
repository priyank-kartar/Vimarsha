"""Scientific Literature ingestion — the arXiv path.

Fetch a paper's LaTeX source from arXiv (the e-print tarball), inline ``\\input``/``\\include``,
and parse it into the same ``ChapterBundle`` the EPUB pipeline produces: ordered ``paragraph``
blocks interleaved with ``equation`` blocks carrying the LaTeX (the client renders it with KaTeX;
its spoken form for narration is filled by the math-to-speech step). arXiv ships clean LaTeX, so
the equations are exact — no OCR.
"""
from __future__ import annotations

import io
import os
import re
import tarfile
import urllib.request

from vimarsha.models import Block, ChapterBundle

_EPRINT_URL = "https://arxiv.org/e-print/{}"
_META_URL = "http://export.arxiv.org/api/query?id_list={}"
_MATH_ENVS = {
    "equation", "equation*", "align", "align*", "displaymath",
    "gather", "gather*", "multline", "multline*", "eqnarray", "eqnarray*",
}
_HEADING_LEVELS = {"section": 1, "subsection": 2, "subsubsection": 3, "paragraph": 4}


def normalize_arxiv_id(ref: str) -> str:
    """Accept a bare id, an abs/pdf URL, or ``arXiv:1706.03762v5`` → the bare id (keeping any
    version). Falls back to the trimmed input for old-style ids like ``math.GT/0309136``."""
    ref = ref.strip()
    m = re.search(r"(\d{4}\.\d{4,5})(v\d+)?", ref)
    if m:
        return m.group(1) + (m.group(2) or "")
    m = re.search(r"([a-z\-]+(?:\.[A-Z]{2})?/\d{7})", ref)
    return m.group(1) if m else ref


def _inline_inputs(texs: dict[str, str], name: str, seen: tuple = ()) -> str:
    """Recursively splice ``\\input{x}`` / ``\\include{x}`` with the body of ``x.tex``."""
    if name in seen:
        return ""

    def repl(m: re.Match) -> str:
        key = os.path.splitext(os.path.basename(m.group(1).strip()))[0]
        return _inline_inputs(texs, key, seen + (name,)) if key in texs else ""

    return re.sub(r"\\(?:input|include)\{([^}]+)\}", repl, texs.get(name, ""))


def fetch_arxiv_latex(arxiv_id: str) -> str:
    """Download the e-print tarball and return the main document's inlined LaTeX source."""
    req = urllib.request.Request(_EPRINT_URL.format(arxiv_id), headers={"User-Agent": "vimarsha/1.0"})
    data = urllib.request.urlopen(req, timeout=90).read()  # noqa: S310 — arxiv.org
    try:
        tf = tarfile.open(fileobj=io.BytesIO(data), mode="r:*")
    except tarfile.ReadError:
        return data.decode("utf-8", "ignore")  # a bare (possibly gz) single .tex
    texs = {
        os.path.splitext(m.name)[0]: tf.extractfile(m).read().decode("utf-8", "ignore")
        for m in tf.getmembers() if m.name.endswith(".tex") and m.isfile()
    }
    if not texs:
        raise ValueError("arXiv e-print has no LaTeX source")
    main = next((k for k, v in texs.items() if "\\begin{document}" in v),
                max(texs, key=lambda k: len(texs[k])))
    return _inline_inputs(texs, main)


def _clean(text: str) -> str:
    return re.sub(r"[ \t]+", " ", text).strip()


def parse_latex_to_blocks(latex_source: str) -> list[Block]:
    """Walk the document body into ordered blocks: ``paragraph`` (prose, inline math kept as
    LaTeX for later math-to-speech), ``heading`` (sections), and ``equation`` (display math,
    ``latex`` = the verbatim environment source). Pure — no network."""
    from pylatexenc.latex2text import LatexNodes2Text
    from pylatexenc.latexwalker import LatexEnvironmentNode, LatexMacroNode, LatexMathNode, LatexWalker

    body = latex_source.split("\\begin{document}", 1)[-1].split("\\end{document}", 1)[0]
    nodes, _, _ = LatexWalker(body).get_latex_nodes()
    conv = LatexNodes2Text(math_mode="with-delimiters", keep_comments=False, strict_latex_spaces=False)

    blocks: list[Block] = []
    buf: list = []

    def add(kind: str, *, text: str | None = None, latex: str | None = None, level: int | None = None) -> None:
        blocks.append(Block(id=f"b{len(blocks)}", index=len(blocks), kind=kind, text=text, latex=latex, level=level))

    def flush() -> None:
        if not buf:
            return
        prose = conv.nodelist_to_text(buf)
        buf.clear()
        for para in re.split(r"\n\s*\n", prose):
            para = _clean(para)
            if para:
                add("paragraph", text=para)

    def is_display_math(n) -> bool:
        return (isinstance(n, LatexEnvironmentNode) and n.environmentname in _MATH_ENVS) or (
            isinstance(n, LatexMathNode) and getattr(n, "displaytype", "") == "display"
        )

    for n in nodes:
        if is_display_math(n):
            flush()
            add("equation", latex=n.latex_verbatim().strip())
        elif isinstance(n, LatexMacroNode) and n.macroname in _HEADING_LEVELS:
            flush()
            # Convert the section's ARGUMENT, not the whole macro — rendering `\section{X}`
            # decorates it ("§ X", uppercased); the {X} group gives the clean title.
            args = (n.nodeargd.argnlist if n.nodeargd else None) or []
            title = ""
            for arg in reversed(args):
                if arg is not None:
                    title = _clean(conv.latex_to_text(arg.latex_verbatim()))
                    if title:
                        break
            if title:
                add("heading", text=title, level=_HEADING_LEVELS[n.macroname])
        else:
            buf.append(n)
    flush()
    return blocks


def arxiv_metadata(arxiv_id: str) -> tuple[str, str]:
    """(title, authors) from the arXiv Atom API; falls back to the id if unavailable."""
    try:
        req = urllib.request.Request(_META_URL.format(arxiv_id), headers={"User-Agent": "vimarsha/1.0"})
        feed = urllib.request.urlopen(req, timeout=30).read().decode("utf-8", "ignore")  # noqa: S310
        title = re.search(r"<entry>.*?<title>(.*?)</title>", feed, re.S)
        authors = re.findall(r"<author>\s*<name>(.*?)</name>", feed, re.S)
        t = _clean(re.sub(r"\s+", " ", title.group(1))) if title else ""
        return (t or f"arXiv:{arxiv_id}", ", ".join(a.strip() for a in authors))
    except Exception:  # noqa: BLE001 — metadata is best-effort
        return (f"arXiv:{arxiv_id}", "")


def ingest_arxiv(ref: str) -> ChapterBundle:
    """A whole arXiv paper as one ``ChapterBundle`` (paragraphs + headings + equation blocks).
    Equation blocks have their ``text`` filled with the spoken form by math-to-speech so they
    can be narrated; inline math in prose is also rewritten. ``latex`` is never touched."""
    from vimarsha.math_speech import verbalize_blocks
    arxiv_id = normalize_arxiv_id(ref)
    title, _authors = arxiv_metadata(arxiv_id)
    blocks = parse_latex_to_blocks(fetch_arxiv_latex(arxiv_id))
    verbalize_blocks(blocks)
    if not any(b.kind == "paragraph" for b in blocks):
        raise ValueError(f"arXiv:{arxiv_id} produced no readable text")
    return ChapterBundle(chapterId=f"arxiv-{arxiv_id}", title=title, blocks=blocks, figureMap=[])
