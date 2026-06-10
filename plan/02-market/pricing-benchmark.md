# Pricing Benchmark

> **Status:** Draft · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). Ballparks from general knowledge — **verify
> every number in a research pass before any pricing ADR** (prices shift constantly).
> Consumer: [monetization](../05-monetization/monetization.md); costs: Q-COST.

## The neighborhood (approximate, to be verified)

| Product | Model | Ballpark | Take-away for us |
|---|---|---|---|
| Audible | subscription + credits | ~$15/mo | anchors "narrated books" at a two-digit monthly price |
| Speechify Premium | annual-billed sub | ~$140/yr (~$12/mo) | flat TTS already commands real money on convenience alone |
| ElevenLabs Reader / plans | freemium → tiers | free app; platform tiers $5–$22/mo | voice quality is being commoditized downward — don't price on voice |
| Voice Dream | one-time → now sub (~$60–80/yr) | a11y community pays for *control*, resents sub-flips | be honest and stable; consider lifetime-style goodwill |
| NotebookLM | bundled w/ Google One AI | ~$20/mo bundle | "AI about your docs" is being given away in bundles — don't price on "AI" either |

## Implications

1. **Price the structure intelligence, not the voice or the AI label** — figures-on-cue +
   grounded Discuss + whole-library narration is the premium story
   ([positioning](positioning.md)).
2. **The natural axis is narration minutes** (GPU COGS — metering maps cost to revenue,
   [ADR-009](../00-overview/decision-log.md#adr-009--final-scope-backend-hosted-gpu-narration-service));
   the neighborhood suggests **$8–15/mo** as the viable band, with the free tier generous
   enough to finish a real taste (N chapters, Q-FREE).
3. **COGS floor before anything:** cost-per-narrated-chapter-hour from the P7 alpha
   (Q-COST) sets the floor; a typical book ≈ 8–12 listening hours — the unit economics must
   survive a heavy month.
4. **Goodwill levers:** no nag, meter visible, maybe a lifetime/founders option (the Voice
   Dream lesson cuts both ways — their *flip* angered users; *starting* honest doesn't).

## Research TODO (gates the M6 pricing ADR)

Verify all table numbers · App Store small-business rate math (15% under $1M) · regional
pricing posture (India matters for the persona mix) · trial mechanics that don't require a
card.
