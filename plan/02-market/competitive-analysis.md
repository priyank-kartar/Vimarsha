# Competitive Analysis

> **Status:** Draft · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). First-pass landscape from product knowledge —
> needs a proper research pass (pricing/feature verification) before M6 decisions lean on
> it. Positioning conclusions: [positioning](positioning.md).

## The landscape

| Player | What it is | What it does well | What it lacks (our gap) |
|---|---|---|---|
| **Audible / audiobook stores** | Catalog of produced audiobooks | Professional narration, ecosystem | Only their catalog (no *your* EPUBs); pay again for books you own; **figures/diagrams simply gone**; no conversation |
| **Speechify** | TTS reader (files, web, scans), big brand | Voice quality marketing, cross-platform, OCR breadth | Flat TTS *over* text — no structure awareness, no figure sync, busy utility UI, aggressive upsell |
| **ElevenLabs Reader** | TTS app on best-in-class voices | Voice naturalness, free tier generosity (for now) | Same flatness: no figures, no grounded discussion, content-pipe not a *reader* |
| **Voice Dream Reader** | The accessibility-community classic | Deep reading controls, format breadth, loyal a11y base | Dated UI, robotic-leaning voices, no AI layer, no figure intelligence |
| **Apple Books read-aloud / Spoken Content** | OS-level TTS | Free, built-in | Hidden, mechanical, no sync UI to speak of, EPUB support quirks |
| **Matter / Readwise Reader** | Read-it-later with TTS | Articles + highlights ecosystem | Article-first, not books; no EPUB depth; no figure sync |
| **NotebookLM (podcast mode)** | AI "discussion about your docs" | The wow of generated conversation | It *replaces* the text with a summary performance — doesn't read the book; no faithful narration |

## The empty quadrant

Plot it: **faithful narration of your own books** (x) vs **structure intelligence —
figures, sync, grounded discussion** (y). Audiobooks sit high-x/zero-y (but not *your*
books); TTS readers mid-x/low-y; NotebookLM low-x/mid-y. **High-x/high-y is empty — that's
Vimarsha:** your EPUBs, narrated at audiobook quality, figures on cue, a conversation
grounded in the passage. The UI ([motion-grammar](../03-design/motion-grammar.md)) is the
moat-deepener: utilities can't easily become beautiful.

## Threats to watch

- **Apple** sherlocking read-aloud with figure awareness (mitigation: depth + conversation
  + being the *dedicated* experience).
- **ElevenLabs/Speechify adding "ask about this"** — likely shallow (ungrounded) first;
  our grounding + figure sync is the defensible pair.
- **Voice cost collapse** helps us (narration COGS ↓) more than it helps flat readers
  (their differentiation IS the voice; ours is the structure intelligence).

## Research TODO (before M6 pricing)

Verify current pricing/limits for Speechify/ElevenLabs/Voice Dream/Audible
([pricing-benchmark](pricing-benchmark.md)); test each with a figure-heavy EPUB and record
the actual failure modes (screenshots → [references](../03-design/references.md)).
