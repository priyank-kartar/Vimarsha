# Figure Accuracy

> **Status:** Draft · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). "The figure appears at the right moment" is a
> pillar — so it gets a number, not a vibe. Detector design:
> [figure-intelligence](../04-architecture/figure-intelligence.md).

## What we measure

For each figure in a corpus chapter, ground truth = the paragraph range where a human says
it's being discussed. Against the produced `figureMap`:

- **Precision** (of auto-pops shown, how many were right) — the sacred metric: *a wrong
  figure is worse than no figure* ([principle 7](../03-design/design-principles.md)).
- **Recall** (of discussable figures, how many got a span) — the improvement axis for the
  LLM fallback (P6).
- **Timing tolerance:** a pop within ±1 paragraph of ground truth counts; grossly early/late
  pops count as wrong (they *feel* wrong even when the link is right).

## Targets (provisional until first measurement)

| Metric | Rules-only (ship bar, M3) | With LLM fallback (P6 exit bar) |
|---|---|---|
| Precision | ≥ 0.95 | ≥ 0.95 (must not drop) |
| Recall | measure + record (likely ~0.5–0.7 on labeled figures) | beats rules-only meaningfully, else P6 doesn't ship |

## The labeled set (P6 entry gate; start small during M3)

~5 Grade-A corpus chapters ([epub-compatibility](epub-compatibility.md)), figure-dense,
hand-labeled (figure id → paragraph range) in a simple JSONL the backend tests can consume.
Labeling is an hour of honest work per book — do it while verifying V21, when you're
listening anyway.

## Failure taxonomy (tag every miss)

`fuzzy-reference` ("the chart below") · `unlabeled-figure` · `far-reference` (mention pages
away) · `multi-candidate` (ambiguous "the diagram") · `caption-only` (figure never discussed
in body) · `detector-bug` (rules wrong on an explicit reference — always fix these first).
The taxonomy tells P6 what the LLM actually needs to solve, instead of guessing.

## Product backstops (independent of accuracy)

The Figures gallery reaches everything; auto-pop dismissal is one tap and never pauses
audio; zero-span figures are gallery-only by design. Accuracy work raises delight; the
backstops guarantee usability at any accuracy.
