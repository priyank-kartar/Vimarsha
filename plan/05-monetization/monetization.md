# Monetization

> **Status:** Draft · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). Direction is set (freemium, meter the GPU);
> numbers are deliberately open until the P7 alpha measures costs (Q-COST). Benchmarks:
> [pricing-benchmark](../02-market/pricing-benchmark.md). Final shape lands as ADRs during M6.

## Principles (stable even while numbers float)

1. **Never nag.** The paywall appears at the meter, contextually, dismissibly — conversion
   on value, not friction ([vision](../00-overview/README.md) "success looks like").
2. **Meter what costs us:** narration minutes (GPU). Don't gate what's free to serve
   (reading cached chapters, memos on-device, the UI itself).
3. **The free tier must deliver the hero loop** — a user should *finish a real taste*
   (hear figures pop in their own book) before any ask. Default: N full-quality chapters
   (Q-FREE; pick N after Q-COST).
4. **Honest meter:** minutes visible in settings; no surprise lockouts mid-chapter (a
   started chapter always finishes).

## The likely shape (to be ADR'd in M6)

| | Free | Premium (💎) |
|---|---|---|
| Narration | N chapters' worth of minutes (one-time taste) | monthly minutes, sized so a typical book/month fits ([pricing-benchmark](../02-market/pricing-benchmark.md): $8–15/mo band) |
| Figures, reading surface, memos | full | full |
| Discuss | capped depth/turns on the base model | deeper context, better hosted model (F35, Q-LLM) |
| Whole-book queue (F15) | — | ✓ |
| Local-backend users (power path) | everything free forever (their GPU, their cost) | n/a — and that's fine; they're advocates, not lost revenue |

Candidate add-ons, decide later: lifetime/founders tier (goodwill lever) · narration-minute
top-up packs (overflow without upsell pressure).

## What we will NOT do

Ads · selling/training on user content ([privacy-security](../04-architecture/privacy-security.md))
· dark-pattern trials (card-up-front) · gating accessibility features (the a11y persona's
core path stays usable free — metering narration is acceptable, charging *extra* for
accessibility settings is not).

## Open (all gated on P7 measurements)

Q-COST (cost/chapter-hour) → free-N and monthly-minute sizing → price point → trial
mechanics. Each lands as its own ADR with the measurement attached.
