# Vimarsha — Talking EPUB Reader with Figure Sync & Voice Discussion

**Design spec — 2026-06-03**

Vimarsha is an ebook reader that reads books aloud, intelligently surfaces the
right figure/diagram/quote at the moment it is discussed, and lets the reader
record voice notes — and optionally hold a spoken AI conversation — about the
passage in front of them.

---

## 1. Scope (v1)

- **Format:** EPUB only. Internal model is format-agnostic so MOBI/PDF can be
  added later behind a normalizer without touching the core.
- **Reading aloud:** Chatterbox TTS, pre-generated per chapter.
- **Figure intelligence:** detect figures/diagrams/tables/pull-quotes and show
  each one on screen for the entire span of text where it is discussed.
- **Voice notes:** record + on-device transcription, pinned to the paragraph.
- **Deep-dive discussion (opt-in):** spoken AI conversation about the passage.
- **Player basics:** chapter index with offline/download badges, continuous
  media seek, playback speed, play/pause, resume-where-you-left-off.

**Explicitly out of scope for v1:** MOBI/PDF ingestion, math/formula rendering,
multi-voice/character narration, cloud sync of the library, accounts.

---

## 2. Architecture

Two tiers. The client is deliberately thin and **fully offline once a chapter
is cached**; the GPU backend is **stateless** and touched only at import and
during a deep-dive conversation.

### 2.1 Client — Flutter app (target: phone; macOS desktop for development)

Responsibilities:
1. **Library & import UI** — add an EPUB; show progress while the backend
   prepares a chapter.
2. **Reader / Player** — render EPUB text, play the single cached chapter audio
   file with native media controls (play/pause, seek, speed), resume position.
3. **Figure overlay** — show the correct figure as a **floating card** when
   playback time enters that figure's time range; tap to expand to a full-screen
   view; auto-collapse when the range ends.
4. **Voice memos** — record audio, transcribe **on-device (Whisper)**, pin
   audio + transcript to the current paragraph, save to local notes. Works
   offline.
5. **Deep-dive conversation** — opt-in panel; sends a transcribed question plus
   passage/figure context to the backend; plays back the spoken answer.
6. **Local storage** — chapter bundles (text model + audio + figure map +
   timings), memos, reading progress.

### 2.2 Backend — Python / FastAPI on the GPU box

Touched only twice in a book's life:

1. **Import job (per chapter, lazy):** parse EPUB → build internal block model →
   figure/quote-finding pass (rules + LLM fallback) → Chatterbox TTS per
   paragraph, stitched into one chapter file with a paragraph→time table →
   returns the chapter bundle.
2. **Conversation endpoint:** receives transcribed question + context → LLM
   (configurable: local model *or* Claude API) → Chatterbox speaks the reply →
   streams audio back.

### 2.3 Repo shape (monorepo)

```
/app        Flutter client
/backend    Python/FastAPI service (parsing, TTS, figure pass, conversation)
/shared     Bundle JSON schema + fixtures both sides agree on
/docs       Specs, plans
```

---

## 3. Import & figure/quote pipeline (backend, per chapter)

**Step 1 — Parse EPUB → internal block model.** Walk the chapter XHTML in
reading order into typed blocks: `heading`, `paragraph`, `image`
(`src`, `alt`, `figcaption`), `figure`, `blockquote`, `pullquote`, `table`,
`list`. Each block has a stable `id` and an order index. This common model
feeds both TTS and figure-sync.

**Step 2 — Build the figure registry.** Collect every visual asset (`<img>`,
`<figure>`, `<svg>`, `<table>`) with its caption and any label/number
("Figure 3.2", "Table 4", "Diagram 1") from `<figcaption>` or nearby text. Also
flag special-display text — `<blockquote>`, pull-quotes/epigraphs (detected via
`epub:type` or class names like `pullquote`/`epigraph`) — these are the things
that "render differently on a Kindle." Each entry:
`{id, kind: figure|diagram|table|pullquote, asset, caption, label}`.

**Step 3 — Mention detection + discussion span (rules first).** Regex-scan
paragraph text for references (`Figure 3.2`, `Fig. 4`, `see the table below`).
Match labeled references to the registry by number. The **span** runs from the
paragraph of the first reference to the paragraph of the last reference in the
same discussion, capped by a window so it cannot run away. Embedded images with
no textual reference default to a span around their own position.

**Step 4 — LLM fallback (leftovers only).** For fuzzy/unlabeled mentions ("the
chart below", "as illustrated", an unreferenced image), send only that
neighborhood of text + the figure list to the configurable LLM and ask: which
figure, and where does the discussion start/end? Most figures never reach this
step.

**Step 5 — Narration synthesis + stitching.** Chatterbox synthesizes
paragraph-by-paragraph (respecting the model's input-length limit), inserting
natural pauses at paragraph/section breaks, and concatenates the segments into a
single `chapter.<ext>` audio file. During concatenation it records each
paragraph's offset: `paraId → [startMs, endMs]`. This timing table is plain
arithmetic from segment durations — **no forced alignment**. Captions are read;
pure-image blocks are skipped.

**Step 6 — Convert spans to time + emit bundle.** Each figure's
`[startPara … endPara]` span is converted to `[startMs … endMs]` using the
timing table. Emit:

```jsonc
{
  "chapterId": "...",
  "blocks": [ /* typed block model in reading order */ ],
  "audio": "chapter.mp3",                 // single stitched file
  "paraTimings": { "p12": [0, 4200], ... },
  "figureMap": [
    { "figureId": "f3_2", "kind": "diagram",
      "asset": "...", "caption": "...",
      "startMs": 18000, "endMs": 41000 }
  ]
}
```

The client caches this and is fully offline for that chapter.

---

## 4. Playback & figure sync (client)

- Playback is **one continuous media file** with native controls — seek, scrub,
  and speed all work normally; no paragraph mapping needed at playback time.
- The figure overlay is driven purely by time: on each tick (and on seek), the
  player checks whether `currentMs` falls inside any `figureMap` entry's
  `[startMs, endMs]`. If so, show that figure's **floating card**; when it
  exits the range, collapse it. Seeking updates this automatically.
- Display style is chosen per `kind`: figures/diagrams/tables as the floating
  card (tap → full screen); pull-quotes/epigraphs in a distinct quote style.
- Resume: persist `currentMs` per chapter.

---

## 5. Voice memos & deep-dive (client + backend)

**Default — lightweight memo (offline):**
1. Tap ● Record. Narration auto-pauses; live waveform; pinned to the current
   paragraph.
2. Stop → on-device Whisper transcribes → memo audio + transcript saved to
   notes, pinned to the paragraph. Done. No network.

**Opt-in — deep-dive conversation (GPU backend):**
1. From a memo, tap "💬 Discuss this".
2. Client sends the transcribed question + passage/figure context to the
   conversation endpoint.
3. LLM (local model *or* Claude API, configurable in settings) answers;
   Chatterbox synthesizes the spoken reply; audio streams back.
4. Continue by voice (hold to talk → on-device STT) or keyboard.

---

## 6. Models & configuration

- **TTS:** Chatterbox (resemble-ai/chatterbox), GPU. Conditioned on a reference
  narrator voice (configurable; ships with a calm default). Consistent timbre
  across a chapter via the same reference.
- **STT:** on-device Whisper (e.g. whisper.cpp). Runs offline on the client.
- **LLM:** abstraction with two backends, chosen in settings — a local model
  (Ollama / llama.cpp) or the Claude API.
- **Expectation setting:** Chatterbox is a strong, consistent synthetic narrator
  (ideal for nonfiction/textbooks), not a hand-acted performance.

---

## 7. Shared bundle contract

The chapter-bundle JSON in §3 Step 6 is the single interface between backend and
client, defined in `/shared` with fixtures. Either side can be developed and
tested against the fixtures independently.

---

## 8. Error handling & edge cases

- **Chapter not yet imported:** show a "preparing…" state; client requests
  import; only mark a chapter offline-ready once its bundle is fully cached.
- **Backend unreachable:** reading/figures/memos still work for cached chapters;
  only import of new chapters and deep-dive are disabled, with a clear message.
- **No figures / no references in a chapter:** `figureMap` is empty; reader
  behaves as a plain talking book.
- **Unmatched mention after rules + LLM:** leave the mention as plain text (no
  spurious figure); log for later tuning.
- **TTS segment failure:** retry; on persistent failure, insert a short silence
  and a flagged gap rather than aborting the whole chapter.
- **STT failure on a memo:** keep the audio memo; mark transcript as
  unavailable, allow retry.

---

## 9. Testing strategy

- **Shared schema:** validate fixtures against the bundle schema both ways.
- **Backend:** unit-test the EPUB block parser, the figure registry, and the
  rule-based mention/span detector against small EPUB fixtures with known
  figures; mock the LLM and TTS for pipeline tests; one integration test that
  runs a real chapter end-to-end to a bundle.
- **Client:** widget tests for the player (seek → figure show/hide at the right
  time ranges), the record→memo→transcript flow (mock STT), and the deep-dive
  panel (mock backend). Figure-sync logic unit-tested against a fixture bundle.

---

## 10. Build order (high level)

1. Shared bundle schema + fixtures.
2. Backend EPUB parser → block model.
3. Backend figure registry + rule-based mention/span detection.
4. Backend TTS + stitching + timing table; emit full bundle.
5. Client library/import + chapter index with download badges.
6. Client player: single-file playback, seek, speed, resume.
7. Client figure overlay (floating card + expand) driven by time ranges.
8. Client voice memo + on-device STT + notes.
9. Backend conversation endpoint + LLM abstraction (local / Claude).
10. Client deep-dive panel.
11. LLM fallback for fuzzy figure mentions.
