# Design Principles

> **Status:** Reviewed · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). The judgment calls behind every screen.
> Canonical law (tokens, APIs, rules) is [apple/CLAUDE.md](../../apple/CLAUDE.md); this doc
> is the *why* behind it.

1. **All motion, no pages.** The app is one continuously morphing surface. A "screen" is a
   state reached by transforming what's already visible. If a feature seems to need a page,
   the design isn't finished. (Prime Directive — [apple/CLAUDE.md](../../apple/CLAUDE.md).)
2. **Content is paper, controls are glass.** Books, text, figures are matte and physical;
   interactive things float as Liquid Glass. The one sanctioned hybrid is the figure's glass
   *carrier* (glass frame, matte image).
3. **Editorial calm.** Generous negative space, serif display type, near-zero chrome. The
   library should feel like a gallery, not a file manager. Color discipline: the palette is
   the canvas; the books supply all other saturation.
4. **Motion explains, or it goes.** Every animation must answer "where did this come from /
   where did it go." Decorative motion that doesn't carry spatial continuity gets cut.
5. **Scrubbable, never scripted.** Transitions are driven by scroll/gesture progress or
   retargetable springs — the user can grab, reverse, and interrupt anything mid-flight.
6. **The ears lead, the eyes confirm.** This is an eyes-free product first: every visual
   state has an audible/announced equivalent, and nothing important happens *only* visually.
7. **A wrong figure is worse than no figure.** Auto-pop optimizes precision over recall;
   the gallery is the guaranteed path ([figure-accuracy](../06-content-pipeline/figure-accuracy.md)).
8. **Accessibility is a parity feature, not a fallback.** Reduce Motion/Transparency users
   get a *designed* experience (flat list, matte tints), not an apologetic one
   ([accessibility](accessibility.md)).
9. **Quality bars are budgets.** 120Hz during flicks, <1s cached-chapter start, first-run to
   first narration <2 min — regressions are bugs, not tradeoffs.
10. **Honest by default.** DRM we can't read, chapters that can't narrate, AI that's
    guessing — say so plainly in the UI; never fake success.
