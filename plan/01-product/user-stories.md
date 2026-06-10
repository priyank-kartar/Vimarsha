# User Stories & Acceptance Criteria

> **Status:** Draft · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). v1-scope stories (M1–M3) with testable
> acceptance criteria; later-scope stories get written when their bucket is itemized.
> Features: [feature-list](feature-list.md) · build: [build-roadmap](../08-engineering/build-roadmap.md).

## Library (M1–M2)

**S1 — Browse my shelf.** As a reader, I scroll a living stack of my books and it feels like
handling a pile of hardbacks.
- AC: depth-stack transforms are continuous with scroll (scrub = motion); front card full
  size/bright; receding cards shrink/dim/tuck up; no spring overshoot on settle.
- AC: Reduce Motion renders a flat full-size list; everything still reachable.

**S2 — Add a book.** As a reader, I import an EPUB and see *my actual book*.
- AC: document picker → book appears in the stack with its real cover (extracted client-side);
  coverless EPUBs get the generated cloth cover with title serif.
- AC: corrupt/DRM files fail with an honest message, never a crash (links Q-DRM).

**S3 — Focus a book.** As a reader, settling a book into the front slot reveals what I can do.
- AC: grow-to-front promotion plays; the glass control cluster (Play/Figures/Memo/Discuss)
  morphs out of the cover and re-absorbs on scroll; VoiceOver exposes the same four actions.

## Narration (M2–M3)

**S4 — Hear a chapter.** As a reader, I tap a chapter and it narrates.
- AC: first narration shows pending status with progress; completed chapter starts playing;
  status `error` offers retry (e.g. no-text part-divider chapters fail gracefully).
- AC: cached chapters start in <1s and replay with the network off.

**S5 — Listen like an audiobook.** As a listener, transport works the way my ears expect.
- AC: play/pause/seek/speed (incl. >1×) work; kill the app mid-chapter → relaunch resumes
  within the same paragraph; macOS keyboard space bar toggles.

**S6 — Follow along.** As a reader glancing at the screen, I always see where the voice is.
- AC: the audibly-current paragraph is highlighted and kept in view (auto-scroll);
  tapping any paragraph seeks the audio to it within the paragraph's start.

## Figures (M3)

**S7 — See the figure on cue.** As a listener, the figure under discussion appears without
me doing anything.
- AC: overlay rises on its glass carrier at `startMs`, recedes at `endMs`; overlapping spans
  stack; dismissing early is possible and doesn't pause audio.
- AC: zero auto-pop is acceptable for a span; a *wrong* figure is a logged defect
  ([figure-accuracy](../06-content-pipeline/figure-accuracy.md)).

**S8 — Browse all figures.** As a reader, I can reach any figure deliberately.
- AC: Figures gallery is a morphed grid state (no page push); selecting a figure can seek
  narration to its span.

## Cross-cutting

**S9 — It never loses my place or my data.** Progress, caches, memos, threads survive
relaunch and offline; nothing book-derived leaves the device except the transient narration
request ([privacy-security](../04-architecture/privacy-security.md)).

**S10 — It respects my settings.** Reduce Motion/Transparency, Dynamic Type XXL, VoiceOver:
every v1 state passes the [accessibility matrix](../03-design/accessibility.md).
