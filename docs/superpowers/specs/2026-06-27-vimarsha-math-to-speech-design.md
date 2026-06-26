# Vimarsha — Math-to-Speech (Scientific Literature Phase 2b)

> **Status:** Design · **Date:** 2026-06-27 · **Track:** Scientific Literature
> (Phase 1 = apple section shell · Phase 2a = arXiv LaTeX → blocks · **2b = this**)
> Backend-only. Unblocks narration of papers.

## Problem

Phase 2a (`arxiv_ingest.py`) turns an arXiv paper into a `ChapterBundle` of ordered
blocks, deliberately leaving math **unspoken**:

- Display math → an `equation` block carrying verbatim `latex` (for the client's KaTeX
  render) with `text = None`. `narrate.narratable_text` doesn't handle `equation`, so these
  blocks are **silently skipped** by narration.
- Inline math stays raw in paragraph/heading `text` as `$…$` / `\(…\)`. Chatterbox would
  literally read "dollar c dollar".

Phase 2b fills the spoken form so Chatterbox can narrate papers naturally, **without
altering the `latex` field** (KaTeX rendering on the client is untouched).

## Approach (decided)

A **pure-Python port of MathJax's Speech Rule Engine (SRE) conventions** — deterministic,
fully unit-testable, no Node runtime, no learned model. Rejected alternatives:

- **Node `speech-rule-engine`** — best fidelity but adds a Node dependency + subprocess
  seam to a pure-Python (uv) backend; hard to test offline; heavier Docker image.
- **LLM seam (Ollama/GLM)** — non-deterministic, network-bound, slow per-equation,
  untestable offline; violates the codebase's minimal-seams rule.
- **MathReader-style fine-tuned T5** (arXiv 2501.07088) — a learned LaTeX→speech model.
  Weights aren't publicly released; it ships inside a heavyweight Nougat-OCR + NeMo-TTS
  pipeline we don't need (arXiv gives exact LaTeX; Chatterbox is our TTS). Adopted only as
  the **quality bar / error-type reference**, not the method.

The SRE port follows MathSpeak/ClearSpeak rule conventions for the constructs that dominate
ML/physics papers, with a graceful fallback so **no equation ever yields garbage or is
silently skipped**.

## Architecture

One new pure module: `backend/src/vimarsha/math_speech.py`. Three stages, mirroring SRE's
layering (scoped down):

### 1. Parse — LaTeX math → expression tree
Reuse `pylatexenc` (already in the `papers` extra) to walk math nodes; normalize into a
small internal node model so speech rules never touch raw LaTeX strings:

```python
@dataclass
class MathNode:
    kind: str            # "frac" | "sup" | "sub" | "sqrt" | "bigop" | "op" |
                         # "ident" | "number" | "greek" | "func" | "accent" |
                         # "group" | "row" | "matrix" | "unknown" | ...
    value: str = ""      # literal payload for atoms (identifier, number, op name)
    children: list["MathNode"] = field(default_factory=list)
    # script carriers: sub/sup live as children with role tags where needed
```

Parsing is best-effort: anything the normalizer can't classify becomes a `kind="unknown"`
node carrying its source token(s), to be handled by the fallback rule (never dropped).

### 2. Speak — tree → spoken string (MathSpeak-style rules)
One pure rule function per node kind, dispatched on `kind`. Style is **ClearSpeak-leaning**
(natural read-aloud) rather than strict MathSpeak literalness — it's an audiobook, not a
screen reader. The literal-vs-natural choice is a single tunable constant so it can be
flipped later.

### 3. Apply — entry points used by ingestion
- `speak_latex(latex: str) -> str` — the core verbalizer (parse → speak). Pure.
- `verbalize_blocks(blocks: list[Block]) -> list[Block]`:
  - for each `equation` block: set `text = speak_latex(block.latex)` (leave `latex` as-is);
  - for each `paragraph`/`heading`: replace inline `$…$` and `\(…\)` spans in `text` with
    `speak_latex(span)` in place.

## Integration (minimal, one seam + one line)

- `ingest_arxiv` calls `verbalize_blocks(blocks)` as its final step (after
  `parse_latex_to_blocks`), so verbalization is reusable by any future LaTeX source
  (e.g. PDF/OCR path) — not arXiv-specific.
- `narrate.narratable_text` gains `equation` to the narratable set:
  `if block.kind in (... , "equation"): return block.text or None`.
  Equation blocks now carry `text`, so they narrate like any other block; timings + figure
  ms resolution are unchanged (an equation is "just another narratable block").
- `latex` field, KaTeX rendering, and the apple client are **untouched**.

## The ruleset (MathSpeak port, pragmatic core)

| Group | Examples → spoken |
|---|---|
| Atoms | identifiers read as-is; numbers; `\alpha`→"alpha"; `\infty`→"infinity"; `\partial`→"partial"; `\nabla`→"del" |
| Scripts | `x^2`→"x squared"; `x^3`→"x cubed"; `x^n`→"x to the n-th power"; compound exponent→"to the power of …"; `x_i`→"x sub i"; `'`→"prime" |
| Fractions | simple→"a over b" (or "one half"); compound→"the fraction … over … end fraction" |
| Roots | `\sqrt{x}`→"the square root of x"; `\sqrt[n]{x}`→"the n-th root of x" |
| Big operators | `\sum_{i=1}^{n}`→"the sum from i equals 1 to n of …"; `\prod`,`\int`,`\lim` similarly |
| Operators/relations | `+ - = \times \cdot \leq \geq \neq \approx \to \in \subset \cup \cap \pm` → words; juxtaposition (implicit multiply) stays silent |
| Functions/sets | `\sin \cos \log \exp \max \min`→names; `\mathbb{R}`→"the real numbers"; `\vec{x}`/`\mathbf{x}`→"vector x"; `\hat{x}`→"x hat"; `\bar{x}`→"x bar" |
| Delimiters | spoken ("open paren … close paren") only for non-trivial grouping; suppressed for argument grouping |
| Matrices / multiline | `matrix`/`pmatrix`/`cases`/`align` → row-by-row ("matrix, row 1: … row 2: …"); **fall back to the generic rule if row-by-row reads noisy** |
| **Fallback** | any unrecognized macro/environment → read its name as words and recurse into children; **never** emit LaTeX or `$`. No equation is ever skipped. |

## Testing (TDD)

- Pure unit tests, one per rule group, asserting **exact** spoken strings (write failing →
  minimal rule → green). Includes the fallback path (unknown macro degrades cleanly) and the
  inline-rewrite path (a paragraph with `$c$` → "… c …", no dollar signs left).
- A `narratable_text` test: an `equation` block with `text` set is now narratable.
- Opt-in live test (not in the default suite): verbalize the 8 display equations of
  "Attention Is All You Need" (the 2a live corpus) and assert no `$`/backslash leakage +
  eyeball naturalness.
- Both existing suites stay green; no apple-side change.

## Scope / YAGNI

- **In:** display equations + inline math verbalization; the pragmatic-core ruleset above;
  graceful fallback; the narrate hook.
- **Out (later phases):** exhaustive LaTeX coverage (exotic environments, deeply nested
  matrices beyond row-by-row); a learned/T5 verbalizer (the seam — `speak_latex` — makes a
  later swap possible without touching callers); the PDF/OCR LaTeX source (separate phase),
  which will reuse `verbalize_blocks` unchanged.

## Risks

- `pylatexenc`'s math-node granularity may not cleanly expose every script/operator
  structure → mitigated by the normalize step + `unknown` fallback (degrade, never crash).
- Over-verbose output on dense equations → mitigated by ClearSpeak-leaning brevity (suppress
  argument-grouping parens, silent juxtaposition) and the live-corpus eyeball.
