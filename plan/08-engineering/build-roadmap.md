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
- **V11** · **[SPIKE]** Client-side cover extraction from EPUB (container.xml → OPF →
  cover-image manifest item; fall back to first image / generated cloth cover). Proves
  [ADR-006](../00-overview/decision-log.md#adr-006--cover-art-is-client-side). (needs V10)
- **V12** · SwiftData models + persistence: Books/Chapters with status + progress; the
  static `BookSeed` shelf becomes the empty-state/demo path. (needs V10)
  ↳ [data-model](../04-architecture/data-model.md)
- **V13** · `BackendClient` seam: protocol + URLSession impl + test double; wire `POST /toc`
  (multipart EPUB upload → book meta + chapters). (needs V12)
  ↳ [tech-stack §Contract](../04-architecture/tech-stack.md) ·
  [shared/bundle.schema.json](../../shared/bundle.schema.json) ·
  Flutter reference: `app/lib/core/backend/dio_backend_client.dart`
- **V14** · Lazy chapter download: `POST /import?chapter_index=N` → bundle JSON + MP3 cached
  in the container; per-chapter status (none/pending/ready/error) + progress UI on the
  chapter list. (needs V13) ↳ [app-architecture](../04-architecture/app-architecture.md) ·
  [narration-pipeline](../04-architecture/narration-pipeline.md)
- **V15** · **[verify]** A real EPUB imported on device: its cover renders in the stack,
  chapters list from `/toc`, one chapter narrates end-to-end against the local backend
  (`uv run uvicorn vimarsha.server:app --port 8000`). (needs V11, V14)

## Phase P3 — Narrated reading

> Goal: the product's core loop — listen to a chapter with live highlight and figures on
> cue — entirely on the one morphing surface.

- **V16** · Audio engine: app-lifetime shared playback owner (AVFoundation), play/pause/
  seek/speed/resume, throttled progress persistence; the audio seam + test double. (needs V14)
  ↳ [app-architecture §Seams](../04-architecture/app-architecture.md) · Flutter reference:
  `app/lib/features/player/`
- **V17** · Cover→reading-surface morph: the focused hardback opens into the reading canvas
  (matched geometry; the cover art is the shared element); back-morph on close. (needs V07)
  ↳ [screen-flows §Reading](../03-design/screen-flows.md) · [apple/CLAUDE.md §Prime Directive](../../apple/CLAUDE.md)
- **V18** · Reading surface: blocks rendered (serif body, figures inline as paper),
  paragraph highlight + auto-scroll driven by `paraTimings`. (needs V16, V17)
- **V19** · Tap-a-paragraph-to-seek + the compact glass transport cluster (play/pause/
  seek/speed) — controls are glass, content is paper. (needs V18)
- **V20** · Figure overlay on the glass carrier: auto-pop at `startMs`, recede at `endMs`,
  stacked when spans overlap; Figures gallery as a morphed grid state. (needs V18)
  ↳ [figure-intelligence](../04-architecture/figure-intelligence.md) ·
  [apple/CLAUDE.md §Glass moments #8](../../apple/CLAUDE.md)
- **V21** · **[verify]** Eyes-free run: a full real chapter listened end-to-end on device —
  highlight tracks, figures pop on cue, seek/speed/resume all work, offline replay from
  cache works. (needs V19, V20)

---

## Expansion buckets (itemized only when we get there — deliberately not sprints)

> Each bucket becomes a detailed phase (with V-items) via its own spec pass when it's next
> up. Order is the default; reshuffle by decision.

- **P4 — Memos:** hold-to-record at the paragraph pin → `/transcribe` → Notes state.
  (Flutter behavioral reference: old Plans 5a–5b.)
- **P5 — Discuss:** the native rebuild of the old Plan 6b spec — grounded chat, hold-to-talk,
  spoken replies, pause-on-audio-conflict, Conversations. ↳ [conversation-ai](../04-architecture/conversation-ai.md)
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
