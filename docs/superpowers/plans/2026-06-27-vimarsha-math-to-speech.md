# Math-to-Speech (Scientific Literature Phase 2b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Verbalize arXiv LaTeX math into spoken English so Chatterbox can narrate papers — fill each `equation` block's `text` and rewrite inline `$…$` in prose, leaving the `latex` field (KaTeX) untouched.

**Architecture:** One pure module `backend/src/vimarsha/math_speech.py` in three stages mirroring MathJax SRE: **tokenize** the `pylatexenc` node-list (split raw char runs into char tokens, carry macros with their arg-nodes, recurse into groups) → **parse** tokens into a small `MathNode` tree (recursive descent, postfix `^`/`_` scripts, macro arities, `unknown` fallback) → **speak** the tree with ClearSpeak-leaning rules. Public `speak_latex(str)->str` + `verbalize_blocks(blocks)->blocks`; `ingest_arxiv` calls the latter; `narrate.narratable_text` gains `equation`.

**Tech Stack:** Python 3.13, `pylatexenc` (already in the `papers` extra), pytest. No new dependency, no Node, no model.

## Global Constraints

- **TDD**: write failing test → run-fail → minimal impl → run-pass → commit. Small commits.
- **Commit trailer** on every commit:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- **Pure module**: `math_speech.py` does NO network and NO file I/O. (`pylatexenc` is the only import beyond stdlib + `vimarsha.models`.)
- **Never mutate `Block.latex`** — it is the client's KaTeX source. Math-to-speech only writes `Block.text`.
- **No leakage**: verbalized output must never contain `$`, `\`, `{`, `}`, `^`, `_`, or a raw LaTeX macro name with its backslash. Unknown constructs degrade to spoken words.
- **Test through the public API** (`speak_latex`) wherever possible — the token/parse internals are implementation details and must stay refactorable. Tests assert exact spoken strings.
- **Run tests from `backend/`** with `uv run pytest`. The whole suite must stay green.
- Style is **ClearSpeak-leaning** (natural read-aloud), gated behind a single module constant `STYLE` (value `"clearspeak"`) so a later switch to strict MathSpeak is a one-line change.

---

## File structure

- `backend/src/vimarsha/math_speech.py` — **new**. The whole verbalizer: `MathNode`, `_tokenize`, `_parse`, `_speak` + rule tables, `speak_latex`, `verbalize_blocks`. Grows task-by-task (one file; mirrors `arxiv_ingest.py`).
- `backend/tests/test_math_speech.py` — **new**. Unit tests, one group per task, all through `speak_latex` (+ the `verbalize_blocks` tests in the last task).
- `backend/src/vimarsha/arxiv_ingest.py` — **modify** (`ingest_arxiv`: one call to `verbalize_blocks`).
- `backend/src/vimarsha/narrate.py` — **modify** (`narratable_text`: add `"equation"`).
- `backend/tests/test_arxiv_ingest.py` — **modify** (add the live-corpus opt-in check + the no-leak assertion).

---

### Task 1: Module skeleton — tokenize/parse/speak with atoms & binary operators

Establishes the whole pipeline end-to-end for the simplest expressions (identifiers, numbers, Greek letters, binary operators/relations). Later tasks add rule groups onto this scaffolding.

**Files:**
- Create: `backend/src/vimarsha/math_speech.py`
- Test: `backend/tests/test_math_speech.py`

**Interfaces:**
- Consumes: `pylatexenc.latexwalker` (`LatexWalker`, `LatexCharsNode`, `LatexGroupNode`, `LatexMacroNode`, `LatexMathNode`).
- Produces (relied on by every later task):
  - `MathNode` dataclass: `kind: str`, `value: str = ""`, `children: list[MathNode] = []`.
  - `speak_latex(latex: str) -> str` — strips one optional `$…$` / `\(…\)` / `\[…\]` wrapper, tokenizes → parses → speaks, returns a collapsed-whitespace spoken string.
  - Internal (later tasks extend these in place): `_tokenize(nodelist) -> list[tuple]`, `_parse(tokens) -> MathNode`, `_speak(node: MathNode) -> str`, and the rule tables `GREEK`, `OPERATORS`.

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_math_speech.py
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_math_speech.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'vimarsha.math_speech'`.

- [ ] **Step 3: Write minimal implementation**

```python
# backend/src/vimarsha/math_speech.py
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_math_speech.py -v`
Expected: PASS (4 assertions in `test_atoms_and_binary_operators`).

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/math_speech.py backend/tests/test_math_speech.py
git commit -m "feat(backend): math-to-speech skeleton — atoms + operators (Phase 2b)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Scripts — superscripts, subscripts, primes

**Files:**
- Modify: `backend/src/vimarsha/math_speech.py` (`_parse` postfix loop, `_macro_atom`/`_atom` script handling, new `sup`/`sub` rules)
- Test: `backend/tests/test_math_speech.py`

**Interfaces:**
- Consumes: Task 1's `_parse`, `MathNode`, `_RULES`.
- Produces: `sup`/`sub`/`primed` node kinds + their speak rules; `_script_operand`. Relied on by Task 4 (big-operator bounds reuse `_script_operand`).

- [ ] **Step 1: Write the failing test**

```python
def test_scripts():
    assert speak_latex(r"x^2") == "x squared"
    assert speak_latex(r"x^3") == "x cubed"
    assert speak_latex(r"x^n") == "x to the n-th power"
    assert speak_latex(r"x^{n+1}") == "x to the power of n plus 1"
    assert speak_latex(r"x_i") == "x sub i"
    assert speak_latex(r"x_i^2") == "x sub i squared"
    assert speak_latex(r"f'") == "f prime"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_math_speech.py::test_scripts -v`
Expected: FAIL — `x^2` currently parses `^` as an `unknown` char → wrong string.

- [ ] **Step 3: Write minimal implementation**

In `_parse`, after obtaining each `atom`, attach trailing scripts and primes before appending. Replace the body of the `while i < n` loop:

```python
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
```

Add the operand helper (single token: a group or one char/macro becomes the script):

```python
def _script_operand(tokens: list[tuple], i: int) -> tuple[MathNode, int]:
    if i >= len(tokens):
        return MathNode("row"), i
    if tokens[i][0] == "group":
        return MathNode("row", children=_parse(tokens[i][1]).children), i + 1
    return _atom(tokens, i)
```

Add the speak rules and register them:

```python
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


_RULES.update({"sup": _speak_sup, "sub": _speak_sub, "primed": _speak_primed})
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_math_speech.py -v`
Expected: PASS (all of Task 1 + `test_scripts`).

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/math_speech.py backend/tests/test_math_speech.py
git commit -m "feat(backend): math-to-speech scripts — squared/cubed/sub/prime (Phase 2b)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Fractions & roots

**Files:**
- Modify: `backend/src/vimarsha/math_speech.py` (`_macro_atom` cases for `frac`/`sqrt`, new speak rules)
- Test: `backend/tests/test_math_speech.py`

**Interfaces:**
- Consumes: `_arg_tree`, `MathNode`, `_RULES`.
- Produces: `frac`/`sqrt` node kinds + rules.

- [ ] **Step 1: Write the failing test**

```python
def test_fractions_and_roots():
    assert speak_latex(r"\frac{a}{b}") == "a over b"
    assert speak_latex(r"\frac{1}{2}") == "one half"
    assert speak_latex(r"\frac{a+b}{c}") == "the fraction a plus b over c end fraction"
    assert speak_latex(r"\sqrt{x}") == "the square root of x"
    assert speak_latex(r"\sqrt{x+1}") == "the square root of x plus 1"
    assert speak_latex(r"\sqrt[3]{x}") == "the 3-th root of x"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_math_speech.py::test_fractions_and_roots -v`
Expected: FAIL — `\frac` currently hits the `unknown` macro branch.

- [ ] **Step 3: Write minimal implementation**

In `_macro_atom`, before the unknown-macro fallback, add the structural cases:

```python
    if name == "frac" and len(args) >= 2:
        return MathNode("frac", children=[_arg_tree(args[0]), _arg_tree(args[1])])
    if name == "sqrt":
        # args = [optional-degree-or-None, radicand]; radicand is the last arg
        degree = _arg_tree(args[0]) if len(args) >= 2 and args[0] is not None else None
        radicand = _arg_tree(args[-1]) if args else MathNode("row")
        children = [radicand] + ([degree] if degree is not None else [])
        return MathNode("sqrt", value=("nth" if degree is not None else "square"),
                        children=children)
```

Add speak rules. A "simple" operand is a single atom (one child / atomic kind); compound operands get the bracketed "the fraction … end fraction" form:

```python
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


_RULES.update({"frac": _speak_frac, "sqrt": _speak_sqrt})
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_math_speech.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/math_speech.py backend/tests/test_math_speech.py
git commit -m "feat(backend): math-to-speech fractions + roots (Phase 2b)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Big operators (with bounds), functions, sets, accents

**Files:**
- Modify: `backend/src/vimarsha/math_speech.py` (`_macro_atom` cases, `_parse` to attach bounds to big operators, new tables + rules)
- Test: `backend/tests/test_math_speech.py`

**Interfaces:**
- Consumes: `_script_operand` (Task 2), `_arg_tree`, `MathNode`, `_RULES`.
- Produces: `bigop`/`func`/`set`/`accent` node kinds + rules; `BIGOPS`, `FUNCTIONS`, `SETS`, `ACCENTS` tables. The `bigop` parse path reuses the postfix `^`/`_` loop already in `_parse`.

- [ ] **Step 1: Write the failing test**

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_math_speech.py::test_bigops_functions_sets_accents -v`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

Add tables (top of module, near `GREEK`):

```python
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
```

In `_macro_atom`, before the unknown fallback, add (order: structural cases from Task 3, then these):

```python
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
```

A `bigop`'s `_`/`^` bounds follow it as separate tokens, so **no new parse code is needed**: the postfix script `while` loop from Task 2 already wraps the `bigop` atom in `sub`/`sup` nodes when bounds are present (e.g. `\sum_{...}^{...}` → `sup(sub(bigop, lower), upper)`). The operand that the operator ranges over is simply the **next atom in the row**. So both the bounds and the operand are resolved entirely in the speak layer, at the **row** level. Replace `_speak_row` with a version that folds a `bigop` (possibly wrapped in sub/sup) together with the following sibling as its operand:

```python
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
    return f"{word}{bounds} of {operand_txt}".strip()


def _speak_row(node: MathNode) -> str:
    out: list[str] = []
    kids = [c for c in node.children if c is not None]
    i = 0
    while i < len(kids):
        if _bigop_base(kids[i]) is not None:
            operand = _speak(kids[i + 1]) if i + 1 < len(kids) else ""
            out.append(_speak_bigop_group(kids[i], operand))
            i += 2
        else:
            out.append(_speak(kids[i]))
            i += 1
    return " ".join(p for p in out if p)
```

Add `func`/`set`/`accent` rules. A `func` consumes its following sibling too — handle it in the same row loop branch:

```python
def _speak_set(node: MathNode) -> str:
    return node.value


def _speak_accent(node: MathNode) -> str:
    pre, post = node.value.split("|", 1)
    return f"{pre}{_speak(node.children[0])}{post}"
```

Extend the `_speak_row` loop to also fold a `func` with its operand (add this `elif` before the plain `else`). The expected strings differ per function: `\sin x`→"sine of x" but `\log n`→"log n", so only the trig names insert " of"; the `FUNCTIONS` table words that already end in " of" (`exp`, `max`, `min`, `det`) carry their own joiner; everything else reads bare:

```python
        elif kids[i].kind == "func":
            operand = _speak(kids[i + 1]) if i + 1 < len(kids) else ""
            word = kids[i].value
            needs_of = word in {"sine", "cosine", "tangent"} or word.endswith(" of")
            joiner = "" if word.endswith(" of") else (" of" if needs_of else "")
            out.append(f"{word}{joiner} {operand}".strip())
            i += 2
```

Register the leaf rules:

```python
_RULES.update({"bigop": _speak_value, "func": _speak_value,
               "set": _speak_set, "accent": _speak_accent})
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_math_speech.py -v`
Expected: PASS (all prior tasks + `test_bigops_functions_sets_accents`).

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/math_speech.py backend/tests/test_math_speech.py
git commit -m "feat(backend): math-to-speech big operators, functions, sets, accents (Phase 2b)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Delimiters, matrices/multiline, and the graceful fallback

**Files:**
- Modify: `backend/src/vimarsha/math_speech.py` (delimiter chars in `_atom`, environment handling in `_tokenize`/`_parse`, refine `_speak_unknown`)
- Test: `backend/tests/test_math_speech.py`

**Interfaces:**
- Consumes: all prior. Produces: `delim`/`matrix`/`mrow` handling + a hardened `_speak_unknown`. This is the no-leakage backstop the Global Constraints require.

- [ ] **Step 1: Write the failing test**

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_math_speech.py::test_delimiters_matrices_and_fallback -v`
Expected: FAIL — parens become "unknown", environments unhandled.

- [ ] **Step 3: Write minimal implementation**

Handle parentheses/brackets in `_atom`'s char branch (add before the final `unknown` return):

```python
        if c in "()":
            return MathNode("delim", value="open paren" if c == "(" else "close paren"), i + 1
        if c in "[]":
            return MathNode("delim", value="open bracket" if c == "[" else "close bracket"), i + 1
```

and register: add `"delim": _speak_value` to the `_RULES.update({...})` in Task 4 (or a new `_RULES.update({"delim": _speak_value})`).

Handle environments. `pylatexenc` yields `LatexEnvironmentNode` for `\begin{...}…\end{...}`. Import it and tokenize it as a `("env", name, nodelist)` token:

```python
from pylatexenc.latexwalker import LatexEnvironmentNode  # add to the import block
```

In `_tokenize`, add a branch:

```python
        elif isinstance(n, LatexEnvironmentNode):
            toks.append(("env", n.environmentname, n.nodelist))
```

In `_atom`, handle the env token (add a branch alongside the others):

```python
    if tok[0] == "env":
        return _env_atom(tok[1], tok[2]), i + 1
```

Add the matrix builder + rule. Rows split on `\\` (a macro named `` `\\` `` → in pylatexenc the row separator appears as a macro; treat any macro whose name is empty/`\\` as a row break, and `&` chars as column breaks):

```python
_MATRIX_ENVS = {"matrix", "pmatrix", "bmatrix", "vmatrix", "Vmatrix", "smallmatrix",
                "array", "cases", "aligned", "align", "align*", "split", "gather"}


def _env_atom(name: str, nodelist) -> MathNode:
    toks = _tokenize(nodelist)
    if name in _MATRIX_ENVS:
        rows: list[list[list[tuple]]] = [[[]]]
        for t in toks:
            if t == ("char", "&"):
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


_RULES.update({"matrix": _speak_matrix, "delim": _speak_value})
```

> **Implementer note:** `&` reaches `_tokenize` as a `("char", "&")` token (it is ordinary text to pylatexenc). The row separator `\\` reaches it as a macro token — confirm its `macroname` at runtime (it may be `"\\"` or empty) with a quick `uv run python -c` probe and include that value in the `("\\", "", "cr")` set. The test only asserts row-by-row structure + no leakage, so exact cell punctuation is flexible.

Harden `_speak_unknown` so multi-letter macro names read as words and nothing leaks (replace the Task 1 version):

```python
def _speak_unknown(node: MathNode) -> str:
    name = node.value.lstrip("\\")
    name = re.sub(r"[\\${}^_&]", " ", name).strip()
    parts = [name] + [_speak(c) for c in node.children]
    return " ".join(p for p in parts if p)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_math_speech.py -v`
Expected: PASS (all groups). Also run the whole file to confirm no regressions.

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/math_speech.py backend/tests/test_math_speech.py
git commit -m "feat(backend): math-to-speech delimiters, matrices, hardened fallback (Phase 2b)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Wire into ingestion + narration (`verbalize_blocks`, hook, live corpus)

**Files:**
- Modify: `backend/src/vimarsha/math_speech.py` (add `verbalize_blocks`)
- Modify: `backend/src/vimarsha/arxiv_ingest.py` (`ingest_arxiv` calls it)
- Modify: `backend/src/vimarsha/narrate.py` (`narratable_text` adds `"equation"`)
- Test: `backend/tests/test_math_speech.py`, `backend/tests/test_arxiv_ingest.py`

**Interfaces:**
- Consumes: `speak_latex`; `vimarsha.models.Block`.
- Produces: `verbalize_blocks(blocks: list[Block]) -> list[Block]` — mutates in place and returns the list: fills `equation.text` from `equation.latex`; rewrites inline `$…$`/`\(…\)` spans inside `paragraph`/`heading` `text`. Never alters `latex`.

- [ ] **Step 1: Write the failing tests**

```python
# in tests/test_math_speech.py
from vimarsha.math_speech import speak_latex, verbalize_blocks
from vimarsha.models import Block


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
```

```python
# in tests/test_arxiv_ingest.py — narration now reads equation blocks
from vimarsha.narrate import narratable_text
from vimarsha.models import Block


def test_equation_block_is_narratable_once_spoken():
    eq = Block(id="b0", index=0, kind="equation", latex="E=mc^2", text="E equals m c squared")
    assert narratable_text(eq) == "E equals m c squared"
    # …and an unspoken equation (no text) is still skipped
    assert narratable_text(Block(id="b1", index=1, kind="equation", latex="x")) is None
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && uv run pytest tests/test_math_speech.py::test_verbalize_fills_equation_text_and_keeps_latex tests/test_arxiv_ingest.py::test_equation_block_is_narratable_once_spoken -v`
Expected: FAIL — `verbalize_blocks` undefined; `narratable_text` returns `None` for equations.

- [ ] **Step 3: Write minimal implementation**

Add to `math_speech.py`:

```python
from vimarsha.models import Block  # add to imports

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
        elif b.kind in ("paragraph", "heading") and b.text and "$" in b.text:
            b.text = _rewrite_inline(b.text)
    return blocks
```

In `arxiv_ingest.py` `ingest_arxiv`, verbalize before constructing the bundle:

```python
    from vimarsha.math_speech import verbalize_blocks
    blocks = parse_latex_to_blocks(fetch_arxiv_latex(arxiv_id))
    verbalize_blocks(blocks)
    if not any(b.kind == "paragraph" for b in blocks):
        raise ValueError(f"arXiv:{arxiv_id} produced no readable text")
```

In `narrate.py` `narratable_text`, add `equation` to the text-bearing set:

```python
    if block.kind in ("heading", "paragraph", "blockquote", "pullquote", "list", "equation"):
        return block.text or None
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && uv run pytest tests/test_math_speech.py tests/test_arxiv_ingest.py -v`
Expected: PASS.

- [ ] **Step 5: Add the opt-in live corpus check (no-leak on a real paper)**

Append to `tests/test_arxiv_ingest.py` (skipped unless `VIMARSHA_LIVE=1`, matching the repo's live-test convention — confirm the exact env var/marker other live tests use and follow it):

```python
import os
import pytest


@pytest.mark.skipif(os.environ.get("VIMARSHA_LIVE") != "1", reason="hits arxiv.org")
def test_attention_paper_math_is_speakable():
    from vimarsha.arxiv_ingest import ingest_arxiv
    bundle = ingest_arxiv("1706.03762")
    eqs = [b for b in bundle.blocks if b.kind == "equation"]
    assert eqs, "expected display equations"
    for b in eqs:
        assert b.text, f"equation {b.id} has no spoken text"
        assert "$" not in b.text and "\\" not in b.text, f"leak in {b.id}: {b.text!r}"
    # inline math no longer leaves dollar signs in prose
    for b in bundle.blocks:
        if b.kind == "paragraph":
            assert "$" not in (b.text or "")
```

Run (live): `cd backend && VIMARSHA_LIVE=1 uv run pytest tests/test_arxiv_ingest.py::test_attention_paper_math_is_speakable -v`
Expected: PASS — every equation has spoken `text`, no `$`/`\` leakage. **Eyeball the printed equations for naturalness** (run with `-s` and add a temporary print if helpful; remove before commit).

- [ ] **Step 6: Run the full suite**

Run: `cd backend && uv run pytest`
Expected: all green (the ~55 existing + the new math-speech tests).

- [ ] **Step 7: Commit**

```bash
git add backend/src/vimarsha/math_speech.py backend/src/vimarsha/arxiv_ingest.py \
        backend/src/vimarsha/narrate.py backend/tests/test_math_speech.py \
        backend/tests/test_arxiv_ingest.py
git commit -m "feat(backend): verbalize math at ingest + narrate equation blocks (Phase 2b)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Notes for the implementer

- The trickiest reality is in Task 1's probe findings: `pylatexenc` returns `\frac`/`\sqrt`/`\alpha`/`\sum` as **macro nodes** but leaves `^ _ + = < > ( )`, digits, and identifiers inside raw `LatexCharsNode` text — so the tokenizer splits char runs into single-char tokens and the parser does the structural work. Re-run the probes in `git log` of this session if a node shape surprises you.
- When a rule's exact spoken string is ambiguous, the **test is the contract** — make the rule match the asserted string, and keep output free of `$ \ { } ^ _`.
- Keep everything in the one module; it mirrors `arxiv_ingest.py`. If it grows past ~400 lines, a later refactor can split tables/parse/speak — not now (YAGNI).
- Final merge: feature branch → small commits (above) → `cd backend && uv run pytest` green → `--no-ff` merge to `main`. Update the Scientific Literature track notes/commit message to mark **Phase 2b done**.
```
