# EPUB Compatibility

> **Status:** Draft · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). The hard correctness problem: real-world
> EPUBs are wildly diverse, and every weird one is someone's favorite book. This doc owns
> the corpus + the failure policy. Pipeline: [narration-pipeline](../04-architecture/narration-pipeline.md).

## Policy

**Import generously, narrate honestly, never fake.** Any parseable EPUB gets into the
library; chapters that can't narrate say so (`error` + reason — the backend already raises
rather than caching junk); a failure mode without a graceful message is a bug.

## The graded corpus (build during M2; lives outside the repo, indexed here)

Grade A — must be perfect: well-formed nonfiction with labeled figures (the product's
home turf; includes `shared/fixtures/sample.epub`).
Grade B — must work: part-divider pages (known: no-text chapters raise → `error` state),
footnotes/endnotes, image-heavy chapters, poetry/quotes formatting, very long chapters
(20k+ chars — minutes-long synth).
Grade C — must degrade gracefully: image-only chapters, unlabeled figures (gallery-only),
tables (read? skip? summarize-in-copy?), equations (MathML/images), fixed-layout EPUB3,
RTL + Indic scripts (later: matters for the name's home market), DRM (detect + message,
Q-DRM), malformed/ancient files.

| # | Book/file | Grade | Known issues | Last run | Result |
|---|---|---|---|---|---|
| 1 | `shared/fixtures/sample.epub` | A | none (fixture) | 2026-06 (Flutter era) | ✅ |
| — | *populate as corpus books are added (V15 onward)* | | | | |

## Known failure modes (running list — add as found)

- Part-divider/no-text chapters → backend raises → client `error` + retry (✅ handled;
  copy review pending: "Couldn't narrate — this chapter has no readable text").
- Disk-pressure during synth of full books (dev) — [narration-pipeline debts](../04-architecture/narration-pipeline.md).
- Cover extraction variability (V11 spike will produce its own list: OPF `cover-image`
  vs `meta name="cover"` vs first-image heuristics).

## Verification cadence

V15 runs the Grade-A set; each later milestone widens (M3 exit: A+B green; P9 audit: full
corpus with recorded results in the table above). A corpus regression blocks merge same as
a test failure.
