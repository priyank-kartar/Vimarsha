# Vision — One-Pager

> **Status:** Reviewed · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). See also: [decision log](decision-log.md) ·
> [positioning](../02-market/positioning.md) · [product spec](../01-product/product-spec.md).

## The problem

The books most worth reading are the hardest to listen to. Audiobooks only exist for a
fraction of titles, cost extra even when you own the text, and **silently drop every figure,
chart, and diagram** — exactly the content that carries the argument in nonfiction, science,
design, and textbooks. TTS reader apps narrate your own files, but they read *flatly over*
the text: no sense of where the figures are, no way to glance at the right one at the right
time, and no way to ask "wait, what did that mean?" without leaving the book.

## The product

**Vimarsha turns any EPUB you own into a book that talks with you.**

- **It reads aloud** — one tap on a chapter and a natural voice narrates it (GPU TTS at
  audiobook quality), resumable, speed-controlled, offline once cached.
- **It shows the figure on cue** — at the moment the narration discusses Figure 3, Figure 3
  floats up on screen, then recedes. Eyes-free reading that never loses the figure.
- **It discusses the passage** — hold the button and talk: ask for an explanation, record a
  voice note, or have a back-and-forth grounded in exactly the paragraph you're hearing.
- **It's beautiful** — a single continuously-morphing Liquid Glass surface (no pages, no
  chrome); the library is a living stack of your actual books.

## North star

> **From EPUB to narrated, figure-synced listening in one tap — and never lose the figure.**
> Every product decision is measured against whether it makes eyes-free reading of *real,
> figure-heavy books* more seamless, more faithful, or more delightful.

## What it is

- A narration-first, figure-synced reader for **your own EPUBs**.
- iOS + macOS native (SwiftUI, iOS 26 / macOS 26, Liquid Glass), App Store-bound.
- Offline-capable per chapter once narrated; the GPU narration step is the cloud moment
  (hosted service in final scope; self-run backend for dev/power users).
- Freemium: generous taste of full-quality narration; premium meters the GPU minutes.

## What it is *not*

- Not an audiobook store or catalog — we narrate what you already own.
- Not a flat TTS overlay — narration is structure-aware (blocks, figures, spans, timings).
- Not a cloud vault of your library — books are processed transiently, stored on-device.
- Not a general chatbot — Discuss is grounded in the passage you're reading.

## The pillars ([ADR-010](decision-log.md#adr-010--pillars-three-co-headline-one-supporting))

| Pillar | In one line |
|---|---|
| 🎧 Your books, talking *(co-pillar)* | Any EPUB → audiobook-quality narration in one tap. |
| 👁 Figures on cue *(co-pillar)* | The right diagram appears the moment it's discussed. |
| 💬 Discuss the passage *(co-pillar)* | Spoken/typed conversation grounded in where you are. |
| 🎨 All motion, no pages | A Liquid Glass surface that's a reason to open the app. |

## Target user (short)

People who *want* to get through dense, figure-heavy books — commuters and multitaskers,
students with textbook stacks, design/science readers — plus readers for whom listening is
the accessible path. Full personas in [`01-product/personas-jobs.md`](../01-product/personas-jobs.md).

## Success looks like

- A new user hears their own book narrated within 2 minutes of install (first chapter).
- "The figure popped up right when it mattered" is the thing people demo to friends.
- Listening sessions resume daily; Discuss threads get saved; premium converts on narration
  minutes, never on nagging.
