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

## V25 — Coupled scroll+zoom hero settle (motion grammar #5) ✅

**What:** Phase P1.5 #4 — the missing motion grammar **#5**. As the editorial header
translates off the top, the whole book tower scales toward the viewer **as one rigid group**.
New `HeroSettle` pure math maps the scroll **distance-to-rest** → a tower scale: `baseScale`
1.0 at the top (the zoomed-out hero state) easing **in-out** (smoothstep) up to `peakScale`
1.06 once the header has scrolled off (`settleBand` 0.55 vh), then holding at peak through the
browsing scroll. No timers, fully scrubbable, and it un-zooms on the loop-back to top
(distance → 0). The zoom is anchored on the front slot (`StackTransform.frontSlot` 0.72) so
the dominant front cover holds while the receding stack grows toward the viewer — the
reference's fixed-point zoom.

**Wiring:** one `scaleEffect(_:anchor:)` on `BookTower` *as a whole* (the per-card depth-stack
parallax + slot-emit ride inside the group), driven by the already-tracked `distanceToRest`
and anchored at `UnitPoint(0.5, frontSlot)` via new `heroSettle(in:)` / `heroAnchor(in:)`
helpers in `LibraryStackView`. **Reduce Motion exempt** — pinned to `.rest` (no hero zoom, per
the accessibility static fallback). At rest the scale is exactly 1.0, so the effect is a no-op
until scroll engages it — no change to the resting layout. `HeroSettle.swift` + its tests are
new files; no other library math touched.

**Evidence:** both suites `** TEST SUCCEEDED **` (macOS + iPhone 17 Pro sim); 10 new
`HeroSettleTests` (degenerate viewport, base/peak clamps, overscroll→rest, hold-past-band,
monotonic growth, no-overshoot, ease-in-out shape + symmetric midpoint, front-slot anchor,
viewport-fraction scaling), all prior suites stayed green. Rest capture reviewed in
[`artifacts/V25/v25-rest-dark.png`](artifacts/V25/) — **looked at:** the editorial header +
uniform-card staircase render identically to V24 (confirming the rest no-op). Commits
`c7b4d86` (math+tests) + `7df43b3` (wiring), merged `1c31b84`.

**Device-gated:** the scroll-driven zoom **feel** (does the front cover read as held? is the
1.06 peak the right strength? does it couple cleanly with the header translate-off and the
slot-emit landing?) and the anchor approximation — `scaleEffect`'s anchor is in the tower's
*own* bounds, not viewport space, so the "fixed point" drifts slightly across a long scroll;
kept subtle and flagged for **V26** live re-review (where hero zoom is on the checklist). A
scrolled/zoomed capture could not be produced headless (simctl injects no scroll gesture).

---

## V24 — Focus & cluster fixes (from V09) ✅

**What:** Phase P1.5 #3 — the four focus/cluster deviations the V09 human review filed
([V09-motion-review](V09-motion-review.md) findings #2 + monitoring notes):
1. **Double title killed** — the focused front cover printed its own debossed title *and* the
   serif metadata reveal in the same eyeline. `HardbackCoverView` gains `titleOpacity`
   (default 1); the focused card passes `1 - promotion`, so the debossed title fades out
   exactly as the metadata reveal fades in. Only the focused card promotes → only it fades;
   Reduce Motion (focus `.none`) leaves every title fully printed.
2. **Cluster glass cooled to sky/aqua** — the controls *looked* butter/gold (V09 monitoring
   note). Root cause confirmed in `artifacts/V07/03-cluster-emerged-live.png`: the cluster sat
   over the gold "A SENSE OF PLACE" board and its weak tint (sky 0.16) let that cover refract
   through. Tint opacities raised (sky 0.16→0.26, aqua/play 0.22→0.32) so the intended tint
   reads regardless of the cover beneath. (The tint *choice* was already sky/aqua per the glass
   rules — the bug was strength + substrate, not a butter tint.)
3. **Cluster anchored inside the focused cover's bottom edge** — new `FocusAffordancePlacement`
   (pure math, 7 tests) maps the next (occluding) book's top edge → the bottom padding that
   lifts the metadata + cluster to sit just inside the focused cover's *visible* bottom (the
   next book's top), above the book that overlaps it; clamped to a resting margin (cover bottom
   below the fold → rests at the viewport bottom as before) and a mid-viewport ceiling.
   `BookTower` publishes each card's top edge via a new `CardTopYKey` alongside the existing
   midY; `LibraryStackView` feeds `cardTops[focus.index + 1]` into the placement function. The
   metadata + cluster now read as extruded from the focused cover rather than floating over the
   book below it.
4. **Grow-to-front strengthened** — `BookFocus.scaleBoost` 0.04 → 0.07; the +4% promotion read
   too faint against the uniform-card stack.

**Wiring:** `HardbackCoverView(book:titleOpacity:)` (new param, applied to the title block);
`BookTower` passes `1 - promotion` for the focused card + emits `CardTopYKey`; `LibraryStackView`
gains `@State cardTops`, an `onPreferenceChange(CardTopYKey)`, and `focusAffordances(in:)` (now a
function taking the viewport size for the placement math). `FocusAffordancePlacement` + its tests
are new files. No StackTransform/SlotEmit/HeaderContrast constants touched (the front-slot
calibration noted below is out of V24 scope).

**Evidence:** both suites `** TEST SUCCEEDED **` (macOS + iPhone 17 Pro sim); `FocusAffordancePlacementTests`
(7) + `HardbackCoverTitleFadeSnapshotTests` (printed vs faded rasters differ) added, all prior
suites stayed green. Captures reviewed in [`artifacts/V24/`](artifacts/V24/) — **looked at:**
- `01-rest-dark.png`: the focused **HEY** (pink) cover's debossed title is now visibly **faded**
  (cf. V23 where it was bold) and its metadata reveal sits on the cover, not at the viewport
  bottom over the gold board.
- `02-cluster-emerged-live.png` (cluster temporarily forced `emerge: 1` to capture real Liquid
  Glass, then reverted): the four controls read as **cool sky/aqua glass** (play ▶ aqua-rimmed,
  rest sky) sitting **on the focused pink cover, above the blue book** — no longer the warm
  butter/gold of `V07/03` over the gold board. Both V24 wins (tint + placement) visible at once.
- `03-rest-light.png`: title fade holds on the butter canvas too (HEY debossed title dimmed,
  metadata revealing); the unfocused blue "Design by Accident" keeps its full bold title.
Binary mtime confirmed fresh before each shot. Merge `899e234` (commits `1654a89` placement,
`1fd5b4b` title fade, `eb86266` scaleBoost + tint).

**Device-gated:** the live *feel* of grow-to-front at 0.07 and the cluster's cover-anchored
travel as you scroll a book through the slot need an injectable scroll the agent-loop lacks —
math-tested + verified at the (partial) rest focus. Folds into **V26**. **Finding logged for
V26/follow-up (out of V24 scope):** at rest the front-slot (StackTransform.frontSlot 0.72) sits
*between* HEY and the dominant front cover (Design by Accident), so focus can land on the
behind-stack book rather than the front-most fully-visible cover. The double-title fix + anchoring
stay correct (everything is keyed to `focus.index`), but the *dominant* cover isn't always the
focused one — re-judge whether frontSlot wants nudging toward the front-most card when V25 (hero
zoom) or V26 tune the stack.

---

## V23 — Stack depth polish ✅

**What:** Phase P1.5 #2 — make depth read strong now that cards are one uniform size
(ADR-011), addressing V09 audit rows #1 (no desaturation) and #3 (opacity floored, didn't
dissolve). Two new `StackTransform` behaviours on recede + a tuning pass:
1. **Desaturation** (motion grammar #1 / §Physical book rendering "recessed covers may
   desaturate slightly; the front cover is full-chroma"): new `saturation` field lerps
   full chroma `1.0` at the front → `rearSaturationFloor 0.85` at the floor (`saturationFalloff
   0.25`). Applied via `.saturation(t.saturation)` in the `visualEffect` chain (render-side,
   no layout thrash).
2. **Scrim dissolve** (recede-and-clip #3 / glass moment #1): over the last `dissolveBand`
   (0.15vh) of travel — the cover passing under the glass top-scrim, ending at the top edge
   where `travel == frontSlot` — the (already floored) opacity ramps **below the 0.35 floor
   to 0**, so a cover melts into the scrim instead of clipping at the floor. Below the band
   the mid-recede plateau is untouched.
3. **Tuning:** `rearScaleFloor 0.62 → 0.60` so the staircase reads deeper now that size
   carries no meaning (within the reference's 0.75→0.6 rear-shrink range). Tuck/falloffs
   unchanged (already in range); the per-card contact shadows (keyed to promotion, in the
   view) left as-is — out of this item's scope.

**Wiring:** `StackTransform.at(...)` gains the `saturation` field + the dissolve term;
`identity` carries `saturation: 1`. `LibraryStackView`'s `BookTower` visualEffect adds one
`.saturation(t.saturation)` between opacity and offset. No other call sites; Reduce-Motion
branch (flat list, no transforms) untouched.

**Evidence:** both suites `** TEST SUCCEEDED **` (macOS + iPhone 17 Pro sim). `StackTransformTests`
gained `desaturatesOnRecede` (full→floor lerp + clamp) and `dissolvesUnderScrim` (plateau
before the band, below-floor inside it, ~0 at the top edge); `floorsClamp` updated (opacity now
dissolves far above, so it asserts the scale + saturation floors). Rest screenshots reviewed in
[`artifacts/V23/`](artifacts/V23/): `01-rest-dark.png` + `02-rest-light.png` — **looked at:** the
top **OPTIC** cover dissolves/dims under the glass scrim capsule (fading toward the canvas, no
longer a solid floored slab) and the receded covers read slightly muted; the staircase below
is intact in both modes. Binary mtime confirmed fresh (13:50) before the shots — not the
stale-binary trap. Commit `2559eb1`, merged `76ca193`.

**Device-gated:** the full dissolve-to-0 at the very top edge and the live *feel* of covers
desaturating/melting under the scrim mid-scroll need an injectable scroll the agent-loop env
lacks (no idb/assistive gesture injection) — math-tested + verified at the rest position
(OPTIC already visibly dissolving). Folds into the **V26** library quality re-review (scroll a
cover up under the scrim, confirm it melts cleanly with no hard edge; judge whether 0.85
desaturation reads strong enough or wants deepening). V24's double-title + cluster tint still
visible at rest (its scope, untouched).

---

## V22 — Uniform book cards ✅

**What:** Phase P1.5 #1 ([ADR-011](../00-overview/decision-log.md#adr-011--uniform-book-card-geometry-in-the-library-stack))
— ONE card geometry for every book in the library stack, replacing the scattered per-book
sizes the V09 human review called "not good". New `Library/CardGeometry.swift` (pure math):
`widthFraction 0.70` · `widthCap 460` · `aspect 0.50` + `width(forViewportWidth:)` (fraction,
capped, clamped ≥ 0). 5 Swift Testing cases (`CardGeometryTests`).

**Wiring:** `HardbackCoverView.aspectRatio` now uses `CardGeometry.aspect` (no longer
`BookSeed.aspect` — the seed field is retained for future cover-art fitting, not layout).
`BookTower`'s stacked + Reduce-Motion branches both frame to
`CardGeometry.width(forViewportWidth:)`; the per-index `widthFactor` helper is deleted.
Stack overlap tightened (`-0.04` → `-0.052` of viewport height) so the now-uniform slabs
read as a calm, neat editorial staircase. The depth-stack transform alone supplies the
staircase; size carries no meaning anymore.

**Evidence:** both suites `** TEST SUCCEEDED **` (macOS + iPhone 17 Pro sim); the existing
snapshot suites stayed green through the geometry change. Rest screenshots reviewed in
[`artifacts/V22/`](artifacts/V22/): `01-rest-dark.png` (pre-tighten), `02-rest-dark-tighter.png`
(shipped 0.052 — five even, uniform-width cards stepping neatly), `03-rest-light.png`. Commits
`45de6dd` (CardGeometry + tests) + `85f6945` (wiring), merged `53d7dec`.

**Device-gated:** the V09 double-title (debossed cover title + metadata reveal overlapping)
and the butter-tinted cluster are still visible at rest — both are explicitly **V24**'s
scope, untouched here. Live scroll *feel* of the tighter stack → re-judged at the V26
quality re-review.

---

## V09 — Motion review vs the reference 🚧 needs human review (motion feel + 1 gap)

**What:** the **[verify]** checkpoint for Phase P1 — audit every named motion-grammar
pattern against [the reference analysis](../../apple/docs/reference/ref-books-video-analysis.md)
and file deviations. This is a human-judgement gate (the agent-loop environment **cannot
inject scroll/drag gestures into the simulator** — no idb/assistive access — so *feel in
motion* is fundamentally a human scrub). The agent loop did every machine-verifiable part and
left a full findings doc for the human.

**Wiring:** no code changed. **No `StackTransform`/`SlotEmit`/`BookFocus`/`HeaderContrast`
constants were touched** — they sit within the reference-described ranges and tuning the
*feel* is exactly the decision this gate exists for, so proposed tweaks are filed as findings
rather than applied blind.

**Evidence:**
- Both suites green this run: `xcodebuild … -destination 'platform=macOS' test` and
  `… 'platform=iOS Simulator,name=iPhone 17 Pro' test` → both `** TEST SUCCEEDED **`.
- Rest/hero state captured on iPhone 17 Pro (dark + light) →
  `.agent-loop/artifacts/V09/01-rest-hero-dark.png`, `02-rest-hero-light.png`; read back and
  confirmed: editorial header + glass top-scrim + clean depth staircase, front slot at 0.72
  reads right.
- Static audit of all **7** named patterns → constants → reference expectation in
  [`.agent-loop/artifacts/V09-review-notes.md`](../../.agent-loop/artifacts/V09-review-notes.md)
  (table + suggested-but-unapplied tweaks + the live how-to-run script).
- **6/7 patterns implemented.** Screenshot-confirmed finding: **V07 double-title** (front
  cover's debossed title + the metadata reveal overlap in one eyeline) is visible even at
  plain rest. Carried-forward monitoring notes (V05 puck flatness, V07 butter tint, V07
  cluster placement) folded into the same doc for the live check.

**Device-gated → NEEDS HUMAN:** (1) live scroll/flick/focus scrub for motion *feel* —
grow-to-front promotion (#2), recede-and-clip dissolve (#3), slot-emit landing springiness
(#4), inertial flick dwell/no-overshoot (#6), and whether #1 needs the reference's
desaturation; (2) the V05 glass puck + V07 tint/double-title/placement fixes; (3) one genuine
**gap** — **motion grammar #5 (coupled scroll+zoom hero settle) is NOT implemented** (the
per-card scaleEffect at `LibraryStackView:203` is the depth-stack, not a rigid-group hero
zoom); the reference's signature opening zoom should be scoped as its own future V-item. Item
left 🚧; `V09` written to `.agent-loop/NEEDS_HUMAN`.

---

## V08 — Slot-emit staircase fan-up ✅ both suites green + snapshot + live launch verified

**What:** `Library/SlotEmit.swift` — pure `midY → {scale, opacity, yOffset}` for the entrance
(motion grammar #4 / apple/CLAUDE.md §Motion grammar #4). The counterpart to `StackTransform`'s
recede: the emit band runs from the viewport **bottom edge** (anchor, progress 0) up to the
front slot (arrived, progress 1), so `progress = clamp((vh − midY) / ((1 − frontSlot)·vh), 0, 1)`
— a cover travels its full rise exactly as it scrolls from first appearance to the slot. An
**ease-out** soft landing (`1 − (1 − p)²`, strictly monotonic, **no overshoot past identity**)
lifts the cover from the shelf anchor (`scale 0.86`, `opacity 0` → rises into existence,
`yOffset +0.12·vh` sunk toward the shelf) to identity at the slot. Above the slot emit is
identity and `StackTransform` owns the recede — the two meet at the slot with no jump, so the
staircase is one continuous surface. **Stagger is intrinsic** (no scripted per-item phase):
overlapping cards have staggered midYs, so each emits just after the one below it — the stepped
fan-up falls out of the geometry. No state, no time — scrubbable like the rest of the library
math.

**Wiring:** `BookTower`'s `visualEffect` composes `SlotEmit.at(...)` with the existing
`StackTransform` + grow-to-front promotion in one pass — `scale = t.scale·emit.scale·(1 +
promotion·scaleBoost)` (bottom anchor, so the cover grows up off the shelf), `opacity =
t.opacity·emit.opacity`, `offset = t.yOffset + emit.yOffset`. At the slot the focused card is
fully opaque/full-size (emit identity there), so V06/V07 focus + cluster are untouched. Reduce
Motion's flat full-size list is the other `card(...)` branch — emit only runs in the depth-stack
branch, so the static fallback is unchanged.

**Evidence:**
- 9/9 `SlotEmitTests` green on macOS + iPhone 17 Pro sim (degenerate viewport → identity; at/above
  the slot → identity; bottom edge → anchor with the exact `riseFraction·vh` sink; clamp below the
  edge — no sinking past the shelf; monotonic rise as midY climbs; **no overshoot** across the band
  — scale ≤ 1, opacity ∈ [0,1], yOffset ≥ 0; ease-out front-loaded past the linear midpoint;
  continuity at the slot).
- `SlotEmitSnapshotTests` (macOS `ImageRenderer`): a real `HardbackCoverView` rendered anchored
  vs arrived; rasters differ. PNGs in `.agent-loop/artifacts/V08/08-slot-emit-anchored.png` +
  `09-slot-emit-arrived.png` — **looked at:** anchored is the blank ink canvas (the cover hasn't
  appeared — opacity 0 at the shelf); arrived is the full *Design by Accident* blue hardback,
  full size + opacity + gilt edge. The rise-into-view is unmistakable.
- Live launch on iPhone 17 Pro sim (dark): `.agent-loop/artifacts/V08/01-rest-launch.png` —
  **looked at:** the staircase renders intact (OPTIC receding at top → DAVID CROW → HEY pink →
  DESIGN BY ACCIDENT blue at the front) with a faint cover just emerging from the bottom shelf
  edge (the emit anchor). Binary mtime confirmed fresh (02:18) before the shot — not the stale-binary
  trap. Both full suites `** TEST SUCCEEDED **` on macOS + iPhone 17 Pro.
- Commits `2cd8766` (math+tests) + `be98e98` (wiring+snapshot), merged `4d06e01`.

**Device-gated:** the live *feel* of scrubbing the fan-up — scrolling down and watching covers
rise sequentially from the shelf into the staircase, the ease-out landing reading as "springy but
no overshoot" at flick velocity — needs an injectable scroll the agent-loop env lacks (no
idb/assistive gesture injection), so it's math-tested + snapshot-rendered + verified at the rest
position rather than captured mid-scroll. Folds into the **V09** motion review (record a scroll-down
on device/sim, confirm covers emit cleanly with no bounce and stay on the 120Hz deadline). The
math, the seamless slot handoff, and the rise-into-view are proven here.

## V07 — Glass control cluster ✅ both suites green + live glass verified

**What:** `Library/ControlCluster.swift` — pure `promotion → {emerge}` (glass moment #5 /
apple/CLAUDE.md §UI map state 2). `emerge` is a smoothstep above an `emergeThreshold` (0.3):
the four controls stay melded into one glass blob (absorbed into the cover) until the focused
book is meaningfully settled, then fan apart; scrolling away reverses it. `xOffset(forControl:
of:spacing:)` fans the controls symmetrically about the centre, scaled by `emerge` (offset 0
when absorbed). A nested `Control` enum (`play, figures, memo, discuss`) carries each control's
SF Symbol + VoiceOver label. No state, no timers — scrubbable like `StackTransform`/`BookFocus`.
`Library/ControlClusterView.swift` renders it: a `GlassEffectContainer` of four controls, each
with a `glassEffectID`, so low emerge melds them into one blob and rising emerge splits them
(the glass analogue of grow-to-front). Play is tinted `aqua` (active), the rest `sky`
(interactive); Reduce Transparency swaps token-tinted matte fallbacks; the cluster is inert +
`accessibilityHidden` until `emerge > 0.5`. Stub `onActivate` (the reading/figures/memo/discuss
morphs land in later items).

**Wiring:** `LibraryStackView`'s bottom overlay became `focusAffordances` — a `VStack` of the
V06 `FocusMetadataView` reveal with the `ControlClusterView` beneath it, both fed the same eased
`focus.promotion`, so metadata + controls grow and recede together. This hosts the metadata with
the cluster (addressing the V06 note that the bare caption grazed the next rising cover). Under
Reduce Motion `focus` is `.none`, so the whole affordance (and cluster) is absent — consistent
with V06.

**Evidence:**
- 11/11 `ControlClusterTests` green on macOS + iPhone 17 Pro sim (control order; at/below
  threshold absorbed; full promotion → emerge 1; clamp ≤1 past full; monotonic across the band;
  smoothstep-eased mid-band; melded-at-centre when absorbed; symmetric fan summing to zero;
  spread scales with emerge; degenerate single-control = no offset).
- `ControlClusterSnapshotTests` (macOS `ImageRenderer`, opaque fallback): absorbed vs emerged
  rasters differ; PNGs in `.agent-loop/artifacts/V07/06-cluster-absorbed.png` +
  `07-cluster-emerged.png` — **looked at:** emerged shows the four controls (play ▶ w/ aqua rim,
  figures, mic, discuss bubbles w/ sky rims) fanned out; absorbed is the melded near-empty state.
- Live on iPhone 17 Pro sim (dark): `03-cluster-emerged-live.png` (cluster temporarily forced
  `emerge: 1` to capture the **real Liquid Glass** controls, since scroll-settle injection isn't
  available in the agent-loop) — **looked at:** four tinted glass circles fanned beneath the
  focused *Design by Accident* cover, paper-coloured icons, play left. `01-rest-launch.png` (real
  wiring) — **looked at:** at the imperfect launch rest-alignment the focused book's promotion is
  partial, so the cluster is correctly absorbed/faint (re-absorbed). Both full suites
  `** TEST SUCCEEDED **`.
- Commits `025b0e1` (math+tests) + `4b98b0b` (view+wiring+snapshot), merged `780b36b`.

**Device-gated:** the live *feel* of the controls morphing out as you scroll-settle a book onto
the slot — the meld→split timing, the emerge ramp, the 120Hz glass cost — needs an injectable
scroll the agent-loop env lacks (no idb/assistive gesture injection) and a live glass compositor
`ImageRenderer` doesn't run. Folds into the **V09** motion review (record a settle on device/sim,
confirm the cluster melds/splits cleanly and stays on the frame deadline). **Gotcha logged for
the next agent:** `xcodebuild … build` was repeatedly reporting `BUILD SUCCEEDED` **without
recompiling** edited Swift (stale binary, old mtime) — every "nothing renders" screenshot was a
stale install. Confirm the app binary mtime updated (or grep the build log for `Compiling
<File>.swift`) before trusting a simulator screenshot. **Tuning note for V09:** metadata +
cluster together (~y600–735 at launch) overlap the focused cover's lower third and the next
rising cover's top — revisit vertical placement / the cover→controls emergence anchor when V17
opens the cover into the reading surface.

## V06 — Book-focus state ✅ both suites green + live focus verified

**What:** `Library/BookFocus.swift` — pure `at(midYs: [Int: CGFloat], viewportHeight:) →
{index, emphasis}`: the card whose viewport midY is nearest the front slot
(`StackTransform.frontSlot` 0.72) **owns** it; `emphasis` (0…1) peaks when the card sits on
the slot line and falls to 0 at the `settleWindow` edge (0.18·viewport). An eased `promotion`
(`emphasis²`, "steeper curve near the front") drives the grow-to-front bump, the deepening
contact shadow, and the metadata reveal. Deterministic lower-index tie-break, degenerate /
empty inputs → `.none`. No state, no time — scrubbable like `StackTransform`/`HeaderContrast`
(motion grammar #2). `FocusMetadataView` renders the focused book's title (editorial New York
serif) + small-caps author on the **matte** canvas (content is paper, never glass), faded by
`reveal`; decorative → `accessibilityHidden`.

**Wiring:** each card publishes its `frame(in: .scrollView).midY` via a `CardMidYKey`
PreferenceKey (background GeometryReader); `LibraryStackView.onPreferenceChange` computes
`BookFocus.at(...)` into `@State focus` and feeds it to `BookTower`. The focused card alone
gets the grow-to-front scale (`t.scale · (1 + promotion·scaleBoost)`, `scaleBoost` 0.04,
bottom-anchored on top of the depth-stack transform, still inside the same render-side
`visualEffect`) and a contact shadow that deepens with `promotion` (opacity 0.30→0.48, radius
16→26, y 12→18). The reveal is a `.overlay(alignment: .bottom)`. **Reduce Motion** (flat
full-size list, no front slot) pins `focus = .none` → no promotion, no reveal.

**Evidence:**
- 9/9 `BookFocusTests` green on macOS + iPhone 17 Pro sim (empty/degenerate → none, on-slot =
  full emphasis, beyond-window → none, nearest-wins, monotonic fall-off, above/below
  symmetry, promotion eased ≤ emphasis with exact endpoints, continuity near the slot).
- `BookFocusSnapshotTests` (macOS-only, `ImageRenderer`) renders the real `FocusMetadataView`
  at `reveal: 0` vs `1` and asserts the rasters differ; PNGs in
  `.agent-loop/artifacts/V06/04-focus-hidden.png` + `05-focus-revealed.png` — **looked at:**
  revealed shows "Design by Accident" in the warm off-white serif + "FOR A NEW HISTORY OF
  DESIGN" small-caps author on ink; hidden is the opacity-0 (near-empty) state.
- Live launch on iPhone 17 Pro sim (dark): `.agent-loop/artifacts/V06/01-launch-top.png` —
  **looked at:** at rest the front-slot book (index 3, *Design by Accident*) is detected and
  its metadata reveal fades up at the bottom; the blue board reads as the promoted card. Both
  full suites `** TEST SUCCEEDED **` on macOS + iPhone 17 Pro.
- Commits `0c14a24` (math+tests) + `671f97f` (wiring+snapshot), merged `40aea2b`.

**Device-gated:** the live *feel* of grow-to-front as you flick a book into the slot (the
emphasis ramp, shadow deepening, reveal timing) folds into the **V09** human motion review —
scroll injection into the simulator isn't available in the agent-loop env, so focus is
math-tested + snapshot-rendered + verified at the rest position rather than captured
mid-flick. Tuning note for V07/V09: the bottom-anchored metadata caption currently sits low
enough to graze the next rising cover — revisit placement when the V07 glass control cluster
grows from the focused cover (it may host the metadata instead).

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
