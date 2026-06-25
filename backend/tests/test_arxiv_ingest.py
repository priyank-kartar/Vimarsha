"""arXiv → ChapterBundle ingestion: id normalization + the pure LaTeX→blocks parse (paragraphs,
headings, and equation blocks carrying the verbatim LaTeX, inline math preserved for later
math-to-speech). The network fetch is exercised by an opt-in live test, not here."""
from vimarsha.arxiv_ingest import normalize_arxiv_id, parse_latex_to_blocks


def test_normalize_arxiv_id_forms():
    assert normalize_arxiv_id("1706.03762") == "1706.03762"
    assert normalize_arxiv_id("https://arxiv.org/abs/1706.03762v5") == "1706.03762v5"
    assert normalize_arxiv_id("arXiv:2401.00001 ") == "2401.00001"
    assert normalize_arxiv_id("http://arxiv.org/pdf/2305.12345v2") == "2305.12345v2"


_SRC = r"""
\documentclass{article}
\begin{document}
\section{Introduction}
The relation between mass and energy is given below.

\begin{equation}
E = m c^2
\end{equation}

It follows that mass and energy are equivalent, where $c$ is the speed of light.
\end{document}
"""


def test_parse_interleaves_paragraphs_headings_equations():
    blocks = parse_latex_to_blocks(_SRC)
    kinds = [b.kind for b in blocks]
    assert "heading" in kinds          # \section → heading
    assert "equation" in kinds         # display math → equation block
    assert kinds.count("paragraph") >= 2

    # document order preserved: heading, paragraph, equation, paragraph
    assert kinds.index("equation") > kinds.index("heading")

    eq = next(b for b in blocks if b.kind == "equation")
    assert "c^2" in (eq.latex or "")   # the verbatim LaTeX is carried for KaTeX

    heading = next(b for b in blocks if b.kind == "heading")
    assert "Introduction" in (heading.text or "")

    # inline math stays as LaTeX in prose (the math-to-speech step verbalizes it later)
    last_para = [b for b in blocks if b.kind == "paragraph"][-1]
    assert "$c$" in (last_para.text or "")


def test_equation_blocks_have_no_spoken_text_yet():
    # 2a only extracts; the spoken form (Block.text for equations) is filled by math-to-speech.
    eq = next(b for b in parse_latex_to_blocks(_SRC) if b.kind == "equation")
    assert eq.text is None
    assert eq.latex
