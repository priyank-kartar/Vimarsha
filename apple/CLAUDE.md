# Vimarsha Apple Client — UI Agent Guide

The native Swift client of Vimarsha, where **the UI is the product**. Read this before
writing any Swift code in `apple/`. For the product itself (what Vimarsha does, the backend,
the contract), read the root [`CLAUDE.md`](../CLAUDE.md); for the reference design this UI
is built from, read
[`docs/reference/ref-books-video-analysis.md`](docs/reference/ref-books-video-analysis.md)
(frame stills in `docs/reference/frames/`).

## What this is

A SwiftUI multiplatform app (iOS 26 + macOS 26) replacing the Flutter client (`app/`, which
stays as the working reference implementation). Same product, full parity: library →
narrated reading with synced figures → voice memos → Discuss (AI conversation). Same
stateless Python backend and contract: `ChapterBundle`
([`shared/bundle.schema.json`](../shared/bundle.schema.json)), endpoints `POST /toc`,
`POST /import?chapter_index=N`, `GET /audio/{name}`, `GET /image/{name}` (figure image
bytes, parallel to `/audio`), `POST /transcribe`, `POST /chat`, `POST /speak`. That is the
full client-facing set (the root guide's shorter list is the import-time core); only
`ChapterBundle` is schema-backed — the other request/response shapes are defined in the
per-feature specs and mirrored from the Flutter client. The client keeps the original EPUB
and re-uploads it per chapter download, exactly like the Flutter client.

**Cover art is client-side (decided 2026-06-11).** The contract has no cover field
(`BookMeta` is `{title, author}` only) and the backend stays untouched: the Swift client
extracts/renders covers itself from the EPUB it already holds locally. Until the library
plan wires `/toc` + EPUB cover extraction, the shelf renders from static seed data
(`Library/BookSeed.swift`) with generated cloth-bound covers.

## The Prime Directive: all motion, no pages

The app is **one continuously morphing surface**. This is the selling point; everything else
serves it.

- **No `NavigationStack` pushes. No page-style modal sheets.** A "screen" is a *state* of
  the surface, reached by morphing what is already visible.
- Every state change is a **gesture- or scroll-driven continuous transform**. Shared
  elements morph via `matchedGeometryEffect` / `glassEffectID`; nothing teleports, nothing
  hard-cuts.
- Transitions are **interruptible and scrubbable**: drive them from scroll/gesture progress
  or springs that retarget mid-flight — never from fixed-duration timers the user can't
  grab.
- If a feature seems to need a new page, redesign it as a morph of the current state. (The
  reference clip never leaves its one surface — that's the bar.)

## Color palette (canonical tokens)

The user-supplied 4-color palette **is the canvas** — the whole app visibly lives in these
colors (plus real book-cover art, which supplies all other saturation, like the reference).

| Token | Hex | Light mode role | Dark mode role |
|---|---|---|---|
| `butter` | `#F4F48F` | primary canvas | glow accent, highlights, progress |
| `aqua` | `#8FE5DC` | secondary surface, progress | active glow, live waveforms |
| `sky` | `#6FAFD0` | interactive tint, controls | interactive tint, glass tint |
| `slate` | `#5A8C9D` | deep accents, dividers — never body text | elevated surface tint |
| `ink` (derived) | `#101F26`–`#1C313A` ramp | text/ink (deepest step) | primary canvas (slate hue, deepened) |

- Hexes are **sampled estimates** from the palette image — keep them in ONE place
  (`Palette.swift`) so a correction is a one-line change.
- **Dark-first:** design every state on `ink` first; light mode is the derived variant on
  `butter`/`aqua` canvases. Both modes ship.
- **Text is one role in two modes:** the darkest `ink` step on light canvases (≥11:1 on
  both `butter` and `aqua`); a warm off-white derived from `butter` at low saturation on
  `ink` — never pure `#FFFFFF`, and never `slate`/`sky` for body text (slate-on-butter is
  3.2:1, slate-on-aqua 2.5:1 — both fail WCAG AA; they're decorative/large-display only).
- Never introduce ad-hoc colors. New semantic roles get tokens derived from these five.

## Typography

- **Display/headers: New York (native Apple serif)** — large, light weight, tight leading,
  often centered; the editorial "ART SPACE" feel. Small-caps letterspaced labels for section
  markers ("CHAPTER 4" style) via `.fontDesign(.serif)` + tracking, or `Font.custom` New York
  optical sizes.
- **Body/UI: SF Pro.** Reading-surface text may use New York for bookish warmth — decide in
  the reading-view spec and stay consistent.
- **Dynamic Type is required** everywhere, including the display serif (use relative text
  styles, not fixed point sizes).

## Liquid Glass usage rules

Glass is the app's material for *interactive things and overlays* — never a full-page wash
that kills the editorial calm. The canvas is matte (`ink`/`butter`); glass floats above it.

- APIs: `.glassEffect(...)` for elements, `GlassEffectContainer` to group elements whose
  glass should meld/split as they move, `glassEffectID` for glass-to-glass morphs (the
  glass analogue of `matchedGeometryEffect`). **Constraint:** `glassEffectID(_:in:)` only
  works between views inside the SAME `GlassEffectContainer` sharing a `@Namespace` —
  standalone it's inert. Cross-state morphs (e.g. cover → reading surface) need the
  container to span both states, or a plain `matchedGeometryEffect` for the matte parts.
- Tint glass with `sky` (interactive) or `aqua` (live/active); avoid untinted grey glass.
- Respect what glass means: **content is paper, controls are glass.** Book covers, text, and
  figure images are matte/physical; play controls, pucks, scrims, and panels are glass. The
  figure overlay rides a glass **carrier card** — the frame/scrim is glass, the figure image
  itself stays matte paper (this is the rule's one sanctioned content-adjacent glass case).
- The named glass moments (from the reference analysis — implement these, don't improvise):
  1. **Glass top-scrim dissolve** — receding covers dissolve into a glass capsule at the top
     safe area instead of hard-clipping.
  2. **Lensing drag puck** — a small glass drop tracks the user's drag and refracts the
     cover beneath it.
  3. **Floating glass header plane** — the chapter/section header sits on glass the book
     tower scrolls *under*; passing covers bloom color through the ghosted serif.
  4. **`GlassEffectContainer` merge on promotion** — cards' glass edges meld as a cover
     grows to the front, split as it recedes.
  5. **Glass control cluster** — Play/Narrate, Figures, Voice note, Discuss morph out of the
     focused hero cover as glass controls, re-absorb on scroll.
  6. **Glass-meniscus shelf slot** — covers surface up through a pool of glass that bulges
     and settles.
  7. **Velocity-reactive sheen** — specular glass highlights sweep gilt edges and debossed
     type on fast flicks.
  8. **Figure overlay on a glass carrier** — the synced figure morphs out of the narrated
     passage on a glass carrier card (glass frame/scrim, matte figure image), floats with
     refraction at the edges, morphs back.

## Motion grammar (the named patterns — use these names in specs, code, and commits)

1. **Depth-stack parallax scroll** — the signature library motion. Each book card's
   scale/opacity/y-offset is a **pure continuous function of its viewport position**: front
   card ≈1.0 scale and bright; cards above shrink toward ≈0.6, dim, and tuck upward.
   SwiftUI: the primary implementation is a GeometryReader (or `onScrollGeometryChange`)
   mapping each card's `midY → {scale, opacity, yOffset}` with explicit clamps — front
   scale capped at 1.0, rear floors so the stack never collapses; `zIndex` is set per-card
   from that same computed position. `.scrollTransition(.interactive)` is only suitable for
   simple enter/exit effects (its phase value is a coarse −1…1 signal, not true viewport
   position) — use it for the recede fade, not the stack math.
2. **Grow-to-front promotion** — the card entering the front slot scales up and brightens
   while the displaced one scales down and dims; steeper curve near the front; contact
   shadow deepens as scale → 1.0.
3. **Recede-and-clip** — top-exiting cards shrink, dim, and pass behind the glass top-scrim,
   fading their last ~15% of travel.
4. **Slot-emit staircase fan-up** — covers rise sequentially from the bottom shelf anchor
   into a stepped staircase; staggered, **driven by scroll offset (scrubbable), not time**;
   springy but no overshoot.
5. **Coupled scroll+zoom hero settle** — the header translates off while the stack scales
   toward the viewer as one rigid group, ease-in-out, anchored so a chosen point stays fixed.
6. **Inertial flick with dwell** — momentum that lands softly with **no bounce overshoot**;
   back-to-back flicks stack velocity; the lensing puck appears on finger-down.
7. **Settle contrast shift** — header type animates light→full contrast as a function of
   distance-to-rest (scroll-driven, never a timer).

**Performance budget:** target 120Hz ProMotion with no sustained frame drops during flicks —
budget glass so the worst-case flick stays on the frame deadline (fewer concurrent live
glass effects during high-velocity scroll; promote/demote glass at rest). Cover art is
pre-rendered/downsampled into textures at import; never decode images during scroll.
`drawingGroup()` is a last resort and **must never wrap a subtree that contains or sits
beneath a `glassEffect`/material** — it rasterizes to a flat layer and kills glass
refraction; if used, scope it to a pure-matte cover-art sublayer with no glass over it.
Profile with Instruments before and after every motion-heavy merge.

## Physical book rendering

- Real EPUB cover art mapped onto a **physical hardback card**: subtle cover rounding,
  layered fore-edge page texture along one edge, soft diffuse contact shadow, optional gilt
  edge accent for flourish.
- Depth is **2.5D** — scale + offset + shadow (like the reference), *not* literal 3D
  rotation. No perspective transforms on covers.
- Depth comes from scale/opacity/shadow, **not blur**. Recessed covers are dimmed and may
  desaturate slightly; the front cover is full-chroma.
- If an EPUB has no cover image, fall back to a generated cloth-bound cover: title in the
  display serif, tone-on-tone on a `slate`/`sky` derived cloth color. (Real art is the rule;
  this is only the missing-art fallback.)

## UI map (states of one surface — not pages)

1. **Library stack** — the reference design: editorial header (app/section title) on the
   floating glass plane above the depth-stacked tower of the user's books. Scroll is
   browsing; browsing is the animation.
2. **Book focus** — scroll settles a book into the front slot; the glass control cluster
   morphs out of the cover (Play/Narrate, Figures, Voice note, Discuss). Chapters appear as
   a secondary stack/fan from the focused book.
3. **Narrated reading surface** — the focused cover morphs open into the reading canvas:
   paragraph-level highlight synced to narration, auto-scroll, tap-a-paragraph-to-seek
   (parity with the Flutter reading view). Transport (play/pause/seek/speed) lives in a
   compact glass cluster, not a chrome bar.
4. **Figure overlay** — at each figure's `startMs`, the figure morphs out of the passage on
   a floating glass carrier card (glass frame, matte image; stacked if several overlap);
   morphs back at `endMs`. The Figures gallery is a morphed grid state of the same surface.
5. **Memo record** — hold gesture on the glass mic control; an `aqua` waveform puck while
   recording; release → `/transcribe` → memo pinned at the paragraph. Notes list is a
   morphed list state.
6. **Discuss panel** — a glass plane that morphs up *within* the canvas — a state of the
   surface, never a `.sheet`/`.fullScreenCover`. Opening does not pause playback (parity
   rule). Keyboard-default input + hold-to-talk; replies text-first with a speaker control
   (`/speak`); Save persists the thread. The system keyboard is the one sanctioned
   OS-driven surface and is exempt from the morph rule.
   **Pause-on-audio-conflict (carried over from the Flutter spec):** while a reply is being
   spoken or the user is voice-typing, pause chapter narration and resume after if it was
   playing.
7. **Conversations** — saved threads as a morphed list state; reopen read-only; delete.

"Morphed list state" concretely: the current surface reflows into a scrollable list on the
same canvas (e.g. the stack flattens into rows, or a glass-backed list plane rises) — never
a `NavigationStack` push or sheet. The exact choreography belongs to each feature's spec.

## Accessibility & restraint

- **Reduce Motion:** distinguish the two kinds of motion. *Continuous-layout effects* get a
  static-layout fallback: the depth-stack renders as a flat, full-size single-column list of
  cover cards (no scale/opacity/offset-by-position, no hero zoom), scrolled normally.
  *Discrete state morphs* (book focus, reading surface, Discuss) become cross-dissolves or
  instant swaps. Check `accessibilityReduceMotion` everywhere.
- **Reduce Transparency:** every glass element has an opaque fallback (token-tinted matte).
- **Dynamic Type** everywhere; the stack and reading surface must survive XXL sizes.
- **VoiceOver:** the reference has zero chrome; we must not have zero affordances. Every
  gesture-only interaction (hold-to-record, double-tap, scroll-to-focus) needs an
  accessibility action and label.
- Restraint: motion serves comprehension (where things came from / where they went). If an
  animation doesn't explain spatial continuity, cut it.

## Project setup & how to run (verified 2026-06-11)

- **Product/target name `Vimarsha`**, bundle id `com.vimarsha.apple` (the Flutter app owns
  `com.vimarsha.vimarsha` — see `app/macos/Runner/Configs/AppInfo.xcconfig`; don't collide,
  both may be installed during the transition).
- Layout: `apple/Vimarsha.xcodeproj` (hand-authored, **folder-synchronized** — new files in
  `Vimarsha/`/`VimarshaTests/` join their target automatically, no pbxproj edits), sources
  in `apple/Vimarsha/` (`Design/Palette.swift`, `Library/…`), tests in `apple/VimarshaTests/`.
- Build & test (both verified green):
  ```bash
  cd apple
  xcodebuild -scheme Vimarsha -destination 'platform=macOS' test
  xcodebuild -scheme Vimarsha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
  ```
- Run on the simulator:
  ```bash
  xcodebuild -scheme Vimarsha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
  APP=$(find ~/Library/Developer/Xcode/DerivedData/Vimarsha-*/Build/Products/Debug-iphonesimulator -name Vimarsha.app | head -1)
  xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; xcrun simctl install "iPhone 17 Pro" "$APP"
  xcrun simctl launch "iPhone 17 Pro" com.vimarsha.apple
  xcrun simctl ui "iPhone 17 Pro" appearance dark   # canonical mode
  ```
- Requires Xcode 26 with the iOS 26 simulator runtime and macOS 26 SDK installed.
- Backend for live runs: same as root CLAUDE.md (`uv run uvicorn vimarsha.server:app
  --port 8000`); default URL `http://localhost:8000`.

## Tech conventions

- **Swift 6 / Xcode 26**, SwiftUI multiplatform target: iOS 26 + macOS 26. Real Liquid Glass
  APIs only — no backports, no fake glass.
- **TDD with Swift Testing** (`@Test`), same rhythm as the rest of the repo: failing test →
  minimal impl → green → small commit; feature branches merged `--no-ff` to `main`; commits
  carry the repo's `Co-Authored-By` trailer.
- **Seams (keep them minimal, mirror the Flutter client):** exactly two protocols get test
  doubles — `BackendClient` (URLSession impl; the same seven endpoints) and the audio/mic seam
  (AVFoundation impl: playback + record). Everything else in tests is real code. No runtime
  stub modes; integration tests hit the **real** backend (Chatterbox/Whisper/Ollama).
- **Persistence: SwiftData**, mirroring the Drift schema lineage: Books, Chapters (+ status
  + progress), Memos, ChatThreads/ChatLines. Lazy per-chapter bundle download with cached
  `chapter.mp3` + bundle JSON in the app container, like the Flutter `ChapterRepository`.
- **Audio:** AVFoundation (`AVAudioPlayer`/`AVPlayer`) for chapter MP3 + spoken replies;
  `AVAudioRecorder`/`AVAudioEngine` for memos. One shared playback owner (app-lifetime), the
  Flutter client's `AudioHandler` lesson applies: controllers pause, they never dispose the
  shared player.
- **JSON:** `Codable` structs generated to match `shared/bundle.schema.json` exactly
  (camelCase, no key remapping) — the schema is the contract; do not drift from it.
- macOS specifics: window resizable; scroll-wheel/trackpad drive the same motion functions
  as touch (they're scroll-position-driven, so this falls out naturally); hover states may
  add glass sheen but no hover-only functionality.

## Workflow

Same as the repo: brainstorm → spec (`docs/superpowers/specs/`) → plan
(`docs/superpowers/plans/`) → subagent implementation with spec + code-quality review gates.
UI work adds one gate: **motion review on device/simulator** — record the interaction and
check it against the named pattern in this file before merge.

## Status

- 2026-06-10: direction set (this document).
- 2026-06-11: **scaffold landed** (spec: `docs/superpowers/specs/2026-06-11-vimarsha-apple-scaffold-design.md`) —
  Xcode project (multiplatform, folder-synchronized), `Palette.swift`, static `BookSeed`
  shelf, generated hardback covers, **depth-stack parallax scroll** (`StackTransform`
  pure math, 7 unit tests, `visualEffect`-driven), glass top-scrim capsule, Reduce Motion
  flat-list fallback. Verified on iPhone 17 Pro simulator (dark + light) and macOS.
  Next: book focus + glass control cluster, or `/toc` wiring + client-side EPUB covers.
