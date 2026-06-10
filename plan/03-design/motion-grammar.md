# Motion Grammar — The Hero Interaction

> **Status:** Reviewed · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). Motion *is* the product's signature; this doc
> is its home in the plan. The implementable definitions (with SwiftUI notes and the
> performance budget) are canonical in
> [apple/CLAUDE.md §Motion grammar + §Liquid Glass](../../apple/CLAUDE.md); the evidence they
> derive from is the frame-by-frame
> [reference-video analysis](../../apple/docs/reference/ref-books-video-analysis.md)
> (stills in [`apple/docs/reference/frames/`](../../apple/docs/reference/frames/)).

## The seven named patterns (use these names in specs, code, commits)

1. **Depth-stack parallax scroll** — the signature; card transform = continuous function of
   viewport position. *Implemented (V03), tuned in V09.*
2. **Grow-to-front promotion** — front-slot crossing scales/brightens with deepening contact
   shadow. *Partially implemented (V03); emphasis curve in V06.*
3. **Recede-and-clip** — top-exiting cards shrink/dim/tuck **upward** and dissolve under the
   glass top-scrim. *Implemented (V03; direction locked by test after the review caught the
   inverted sign).*
4. **Slot-emit staircase fan-up** — covers rise from the shelf anchor, scroll-driven. *V08.*
5. **Coupled scroll+zoom hero settle** — header exits while the stack scales as one rigid
   group. *Post-V09 tuning candidate.*
6. **Inertial flick with dwell** — soft landings, no bounce, stacking velocity. *Native
   inertia today; tuned + puck in V05/V09.*
7. **Settle contrast shift** — header type gains contrast as it reaches rest. *V04.*

## The eight glass moments

Top-scrim dissolve (✅ V03 basic) · lensing drag puck (V05) · floating glass header plane
(V04 extension) · container merge on promotion (V06/V07) · control cluster from the hero
cover (V07) · meniscus shelf slot (V08 stretch) · velocity-reactive sheen (polish bucket) ·
figure overlay glass carrier (V20).

## Review gate

Every motion-touching V-item ends with a recorded capture checked **against the named
pattern's definition** — not against taste. Deviations either get fixed or get an ADR (the
grammar is allowed to evolve, silently drifting isn't). The full-pass review is
[V09](../08-engineering/build-roadmap.md#phase-p1--the-living-library); device feel
(grammar #6) can only be judged by hand — keep a human in that loop.

## Open motion questions

Stack end behavior (Q-LOOP, default: soft stop) · hero zoom authenticity (the reference's
opening zoom may be mockup chrome — treat as scroll-driven effect, revisit in V09) ·
chapter-fan choreography (Q-CHAP, designed in V06/V17 pass).
