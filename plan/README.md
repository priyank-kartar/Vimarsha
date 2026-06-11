# Vimarsha — Planning Knowledge Base

> **Status:** Living · **Last updated:** 2026-06-11
> The single source of truth for the product *before and during* build. Every doc is meant
> to be edited as we learn. Code lives elsewhere; this folder is the "why" and the "what."

## The one-liner

**The talking EPUB reader — it reads your books aloud, shows you the right figure at the
exact moment it's discussed, and discusses the passage with you. Beautiful enough to be the
reason you open it.**

A narration-first, figure-synced, AI-conversational book reader. iOS/macOS-native
(SwiftUI + Liquid Glass), your own EPUBs, freemium, App Store-bound.

## How to use this knowledge base

- Each doc starts with a **status + last-updated** header. Statuses: `Draft` → `Reviewed` →
  `Locked` (point-in-time docs) or `Living` (always-current docs).
- **Decisions** are recorded in [`00-overview/decision-log.md`](00-overview/decision-log.md)
  (ADR-style, append-only). If you change a decision, add a superseding entry — don't
  silently edit history.
- **Open questions** awaiting sign-off live in
  [`08-engineering/open-questions.md`](08-engineering/open-questions.md) — each with a
  proposed default so work is never blocked.
- **To build something:** go to
  [`08-engineering/build-roadmap.md`](08-engineering/build-roadmap.md) and run a V-item in a
  fresh agent window (instructions at the top of that file).
- **Link, don't repeat.** Canonical engineering docs live in the repo and are linked from
  here: [`CLAUDE.md`](../CLAUDE.md) (repo guide) · [`apple/CLAUDE.md`](../apple/CLAUDE.md)
  (the UI bible) · [`shared/bundle.schema.json`](../shared/bundle.schema.json) (the contract)
  · [`docs/superpowers/specs/`](../docs/superpowers/specs/) (historical per-plan specs) ·
  [`apple/docs/reference/`](../apple/docs/reference/) (the reference-video motion analysis).

## Table of contents

### 00 · Overview
- [README — vision one-pager](00-overview/README.md)
- [Glossary](00-overview/glossary.md)
- [Decision log (ADRs)](00-overview/decision-log.md)

### 01 · Product
- [Product spec](01-product/product-spec.md)
- [Personas & jobs-to-be-done](01-product/personas-jobs.md)
- [Feature list](01-product/feature-list.md)
- [User stories & acceptance criteria](01-product/user-stories.md)
- [Roadmap (milestones M0–M7)](01-product/roadmap.md)

### 02 · Market
- [Competitive analysis](02-market/competitive-analysis.md)
- [Positioning](02-market/positioning.md)
- [Pricing benchmark](02-market/pricing-benchmark.md)

### 03 · Design
- [Design principles](03-design/design-principles.md)
- [Design system (pointer + gaps)](03-design/design-system.md)
- [Motion grammar (the hero interaction)](03-design/motion-grammar.md)
- [Screen flows (states of one surface)](03-design/screen-flows.md)
- [References](03-design/references.md)
- [Accessibility](03-design/accessibility.md)
- [Naming](03-design/naming.md)
- [Sound design](03-design/sound-design.md)

### 04 · Architecture
- [Tech stack](04-architecture/tech-stack.md)
- [App architecture](04-architecture/app-architecture.md)
- [Data model](04-architecture/data-model.md)
- [Narration pipeline](04-architecture/narration-pipeline.md)
- [Figure intelligence](04-architecture/figure-intelligence.md)
- [Conversation AI (Discuss)](04-architecture/conversation-ai.md)
- [Hosted backend (final-scope spine)](04-architecture/hosted-backend.md)
- [Privacy & security](04-architecture/privacy-security.md)

### 05 · Monetization
- [Monetization](05-monetization/monetization.md)

### 06 · Content pipeline (the hard correctness problem)
- [EPUB compatibility](06-content-pipeline/epub-compatibility.md)
- [Figure accuracy](06-content-pipeline/figure-accuracy.md)

### 07 · Go-to-market
- [Go-to-market](07-gtm/go-to-market.md)
- [Marketing & messaging](07-gtm/marketing-messaging.md)
- [ASO assets](07-gtm/aso-assets.md)

### 08 · Engineering
- [Build plan (milestones + DoD)](08-engineering/build-plan.md)
- [Build roadmap (V-items — the agent-runnable spine)](08-engineering/build-roadmap.md)
- [Open questions](08-engineering/open-questions.md)
- [Progress — track A](08-engineering/_progress-A.md)

## The pillars — three co-headline, one supporting ([ADR-010](00-overview/decision-log.md#adr-010--pillars-three-co-headline-one-supporting))

**Three co-pillars (lead with all three):**
1. **🎧 Your books, talking** — any EPUB you own becomes a narrated book in one tap; no
   catalog, no waiting for an audiobook edition.
2. **👁 Figures that appear on cue** — the diagram/chart/quote surfaces on screen at the
   moment the narration discusses it. The thing no audiobook can do.
3. **💬 Discuss the passage** — hold a spoken or typed conversation about exactly where you
   are in the book, grounded in the text.

**One supporting:**
4. **🎨 All motion, no pages** — a Liquid Glass, editorial, continuously-morphing surface;
   the UI is a selling point in itself ([apple/CLAUDE.md](../apple/CLAUDE.md)).

---

## ⚡ Latest direction — v1 feature loop COMPLETE (machine), final human review pending (2026-06-11)

> **M0–M4 done in one day** by the autonomous agent loop (`scripts/agent-loop/`): the full
> v1 loop exists natively — living library (all 7 motion patterns + glass moments), real
> EPUB import with client-side covers, narrated reading with live highlight + figures on
> cue, voice memos (22/22 live), and Discuss (28/28 live vs Ollama + Chatterbox). 47
> V-items merged across P0–P5 + three independent UI-audit fix rounds. **What remains
> before M5 (hosted backend):** the consolidated human review —
> [final-review-checklist](08-engineering/final-review-checklist.md) (~21 feel/UX checks)
> — then polish items it spawns. Pivot history: ADR-004–ADR-011 in the
> [decision log](00-overview/decision-log.md); per-item evidence in
> [_progress-A](08-engineering/_progress-A.md) + [ui-audit-log](08-engineering/ui-audit-log.md).
