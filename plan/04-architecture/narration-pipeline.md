# Narration Pipeline

> **Status:** Reviewed · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). How an EPUB chapter becomes synced audio.
> The code is canonical: `backend/src/vimarsha/` (epub_reader → block_parser →
> figure_registry → mention_detector → ingest → tts → stitch → narrate). This doc is the
> map + the debts.

## The pipeline (per `POST /import?chapter_index=N`)

```
EPUB ──► ordered typed Blocks ──► Figure registry ──► mention detection
                                                       (spans, paragraph-granular)
      ──► Chatterbox TTS per narratable block ──► stitch into ONE chapter.mp3
                                                  recording paragraph→ms DURING concat
      ──► spans converted paragraph→ms ──► ChapterBundle (blocks, figureMap, audio,
                                                          paraTimings)
```

Key properties: timings are **exact by construction** (no forced alignment —
[ADR-002](../00-overview/decision-log.md#adr-002--narration-chatterbox-tts--paragraph-timing-stitch-no-forced-alignment));
un-narratable chapters (e.g. part dividers) **raise** so the client marks `error` instead of
caching junk; figures ship as image bytes via `GET /image/{name}`.

## Performance profile & debts (the honest list)

| Item | State | Plan |
|---|---|---|
| `get_synth()` reloads Chatterbox per request | known debt — memory balloon + latency | cache like `get_transcriber`/`get_llm` (Q-SYNTH, opportunistic pre-P7) |
| MPS synth ~7–8× slower than realtime | dev-path reality | CUDA (RunPod/Docker) for heavy runs; hosted workers in final scope |
| Disk pressure from model downloads/temp files | bit us once (filled the disk) | watch `~/.cache/huggingface`, clean `hub/tmp*`; hosted workers get explicit disk budgets |
| Per-chapter latency UX | minutes-long on dev | the client's `pending` status + (P7) async job queue make it honest — never a spinner with no story |

## Invariants any future backend (incl. hosted) must keep

1. ChapterBundle schema compatibility (the client is built against it).
2. Paragraph-timing exactness (highlight/seek/figures all hang off it).
3. Raise-don't-fake for un-narratable input.
4. Statelessness w.r.t. the user's library (transient processing only —
   [privacy-security](privacy-security.md)).

## Quality levers (post-M3 exploration)

Per-block prosody tuning (headings vs body vs captions read differently), figure-caption
read-aloud policy (read captions? skip? setting?), silence trims between blocks, loudness
normalization across chapters. Each is a measured change against the
[EPUB corpus](../06-content-pipeline/epub-compatibility.md), not a vibe change.
