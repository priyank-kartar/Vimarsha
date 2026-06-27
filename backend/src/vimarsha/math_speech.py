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

from vimarsha.models import Block

from pylatexenc.latexwalker import (
    LatexCharsNode,
    LatexEnvironmentNode,
    LatexGroupNode,
    LatexMacroNode,
    LatexMathNode,
    LatexSpecialsNode,
    LatexWalker,
)

STYLE = "clearspeak"  # the one tunable; "mathspeak" (strict) is a future switch

# --- rule tables (extended by later tasks) -------------------------------------------

BIGOPS = {"sum": "the sum", "prod": "the product", "int": "the integral",
          "oint": "the contour integral", "lim": "the limit", "bigcup": "the union",
          "bigcap": "the intersection"}
FUNCTIONS = {"sin": "sine", "cos": "cosine", "tan": "tangent", "log": "log",
             "ln": "natural log", "exp": "the exponential of", "max": "the maximum of",
             "min": "the minimum of", "det": "the determinant of", "deg": "degree"}
SETS = {"R": "the real numbers", "N": "the natural numbers", "Z": "the integers",
        "Q": "the rationals", "C": "the complex numbers"}
ACCENTS = {"vec": ("vector ", ""), "mathbf": ("vector ", ""), "boldsymbol": ("vector ", ""),
           "hat": ("", " hat"), "bar": ("", " bar"), "overline": ("", " bar"),
           "tilde": ("", " tilde"), "dot": ("", " dot")}

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
        elif isinstance(n, LatexEnvironmentNode):
            toks.append(("env", n.environmentname, n.nodelist))
        elif isinstance(n, LatexSpecialsNode):
            # &  →  column separator in matrix environments; pass through as special token
            if n.specials_chars == "&":
                toks.append(("specials", "&"))
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
        if atom is None:
            continue
        # postfix primes and scripts bind to the atom just parsed
        while i < n and tokens[i] == ("char", "'"):
            atom = MathNode("primed", children=[atom])
            i += 1
        while i < n and tokens[i][0] == "char" and tokens[i][1] in ("^", "_"):
            kind = "sup" if tokens[i][1] == "^" else "sub"
            operand, i = _script_operand(tokens, i + 1)
            atom = MathNode(kind, children=[atom, operand])
            # allow x_i^2 (sub then sup) to chain
        atoms.append(atom)
    return MathNode("row", children=atoms)


def _script_operand(tokens: list[tuple], i: int) -> tuple[MathNode, int]:
    if i >= len(tokens):
        return MathNode("row"), i
    if tokens[i][0] == "group":
        return MathNode("row", children=_parse(tokens[i][1]).children), i + 1
    return _atom(tokens, i)


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
        if c in "()":
            return MathNode("delim", value="open paren" if c == "(" else "close paren"), i + 1
        if c in "[]":
            return MathNode("delim", value="open bracket" if c == "[" else "close bracket"), i + 1
        return MathNode("unknown", value=c), i + 1  # stray punctuation
    if tok[0] == "group":
        return MathNode("row", children=_parse(tok[1]).children), i + 1
    if tok[0] == "macro":
        return _macro_atom(tok[1], tok[2]), i + 1
    if tok[0] == "env":
        return _env_atom(tok[1], tok[2]), i + 1
    return None, i + 1


def _macro_atom(name: str, args: list) -> MathNode:
    if name in GREEK:
        return MathNode("ident", value=GREEK[name])
    if name in MACRO_OPERATORS:
        return MathNode("op", value=MACRO_OPERATORS[name])
    if name == "frac" and len(args) >= 2:
        return MathNode("frac", children=[_arg_tree(args[0]), _arg_tree(args[1])])
    if name == "sqrt":
        # args = [optional-degree-or-None, radicand]; radicand is the last arg
        degree = _arg_tree(args[0]) if len(args) >= 2 and args[0] is not None else None
        radicand = _arg_tree(args[-1]) if args else MathNode("row")
        children = [radicand] + ([degree] if degree is not None else [])
        return MathNode("sqrt", value=("nth" if degree is not None else "square"),
                        children=children)
    if name in BIGOPS:
        return MathNode("bigop", value=BIGOPS[name])
    if name in FUNCTIONS:
        return MathNode("func", value=FUNCTIONS[name])
    if name in ("mathbb", "mathcal") and args:
        inner = _arg_tree(args[0])
        key = inner.children[0].value if inner.children else ""
        return MathNode("set", value=SETS.get(key, key))
    if name in ACCENTS and args:
        pre, post = ACCENTS[name]
        return MathNode("accent", value=f"{pre}|{post}", children=[_arg_tree(args[0])])
    # unknown macro: speak its name as words, keep any args as children (Task 5 refines)
    return MathNode("unknown", value=name, children=[_arg_tree(a) for a in args])


# --- speak ---------------------------------------------------------------------------

def _speak(node: MathNode) -> str:
    fn = _RULES.get(node.kind, _speak_unknown)
    return fn(node)


def _bigop_base(node: MathNode) -> MathNode | None:
    cur = node
    while cur.kind in ("sup", "sub"):
        cur = cur.children[0]
    return cur if cur.kind == "bigop" else None


def _speak_bigop_group(node: MathNode, operand_txt: str) -> str:
    # node is a bigop optionally wrapped: sup(sub(bigop, lower), upper) etc.
    lower = upper = None
    cur = node
    while cur.kind in ("sup", "sub"):
        if cur.kind == "sub":
            lower = _speak(cur.children[1])
        else:
            upper = _speak(cur.children[1])
        cur = cur.children[0]
    word = cur.value  # "the sum" / "the integral" / "the limit"
    bounds = ""
    if word == "the limit":
        if lower is not None:
            bounds = f" as {lower}"
    else:
        if lower is not None and upper is not None:
            bounds = f" from {lower} to {upper}"
        elif lower is not None:
            bounds = f" from {lower}"
        elif upper is not None:
            bounds = f" to {upper}"
    return f"{word}{bounds} of {operand_txt}".strip()


def _speak_set(node: MathNode) -> str:
    return node.value


def _speak_accent(node: MathNode) -> str:
    pre, post = node.value.split("|", 1)
    return f"{pre}{_speak(node.children[0])}{post}"


def _speak_row(node: MathNode) -> str:
    out: list[str] = []
    kids = [c for c in node.children if c is not None]
    i = 0
    while i < len(kids):
        if _bigop_base(kids[i]) is not None:
            operand = _speak(kids[i + 1]) if i + 1 < len(kids) else ""
            out.append(_speak_bigop_group(kids[i], operand))
            i += 2
        elif kids[i].kind == "func":
            operand = _speak(kids[i + 1]) if i + 1 < len(kids) else ""
            word = kids[i].value
            needs_of = word in {"sine", "cosine", "tangent"} or word.endswith(" of")
            joiner = "" if word.endswith(" of") else (" of" if needs_of else "")
            out.append(f"{word}{joiner} {operand}".strip())
            i += 2
        else:
            out.append(_speak(kids[i]))
            i += 1
    return " ".join(p for p in out if p)


def _speak_value(node: MathNode) -> str:
    return node.value


def _speak_unknown(node: MathNode) -> str:
    # Hardened fallback: multi-letter macro names read as words; NOTHING leaks.
    name = node.value.lstrip("\\")
    name = re.sub(r"[\\${}^_&]", " ", name).strip()
    parts = [name] + [_speak(c) for c in node.children]
    return " ".join(p for p in parts if p)


def _speak_sup(node: MathNode) -> str:
    base, exp = _speak(node.children[0]), _speak(node.children[1])
    if exp == "2":
        return f"{base} squared"
    if exp == "3":
        return f"{base} cubed"
    if re.fullmatch(r"[a-z]", exp) or exp.isdigit():
        return f"{base} to the {exp}-th power"
    return f"{base} to the power of {exp}"


def _speak_sub(node: MathNode) -> str:
    return f"{_speak(node.children[0])} sub {_speak(node.children[1])}"


def _speak_primed(node: MathNode) -> str:
    return f"{_speak(node.children[0])} prime"


_SIMPLE_FRACTIONS = {("1", "2"): "one half", ("1", "3"): "one third",
                     ("1", "4"): "one quarter", ("2", "3"): "two thirds"}


def _is_simple(node: MathNode) -> bool:
    if node.kind in ("ident", "number", "op"):
        return True
    if node.kind == "row":
        return len(node.children) <= 1
    return False


def _speak_frac(node: MathNode) -> str:
    num, den = node.children[0], node.children[1]
    n_txt, d_txt = _speak(num), _speak(den)
    if (n_txt, d_txt) in _SIMPLE_FRACTIONS:
        return _SIMPLE_FRACTIONS[(n_txt, d_txt)]
    if _is_simple(num) and _is_simple(den):
        return f"{n_txt} over {d_txt}"
    return f"the fraction {n_txt} over {d_txt} end fraction"


def _speak_sqrt(node: MathNode) -> str:
    radicand = _speak(node.children[0])
    if node.value == "nth":
        return f"the {_speak(node.children[1])}-th root of {radicand}"
    return f"the square root of {radicand}"


_MATRIX_ENVS = {"matrix", "pmatrix", "bmatrix", "vmatrix", "Vmatrix", "smallmatrix",
                "array", "cases", "aligned", "align", "align*", "split", "gather"}


def _env_atom(name: str, nodelist) -> MathNode:
    toks = _tokenize(nodelist)
    if name in _MATRIX_ENVS:
        rows: list[list[list[tuple]]] = [[[]]]
        for t in toks:
            if t == ("specials", "&"):
                rows[-1].append([])
            elif t[0] == "macro" and t[1] in ("\\", "", "cr"):
                rows.append([[]])
            else:
                rows[-1][-1].append(t)
        cells = [[_parse(c) for c in row if c] for row in rows if any(row)]
        return MathNode("matrix", value=name, children=[
            MathNode("mrow", children=row) for row in cells
        ])
    # non-matrix environment: just parse its body inline
    return MathNode("row", children=_parse(toks).children)


def _speak_matrix(node: MathNode) -> str:
    label = "cases" if node.value == "cases" else "matrix"
    parts = [label]
    for r, row in enumerate(node.children, start=1):
        cells = ", ".join(_speak(c) for c in row.children)
        parts.append(f"row {r}: {cells}")
    return " ".join(parts)


_RULES = {
    "row": _speak_row,
    "ident": _speak_value,
    "number": _speak_value,
    "op": _speak_value,
    "unknown": _speak_unknown,
}

_RULES.update({"sup": _speak_sup, "sub": _speak_sub, "primed": _speak_primed})
_RULES.update({"frac": _speak_frac, "sqrt": _speak_sqrt})
_RULES.update({"bigop": _speak_value, "func": _speak_value,
               "set": _speak_set, "accent": _speak_accent})
_RULES.update({"matrix": _speak_matrix, "delim": _speak_value})


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


# --- block-level verbalization -------------------------------------------------------

_INLINE_MATH = re.compile(r"\$([^$]+)\$|\\\(([^)]*?)\\\)")


def _rewrite_inline(text: str) -> str:
    def repl(m: re.Match) -> str:
        return speak_latex(m.group(1) if m.group(1) is not None else m.group(2))
    return re.sub(r"\s+", " ", _INLINE_MATH.sub(repl, text)).strip()


def verbalize_blocks(blocks: list[Block]) -> list[Block]:
    """Fill equation blocks' spoken text and verbalize inline math in prose. In place.
    Never touches Block.latex (the client's KaTeX source)."""
    for b in blocks:
        if b.kind == "equation" and b.latex:
            b.text = speak_latex(b.latex)
        elif b.kind in ("paragraph", "heading") and b.text and ("$" in b.text or "\\(" in b.text):
            b.text = _rewrite_inline(b.text)
    return blocks
