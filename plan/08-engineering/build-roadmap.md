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
- **V07** · Glass control cluster: Play/Figures/Memo/Discuss controls morph out of the
  focused cover (`GlassEffectContainer` + `glassEffectID`), re-absorb on scroll; stub
  actions. (needs V06) ↳ [apple/CLAUDE.md §Glass moments #5](../../apple/CLAUDE.md) ·
  [screen-flows](../03-design/screen-flows.md)
- **V08** · Slot-emit staircase entrance: covers rise from the bottom shelf anchor on first
  appearance, scroll-driven (scrubbable), no overshoot. (needs V03)
  ↳ [motion-grammar #4](../03-design/motion-grammar.md)
- **V09** · **[verify]** Motion review vs the reference: record scroll/flick/focus on the
  iPhone simulator + a device if available; check each named pattern against
  [the reference analysis](../../apple/docs/reference/ref-books-video-analysis.md); tune
  `StackTransform` constants; file deviations as findings. (needs V04–V08)

## Phase P2 — Real books

> Goal: the stack shows *your* EPUBs; chapters fetch from the (local) backend through the
> real seam. Mirrors the proven Flutter data-layer design — port the design, not the code.

- **V10** · EPUB import: document picker (iOS + macOS), security-scoped bookmark, copy into
  the app container; entitlements. ↳ [app-architecture](../04-architecture/app-architecture.md) ·
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
