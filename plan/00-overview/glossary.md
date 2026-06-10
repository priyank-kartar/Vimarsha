# Glossary

> **Status:** Living · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). Shared terminology so every doc uses words the
> same way. Add terms as they appear.

| Term | Meaning |
|---|---|
| **Block** | A typed unit of chapter content from ingestion (paragraph, heading, figure, caption…). Ordered; the narration and reading surface are built from blocks. |
| **ChapterBundle** | The cross-tier contract for one narrated chapter: `{chapterId, title, blocks[], figureMap[], audio, paraTimings}`. Schema: [`shared/bundle.schema.json`](../../shared/bundle.schema.json). |
| **Figure span** | The paragraph range during which a figure is "being discussed", produced by mention detection and converted to `startMs/endMs` against the narration. Drives auto-pop. |
| **Mention detection** | The rule-based pass that links text references ("see Figure 3") to figures and widens their spans. The LLM fallback upgrade is [figure intelligence](../04-architecture/figure-intelligence.md). |
| **Narration stitch** | Backend step that concatenates per-block TTS audio into ONE `chapter.mp3`, recording paragraph→ms timings during concatenation (no forced alignment). |
| **paraTimings** | The paragraph-index→milliseconds table recorded by the stitch; powers highlight, auto-scroll, tap-to-seek, and figure timing. |
| **Auto-pop** | The figure overlay appearing automatically at its span's `startMs` and receding at `endMs`. |
| **Depth-stack** | The signature library UI: a vertical scroll surface where each book's scale/opacity/offset is a continuous function of position. Motion grammar #1 in [apple/CLAUDE.md](../../apple/CLAUDE.md). |
| **Motion grammar** | The named, reusable motion patterns (depth-stack parallax scroll, grow-to-front promotion, recede-and-clip, slot-emit, hero settle, inertial flick with dwell, settle contrast shift). Use the names in specs/code/commits. |
| **Glass moments** | The eight named Liquid Glass usages (top-scrim dissolve, lensing puck, glass header plane, container merge, control cluster, meniscus slot, velocity sheen, figure carrier). Implement these; don't improvise glass. |
| **Front slot** | The low-in-viewport position where the focused book card sits at full size; crossing it triggers grow-to-front promotion. |
| **Memo** | A voice note recorded at a paragraph pin; transcribed by Whisper; listed in Notes. |
| **Discuss** | The grounded conversation feature: chat about the current passage, replies optionally spoken (`/speak`). Threads saveable → Conversations. |
| **Grounding** | Building the LLM prompt from the live reading context (book/chapter/surrounding paragraphs) so Discuss answers about *this* passage, not the world. |
| **Pause-on-audio-conflict** | Client rule: chapter narration pauses while a reply is spoken or the user voice-types, and resumes if it was playing. |
| **Seam** | One of the few sanctioned test-double protocols: `BackendClient` (network), audio/mic, LLM (backend). Everything else tests real. |
| **V-item** | An atomic build-roadmap task sized for one agent window (`V01`, `V02`…). See [build-roadmap](../08-engineering/build-roadmap.md). |
| **Track** | A parallel agent lane with an explicit file scope and its own `_progress-<X>.md` log. |
| **Local backend** | The self-run Python FastAPI service (Chatterbox/Whisper/Ollama) — the dev/power path. |
| **Hosted backend** | The final-scope managed GPU narration service ([ADR-009](decision-log.md#adr-009--final-scope-backend-hosted-gpu-narration-service)); see [hosted-backend](../04-architecture/hosted-backend.md). |
