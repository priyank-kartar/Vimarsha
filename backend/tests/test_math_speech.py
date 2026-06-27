"""Math-to-speech: LaTeX math -> spoken English (pure, pylatexenc-backed)."""
from vimarsha.math_speech import speak_latex


def test_atoms_and_binary_operators():
    assert speak_latex(r"a + b") == "a plus b"
    assert speak_latex(r"\alpha = 3") == "alpha equals 3"
    assert speak_latex(r"x - y \times z") == "x minus y times z"
    # multi-digit numbers coalesce; $…$ wrapper is stripped
    assert speak_latex(r"$12 \leq 30$") == "12 less than or equal to 30"

    # no LaTeX artifacts ever leak
    out = speak_latex(r"\alpha + \beta")
    assert "\\" not in out and "$" not in out


def test_scripts():
    assert speak_latex(r"x^2") == "x squared"
    assert speak_latex(r"x^3") == "x cubed"
    assert speak_latex(r"x^n") == "x to the n-th power"
    assert speak_latex(r"x^{n+1}") == "x to the power of n plus 1"
    assert speak_latex(r"x_i") == "x sub i"
    assert speak_latex(r"x_i^2") == "x sub i squared"
    assert speak_latex(r"f'") == "f prime"


def test_fractions_and_roots():
    assert speak_latex(r"\frac{a}{b}") == "a over b"
    assert speak_latex(r"\frac{1}{2}") == "one half"
    assert speak_latex(r"\frac{a+b}{c}") == "the fraction a plus b over c end fraction"
    assert speak_latex(r"\sqrt{x}") == "the square root of x"
    assert speak_latex(r"\sqrt{x+1}") == "the square root of x plus 1"
    assert speak_latex(r"\sqrt[3]{x}") == "the 3-th root of x"


def test_bigops_functions_sets_accents():
    assert speak_latex(r"\sum_{i=1}^{n} a_i") == \
        "the sum from i equals 1 to n of a sub i"
    assert speak_latex(r"\int_0^1 f") == "the integral from 0 to 1 of f"
    assert speak_latex(r"\sin x") == "sine of x"
    assert speak_latex(r"\log n") == "log n"
    assert speak_latex(r"\mathbb{R}") == "the real numbers"
    assert speak_latex(r"\vec{x}") == "vector x"
    assert speak_latex(r"\hat{y}") == "y hat"
    assert speak_latex(r"\bar{x}") == "x bar"
    assert speak_latex(r"\lim_{n} a_n") == "the limit as n of a sub n"
    # upper-only bound: lower is None, upper is not None — must not be silently dropped
    assert speak_latex(r"\sum^{n} x") == "the sum to n of x"


def test_delimiters_matrices_and_fallback():
    # parentheses spoken for grouping
    assert speak_latex(r"(a + b)") == "open paren a plus b close paren"
    # an unknown macro degrades to spoken words, never leaks LaTeX
    out = speak_latex(r"\foobar{x}")
    assert "\\" not in out and "{" not in out and "foobar" in out
    # a matrix reads row by row, no leakage
    mtx = speak_latex(r"\begin{pmatrix} a & b \\ c & d \end{pmatrix}")
    assert "\\" not in mtx and "$" not in mtx
    assert "matrix" in mtx and "a" in mtx and "d" in mtx
    # even malformed input never raises and never leaks delimiters
    safe = speak_latex(r"$\frac{a}{$")
    assert "$" not in safe and "\\" not in safe


# --- verbalize_blocks tests ---

from vimarsha.math_speech import speak_latex, verbalize_blocks  # noqa: E402
from vimarsha.models import Block  # noqa: E402


def test_verbalize_fills_equation_text_and_keeps_latex():
    blocks = [Block(id="b0", index=0, kind="equation", latex=r"E = m c^2")]
    verbalize_blocks(blocks)
    assert blocks[0].text == "E equals m c squared"
    assert blocks[0].latex == r"E = m c^2"          # latex untouched (KaTeX)


def test_verbalize_rewrites_inline_math_in_prose():
    blocks = [Block(id="b0", index=0, kind="paragraph",
                    text=r"where $c$ is the speed and $\alpha$ a constant.")]
    verbalize_blocks(blocks)
    assert blocks[0].text == "where c is the speed and alpha a constant."
    assert "$" not in blocks[0].text


def test_verbalize_is_idempotent_on_plain_prose():
    blocks = [Block(id="b0", index=0, kind="paragraph", text="no math here.")]
    verbalize_blocks(blocks)
    assert blocks[0].text == "no math here."
