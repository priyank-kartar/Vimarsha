# Progress — Track A (Apple client)

> Part of the [knowledge base](../README.md) · roadmap: [build-roadmap](build-roadmap.md).
> **File scope:** all of `apple/**` (sole track for now — split scopes when a second track
> opens, e.g. backend/hosted work → `_progress-B.md`). Append one entry per finished V-item:
> **What / Wiring / Evidence / Device-gated**. Newest entries on top of their phase.

**Verification conventions (from [apple/CLAUDE.md](../../apple/CLAUDE.md)):**
```bash
cd apple
xcodebuild -scheme Vimarsha -destination 'platform=macOS' test
xcodebuild -scheme Vimarsha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```
Motion items also record a simulator/device capture for the motion review.

---

## V05 — Lensing drag puck [SPIKE] ✅ both suites green + look snapshot-verified

**What:** `Library/LensingPuck.swift` — pure `drag location + speed → {center, diameter,
opacity}` for the glass drop (glass moment #2 / motion grammar #6). The lens lifts above the
touch point (`lift` 30pt) so the finger doesn't occlude the refraction, clamps fully inside
the viewport at every edge, and swells with drag velocity (`speedDiameterGain` 0.04, clamped
at `maxDiameter` 132). `hidden` default = opacity 0. No state, no time — fully scrubbable.
`Library/LensingPuckView.swift` renders it: an interactive `glassEffect` circle with an
`aqua` meniscus rim, plus the Reduce Transparency opaque fallback (token-tinted matte). The
view is decorative — `allowsHitTesting(false)` + `accessibilityHidden(true)`.

**Wiring:** `LibraryStackView` drives the puck from a zero-distance `simultaneousGesture` on
the ScrollView (`DragGesture(minimumDistance: 0)`) so it rides *alongside* the scroll —
appears on finger-down, tracks the fling (`value.location` + `value.velocity`), and on
release fades out **in place** (keeps the last center/diameter, opacity → 0; only opacity is
animated so the position tracks the finger directly without sliding). The puck floats in
viewport space, so both the gesture and the `LensingPuckView` overlay live on the ScrollView,
outside the scrolling tower. **Reduce Motion suppresses it** (decorative continuous effect —
`onChanged` early-returns, puck stays hidden). At rest the puck is `diameter 0`/opacity 0, so
no live glass effect persists when idle.

**Evidence:**
- 7/7 `LensingPuckTests` green on macOS + iPhone 17 Pro sim (hidden invisible, active drag
  visible at base diameter, lift above touch, clamp at all four edges, velocity swell, max
  clamp on a hard flick, degenerate-bounds no-invert).
- `LensingPuckSnapshotTests` (macOS `ImageRenderer`): puck-present vs puck-absent rasters
  differ; PNGs in `.agent-loop/artifacts/V05/01-puck-absent.png` + `02-puck-present.png` —
  **looked at:** the present raster shows the lifted, sky-rimmed drop sitting above the cover
  title; the absent raster has no drop. (Opaque fallback used — `ImageRenderer` can't
  composite live Liquid Glass refraction.)
- Live launch on iPhone 17 Pro sim (dark): `.agent-loop/artifacts/V05/03-rest-launch.png` —
  app builds/installs/launches with the wiring; library + glass top-scrim render, puck hidden
  at rest (correct, no drag).
- Commits `a9c8dd4` + `b72deaf`, merged `c904379`.

**Device-gated:** the SPIKE's second half — the live **glass refraction look** under a moving
finger and its **cost** (the 120Hz flick budget, Instruments profiling) — needs a real drag
the agent-loop environment can't inject (no idb/assistive gesture injection) and a live glass
compositor `ImageRenderer` doesn't run. Both fold into the **V09** motion review (record a
flick on device/sim, confirm the lens reads + stays on the frame deadline). The geometry,
the opaque fallback, and that the drop draws over a cover are proven here; the glass *feel* is
the V09 sign-off.

---

## V04 — Settle contrast shift ✅ both suites green + snapshot-verified

**What:** `Library/HeaderContrast.swift` — pure `distanceToRest → {ghost, label, headline}`
opacities (motion grammar #7). Full contrast at rest (the V03 editorial baseline: ghost
0.26 / label 0.6 / headline 1.0); as the header scrolls away from the top it lerps to light
floors over a settle span of 0.5 viewport-heights, with the **ghost display title fading
furthest** (floor 0.05 vs label 0.18 vs headline 0.32 — the headline keeps the most
contrast). Negative/overscroll distance and degenerate viewport clamp to rest. No timers,
fully scrubbable, settle-darkens on the loop-back to top.

**Wiring:** `LibraryStackView` drives it via `onScrollGeometryChange(for: CGFloat)` reading
`contentOffset.y` (clamped ≥ 0) into a `@State distanceToRest`; the header is the only thing
that depends on it, so the depth-stack `ForEach` is extracted into a `BookTower` subview
(stable `size`/`reduceMotion` inputs → SwiftUI skips re-rendering it on the per-frame scroll
tick — the heavy `visualEffect` path is untouched). Header pulled into a parameterized
`LibraryHeader(contrast:)` so it renders identically from the live scroll state and from
tests. **Reduce Motion pins `.rest`** (no scroll-driven dimming — continuous-effect fallback
rule). Scope note: kept the header *in* the scroll content (matches the reference, where the
header exits the top); the full "covers bloom color through the ghosted serif" glass
header-plane refraction (glass moment #3) is the deferred V04 *extension*, a candidate for
V09/polish — not built here.

**Evidence:**
- 7/7 `HeaderContrastTests` green on macOS + iPhone 17 Pro sim (rest = baseline, overscroll
  clamp, degenerate viewport, monotonic dimming away from rest, floors reached at the span +
  clamp beyond, ghost-dims-most floor ordering, continuity near rest).
- `HeaderContrastSnapshotTests` (macOS-only, `ImageRenderer`) renders the real `LibraryHeader`
  at rest vs `distanceToRest: 600/800` and asserts the rasters differ; PNGs in
  `.agent-loop/artifacts/V04/02-header-rest.png` + `03-header-scrolled.png` — **looked at:**
  rest shows bright off-white MY BOOKS + legible ghost; scrolled shows the ghost nearly
  dissolved into the canvas, LIBRARY faint, MY BOOKS dimmed-but-most-legible. Exactly #7.
- Live launch on iPhone 17 Pro sim (dark) rest state screenshot:
  `.agent-loop/artifacts/V04/01-rest-top.png`.
- Commits `46883a1` + `57f0a84`, merged `532ffd2`.

**Device-gated:** the live *scroll feel* of the shift (and any covers-bloom-through glass
extension) folds into the **V09** human motion review — gesture injection into the simulator
isn't available in the agent-loop environment (no idb/assistive access), so the dimmed state
is math-tested + snapshot-rendered rather than captured mid-flick.

---

## V03 — Depth-stack parallax scroll (static books) ✅ verified both platforms

**What:** `Library/StackTransform.swift` — pure `midY → {scale, opacity, yOffset}` with
clamped rear floors (0.62/0.35), front slot at 0.72, **upward** recede tuck; `BookSeed`
static shelf (8 reference books, cloth/ink/aspect/gilt as stand-in cover assets);
`HardbackCoverView` (cloth sheen, debossed serif via dual text shadows, fore-edge page
capsules, gilt stripe, `@ScaledMetric` type); `LibraryStackView` (editorial ghost/label/
headline header, negative-spacing overlap with document-order z, `visualEffect` transforms,
glass top-scrim capsule, Reduce Motion → flat full-size list, Reduce Transparency → matte
capsule).

**Wiring:** transforms run render-side only (`visualEffect`), no layout thrash; widths vary
by shelf *index* (not id); all hexes in `Palette.swift` (incl. `pageEdge`/`gilt` tokens).

**Evidence:**
- 7/7 `StackTransformTests` green on macOS + iPhone 17 Pro sim (front-slot identity,
  below-front identity, recede direction *negative-y locked by test*, monotonic recede,
  floor clamps, continuity at the slot, degenerate viewport).
- Dark + light screenshots reviewed (canonical dark: ink canvas, staircase tucks up under
  the glass capsule). Commits `d3c4248` (+ fixes) merged `0134d10`.
- 12-agent review pass: confirmed-and-fixed — recede tuck direction was inverted vs the
  reference (the tests had baked in the wrong sign), orphan hexes, RM fallback width,
  id-keyed rhythm, missing `SWIFT_DEFAULT_ACTOR_ISOLATION`.

**Device-gated:** inertial-flick *feel* (grammar #6) — needs a human scroll on
device/simulator; queued into V09.

---

## V02 — Palette tokens ✅

**What:** `Design/Palette.swift` — raw palette (butter/aqua/sky/slate), derived ink ramp
(0x101F26/0x16262D/0x1C313A), warm `paper`, semantic mode-aware tokens (canvas/surface/
textPrimary/tint) via a cross-platform `Color(light:dark:)` dynamic provider; `Color(hex:)`.

**Evidence:** compiles into V03's render; WCAG text rules encoded in
[apple/CLAUDE.md §Color palette](../../apple/CLAUDE.md) (slate/sky never body text).
Commit `d3c4248`.

---

## V01 — Xcode scaffold ✅

**What:** Hand-authored `apple/Vimarsha.xcodeproj` (objectVersion 77,
`PBXFileSystemSynchronizedRootGroup` — files auto-join targets), app + unit-test targets,
shared scheme, multiplatform (`SUPPORTED_PLATFORMS` iphoneos/iphonesimulator/macosx,
deployment 26.0), `GENERATE_INFOPLIST_FILE`, ad-hoc macOS signing,
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, bundle id `com.vimarsha.apple`
(Flutter keeps `com.vimarsha.vimarsha`).

**Evidence:** `xcodebuild … test` green on both destinations on first scaffold build;
app installs + launches on the iPhone 17 Pro simulator. Commit `d3c4248`, merged `0134d10`.
