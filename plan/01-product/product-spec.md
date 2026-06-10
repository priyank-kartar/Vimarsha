# Product Spec

> **Status:** Reviewed · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). End-state product description (final scope);
> what ships when is in [roadmap](roadmap.md) / [build-plan](../08-engineering/build-plan.md).
> UI law: [apple/CLAUDE.md](../../apple/CLAUDE.md); flows: [screen-flows](../03-design/screen-flows.md).

## The loop

**Import → Listen → See → Ask → Keep.**

1. **Import** — pick an EPUB (Files/Finder/share sheet later). The book lands in the living
   library with its real cover on a physical hardback. No account needed to start
   (local/dev backend) — hosted narration introduces Sign in with Apple
   ([ADR-009](../00-overview/decision-log.md#adr-009--final-scope-backend-hosted-gpu-narration-service)).
2. **Listen** — tap a chapter; it's narrated at audiobook quality (GPU TTS) and cached.
   Playback: play/pause/seek/speed/resume; the reading surface highlights the live paragraph
   and auto-scrolls; tap any paragraph to seek. Offline once cached.
3. **See** — figures auto-pop on a glass carrier at the moment the narration discusses them
   and recede after; overlapping figures stack; the Figures gallery reaches any figure
   directly. Accuracy is best-effort by rules today, LLM-assisted later
   ([figure-intelligence](../04-architecture/figure-intelligence.md)).
4. **Ask** — Discuss: a grounded conversation about the current passage — typed by default,
   hold-to-talk for voice; replies text-first with a speak button. Chapter narration pauses
   while a reply speaks or while voice-typing, then resumes. Threads save to Conversations.
   Voice memos pin to the paragraph (hold-to-record → transcript in Notes).
5. **Keep** — everything stays on-device: the EPUB, cached narration, memos, threads,
   progress. The cloud step is transient narration processing only.

## Surfaces (all states of one morphing surface — never pages)

Library depth-stack → book focus (+ glass control cluster) → chapter fan → narrated reading
surface → figure overlay / Figures gallery → memo record / Notes → Discuss panel →
Conversations. Choreography per transition: [screen-flows](../03-design/screen-flows.md).

## Quality bars

- **Narration:** natural enough that a chapter is *pleasant*, not robotic — the single house
  voice is a hiring decision (Q-VOICE).
- **Sync:** highlight within the paragraph that's audibly being read, always (paraTimings
  are exact by construction — [ADR-002](../00-overview/decision-log.md#adr-002--narration-chatterbox-tts--paragraph-timing-stitch-no-forced-alignment)).
- **Figures:** a wrong auto-pop is worse than none; precision over recall
  ([figure-accuracy](../06-content-pipeline/figure-accuracy.md)).
- **Motion:** every transition is one of the named patterns, 120Hz-budgeted
  ([motion-grammar](../03-design/motion-grammar.md)).

## Premium sketch (detail in [monetization](../05-monetization/monetization.md))

Free: full product with N full-quality narrated chapters (taste the hero loop). Premium:
metered narration minutes (the GPU cost axis), Discuss depth, whole-library narration.
Never nag; paywall only at the meter.

## Platforms

iPhone is the product story; macOS ships from the same SwiftUI codebase (role at launch:
open question Q-MAC). iOS 26 / macOS 26 minimum (real Liquid Glass only).

## Out of scope (product-level)

Bank-style content DRM unlocking (Q-DRM: detect + message), PDF (post-v1 candidate, big
pipeline differences), Android (post-launch question), social/sharing of book content.
