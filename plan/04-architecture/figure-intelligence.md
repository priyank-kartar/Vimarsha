# Figure Intelligence

> **Status:** Draft · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). How figures get linked to the text that
> discusses them — today's rules, tomorrow's LLM assist
> ([ADR-003](../00-overview/decision-log.md#adr-003--figure-mentions-rules-first-llm-fallback-later)).
> Measured by [figure-accuracy](../06-content-pipeline/figure-accuracy.md).

## Today (shipped): rule-based mention detection

`backend/src/vimarsha/mention_detector.py` — explicit references ("Figure 3", "Fig. 2.1",
"Table 4") matched to registry entries; each figure's **span** widened around its mention
paragraphs; spans → ms against paraTimings at stitch time. Deterministic, fast, explainable.

**Known misses:** fuzzy references ("the chart below", "as the diagram shows"), unlabeled
images, references far from the figure, multiple plausible targets.

## The upgrade (bucket P6, the old "Plan 7"): LLM fallback at import

Reuse the backend `LlmClient` seam **at import time** (not at read time — auto-pop stays
deterministic on the client):

1. Rules run first and pin everything they can (precision anchor).
2. For unresolved figures / fuzzy mentions, the LLM gets: figure captions + candidate
   paragraphs (windowed) → proposes figure↔paragraph links with confidence.
3. Accept above a threshold; below it, the figure simply has no auto-pop span (gallery-only)
   — **a wrong figure is worse than no figure** ([principle 7](../03-design/design-principles.md)).
4. Output is the same figureMap shape — the client never knows which detector linked it.

Properties to hold: import stays a batch step (LLM latency hides in `pending`); results are
cached in the bundle (no per-playback inference); dev model = local Ollama, hosted model
TBD (Q-LLM).

## Eval before build (P6 entry gate)

Build the labeled corpus first ([figure-accuracy](../06-content-pipeline/figure-accuracy.md)):
ground-truth figure↔paragraph links for the corpus books; measure rules-only
precision/recall; the LLM pass must beat it on recall **without losing precision** — else it
doesn't ship. This is the speko-style "prove the risky bit" discipline applied to AI scope.
