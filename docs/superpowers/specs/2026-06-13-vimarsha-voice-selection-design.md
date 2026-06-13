# Vimarsha — Narrator Voice Selection (design)

_Dated 2026-06-13. Native Swift client (`apple/`) + stateless Python backend (`backend/`)._

## Goal

Let the reader choose the **narrator voice per book**, from a small curated catalog, and hear
a **preview** before committing. Builds directly on the pluggable-TTS work already merged
(`?engine=` on `/import` and `/speak`; `KokoroSynth` alongside `ChatterboxSynth`).

## Decisions (locked in brainstorming)

| Question | Decision |
|---|---|
| Selection scope | **Per-book** (stored on `Book`) |
| Catalog | **Curated list, engine hidden** — named voices backed by Kokoro voices; Chatterbox/cloned voices can join later |
| Re-narration on change | **Lazy** — a chapter re-narrates only when next opened/played |
| UI placement | A **"Narrator"** control in the book-focus cluster → opens a **voice-list panel** (reuses the chapter-list / archive-plane pattern) |
| Preview | **Bundled** pre-generated clips, one per voice; no live call |

Explicitly **out of scope** (YAGNI): a `/voices` endpoint, Chatterbox/cloned voices in the
catalog, global app-wide settings, per-chapter voice.

## Voice catalog (client-owned, static)

A `NarratorVoice` value: `{ id: String (display name), kokoroVoice: String, engine: String }`.
Each voice gets a distinct **proper name** (used everywhere in the app — the "global" name the
reader sees), not an adjective label. v1 entries (engine = `"kokoro"`); easy to rename:

| Name | Kokoro voice | Character |
|---|---|---|
| **Aria** | `af_heart` | American female, warm — **default** |
| **Stella** | `af_bella` | American female, bright |
| **Milo** | `am_michael` | American male, calm |
| **Imogen** | `bf_emma` | British female |
| **Edmund** | `bm_george` | British male, deep |

Kokoro's language is **inferred from the voice prefix** (`a*` = American → `lang_code 'a'`,
`b*` = British → `'b'`), so the client only ever sends the voice id. The catalog lives in one
Swift file (`Library/NarratorVoice.swift`) and is the single source of truth for display
names, the default, and the bundled-preview filenames.

## Backend changes (`backend/`)

1. **`?voice=` on `/import` and `/speak`** — alongside the existing `?engine=`. Blank → the
   engine's built-in default voice (current behavior). Threads to the synth.
2. **`KokoroSynth(voice=…)`** — already stores a voice; change `lang_code` to be **derived
   from the voice prefix** (`voice[0]`: `'b'` → British, else American). Share one `KPipeline`
   per `(device, lang_code)` via a class-level cache so constructing a synth per
   `(engine, voice)` stays cheap (the model loads once per language, not once per voice).
3. **Server synth cache keyed by `(engine, voice)`** — `_cached_synth(engine, voice)`;
   `synth_for(engine, voice, default)` returns the injected default when both are blank
   (preserves env default + test overrides), else a cached instance. Construct via
   `synth_class(engine)(voice=voice)`; give every `Synthesizer` an optional `voice` ctor arg
   (Chatterbox accepts and ignores it for now). The `Synthesizer.synthesize(text)` protocol is
   **unchanged**, so `narrate_bundle` is untouched.
4. **No `/voices` endpoint** — the catalog is the client's; the backend accepts any voice
   string and just passes it to the engine.

## Persistence (SwiftData — schema bump)

- `Book.voiceId: String` — default `"Aria"` (the catalog default id).
- `Chapter.narratedVoiceId: String?` — the voice a cached `chapter.mp3` was rendered in;
  `nil` until first narrated.

Lightweight migration (additive columns with defaults), tested by fabricating a prior-schema
store — same approach as the existing Memos/ChatThreads migrations.

## Lazy re-narration

- `ChapterDownloader.download(…)` gains a `voice:` argument, passes it to
  `backend.importChapter(…, voice:)`, and on success the caller stamps
  `chapter.narratedVoiceId = book.voiceId`.
- **Stale check** (pure function, unit-tested): a `ready` chapter is *stale* when
  `narratedVoiceId != book.voiceId`. On open/play of a stale chapter, it is treated like
  `none`/`pending` and re-downloaded through the existing `pending → ready` flow (the old
  `chapter.mp3` is replaced atomically, same all-or-nothing teardown).
- Changing `book.voiceId` itself computes nothing — it only flips the stale predicate.
- **Two ways to re-render, both graceful:**
  1. **Lazy on play** — opening/playing a stale chapter re-narrates it automatically (above).
  2. **Hold-to-re-render in the chapter list** — long-pressing a chapter row triggers an
     immediate re-render in the book's current voice (re-download through the same flow,
     showing `pending` progress). Lets the reader proactively refresh chapters (one, or each)
     instead of waiting for playback. A non-stale chapter can still be held to re-render (a
     manual refresh); a stale one shows the affordance prominently.
- The **chapter list** marks stale chapters (a small "will re-narrate in <voice>" hint) and
  exposes the hold gesture, so the change is honest and the reader is never surprised by a
  mid-play stall.

## UI (book-focus surface — morph, never a page)

- **New cluster control "Narrator"** with a distinct icon (`person.wave.2.fill`) so it never
  reads as the existing **"Voice notes"** (memos). Cluster order:
  `Play · Narrator · Voice notes · Saved discussions`. (`ControlCluster.Control` gains a case;
  its `allCases` test updates.)
- **Voice-list panel** — tapping "Narrator" opens a glass list panel built on the **same
  pattern as the chapter list / `bookMemosPlane` / `bookConversationsPlane`** archive planes
  already in `LibraryStackView` (a morphed list state of the surface, not a `.sheet`). Layout:
  - a short **warning notice** at the top: *"Changing the voice re-downloads each chapter in
    the new voice before it plays."* — so the cost of switching is clear up front;
  - rows: the catalog voices, the current one check-marked;
  - a **▶ preview** button per row (see below);
  - tapping a row sets `book.voiceId` and dismisses the panel (no chapters re-render yet — that
    happens lazily on play, or eagerly via hold-to-re-render in the chapter list).
- **Preview playback** — each row plays a **bundled** clip
  (`Resources/VoicePreviews/<kokoroVoice>.mp3`) through a lightweight ephemeral player; it
  **ducks/pauses** any chapter narration while previewing (the memo-playback courtesy), then
  restores. No network, works offline.

## Bundled preview audio (dev artifact)

- One clip per catalog voice, all narrating the **same sample sentence** (a short, neutral
  line — final text in the plan), generated once via `POST /speak?engine=kokoro&voice=<v>`
  and committed at `apple/Vimarsha/Resources/VoicePreviews/<kokoroVoice>.mp3`.
- Added to the app target's bundle resources. Regenerating is a documented one-liner per voice
  (kept in the plan), so adding a catalog voice later means: add the entry + drop in its clip.

## Testing

**Backend** (extend `tests/test_tts_engine.py`):
- `?voice=` threads through `/speak` (fake synth records the voice it was built with);
- lang-from-prefix: `af_*` → `'a'`, `bf_*`/`bm_*` → `'b'` (unit test on the derivation);
- `(engine, voice)` cache returns a stable instance and a *different* one per voice;
- unknown engine still → 400.

**Client** (Swift Testing):
- catalog integrity — non-empty, unique ids, default id present, every voice has a bundled
  preview resource;
- `importURL` / `ChapterDownloader` carry `voice`;
- stale predicate: `ready` + `narratedVoiceId != voiceId` ⇒ stale; equal ⇒ fresh;
- hold-to-re-render: invoking the chapter's re-render action downloads with the **book's
  current voice** and stamps `narratedVoiceId` to match (fake backend records the voice);
- migration: a prior-schema store opens with `voiceId == "Aria"`, `narratedVoiceId == nil`;
- `ControlCluster.Control.allCases` includes `.narrator`.

Both suites + both platform builds green; no new runtime stub modes (real Kokoro behind the
network seam, faked in unit tests as today).

## Build order (for the plan)

1. **Backend** `?voice=` + lang-from-prefix + `(engine,voice)` cache (+ tests).
2. **Catalog + persistence** — `NarratorVoice.swift`, `Book.voiceId`, `Chapter.narratedVoiceId`,
   migration (+ tests). Generate & commit the **preview clips**.
3. **Download path** — `ChapterDownloader.voice`, stamp `narratedVoiceId`, stale predicate,
   re-narrate-on-play, and the explicit re-render action (+ tests).
4. **UI** — "Narrator" cluster control + voice-list panel (with the re-download warning) +
   preview playback + chapter-list stale hint and **hold-to-re-render** gesture (+ tests).

Each lands on `main` via a `--no-ff` merge from a feature branch, per repo convention.
