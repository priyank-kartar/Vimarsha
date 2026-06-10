# Positioning

> **Status:** Draft · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). The pillars are decided
> ([ADR-010](../00-overview/decision-log.md#adr-010--pillars-three-co-headline-one-supporting));
> this doc sharpens them against the competition
> ([competitive-analysis](competitive-analysis.md)) and feeds
> [marketing-messaging](../07-gtm/marketing-messaging.md).

## One-sentence position

**For people who own books they never find time to *read*, Vimarsha is the reader that
narrates your own EPUBs at audiobook quality, shows every figure at the moment it's
discussed, and lets you talk about the passage — unlike audiobook stores (their catalog,
not your books, figures dropped) and TTS apps (flat voice over text, no sync, no
conversation).**

## Pillars × "what they lack"

| Pillar | Audible-class | Speechify/ElevenLabs-class | Voice Dream | NotebookLM-class |
|---|---|---|---|---|
| 🎧 Your books, talking | ✗ catalog-only, re-buy | ◐ reads files, flat | ◐ reads files, dated voices | ✗ performs a summary instead |
| 👁 Figures on cue | ✗ figures dropped | ✗ no structure model | ✗ | ✗ |
| 💬 Discuss the passage | ✗ | ✗ (or ungrounded bolt-on) | ✗ | ◐ discusses, but unfaithful to the text |
| 🎨 All motion, no pages | n/a | utility UI | dated UI | n/a |

**The defensible pair is 👁 + 💬:** both depend on the structure pipeline (blocks, spans,
timings, grounding) — a real architecture, not a feature toggle. 🎨 makes it demoable;
🎧 makes it wanted.

## The demo moment (lead everything with it)

Narration says *"as the chart shows…"* — and the chart **rises onto the screen**. Five
seconds, no caption needed. Every asset (App Store preview, social clip, landing page)
builds to this beat ([marketing-messaging](../07-gtm/marketing-messaging.md)).

## Words we own / words we avoid

Own: *"your books, talking" · "figures on cue" · "discuss the passage" · "eyes-free reading."*
Avoid: "TTS" (commodity), "summarize" (we're faithful — anti-NotebookLM), "AI-powered"
(means nothing), "audiobook" unqualified (sets catalog expectations we don't serve).

## Honest weaknesses (position around, don't hide)

Narration needs a GPU moment (cloud) — owned via the transient-processing privacy story
([privacy-security](../04-architecture/privacy-security.md)); EPUB-only at start; iOS 26+
only (premium-device audience, fine for the wedge).
