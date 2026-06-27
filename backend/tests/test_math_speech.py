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
