# V09 — Motion review vs the reference (findings)

> **Status:** Locked (review closed) · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). Machine half by the agent loop; **human
> review closed 2026-06-11 — user verdict: uniform card size, tighter/neater stacking,
> overall UI lift** ([ADR-011](../00-overview/decision-log.md#adr-011--uniform-book-card-geometry-in-the-library-stack)).
> Verdict + the findings below became **Phase P1.5 (V22–V26)** in the
> [build-roadmap](build-roadmap.md). Screenshot artifacts referenced below live in the
> local (gitignored) `.agent-loop/artifacts/` of the machine that ran the loop.
> (Original note: the loop cannot inject scroll/drag gestures, so feel-in-motion items
> were gated on the human scrub this verdict came from.)

## How to run the human review

1. Launch on the iPhone 17 Pro sim (or a device): `cd apple && xcodebuild -scheme Vimarsha
   -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` then install/launch (see
   apple/CLAUDE.md §Project setup). Record screen while you do (3)–(6).
2. **Scroll slowly top→bottom** and watch the depth-stack gradient (#1), the slot-emit
   fan-up off the bottom shelf (#4), and the recede-and-clip under the glass top-scrim (#3).
3. **Flick hard, twice back-to-back** — judge inertial dwell + soft landing, **no overshoot**
   (#6), and whether front covers bloom color through the ghosted header (glass moment #3).
4. **Settle a book onto the front slot** — judge grow-to-front promotion (#2): does the
   focused cover scale up + brighten + deepen its contact shadow while the displaced one
   dims? Does the glass control cluster emerge cleanly (V07)?
5. **Scroll the header off and back** — judge the settle contrast shift (#7): does "MY BOOKS"
   darken to full contrast as it reaches rest, ghost "VIMARSHA" fade to a watermark?
6. Compare against `apple/docs/reference/ref-books-video-analysis.md` §Motion grammar and the
   frame stills in `apple/docs/reference/frames/`.

## Static constant audit (machine-verifiable: math + ranges vs the reference)

Each named motion-grammar pattern (apple/CLAUDE.md §Motion grammar) → its implementation →
its tuning constants → the reference expectation → verdict. **No constants were changed** —
tuning the *feel* is the human call this gate exists for; proposed tweaks are filed as
findings, not applied.

| # | Pattern | Impl | Key constants | Reference says | Verdict |
|---|---------|------|---------------|----------------|---------|
| 1 | Depth-stack parallax scroll | `StackTransform` | frontSlot 0.72, rearScaleFloor 0.62, scaleFalloff 0.55, rearOpacityFloor 0.35, opacityFalloff 0.95, tuck 0.16 | front ≈1.0, rear shrink ≈0.75→0.6, dim/**desaturate**, small upward y-offset | ✅ scale range (1.0→0.62 floor) matches; static depth read good in screenshots. ⚠️ **no desaturation** — only opacity dims (apple/CLAUDE.md calls desaturation optional, "may desaturate slightly"). Feel in motion = human. |
| 2 | Grow-to-front promotion | `BookFocus` + `LibraryStackView:203` | settleWindow 0.18, scaleBoost 0.04, promotion = emphasis² | steeper curve near front, contact shadow deepens as scale→1 | ✅ emphasis² is steeper near 1; shadow deepen wired (`:220`). Bump is small (+4%) — judge live whether it reads as a promotion. |
| 3 | Recede-and-clip | `StackTransform` opacity + glass top-scrim capsule | opacityFalloff 0.95 → floor 0.35 at travel≈0.68 | fade the last ~15% of travel under the top occluder | ⚠️ opacity reaches its **floor (0.35), not 0**, before the scrim — covers stay partly visible rather than dissolving out. Judge live whether the glass capsule sells the dissolve or covers hard-edge under it. |
| 4 | Slot-emit staircase fan-up | `SlotEmit` | anchorScale 0.86, anchorOpacity 0, riseFraction 0.12, ease-out quad | staggered, scrubbable, **springy but no overshoot** | ✅ monotonic ease-out = no overshoot; stagger is intrinsic. ⚠️ reference says "**springy**" — impl is pure decelerate (no spring character at the landing). Human: decide if a gentle settle-spring is wanted vs the current safe ease. |
| 5 | **Coupled scroll+zoom hero settle** | **— none —** | — | header translates off while the **whole stack scales toward the viewer as one rigid group**, ease-in-out, anchored | ❌ **NOT IMPLEMENTED.** `LibraryStackView:203`'s scaleEffect is per-card (`StackTransform×SlotEmit×promotion`), not a rigid-group hero zoom. Out of V04–V08 scope. **File as a gap → own future V-item / polish.** The signature opening zoom of the reference clip is absent. |
| 6 | Inertial flick with dwell | native `ScrollView` inertia | (platform default) | momentum lands soft, **no bounce overshoot**; back-to-back flicks stack velocity | ⏸ untestable without gesture injection. Human: flick hard ×2, watch for bounce/spring at the ends. |
| 7 | Settle contrast shift | `HeaderContrast` | restGhost 0.26 / restHeadline 1.0; floors 0.05 / 0.18 / 0.32; settleSpan 0.5 | headline light-grey → near-black on settle; ghost fades to a watermark | ✅ math + snapshot tested (V04); ghost fades furthest. Live feel = human. |

### Suggested constant tweaks to weigh during the human scrub (NOT applied)
- **#1 desaturation:** consider a small `.saturation(0.85 + 0.15*scale)`-style term on receded
  covers to match the reference's "dim/desaturate"; currently rear covers stay full-chroma,
  just dimmed.
- **#3 dissolve:** consider letting opacity fall below the 0.35 floor *only* in the last ~15%
  of travel under the scrim, so covers truly dissolve into the glass capsule rather than
  clipping at floor.
- **#4 spring:** if the landing feels too "dead", a light critically-damped settle (or a tiny
  `interpolatingSpring` retarget at arrival) would add the reference's "springy" character
  while staying overshoot-free.
- **#5 hero zoom:** scope a dedicated V-item — a scroll-progress-driven rigid-group scale on
  the whole tower coupled to the header translate-off, anchored on a fixed cover point.

## Screenshot-confirmed findings (no gesture needed)

Captured this run into [`artifacts/V09/`](artifacts/V09/): `01-rest-hero-dark.png`,
`02-rest-hero-light.png` (iPhone 17 Pro, rest/hero state, both appearances).

- ✅ **Rest/hero state reads correctly** both modes: editorial header (ghost "VIMARSHA" /
  label "LIBRARY" / headline "MY BOOKS"), glass top-scrim capsule, and a clean depth
  staircase OPTIC→DAVID CROW→HEY→DESIGN BY ACCIDENT with the front (blue) cover dominant low-
  center — the front slot at 0.72 looks right.
- ⚠️ **V07 double-title — CONFIRMED visibly:** the blue front cover shows its own debossed
  printed title "DESIGN BY ACCIDENT" **and** the focus metadata reveal "Design by Accident"
  overlaid in the same eyeline. Fix per the monitoring note below (fade the cover's debossed
  title while metadata shows, or reposition the reveal).
- ⚠️ **Glass control cluster (V07) not visible at rest in the captured frame** — it sits at
  the focused cover's bottom edge and is clipped below the fold / behind the next book. Judge
  live whether it actually emerges on settle and reads as "extruded from the cover" (relates
  to the V07 placement note below).

## Monitoring-session notes (carried forward — verify each live)

- **V05 puck look:** in `artifacts/V05/02-puck-present.png` the puck reads as a flat dark
  translucent circle, not a refractive glass lens. Possibly a snapshot-renderer limitation
  (ImageRenderer may not composite real `glassEffect`) — judge on the live simulator by
  dragging on a cover. If it's genuinely flat in motion, the glass tint/strength needs a
  pass (compare against apple/CLAUDE.md glass moment #2: "a literal magnifying drop").
- **V07 cluster tint:** in `artifacts/V07/03-cluster-emerged-live.png` the four controls
  look butter/yellow-tinted; apple/CLAUDE.md says interactive glass tints **sky** (aqua for
  live/active). Check live whether it's the butter glow accent bleeding through or an actual
  tint choice — if tinted butter, switch to sky.
- **V07 double title:** with the cluster emerged, the metadata reveal ("Design by Accident")
  renders over the cover's own printed title — title appears twice in one eyeline. Consider
  fading the cover's debossed title while metadata is shown, or repositioning the reveal.
  **(Now also confirmed at the plain rest state — see screenshot findings above.)**
- **V07 cluster placement:** the cluster sits at the focused cover's bottom edge overlapping
  the next book below — judge live whether it reads as "extruded from the cover" (intent)
  or "floating on the pile".

## Machine verdict

- Both suites green this run (macOS + iPhone 17 Pro sim, `** TEST SUCCEEDED **`).
- All seven named patterns audited; **6/7 implemented**, **#5 coupled scroll+zoom hero
  settle is a genuine gap** (file as a future V-item). Constants for #1–#4, #7 sit within the
  reference-described ranges; the listed tweaks are judgement calls deferred to the human
  scrub. **#2/#3/#4/#6 feel + #1 desaturation + the V05/V07 items above need eyes on motion.**
- No constants changed (that's this gate's human decision). Item stays 🚧 → `.agent-loop/NEEDS_HUMAN`.
</content>
</invoke>
