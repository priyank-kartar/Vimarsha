# Hosted Backend — The Final-Scope Spine

> **Status:** Draft · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). The managed service that makes Vimarsha
> installable by anyone
> ([ADR-009](../00-overview/decision-log.md#adr-009--final-scope-backend-hosted-gpu-narration-service)).
> Built in bucket **P7**, *after* the product loop is lovable (M0–M4). Everything here is
> design-ahead, not commitment — costs (Q-COST) gate the details.

## Shape

```
Client ──auth──► Thin API (queue + auth + quota; cheap, always-on)
                    │ enqueue chapter job (EPUB + chapter_index)
                    ▼
              GPU workers (serverless, RunPod-class; scale-to-zero)
              run the SAME pipeline as backend/ today (CUDA Dockerfile exists)
                    │ bundle + mp3 + images
                    ▼
              short-lived result storage (hours, signed URLs) ──► client caches ──► deleted
```

- **The client seam doesn't fork:** `BackendClient` gains an auth header + async-job flavor
  (Q-QUEUE default: enqueue + poll); local backend remains a same-protocol base-URL swap.
- **Pipeline invariants carry over** ([narration-pipeline](narration-pipeline.md)): same
  ChapterBundle, same timing exactness, same raise-don't-fake.

## Identity & metering

- **Sign in with Apple** (F43) — the first moment Vimarsha has accounts at all; anonymous
  use remains for local-backend users.
- **Metered narration minutes** (output-audio minutes — what GPUs actually cost): free tier
  = N full-quality chapters' worth ([monetization](../05-monetization/monetization.md));
  premium = monthly minutes; quota enforced server-side, mirrored client-side for honest UI.
- `/chat`/`/speak`/`/transcribe` in hosted scope: cheap relative to narration; metered
  loosely under the same account (detail in P7 design).

## Privacy stance (the hard promise — see [privacy-security](privacy-security.md))

**We never keep your books.** EPUB + derived audio exist on workers/result storage only for
the job's lifetime (target: auto-purge ≤24h, ideally minutes); no library database
server-side; logs carry job metadata, never content. This must be *verifiable* (a written
data-flow doc + retention config in the open) — it's a pillar-level claim
([positioning](../02-market/positioning.md)).

## P7 alpha — what "done" means ([build-plan M5](../08-engineering/build-plan.md))

Fresh user, no local backend → narrates a chapter through the service; **measured
cost-per-chapter-hour logged** (the number that unlocks pricing ADRs); zero-retention
verified by inspection; the local-backend path still works untouched.

## Pre-work that pays off early (opportunistic, before P7)

`get_synth()` model caching (Q-SYNTH — also fixes dev pain) · keeping the CUDA Dockerfile
green (`backend/docs/runpod.md`) · resisting any client assumption that narration is
synchronous (the `pending` status model already encodes this).
