# Vimarsha — Reading View & Figure Overlay (Plan 4 Design)

**Design spec — 2026-06-08**

Turn the player from an audio-transport screen into a **reading + listening**
experience: the chapter text is on screen, the spoken paragraph is highlighted
and auto-scrolled, and the right figure/diagram/quote floats over the text at
the moment it's discussed. Also refines the player chrome.

This is **Plan 4** of the Vimarsha decomposition, split into:
- **Plan 4a** — backend figure-image extraction/serving + client data & player
  sync logic (no new UI).
- **Plan 4b** — the reading view, figure overlay card, and player refinements.

Depends on Plans 1–3c (all merged). Voice notes (Plan 5) and AI conversation
(Plan 6) remain out of scope.

---

## 1. Scope

In scope:
- Backend extracts each figure's image from the EPUB at import, names it
  stably, records it on the figure, and serves it.
- Client downloads + caches figure images (chapter stays fully offline).
- Player loads the cached bundle and renders the chapter **text** with
  typography, distinct **pull-quote/blockquote** styling.
- During playback: **highlight** the narrated paragraph, **auto-scroll** to keep
  it in view, **tap a paragraph to seek** there.
- **Figure overlay:** a floating card shows the active figure during its time
  range (tap to expand full-screen); pull-quotes render as a styled quote card.
- Player refinements: book/chapter **title header**, **skip ±15s**, **compact
  speed control**, cleaner layout/theming.

Out of scope: inline figure rendering within the text (figures appear only as
the synced floating card), word-level highlighting, MOBI/PDF, voice notes, AI.

---

## 2. Backend additions (Plan 4a)

1. **`epub_reader.Chapter` gains `href`** — the chapter document's path inside
   the EPUB (e.g. `OEBPS/chap1.xhtml`), needed to resolve image paths that are
   relative to the chapter document.
2. **`figure_images.extract_images(epub_path, chapter_href, figures, out_dir)`** —
   for each `Figure` with an `asset`, resolve the EPUB-internal path
   (`posixpath.normpath(join(dirname(chapter_href), asset))`), read the bytes
   from the EPUB (via ebooklib `get_item_with_href`), write them to `out_dir`
   under a stable name `{chapterId}_{figureId}{ext}`, and set `Figure.image` to
   that name. Figures without an asset (pull-quotes) are left with
   `image == None`. Missing/unreadable assets are skipped (logged), leaving
   `image == None` rather than failing the import.
3. **`models.Figure` gains `image: str | None`** (alias `image`), regenerate
   `shared/bundle.schema.json`.
4. **`/import`** calls `extract_images` after `narrate_bundle`, writing images to
   the same dir audio uses. **`GET /image/{name}`** serves them (mirrors
   `/audio`, with the same path-traversal guard).

The figure's `asset` (original EPUB href) is retained for reference; `image` is
the served filename the client uses.

---

## 3. Client data & player sync (Plan 4a)

- **`BackendClient.downloadImage(name) -> List<int>`** (bytes; `ResponseType.bytes`),
  with a `FakeBackendClient` counterpart returning canned bytes.
- **`FileStore.imageFile(bookId, index, name)`** → `…/ch{index}/images/{name}`.
- **`ChapterRepository.downloadChapter`** — after caching bundle + audio, fetch
  each `figureMap[].image` (when non-null) via `downloadImage` and cache it.
  Failure to fetch an image does not fail the chapter (the card just won't show
  an image); the bundle/audio path still controls ready/error.
- **`ChapterRepository.loadBundle(bookId, index) -> ChapterBundle?`** — read the
  cached `bundle.json` and parse it with the freezed model.
- **Dart `Figure`** gains `image` (regen via build_runner).
- **`PlayerController`** is given the `ChapterBundle` on `load()` and exposes,
  derived from its tracked `position`:
  - `String? currentBlockId` — block whose `paraTimings` range contains the
    position; between paragraphs, the greatest `startMs ≤ position`.
  - `List<Figure> currentFigures` — ALL `figureMap` entries whose
    `[startMs, endMs]` contains the position, in document order (empty when
    none). Overlapping figures stack; the overlay lets the user tap to switch
    between them.
  - `String? imagePathFor(Figure)` — resolves a figure's `image` to its cached
    local file path via `FileStore` (null for pull-quotes / missing images).
  - `Future<void> seekToBlock(String blockId)` — seek to that block's
    `paraTimings` start (no-op if the block has no timing).
  These update on each position tick and `notifyListeners()`.

All of §3 is unit-tested against a fixture bundle with the existing fakes; no UI.

---

## 4. Reading UI, overlay & player polish (Plan 4b)

- **Reading view** (player body): renders `blocks` in order with typography —
  `heading` (sized by level), `paragraph`, and `blockquote`/`pullquote` in a
  distinct quote style. Built on `scrollable_positioned_list` so the controller
  can scroll a specific block index into view. The block matching
  `currentBlockId` is highlighted; auto-scroll keeps it in view; tapping a
  paragraph calls `controller.seekToBlock(id)`.
- **Figure overlay:** when `currentFigures` is non-empty, a floating card
  animates up over the bottom of the text showing the front figure — for image
  figures, the cached image + label + caption, tappable to a full-screen view;
  for pull-quote-kind figures, a styled quote card. When more than one figure is
  active, the card shows a **stack affordance** (e.g. "1 / N" with tappable
  dots/chevrons) so the user can **switch between the stacked figures**; the
  front selection defaults to the first and is widget-local state that resets
  when the active set changes. The card dismisses when no figure is active.
- **Player chrome:** app bar shows book + chapter title; a bottom transport bar
  with **skip −15s / play-pause / skip +15s**, a **compact speed chip** that
  cycles `0.75→1.0→1.25→1.5→2.0×`, a scrub slider (seek-on-release, already
  built), and current/total time. Calmer reader theming and spacing.
- New dependency: `scrollable_positioned_list`.

---

## 5. Architecture & boundaries

- The bundle remains the single contract; the only change is the additive
  `Figure.image` field. Backwards behavior: a bundle without `image` (pre-4a)
  still parses; figures simply have no image.
- `PlayerController` stays the one place playback position maps to
  reading/figure state; the reading view and overlay are dumb consumers of its
  derived values. The figure overlay and reading list are separate widgets so
  each is testable in isolation.
- Image fetching lives in `ChapterRepository` (alongside audio/bundle), so the
  "download a chapter" unit is one place.

---

## 6. Error handling

- **Image extraction (backend):** an asset that can't be resolved/read is
  skipped with `image == None`; import still succeeds.
- **Image download (client):** a failed image fetch leaves that figure without a
  cached image; the chapter is still `ready`; the card shows a caption-only/
  placeholder state.
- **Missing bundle on open:** if `loadBundle` returns null (corrupt/missing), the
  player shows the existing "couldn't play this chapter" state rather than
  crashing.
- **Figure with no timing / out-of-range ms:** simply never appears in
  `currentFigures`; no crash.
- **Pull-quote with no image:** renders as a quote card (expected, not an error).

---

## 7. Testing

- **Backend (pytest):** `extract_images` against the fixture EPUB (which has two
  `<figure>`s) — resolves paths, writes files, sets `Figure.image`; a missing
  asset → `image None` without error; `/image/{name}` serves bytes and rejects
  traversal. Existing suite stays green.
- **Client unit (4a):** `downloadChapter` caches images; `loadBundle` round-trips
  a cached bundle; `PlayerController` `currentBlockId`/`currentFigures` (incl. an
  overlapping-ranges case)/`imagePathFor`/`seekToBlock` against a fixture bundle
  with known timings.
- **Client widget (4b):** with a fake audio handler + fixture bundle + a
  placeholder image — narrated paragraph highlights and the list scrolls to it;
  tapping a paragraph calls `seekToBlock`; the figure card appears when the
  position enters a figure range and dismisses on exit; with two overlapping
  figures the stack shows "1 / 2" and tapping switches the front; skip ±15s and
  the speed chip call the controller; the title header renders.
- **Manual gate:** run on macOS against the real backend; download a figure-rich
  chapter (e.g. "The Christmas Truce"); confirm text scrolls/highlights with the
  audio and the right diagram pops at the right time.

---

## 8. Build order

**Plan 4a:** (1) `Chapter.href` + `figure_images.extract_images` + `Figure.image`
+ schema; (2) `/import` wiring + `/image` endpoint; (3) `BackendClient.downloadImage`
+ `FileStore.imageFile`; (4) `ChapterRepository` image caching + `loadBundle`;
(5) `PlayerController` sync logic.

**Plan 4b:** (6) reading view (typography + highlight + auto-scroll + tap-seek);
(7) figure overlay card (+ full-screen + quote card); (8) player chrome
refinements; (9) manual macOS verification.
