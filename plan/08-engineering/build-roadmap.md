# Vimarsha — Build Roadmap (Step-by-Step Pointers)

> **Status:** Living · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). Current state → App Store, as discrete
> one-liner pointers. Each **V-item is a self-contained task** sized for its own agent
> window. Companion to the milestone view in [build-plan](build-plan.md) and
> [roadmap](../01-product/roadmap.md).

## How to run a pointer in a fresh agent window

> Open a new agent window in this repo and say: *"Read
> `plan/08-engineering/build-roadmap.md` + the docs it links for **VXX**, then implement
> **VXX**."* Each item lists its context docs (↳) and dependencies (needs …). Do items
> roughly in order; items in the same phase with no shared dependency can run in parallel
> windows (one [track](_progress-A.md) per window — respect file scopes).

**House rules for every V-item** (from [`CLAUDE.md`](../../CLAUDE.md) + [`apple/CLAUDE.md`](../../apple/CLAUDE.md)):
TDD where there's logic (Swift Testing); feature branch → small commits with the repo
trailer → suites green (`xcodebuild … test` both destinations; commands in
[apple/CLAUDE.md §Project setup](../../apple/CLAUDE.md)) → code-quality review → `--no-ff`
merge to `main` → **append an entry to your track's `_progress-<X>.md` with evidence**.
Motion-touching items additionally pass the **motion review** (record the interaction,
check it against the named pattern). Mark the item ✅/🚧 here when you update progress.

**Legend:** `↳` context docs · `(needs Vxx)` dependency · `[SPIKE]` de-risk/prove-it ·
`[verify]` checkpoint, run on a real device/simulator · ✅ done · 🚧 in progress.

---

## Phase P0 — Foundations (done)

- **V01** ✅ · Xcode project scaffold: multiplatform (iOS 26 + macOS 26), folder-synchronized
  pbxproj, `Vimarsha` + `VimarshaTests` targets, shared scheme, MainActor-default isolation.
  — _Done 2026-06-11, commit `d3c4248`._ ↳ [apple/CLAUDE.md §Project setup](../../apple/CLAUDE.md)
- **V02** ✅ · Palette tokens (`Design/Palette.swift`): raw palette + ink ramp + semantic
  dark-first colors + book-rendering tokens; hexes in ONE place. — _Done 2026-06-11._
  ↳ [apple/CLAUDE.md §Color palette](../../apple/CLAUDE.md)
- **V03** ✅ · Depth-stack parallax scroll with static books: `StackTransform` pure math
  (7 tests), `BookSeed` shelf, generated hardback covers, `visualEffect` transforms, glass
  top-scrim + Reduce Motion/Transparency fallbacks. — _Done 2026-06-11, verified both
  platforms + dark/light screenshots; review pass fixed the recede-tuck direction._
  ↳ [motion-grammar](../03-design/motion-grammar.md) · [_progress-A](_progress-A.md)

## Phase P1 — The living library

> Goal: the library stops being a render and becomes the signature *interaction* — every
> motion-grammar pattern present and tuned against the reference.

- **V04** ✅ · Settle contrast shift: header ghost→full contrast as a function of
  distance-to-rest (scroll-driven, no timers); ghost title also dims as the tower scrolls
  under the glass plane. — _Done 2026-06-11, commit `532ffd2`; `HeaderContrast` pure math
  (7 tests) + ImageRenderer snapshot, both suites green. Glass-header-plane refraction
  (covers bloom through ghost) deferred to V09/polish; live scroll feel → V09 motion review._
  ↳ [motion-grammar](../03-design/motion-grammar.md) ·
  [apple/CLAUDE.md §Motion grammar #7](../../apple/CLAUDE.md)
- **V05** ✅ · **[SPIKE]** Lensing drag puck: a small `glassEffect` drop tracking the active
  drag, refracting the cover beneath; prove the look + cost on device. (needs V03)
  — _Done 2026-06-11, commit `c904379`; `LensingPuck` pure geometry (7 tests) +
  `LensingPuckView` (interactive glass circle + opaque fallback) wired via a zero-distance
  `simultaneousGesture` (rides alongside scroll, Reduce Motion suppresses). Both suites green
  + present/absent overlay snapshot. The live glass-refraction **feel + cost** (120Hz flick
  budget, Instruments) needs an injectable drag the agent loop lacks → folded into V09._
  ↳ [apple/CLAUDE.md §Glass moments #2](../../apple/CLAUDE.md)
- **V06** ✅ · Book-focus state: scroll-settle detection (which book owns the front slot),
  grow-to-front emphasis curve + deepening contact shadow, focused-book metadata reveal.
  (needs V03) — _Done 2026-06-11, commit `40aea2b`; `BookFocus` pure math (9 tests) — the
  card nearest the front slot owns it, eased `promotion` drives a grow-to-front scale bump +
  deepening contact shadow on the focused card + `FocusMetadataView` reveal (matte/paper,
  snapshot-tested). Per-card midY via `CardMidYKey`; Reduce Motion pins `.none`. Both suites
  green; live launch focus verified. Live grow-to-front **feel** → V09 motion review._
  ↳ [screen-flows §Book focus](../03-design/screen-flows.md) ·
  [apple/CLAUDE.md §Motion grammar #2](../../apple/CLAUDE.md)
- **V07** ✅ · Glass control cluster: Play/Figures/Memo/Discuss controls morph out of the
  focused cover (`GlassEffectContainer` + `glassEffectID`), re-absorb on scroll; stub
  actions. (needs V06) — _Done 2026-06-11, commit `780b36b`; `ControlCluster` pure math
  (11 tests) — `promotion → emerge` (smoothstep above a settle threshold) + symmetric fan-out
  offsets. `ControlClusterView` melds the four glass controls into one blob when absorbed and
  splits them as `emerge` rises (`GlassEffectContainer` + `glassEffectID`); play tinted aqua,
  rest sky; Reduce Transparency matte fallback; inert + accessibilityHidden until emerged.
  Wired into `LibraryStackView`'s bottom `focusAffordances` (hosts the V06 metadata reveal).
  Both suites green + emerged/absorbed snapshot + live real-glass capture. Live scroll-settle
  morph **feel + glass cost** → V09 motion review._
  ↳ [apple/CLAUDE.md §Glass moments #5](../../apple/CLAUDE.md) ·
  [screen-flows](../03-design/screen-flows.md)
- **V08** ✅ · Slot-emit staircase entrance: covers rise from the bottom shelf anchor on first
  appearance, scroll-driven (scrubbable), no overshoot. (needs V03) — _Done 2026-06-11, commit
  `4d06e01`; `SlotEmit` pure math (9 tests) — the emit band runs from the viewport bottom edge
  (anchor) up to the front slot (arrived), so `progress = clamp((vh−midY)/((1−frontSlot)·vh),0,1)`
  and a cover travels its full rise as it scrolls into the slot. Ease-out soft landing (no
  overshoot past identity); composed with `StackTransform` in `BookTower` — emit owns below the
  slot, recede owns above, they meet at the slot with no jump. Stagger is intrinsic (staggered
  midYs). Both suites green + anchored/arrived snapshot + live launch. Live scrubbing **feel** (the
  springy-no-overshoot landing at flick velocity) → V09 motion review._
  ↳ [motion-grammar #4](../03-design/motion-grammar.md)
- **V09** ✅ · **[verify]** Motion review vs the reference: record scroll/flick/focus on the
  iPhone simulator + a device if available; check each named pattern against
  [the reference analysis](../../apple/docs/reference/ref-books-video-analysis.md); tune
  `StackTransform` constants; file deviations as findings. (needs V04–V08)
  — _Machine half done 2026-06-11 (suites green, static audit of all 7 patterns, captures).
  **Human review done 2026-06-11 (user): verdict = current stack isn't good enough** —
  cards must be ONE size, stacking tighter/neater, overall UI lifted
  ([ADR-011](../00-overview/decision-log.md#adr-011--uniform-book-card-geometry-in-the-library-stack)).
  Verdict + the audit findings (incl. the missing motion grammar #5) filed as
  **Phase P1.5 (V22–V26)** below. Full findings: [V09-motion-review](V09-motion-review.md)._

## Phase P1.5 — Library visual quality (user review round 1)

> Inserted 2026-06-11 from the V09 verdict — numbered after P3's V21. **Do these before
> P2:** the stack is the product's face; building real-book plumbing onto a look the owner
> calls "not good" compounds the rework. Findings source: [V09-motion-review](V09-motion-review.md).

- **V22** ✅ · Uniform book cards ([ADR-011](../00-overview/decision-log.md#adr-011--uniform-book-card-geometry-in-the-library-stack)):
  ONE card geometry for every book — same width (~0.70 of viewport, cap 460) and same
  aspect (~0.50); delete the per-index `widthFactor` rhythm and stop using `BookSeed.aspect`
  for card sizing (keep the field for future cover-art fitting). Tighten stack spacing so
  the overlap is even and the pile reads neat and editorial, not scattered. Update affected
  tests/snapshots. — _Done 2026-06-11, commit `53d7dec`; `CardGeometry` pure math (5 tests):
  `widthFraction 0.70`/`widthCap 460`/`aspect 0.50` + capped `width(forViewportWidth:)`. Both
  view branches + `HardbackCoverView` use it; `widthFactor`/`BookSeed.aspect` dropped from
  layout; overlap tightened `-0.04`→`-0.052`. Both suites green + rest captures (dark+light)
  show an even uniform-width staircase. V09 double-title + cluster tint left for V24._
  ↳ [V09-motion-review](V09-motion-review.md) ·
  [apple/CLAUDE.md §Physical book rendering](../../apple/CLAUDE.md)
- **V23** ✅ · Stack depth polish: receded covers truly **dissolve** under the glass scrim
  (opacity → 0 over the last ~15% of travel, below the rear floor); subtle desaturation on
  recede (full chroma at front → ~0.85 at the floor); re-tune `StackTransform` constants
  (tuck/falloffs/shadows) for the uniform-card stack so depth reads strong with same-size
  cards. (needs V22) — _Done 2026-06-11, commit `2559eb1`, merged `76ca193`; `StackTransform`
  gains a `saturation` field (1.0→0.85 floor, `saturationFalloff 0.25`) + a scrim-dissolve term
  (opacity below the 0.35 floor → 0 over the last `dissolveBand 0.15`vh of travel, ending at the
  top edge); `rearScaleFloor 0.62→0.60` for stronger depth. Wired via `.saturation()` in the
  `visualEffect` chain. Both suites green + dark/light rest captures show OPTIC dissolving under
  the scrim. Live mid-scroll melt/desat feel → V26 re-review._
  ↳ [V09-motion-review](V09-motion-review.md) audit rows #1/#3
- **V24** ✅ · Focus & cluster fixes from V09: fade the cover's debossed title while the
  metadata reveal shows (kill the double title); cluster glass tint butter → **sky** per the
  glass rules; anchor the cluster *inside* the focused cover's bottom edge (no overlap onto
  the next book); strengthen grow-to-front if it reads weak. (needs V22) — _Done 2026-06-11,
  merged `899e234`; `HardbackCoverView.titleOpacity` fades the focused cover's debossed title
  by `1 - promotion`; new `FocusAffordancePlacement` (pure math, 7 tests) + `CardTopYKey` anchor
  the metadata/cluster inside the focused cover's visible bottom (above the next book);
  `ControlClusterView` tint raised (sky 0.16→0.26 / aqua 0.22→0.32 — the "butter" was the gold
  cover refracting through weak glass, tint choice was already sky/aqua); `BookFocus.scaleBoost`
  0.04→0.07. Both suites green + dark/light/forced-emerge captures show the faded title + cool
  sky/aqua cluster on the focused cover. **Out-of-scope finding for V25/V26:** front-slot 0.72
  can focus the behind-stack book, not the dominant front cover._
  ↳ [V09-motion-review](V09-motion-review.md) · [apple/CLAUDE.md §Liquid Glass rules](../../apple/CLAUDE.md)
- **V25** ✅ · Coupled scroll+zoom hero settle — the missing motion grammar **#5**: a
  scroll-progress-driven rigid-group scale of the whole tower coupled to the header
  translate-off, anchored on a fixed point; scrubbable, ease-in-out, no timers; Reduce
  Motion exempt. (needs V23) — _Done 2026-06-11, commits `c7b4d86`+`7df43b3`, merged `1c31b84`;
  `HeroSettle` pure math (10 tests): `distanceToRest` → smoothstep ease-in-out from `baseScale`
  1.0 (zoomed-out hero, header visible) to `peakScale` 1.06 over `settleBand` 0.55 vh, then
  holding; one `scaleEffect` on `BookTower` as a rigid group (per-card parallax rides inside),
  anchored on the front slot (0.72) so the front cover holds; Reduce Motion pins to rest. Both
  suites green + rest capture (no-op at distance 0). Live zoom **feel** + the in-bounds anchor
  approximation → V26 re-review._
  ↳ [apple/CLAUDE.md §Motion grammar #5](../../apple/CLAUDE.md) ·
  [reference analysis](../../apple/docs/reference/ref-books-video-analysis.md)
- **V27** ✅ · Glass top-scrim redesign — contextual visibility (user finding 2026-06-11):
  at rest the scrim capsule read as a **giant empty pill dangling at the top** (both modes,
  worse on the light/butter canvas). — _Done 2026-06-11, commit `fbff4f2`, merged `e412a15`;
  `TopScrim` pure math (9 tests): scrim opacity is a scroll-driven function of the nearest
  cover's top-edge proximity to the viewport top (triangular window, strongest across the
  stack) — invisible at rest, fades in only while a cover dissolves under the top, out after.
  Reshaped from a floating padded capsule to a full-width bottom-rounded band hugging the top
  safe area (`ignoresSafeArea(.top)`); tint re-tuned per mode (sky 0.22 dark / 0.13 light);
  Reduce Transparency matte follows the same visibility rule. Both suites green + rest
  captures (dark+light) confirm the empty pill is gone in both modes. **Appears-during-recede
  is device-gated → verified in the V26 human re-review.**_
  ↳ [apple/CLAUDE.md §Glass moments #1](../../apple/CLAUDE.md) ·
  [V09-motion-review](V09-motion-review.md)
- **V26** ✅ · **[verify]** Library quality re-review: rebuild; capture rest / mid-scroll /
  focused states (dark + light) + a scroll recording if possible; check uniform sizing,
  neat stacking, scrim dissolve, hero zoom, and the cluster fixes against
  [ADR-011](../00-overview/decision-log.md#adr-011--uniform-book-card-geometry-in-the-library-stack)
  and the V09 findings; also eyeball the V05 puck's glass strength and the slot-emit landing
  character; **verify the V27 scrim behavior (invisible at rest, appears only during
  recede)**; then stop for human sign-off. (needs V24, V25, V27)
  — _**Machine half done 2026-06-11; needs human review.** Both suites green; fresh rest
  captures (dark+light) in [`artifacts/V26/`](../../.agent-loop/artifacts/V26/) confirm the
  STATIC quality: uniform cards (ADR-011), neat stacking, scrim dissolve — both modes.
  **Scroll-/gesture-revealed states are device-gated** (no sim gesture injection): hero zoom
  (V25 is a rest no-op), the focused state (V24 cluster/title-fade — promotion ~0 at launch
  rest), slot-emit/recede feel, the V05 puck, and the open `frontSlot 0.72` vs dominant-cover
  calibration. Full findings + human run-book → [_progress-A](_progress-A.md) V26 entry; `V26`
  written to `.agent-loop/NEEDS_HUMAN`. **Closed 2026-06-11 by user directive** ("aage
  badhao" — proceed to P2) after reviewing the final rest captures (dark+light). The
  device-gated motion-FEEL checks (hero zoom strength, focus/cluster live morph, flick
  landing, puck glass) were NOT individually scrubbed — carried as **review debt** into the
  next [verify] gates (V15/V21), which run on live scrolling anyway._

## Phase P2 — Real books

> Goal: the stack shows *your* EPUBs; chapters fetch from the (local) backend through the
> real seam. Mirrors the proven Flutter data-layer design — port the design, not the code.

- **V10** ✅ · EPUB import: document picker (iOS + macOS), security-scoped bookmark, copy into
  the app container; entitlements. — _Done 2026-06-11, merged `bd67c3b`; `EpubImporter`
  (3 tests, real file IO): picked EPUB → `Library/Books/<id>/book.epub`, container-relative
  result, scoped access released after copy, half-state rollback. Glass "+" → `fileImporter`
  (UTType.epub) in `LibraryStackView`; `Config/Vimarsha.entitlements` (macOS app-sandbox +
  user-selected read-only + network client) wired `sdk=macosx*`. Both suites green with the
  sandbox ON; live pick is device-gated → V15._
  ↳ [app-architecture](../04-architecture/app-architecture.md) ·
  Flutter reference: `app/lib/features/library/`
- **V11** ✅ · **[SPIKE]** Client-side cover extraction from EPUB (container.xml → OPF →
  cover-image manifest item; fall back to first image / generated cloth cover). Proves
  [ADR-006](../00-overview/decision-log.md#adr-006--cover-art-is-client-side). (needs V10)
  — _Done 2026-06-11, merged `69aa1c5`; `ZipArchive` (minimal stored+deflate reader, 5
  tests) + `EpubCover` ladder (EPUB3 properties → EPUB2 meta → cover-ish id → first image,
  7 tests) + importer writes `cover.<ext>` (+2). **Proven on a real Penguin EPUB** → true
  cover art (artifact in `.agent-loop/artifacts/V11/`). Spike findings (blank first-image
  on cover-less pirate EPUBs; iCloud unpacked-directory EPUBs) logged in
  [_progress-A](_progress-A.md). Rendering real covers in the stack lands with V12._
- **V12** ✅ · SwiftData models + persistence: Books/Chapters with status + progress; the
  static `BookSeed` shelf becomes the empty-state/demo path. (needs V10)
  — _Done 2026-06-11, merged `3710c6d`; `Book`/`Chapter` @Models (data-model.md v1 slice,
  raw-string status, cascade) + `LibraryStore` (@Observable: load/addBook/deleteBook,
  `EpubInfo` dc:title/creator, off-main `CoverArt` downsample) + `BookSeed`→`ShelfBook`
  (seeds = empty state; real cover art renders on the hardback board). 14 new tests +
  art-vs-cloth snapshot; both suites green. Live picker round-trip → V15._
  ↳ [data-model](../04-architecture/data-model.md)
- **V13** ✅ · `BackendClient` seam: protocol + URLSession impl + test double; wire `POST /toc`
  (multipart EPUB upload → book meta + chapters). (needs V12)
  — _Done 2026-06-11, merged `38e0453`; protocol + `/toc` DTOs (camelCase, mirrors backend
  models) + `Multipart` builder + `URLSessionBackendClient` (localhost default);
  `LibraryStore.addBook` = copy → cover → `/toc` → book + chapter rows, all-or-nothing with
  file rollback (Flutter parity); `FakeBackendClient` = the sanctioned network double.
  Both suites green + **live `/toc` round-trip verified against the running backend**._
  ↳ [tech-stack §Contract](../04-architecture/tech-stack.md) ·
  [shared/bundle.schema.json](../../shared/bundle.schema.json) ·
  Flutter reference: `app/lib/core/backend/dio_backend_client.dart`
- **V14** ✅ · Lazy chapter download: `POST /import?chapter_index=N` → bundle JSON + MP3 cached
  in the container; per-chapter status (none/pending/ready/error) + progress UI on the
  chapter list. (needs V13) — _Done 2026-06-11, merged `fd320ed`; `ChapterBundle` DTOs
  (schema-exact) + seam trio (`/import`+`/audio`+`/image`) + `ChapterDownloader`
  (all-or-nothing cache, best-effort figure images) + `LibraryStore.downloadChapter`
  (cancellable store-owned job, self-heal on load) + `ChapterListView` (glass-backed
  chapter plane off the focused book's Play control, full lifecycle affordances).
  +19 tests, both suites green; live plane open is gesture-gated → V15._
  ↳ [app-architecture](../04-architecture/app-architecture.md) ·
  [narration-pipeline](../04-architecture/narration-pipeline.md)
- **V15** ✅ · **[verify]** A real EPUB imported on device: its cover renders in the stack,
  chapters list from `/toc`, one chapter narrates end-to-end against the local backend
  (`uv run uvicorn vimarsha.server:app --port 8000`). (needs V11, V14)
  — _Machine half done 2026-06-11: live `/toc` → `/import` (real Chatterbox, 3m18s) →
  `/audio` (valid 24.6s MP3 matching paraTimings) round-trip with `sample.epub`; the live
  bundle decodes through the client's actual `ChapterBundleDTO`; both suites green on
  `main`. Artifacts: [`artifacts/V15/`](../../.agent-loop/artifacts/V15/). **Needs human
  review:** the on-device gesture flow — pick a real EPUB via "+", cover in the stack,
  Play → chapter plane, tap-to-narrate (minutes on MPS) → ready, relaunch persistence,
  error/retry path. Full run-book in [_progress-A](_progress-A.md) V15 entry. Note: live
  `GET /image` is unverified (fixture has no images — use a real illustrated book). **Closed 2026-06-11 under the deferred-review
  directive** — pipeline proven live (toc/import/audio + DTO decode); the on-device UX run
  moved to [final-review-checklist](final-review-checklist.md)._

## Phase P3 — Narrated reading

> Goal: the product's core loop — listen to a chapter with live highlight and figures on
> cue — entirely on the one morphing surface.

- **V16** ✅ · Audio engine: app-lifetime shared playback owner (AVFoundation), play/pause/
  seek/speed/resume, throttled progress persistence; the audio seam + test double. (needs V14)
  — _Done 2026-06-11, merged `424264e`; `AudioEngine` seam (ms-int API) +
  `AVFoundationAudioEngine` (AVAudioPlayer, real-WAV-tested) + `PlayerController`
  (@Observable: resume-clamp, transport, 250ms ticker, 5s save throttle, finish persist) +
  `FakeAudioEngine` double. +16 tests, both suites green. UI wiring lands V18._
  ↳ [app-architecture §Seams](../04-architecture/app-architecture.md) · Flutter reference:
  `app/lib/features/player/`
- **V17** ✅ · Cover→reading-surface morph: the focused hardback opens into the reading canvas
  (matched geometry; the cover art is the shared element); back-morph on close. (needs V07)
  — _Done 2026-06-11, merged `bc125a2`; `ReadingSurfaceView` shell (cover plate + serif
  masthead + glass close + ready mark) opened from a now-actionable READY chapter row; the
  tower card hands matched-geometry source to the plate and hides while open; Reduce Motion
  cross-dissolves. Both suites green + forced-state captures (dark/light) + rest regression.
  Live morph feel → V21._
  ↳ [screen-flows §Reading](../03-design/screen-flows.md) · [apple/CLAUDE.md §Prime Directive](../../apple/CLAUDE.md)
- **V18** ✅ · Reading surface: blocks rendered (serif body, figures inline as paper),
  paragraph highlight + auto-scroll driven by `paraTimings`. (needs V16, V17)
  — _Done 2026-06-11, merged `31ad540`; `TimingIndex` (the one lookups owner, 8 tests) +
  player loads bundle/figure-images + `ReadingBlocksView` (typed blocks as paper, narration
  wash) + auto-scroll (anchor 0.3, 4s user cooldown, RM jumps). Both suites green +
  forced-state captures both modes. Live cadence/feel → V21._
- **V19** ✅ · Tap-a-paragraph-to-seek + the compact glass transport cluster (play/pause/
  seek/speed) — controls are glass, content is paper. (needs V18)
  — _Done 2026-06-11, merged `b4b67fb`; `Transport` pure rules (speed ladder/clock, 4
  tests) + `seekToBlock` (untimed no-op) + one-glass-capsule `TransportClusterView`
  (butter progress, aqua play pill, speed chip, matte fallback) + "Read from here"
  VoiceOver action on text rows. Both suites green + forced captures both modes. Live
  drive → V21._
- **V20** ✅ · Figure overlay on the glass carrier: auto-pop at `startMs`, recede at `endMs`,
  stacked when spans overlap; Figures gallery as a morphed grid state. (needs V18)
  — _Done 2026-06-11, merged `a893402`; `FigureOverlaySelection` pure stack rules (6
  tests: stable-set persistence, set-change reset, wrap paging) + `activeFigures`/
  `allFigures` on the player + `FigureCarrierView` (aqua glass frame, MATTE figure
  paper, stacked pager + backing edges) riding above the V19 transport (spring pop/
  recede keyed on the set, RM cross-dissolve) + `FiguresGalleryView` morphed grid
  (matte tiles, tap → `seekToBlock` + morph back) behind a glass top-trailing toggle.
  Both suites green + carrier/gallery captures both modes. Live pop cadence → V21._
  ↳ [figure-intelligence](../04-architecture/figure-intelligence.md) ·
  [apple/CLAUDE.md §Glass moments #8](../../apple/CLAUDE.md)
- **V21** ✅ · **[verify]** Eyes-free run: a full real chapter listened end-to-end on device —
  highlight tracks, figures pop on cue, seek/speed/resume all work, offline replay from
  cache works. (needs V19, V20) — _Machine half done 2026-06-11, **human review deferred
  to final** ([checklist](final-review-checklist.md) §V21). Live harness over the
  PRODUCTION client files (BackendClient/ChapterDownloader/TimingIndex/
  AVFoundationAudioEngine): real `/toc`→`/import`→cache, the whole chapter **played
  through to `onFinish` at 2×** with every timed block the live highlight at some tick
  (9/9) and every spanned figure popping in-span (3/3, 0 leaks), seek/rate/resume +
  offline replay from cache — **ALL PASS**
  ([harness-run.log](../../.agent-loop/artifacts/V21/harness-run.log)). **Found + fixed
  a real bug:** `URLSession.shared`'s 60s idle timeout killed any real `/import`
  (narration is minutes of server silence) → narration-length session, merged `187a287`.
  Both suites green on `main`._

## Phase P-FIX — UI audit fixes (round 1)

> Inserted 2026-06-11 by the **independent UI audit** (fresh `main` build, iPhone 17 Pro
> sim, rest-state captures dark/light/XXXL/increased-contrast). Findings + artifacts:
> [ui-audit-log](ui-audit-log.md) §Round 1. Fix these **before P4** — they are all
> launch-rest-state defects visible in any App Store screenshot.

- **V37** ✅ · **[blocker]** Metadata reveal collides with the neighbor cover: at launch rest
  the focused book's white serif title + letterspaced subtitle straddle the cover seam and
  render text-on-text over the card above (at XXXL "Hey" sits directly on "DAVID CROW").
  Fix direction: anchor the reveal strictly inside the focused cover's own bounds (or a
  dedicated plate below it) with a hard clip — verify at medium AND XXXL, both modes.
  — _Done 2026-06-11, merged `aeb943b`; two root causes: the anchor used LAYOUT tops while
  covers draw transformed (`CardVisualTop` pure math, 5 tests, published per card), and the
  stack had no height bound (`FocusAffordancePlacement.maxHeight` +5 tests +
  `ViewThatFits` metadata-yields + `.clipped()` backstop). Both suites green; rest captures
  medium+XXXL × dark+light in `.agent-loop/artifacts/V37/` show the collision gone._
  ↳ [ui-audit-log](ui-audit-log.md) ·
  `.agent-loop/artifacts/ui-audit-20260611-1731/crop-xxxl-dark-cluster.png`
- **V38** ✅ · Metadata reveal legibility: bare white text over arbitrary cover colors
  (white-on-pink ≈2:1, WCAG fail both modes). Fix direction: back the reveal with a
  sky-tinted glass plate (matte token fallback under Reduce Transparency) or switch to the
  per-mode text token — never raw white over uncontrolled art. — _Done 2026-06-11, merged
  `bd703af`; sky-glass plate (0.30, non-interactive rounded-rect) behind the token text,
  `Palette.surface` matte under Reduce Transparency; paddings tightened so the V37 band
  still holds metadata + cluster at medium. Suites green + dark/light captures in
  `.agent-loop/artifacts/V38/`._
  ↳ [ui-audit-log](ui-audit-log.md) ·
  `.agent-loop/artifacts/ui-audit-20260611-1731/crop-light-mid.png`
- **V39** ✅ · Ghost control-cluster residue at rest: a ~20 px icon-pill ghost floats
  mid-cover on the focused book at promotion≈0 (medium type, both modes). Fix direction:
  fully gate the cluster — opacity 0 AND removed from the hierarchy below an emergence
  threshold, so partial-promotion states never leak a miniature pill. — _Done 2026-06-11,
  merged `e0d2b46`; `ControlCluster.visibilityFloor` (0.25) + `isVisible` + remapped
  `opacity` (0 at the floor → 1 at full emerge); the view renders nothing below the floor
  (+4 tests incl. the exact audit-state regression). Suites green; medium-rest dark/light
  ghost-free + XXXL cluster intact in `.agent-loop/artifacts/V39/`._
  ↳ [ui-audit-log](ui-audit-log.md) ·
  `.agent-loop/artifacts/ui-audit-20260611-1731/crop-dark-mid.png`
- **V40** ✅ · Cluster glass is untinted grey (XXXL rest, both modes): grey pill + monochrome
  dark-grey icons on the pink cover — violates "tint glass with sky/aqua; avoid untinted
  grey glass". Fix direction: sky-tinted glass for the pill, token-derived icon color;
  confirm the tint survives on light covers (pink/butter) too. — _Done 2026-06-11, merged
  `ba000b7`; three causes: weak tints (sky 0.45/aqua 0.52 now), luminance-adaptive glass
  flipping `textPrimary` icons (glass path → `ink0`), and the unclamped XXXL diameter
  outgrowing the fixed fan spacing so the controls never split (diameter clamp 68 + derived
  spacing). Also fixed a V37 regression (`.clipped()` amputated the offset-rendered fan —
  layout now declares fan width). Forced-emerge XXXL captures over the pink cover, both
  modes, in `.agent-loop/artifacts/V40/`; suites green._
  ↳ [ui-audit-log](ui-audit-log.md) ·
  `.agent-loop/artifacts/ui-audit-20260611-1731/crop-xxxl-light-cluster.png`
- **V41** ✅ · Title-fade not engaged at rest (double title): the focused cover's debossed
  title/subtitle stay full strength while the metadata reveal repeats the same strings
  ~150 px away — and at XXXL the cluster sits over the un-faded debossed title. Fix
  direction: drive the V24 deboss-fade from "any focus affordance visible" (metadata OR
  cluster), not solely from promotion progress. — _Done 2026-06-11, merged `9c4bf6f`;
  `BookFocus.debossTitleOpacity` (smoothstep 1→0 over promotion 0…0.4, +5 tests incl. the
  cluster-overlap invariant): the printed title is fully gone before the cluster's
  visibility promotion (≈0.53) and while the metadata reveal is still faint. Both suites
  green; medium+XXXL × dark+light rest captures in `.agent-loop/artifacts/V41/` show one
  title at medium and a blank cover under the XXXL cluster. **P-FIX round 1 complete.**_
  ↳ [ui-audit-log](ui-audit-log.md) ·
  `.agent-loop/artifacts/ui-audit-20260611-1731/crop-dark-mid.png`

## Phase P4 — Memos (itemized 2026-06-11; behavioral reference = frozen Flutter Plans 5a–5b)

> Voice notes pinned to the paragraph. Port the *design* from the Flutter client
> (`app/lib/features/`), specs in `docs/superpowers/specs/` (2026-06 memo specs) — read them
> first; link-don't-reinvent. Mic permission strings + entitlements are part of V28.

- **V28** ✅ · Memo recording: hold-to-record on the cluster's Memo control (long-press, aqua
  waveform puck while held), AVAudioRecorder behind the audio/mic seam, SwiftData `Memo`
  model (chapter + paragraphIndex pin), audio saved to the container. Mic permission primer.
  (needs V07, V16) — _Done 2026-06-11, merged `dd2144c`; `RecorderEngine` seam
  (AVAudioRecorderEngine m4a + metering / FakeRecorderEngine), `Memo` @Model (chapter
  cascade, paragraph+ms pin, pending status — transcription = V29), `MemoCapture`
  (pause-while-recording → save ≥400ms into the book's subtree → resume-if-was-playing;
  denied/failure/race recovery; 10 tests). Mic control + aqua level-waveform puck ride the
  reading surface's transport (screen-flows pins memo record to READING — the pin needs a
  live playhead; the library cluster's Memo stays a stub until V30). Entitlement + usage
  string landed. Both suites green; puck snapshots + rest regression in
  `.agent-loop/artifacts/V28/`. Real-mic feel → V31 deferred checklist._
  ↳ [data-model](../04-architecture/data-model.md) ·
  [screen-flows §Memo record](../03-design/screen-flows.md)
- **V29** · Transcription wiring: memo audio → `POST /transcribe` (faster-whisper, live
  backend) → transcript on the Memo; status pending/ready/error + retry, mirroring the
  chapter-status pattern. Live round-trip with a fixture WAV through the real backend.
  (needs V28, V13)
- **V30** · Notes state: morphed list state on the surface (never a sheet) — play memo,
  open-at-pin (jump narration to the paragraph), retry, delete; accessibility per the
  [matrix](../03-design/accessibility.md). (needs V29)
- **V31** · **[verify]** Memos end-to-end: fixture-audio memo → live transcript → Notes →
  open-at-pin seeks correctly; suites + captures; real-mic hold-to-record feel → deferred
  checklist. (needs V30)

## Phase P5 — Discuss (itemized 2026-06-11; spec = `docs/superpowers/specs/2026-06-10-vimarsha-deep-dive-conversation-design.md`)

> The native rebuild of old Plan 6b. **Read the spec first** — interaction rules (§4) are
> binding: open-without-pausing, pause-on-audio-conflict, save-on-demand. Needs **Ollama**
> live (`ollama serve` + `llama3.2:3b`); if absent, do machine-testable parts against the
> LLM seam's test double and note the live gap in the deferred checklist.

- **V32** · Chat data layer: `ChatContext` snapshot from the player state, grounded
  `POST /chat` via `BackendClient`, in-memory `ChatStore` (mirror Flutter `ChatController`
  semantics: send-guard, error states), SwiftData `ChatThread`/`ChatLine` +
  save-on-demand repository. (needs V13, V16)
  ↳ [conversation-ai](../04-architecture/conversation-ai.md) · [data-model](../04-architecture/data-model.md)
- **V33** · Discuss panel: glass plane morphs up *within* the canvas (never `.sheet`;
  keyboard is the one sanctioned OS surface) — keyboard-default input + send, replies
  text-first; opening does NOT pause narration. (needs V32, V17)
  ↳ [screen-flows §Discuss](../03-design/screen-flows.md)
- **V34** · Voice input: hold-to-talk → `/transcribe` → input field; **pause-on-audio-
  conflict** while voice-typing (pause narration, resume if it was playing). (needs V33, V28)
- **V35** · Spoken replies + persistence: speaker control → `POST /speak` → played on the
  shared audio engine with the same pause/resume rule; **Save** persists the thread;
  Conversations as a morphed list state (reopen read-only, delete). (needs V33)
  ↳ [sound-design §audio-priority ladder](../03-design/sound-design.md)
- **V36** · **[verify]** Discuss end-to-end vs live Ollama + backend: grounded answer about
  the actual passage, spoken reply pauses/resumes narration, saved thread reopens; suites +
  captures; conversational *feel* → deferred checklist. (needs V34, V35)

---

## Expansion buckets (itemized only when we get there — deliberately not sprints)

> Each bucket becomes a detailed phase (with V-items) via its own spec pass when it's next
> up. Order is the default; reshuffle by decision.

- **P6 — Figure intelligence:** LLM fallback at import for fuzzy mentions (old Plan 7) +
  the [figure-accuracy](../06-content-pipeline/figure-accuracy.md) corpus.
- **P7 — Hosted backend alpha:** queue + workers + Sign in with Apple + metered minutes.
  ↳ [hosted-backend](../04-architecture/hosted-backend.md) ([ADR-009](../00-overview/decision-log.md#adr-009--final-scope-backend-hosted-gpu-narration-service))
- **P8 — Monetization + onboarding:** paywall, free-tier shape, first-run flow ending in a
  narrated chapter. ↳ [monetization](../05-monetization/monetization.md)
- **P9 — Polish + accessibility audit:** the [accessibility](../03-design/accessibility.md)
  fallback matrix verified per state; performance (120Hz budget) pass; EPUB-compat hardening
  from the [corpus](../06-content-pipeline/epub-compatibility.md).
- **P10 — Ship:** TestFlight beta → ASO assets → App Store review → launch.
  ↳ [go-to-market](../07-gtm/go-to-market.md)
