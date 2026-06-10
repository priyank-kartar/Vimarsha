# Roadmap

> **Status:** Living · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). The product-facing milestone narrative; the
> engineering detail (DoD per milestone) is [build-plan](../08-engineering/build-plan.md),
> the per-task spine is [build-roadmap](../08-engineering/build-roadmap.md). Deliberately
> few phases now — buckets get itemized only when they're next
> (per the 2026-06-11 "start small" direction).

| Milestone | One line | Scope refs | State |
|---|---|---|---|
| **M0 — Foundations** | The signature stack renders, tested, both platforms | V01–V03 | ✅ 2026-06-11 |
| **M1 — Living library** | The stack becomes the signature *interaction* (all motion patterns, control cluster) | V04–V09 · F01, F04 | next |
| **M2 — Real books** | Your EPUBs, your covers, chapters narrating via the local backend | V10–V15 · F02–F03, F10, F13 | |
| **M3 — Narrated reading** | The core loop: listen + highlight + figures on cue, offline replay | V16–V21 · F11–F12, F20–F23 | |
| **M4 — Memos + Discuss** | Voice notes and grounded conversation, natively (old Plans 5/6b behavior) | P4–P5 · F30–F34 | |
| **M5 — Hosted alpha** | A fresh user narrates with zero setup; minutes metered; costs measured | P7 · F14, F43 | |
| **M6 — Monetize + polish** | Paywall, onboarding, accessibility + perf + EPUB-compat audits | P8–P9 · F44–F45, F41 | |
| **M7 — Ship** | TestFlight → App Store | P10 | |

## Sequencing logic

- **M1 before M2:** the interaction model (focus, cluster, morphs) must exist before real
  data wires into it — retrofitting motion onto plumbing is how pages sneak back in.
- **M2 before M3:** the reading surface consumes real bundles; faking them would build the
  wrong thing.
- **M4 after M3:** memos/Discuss hang off the reading surface and the audio engine.
- **M5 (hosted) after the loop is lovable:** the service is worth building only for a
  product people already want; its costs (Q-COST) gate pricing (M6).
- **Figure-LLM fallback (P6)** floats: it can land any time after M3 — it's an accuracy
  upgrade, not a dependency.

## Initial scope vs final scope, in one breath

**Initial (M0–M3):** a beautiful, working, single-user reader — your EPUBs narrated with
figures on cue, against a backend you run.
**Final (M7):** the same product anyone can install — hosted narration, accounts, metering,
Discuss at depth, on the App Store.
