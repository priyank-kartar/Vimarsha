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
