"""LaTeX math -> spoken English, a pure-Python port of MathJax SRE conventions.

Three stages: tokenize the pylatexenc node-list (raw char runs become single-char tokens,
macros carry their argument nodes, groups recurse) -> parse into a small MathNode tree
(recursive descent; postfix ^/_ scripts; macro arities; unknown -> graceful fallback) ->
speak the tree with ClearSpeak-leaning rules. No network, no I/O. Only Block.text is written
by callers; Block.latex (the client's KaTeX source) is never touched.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

from pylatexenc.latexwalker import (
    LatexCharsNode,
    LatexGroupNode,
    LatexMacroNode,
    LatexMathNode,
    LatexWalker,
)

STYLE = "clearspeak"  # the one tunable; "mathspeak" (strict) is a future switch

# --- rule tables (extended by later tasks) -------------------------------------------

GREEK = {
    "alpha": "alpha", "beta": "beta", "gamma": "gamma", "delta": "delta",
    "epsilon": "epsilon", "varepsilon": "epsilon", "zeta": "zeta", "eta": "eta",
    "theta": "theta", "vartheta": "theta", "iota": "iota", "kappa": "kappa",
    "lambda": "lambda", "mu": "mu", "nu": "nu", "xi": "xi", "pi": "pi", "rho": "rho",
    "sigma": "sigma", "tau": "tau", "upsilon": "upsilon", "phi": "phi",
    "varphi": "phi", "chi": "chi", "psi": "psi", "omega": "omega",
    "Gamma": "capital gamma", "Delta": "capital delta", "Theta": "capital theta",
    "Lambda": "capital lambda", "Xi": "capital xi", "Pi": "capital pi",
    "Sigma": "capital sigma", "Phi": "capital phi", "Psi": "capital psi",
    "Omega": "capital omega", "infty": "infinity", "partial": "partial", "nabla": "del",
}

# single-character operators/relations found inside LatexCharsNode text
OPERATORS = {
    "+": "plus", "-": "minus", "=": "equals", "<": "less than", ">": "greater than",
    "/": "divided by", "*": "times", ",": "comma", "!": "factorial", "|": "bar",
}

# macro operators/relations (multi-char in LaTeX)
MACRO_OPERATORS = {
    "times": "times", "cdot": "times", "div": "divided by", "pm": "plus or minus",
    "mp": "minus or plus", "leq": "less than or equal to", "le": "less than or equal to",
    "geq": "greater than or equal to", "ge": "greater than or equal to",
    "neq": "not equal to", "ne": "not equal to", "approx": "approximately equals",
    "equiv": "is equivalent to", "sim": "tilde", "propto": "is proportional to",
    "to": "to", "rightarrow": "to", "Rightarrow": "implies", "leftarrow": "from",
    "in": "in", "notin": "not in", "subset": "subset of", "subseteq": "subset of",
    "supset": "superset of", "cup": "union", "cap": "intersection",
    "forall": "for all", "exists": "there exists", "cdots": "dot dot dot",
    "ldots": "dot dot dot", "dots": "dot dot dot",
}


@dataclass
class MathNode:
    kind: str                         # "row" | "ident" | "number" | "op" | "unknown" | ...
    value: str = ""
    children: list["MathNode"] = field(default_factory=list)


# --- tokenize ------------------------------------------------------------------------

# Token shapes:
#   ("char", c)              one significant (non-space) character from a CharsNode
#   ("macro", name, [arg])   a macro; args are pylatexenc nodes (LatexGroupNode or None)
#   ("group", [tokens])      a {...} group, inner already tokenized

def _tokenize(nodelist) -> list[tuple]:
    toks: list[tuple] = []
    for n in nodelist or []:
        if isinstance(n, LatexCharsNode):
            for ch in n.chars:
                if not ch.isspace():
                    toks.append(("char", ch))
        elif isinstance(n, LatexMacroNode):
            args = list(n.nodeargd.argnlist) if n.nodeargd else []
            toks.append(("macro", n.macroname, args))
        elif isinstance(n, LatexGroupNode):
            toks.append(("group", _tokenize(n.nodelist)))
        elif isinstance(n, LatexMathNode):
            toks.extend(_tokenize(n.nodelist))
        # comments / unknown node types are ignored
    return toks


def _arg_tree(argnode) -> MathNode:
    """Parse a macro argument (a pylatexenc group/None) into a MathNode subtree."""
    if argnode is None:
        return MathNode("row")
    return _parse(_tokenize(getattr(argnode, "nodelist", []) or []))


# --- parse ---------------------------------------------------------------------------

def _parse(tokens: list[tuple]) -> MathNode:
    """Token list -> a 'row' MathNode (children in document order)."""
    atoms: list[MathNode] = []
    i = 0
    n = len(tokens)
    while i < n:
        atom, i = _atom(tokens, i)
        if atom is not None:
            atoms.append(atom)
    return MathNode("row", children=atoms)


def _atom(tokens: list[tuple], i: int) -> tuple[MathNode | None, int]:
    tok = tokens[i]
    if tok[0] == "char":
        c = tok[1]
        if c.isdigit():
            num = c
            i += 1
            while i < len(tokens) and tokens[i][0] == "char" and tokens[i][1].isdigit():
                num += tokens[i][1]
                i += 1
            return MathNode("number", value=num), i
        if c.isalpha():
            return MathNode("ident", value=c), i + 1
        if c in OPERATORS:
            return MathNode("op", value=OPERATORS[c]), i + 1
        return MathNode("unknown", value=c), i + 1  # stray punctuation
    if tok[0] == "group":
        return MathNode("row", children=_parse(tok[1]).children), i + 1
    if tok[0] == "macro":
        return _macro_atom(tok[1], tok[2]), i + 1
    return None, i + 1


def _macro_atom(name: str, args: list) -> MathNode:
    if name in GREEK:
        return MathNode("ident", value=GREEK[name])
    if name in MACRO_OPERATORS:
        return MathNode("op", value=MACRO_OPERATORS[name])
    # unknown macro: speak its name as words, keep any args as children (Task 5 refines)
    return MathNode("unknown", value=name, children=[_arg_tree(a) for a in args])


# --- speak ---------------------------------------------------------------------------

def _speak(node: MathNode) -> str:
    fn = _RULES.get(node.kind, _speak_unknown)
    return fn(node)


def _speak_row(node: MathNode) -> str:
    return " ".join(_speak(c) for c in node.children if c is not None)


def _speak_value(node: MathNode) -> str:
    return node.value


def _speak_unknown(node: MathNode) -> str:
    # a stray char or unrecognized macro: read the name as words, recurse into children
    name = re.sub(r"[\\${}^_]", " ", node.value)
    name = re.sub(r"[a-z][A-Z]", lambda m: m.group(0)[0] + " " + m.group(0)[1], name)
    parts = [name.strip()] + [_speak(c) for c in node.children]
    return " ".join(p for p in parts if p)


_RULES = {
    "row": _speak_row,
    "ident": _speak_value,
    "number": _speak_value,
    "op": _speak_value,
    "unknown": _speak_unknown,
}


# --- public --------------------------------------------------------------------------

_WRAPPERS = (
    (r"\(", r"\)"), (r"\[", r"\]"),
)


def _strip_math_delims(latex: str) -> str:
    s = latex.strip()
    if s.startswith("$$") and s.endswith("$$"):
        return s[2:-2].strip()
    if s.startswith("$") and s.endswith("$"):
        return s[1:-1].strip()
    for lo, hi in _WRAPPERS:
        if s.startswith(lo) and s.endswith(hi):
            return s[len(lo):-len(hi)].strip()
    return s


def speak_latex(latex: str) -> str:
    """Verbalize a LaTeX math fragment into spoken English. Pure; never raises on bad input."""
    inner = _strip_math_delims(latex or "")
    if not inner:
        return ""
    try:
        nodes, _, _ = LatexWalker(inner).get_latex_nodes()
        tree = _parse(_tokenize(nodes))
        spoken = _speak(tree)
    except Exception:  # noqa: BLE001 — speech must never crash narration
        spoken = re.sub(r"[\\${}^_]", " ", inner)
    return re.sub(r"\s+", " ", spoken).strip()
