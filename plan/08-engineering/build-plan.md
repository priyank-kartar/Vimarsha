# Build Plan

> **Status:** Living · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). The milestone view with a definition of done
> each; the step-by-step pointers live in [build-roadmap](build-roadmap.md). Product-facing
> narrative in [roadmap](../01-product/roadmap.md).

## M0 — Foundations ✅ (2026-06-11)

Xcode multiplatform scaffold, palette tokens, depth-stack parallax scroll with static books,
glass top-scrim, accessibility fallbacks. (V01–V03)
**DoD (met):** builds + 7 transform tests green on macOS and the iOS 26.5 simulator; renders
correct in dark (canonical) + light; merged `0134d10`. Evidence: [_progress-A](_progress-A.md).

## M1 — The living library (V04–V09 + P1.5: V22–V26)

Every motion-grammar pattern present and tuned: settle shift, lensing puck, book focus +
grow-to-front, glass control cluster, slot-emit entrance.
**DoD:** motion review passes against the
[reference analysis](../../apple/docs/reference/ref-books-video-analysis.md) pattern-by-pattern
on a simulator/device recording; controls cluster morphs out of the focused cover and
re-absorbs; Reduce Motion path still coherent.
**Extended 2026-06-11:** V04–V09 built + reviewed; the review verdict
([V09-motion-review](V09-motion-review.md), ADR-011) added **Phase P1.5 — library visual
quality** (uniform cards, stack polish, cluster fixes, the missing hero zoom). M1 closes
when **V26** passes human sign-off.

## M2 — Real books (V10–V15)

EPUB import, client-side covers, SwiftData persistence, `BackendClient` seam, `/toc` +
lazy `/import` chapter download with status.
**DoD:** a real EPUB imported on device shows its actual cover in the stack and narrates one
chapter end-to-end against the local backend; chapter cache survives relaunch; seam test
doubles in place (network only — everything else real).

## M3 — Narrated reading (V16–V21)

Audio engine, cover→reading morph, paragraph highlight + auto-scroll, tap-to-seek, glass
transport, figure overlay on cue, Figures gallery.
**DoD:** a full chapter listened eyes-free on device: highlight tracks `paraTimings`,
figures pop at their spans, seek/speed/resume work, cached chapter replays offline. This is
**feature core-parity** with the frozen Flutter client's reading loop.

## M4 — Memos + Discuss (buckets P4–P5)

Voice memos at paragraph pins (Whisper transcripts, Notes state); the native Discuss build
(grounded chat, hold-to-talk, spoken replies, pause-on-audio-conflict, Conversations).
**DoD:** full parity with the frozen Flutter client + the old Plan 6b spec, natively, on the
one surface; Ollama-backed live test passes.

## M5 — Hosted backend alpha (bucket P7)

Managed GPU workers + job queue + Sign in with Apple + metered narration minutes; client
switches between local/hosted via the same seam.
**DoD:** a fresh user with no local backend narrates a chapter through the hosted service;
cost per chapter-hour measured and logged (feeds pricing); zero book retention verified.

## M6 — Monetization + onboarding + polish (buckets P8–P9)

Paywall + free tier, first-run flow ending in a narrated chapter, accessibility audit,
performance pass, EPUB-compat hardening.
**DoD:** free→premium path works in sandbox; first-run to first-narration < 2 min;
accessibility matrix verified per state; corpus books all import or fail gracefully.

## M7 — Ship (bucket P10)

TestFlight beta, ASO assets, App Store submission.
**DoD:** approved and live; launch checklist in [go-to-market](../07-gtm/go-to-market.md) done.
