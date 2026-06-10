# Decision Log (ADRs)

> **Status:** Living · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). Architecture/product decision records.
> Append-only: to change a decision, add a new entry that supersedes the old one (note it in
> both). ADR-001–007 are recorded retroactively (decisions predate this log); each cites
> where it was originally made.

**Template**
```
### ADR-NNN — <title>
- Date: YYYY-MM-DD · Status: Proposed | Accepted | Superseded by ADR-XXX
- Context: <why this came up>
- Decision: <what we chose>
- Rationale: <why>
- Consequences: <tradeoffs, follow-ups>
```

---

### ADR-001 — Two-tier architecture: stateless backend, client re-uploads the EPUB
- Date: 2026-06-03 (retro-logged 2026-06-11) · Status: Accepted
- Context: Where does book state live, given a GPU backend and an offline-capable client?
- Decision: The backend is **stateless**; the client keeps the original EPUB and re-uploads
  it with a `chapter_index` to narrate each chapter on demand (`POST /import`). The client
  caches `chapter.mp3` + bundle JSON locally.
- Rationale: No server-side library to secure/sync; offline reading once cached; backend
  swappable (local ↔ RunPod ↔ hosted).
- Consequences: Upload cost per chapter (acceptable: EPUBs are small); hosted-scope keeps
  the same shape (transient processing, zero retention — see ADR-009). Original:
  [`docs/superpowers/specs/2026-06-03-vimarsha-ebook-reader-design.md`](../../docs/superpowers/specs/2026-06-03-vimarsha-ebook-reader-design.md).

### ADR-002 — Narration: Chatterbox TTS + paragraph-timing stitch (no forced alignment)
- Date: 2026-06-03 (retro-logged 2026-06-11) · Status: Accepted
- Context: Need audiobook-quality narration with paragraph-accurate timings for highlight,
  seek, and figure sync.
- Decision: Synthesize per narratable block with **Chatterbox**, concatenate into ONE
  `chapter.mp3`, and record paragraph→ms timings **during concatenation** instead of running
  forced alignment.
- Rationale: Timings are exact by construction; one audio file simplifies the player; no
  alignment model dependency.
- Consequences: Timing granularity is the block/paragraph (fine for our features); GPU-heavy
  synth (~7–8× slower than realtime on MPS) motivates the hosted service (ADR-009) and the
  known `get_synth()` caching debt ([narration-pipeline](../04-architecture/narration-pipeline.md)).

### ADR-003 — Figure mentions: rules first, LLM fallback later
- Date: 2026-06-04 (retro-logged 2026-06-11) · Status: Accepted
- Context: Auto-pop needs text→figure links; explicit references ("Figure 3") are easy,
  fuzzy ones ("the chart below") are not.
- Decision: Ship **rule-based mention detection** with span widening; treat auto-pop as
  best-effort; add an **LLM fallback at import time** later (the old "Plan 7", now
  [figure-intelligence](../04-architecture/figure-intelligence.md) + roadmap bucket P6).
- Rationale: Rules cover the common case cheaply and deterministically; the Figures gallery
  is the reliable fallback surface.
- Consequences: Auto-pop accuracy is a measured, improvable metric — see
  [figure-accuracy](../06-content-pipeline/figure-accuracy.md).

### ADR-004 — Client pivot: native SwiftUI + Liquid Glass (iOS 26 + macOS 26)
- Date: 2026-06-10 · Status: Accepted
- Context: UI is the main selling point; the Flutter client proved the product but not the
  feel. User supplied a palette + reference video ("all motion, no pages").
- Decision: Rebuild the client **native Swift/SwiftUI** under `apple/`, iOS 26 + macOS 26
  only, real Liquid Glass APIs, full feature parity as the goal. Design law lives in
  [`apple/CLAUDE.md`](../../apple/CLAUDE.md).
- Rationale: Liquid Glass + ProMotion-grade motion are native-only; the reference's motion
  grammar maps directly to SwiftUI primitives.
- Consequences: Two clients exist during transition (see ADR-007); no backward OS support;
  the motion-review gate joins the workflow.

### ADR-005 — Palette as the canvas, dark-first
- Date: 2026-06-10 · Status: Accepted
- Context: User-supplied 4-color palette (butter/aqua/sky/slate); reference video used a
  neutral cream canvas instead.
- Decision: The palette **is the canvas** (the app visibly lives in the four colors + a
  derived `ink` ramp); design **dark-first**, both modes ship; body text is `ink`-on-light /
  warm-paper-on-dark (slate/sky are decorative only — WCAG).
- Rationale: Distinctive identity over reference mimicry; dark suits night reading.
- Consequences: All hexes live in one place (`Palette.swift`); book covers supply all other
  saturation. See [apple/CLAUDE.md §Color palette](../../apple/CLAUDE.md).

### ADR-006 — Cover art is client-side
- Date: 2026-06-11 · Status: Accepted
- Context: The depth-stack's premise is real covers, but the contract has no cover field
  (`BookMeta` = title+author).
- Decision: The Swift client extracts/renders covers itself from the EPUB it already holds;
  the backend contract stays untouched. Static `BookSeed` covers stand in until extraction
  lands (V11).
- Rationale: Keeps the backend stateless and the contract stable; covers are a client
  rendering concern.
- Consequences: Client needs an EPUB cover-extraction path (V11 `[SPIKE]`); generated
  cloth-bound covers remain the missing-art fallback.

### ADR-007 — Freeze the Flutter client; all new feature work is Swift-only
- Date: 2026-06-11 · Status: Accepted
- Context: The old Plan 6b (Discuss UI) was queued for Flutter when the Swift pivot landed.
- Decision: **Flutter is frozen** as the working behavioral reference (it stays green, no
  new features); Discuss UI and everything after are built natively (roadmap bucket P5).
- Rationale: Two evolving clients double every feature; the Flutter app's value now is
  parity reference + a working data-layer design to mirror.
- Consequences: `app/` tests stay in CI as-is; HANDOFF/CLAUDE.md updated; the old Plan 6b
  spec remains the *behavioral* spec for the native Discuss build.

### ADR-008 — Ambition: App Store product
- Date: 2026-06-11 · Status: Accepted
- Context: Personal tool vs public product determines whether market/monetization/GTM are
  real workstreams.
- Decision: Vimarsha ships publicly on the App Store. Market, positioning, pricing,
  monetization, and GTM are first-class plan sections.
- Rationale: The product gap (own-EPUB narration + figure sync + grounded discussion) is
  real and underserved; the UI is differentiated enough to market.
- Consequences: Hosted backend becomes necessary (ADR-009); privacy claims must be
  verifiable; ASO/beta/launch enter the roadmap (buckets P8/P10).

### ADR-009 — Final-scope backend: hosted GPU narration service
- Date: 2026-06-11 · Status: Accepted
- Context: Local-only narration requires users to run a Python GPU service — a non-starter
  for App Store users.
- Decision: Final scope is a **managed GPU narration service** (RunPod-class serverless
  workers + a thin API): job queue per chapter, Sign in with Apple accounts, metered
  narration minutes, transient processing with **zero book retention**. The local backend
  remains the dev/power path; the client's `BackendClient` seam covers both.
- Rationale: Chatterbox-quality narration needs a GPU somewhere; metering minutes maps cost
  to revenue (see [monetization](../05-monetization/monetization.md)).
- Consequences: Accounts/quota/billing enter scope (bucket P7); cost-per-chapter-hour must
  be measured before pricing (open question Q-COST); privacy stance formalized in
  [privacy-security](../04-architecture/privacy-security.md). Spine:
  [hosted-backend](../04-architecture/hosted-backend.md).

### ADR-010 — Pillars: three co-headline, one supporting
- Date: 2026-06-11 · Status: Accepted
- Context: Need a stable selling frame for positioning, messaging, and scope calls.
- Decision: Co-pillars: **🎧 Your books, talking** · **👁 Figures on cue** · **💬 Discuss the
  passage**. Supporting: **🎨 All motion, no pages**.
- Rationale: The first three are the product's unique loop; the fourth is the differentiator
  that makes it demoable but isn't a user job by itself.
- Consequences: Scope decisions defend the co-pillars first; messaging leads with all three
  ([positioning](../02-market/positioning.md)).
