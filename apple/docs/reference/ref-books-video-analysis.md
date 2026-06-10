# Reference video analysis — `ref books.mp4` ("ART SPACE")

Frame-by-frame analysis of the 9.7s reference clip (1600×1200 @ 30fps, sampled at 2fps →
19 frames), produced 2026-06-10 by a 6-agent workflow (4 overlapping chunk readers, 1
full-sequence motion-arc reader, 1 synthesizer). Eight representative frames live in
[`frames/`](frames/). **Read this instead of re-analyzing the video.**

This clip is the visual/motion template for the Vimarsha Swift client's library and
chapter-cover surfaces. The design rules derived from it live in
[`apple/CLAUDE.md`](../../CLAUDE.md) — this document is the evidence.

## What the reference is

A phone-mockup concept for an editorial "book browser" — branded "ART SPACE / CHAPTER 4 /
UPCOMING RELEASES" — that presents a curated list of design/art books not as a flat
scrolling list but as a single living 3D object: a vertical tower out of which
physical-looking hardback covers rise, fan into a receding staircase, grow as they advance
to the foreground, then recede and exit behind the Dynamic Island. Gallery-grade,
type-forward, tactile-physical: warm-neutral matte canvas, pure-white page, debossed
tone-on-tone serif and condensed-caps typography that reads like printed cloth covers,
soft realistic contact shadows, and effectively **zero chrome** — no tab bar, nav bar,
buttons, or search. The whole experience is one continuously morphing surface driven by
scroll: **all motion, no pages.**

Note: the iPhone frame and taupe surround are presentation/mockup chrome, not app UI.

## Interaction flow (the definitive clip narrative)

One uninterrupted vertical scroll through a single morphing stacked-book surface, ending in
a loop back to the start state. No tap-through, tab switch, or slide-in page anywhere.

- **0.0–1.0s (frames 1–2, hero/start):** Chapter-title block at top — large low-contrast
  warm-grey serif "ART / SPACE", tiny letterspaced "CHAPTER 4", darker near-black serif caps
  "UPCOMING / RELEASES". Lower ~55%: receding 3D staircase of overlapping hardbacks,
  back→front: crimson, light-grey "OPTIC", navy "DAVID CROW", pink "HEY", royal-blue
  "DESIGN BY ACCIDENT". Motion eases in almost imperceptibly.
- **1.0–2.5s (frames 3–6, title recedes, zoom-in):** A faint translucent circular touch dot
  appears on the blue book. A coupled scroll-up + scale-up ramps to peak velocity:
  "ART/SPACE" exits the top, "UPCOMING/RELEASES" clips under the Dynamic Island, and the
  stack enlarges toward the viewer as one rigid group. The dot tracks a fixed point in the
  artwork — confirming a continuous transform on a shared surface, not a screen swap. A thin
  gold page-edge stripe shows on the blue book. Motion eases out toward settle.
- **2.5–4.5s (frames 6–10, mid-list fling):** Near-still pre-fling hold (touch puck on the
  blue cover), then a fast momentum flick (slight motion blur). The stack advances about a
  full position: "OPTIC" exits behind the Island, "DAVID CROW" becomes top, "HEY" rises, new
  covers enter from below — a tall pink "HEY / DESIGN & / ILLUSTRATION" and a mustard-yellow
  "DAVID THULSTRUP: A SENSE OF PLACE" that grows into the front slot. Each cover scales up
  as it advances (coverflow/parallax morph). The fling decelerates with ease-out.
- **4.5–7.5s (frames 11–15, deep list, second flick):** Warmer titles surface: maroon
  "DESIGN EMERGENCY", dark-brown "NEW UTILITARIAN" (magenta caps flanked by pink heart
  glyphs), then near-black "THE ECAL MANUAL OF STYLE" rising to the foreground. Velocity
  shows two flicks with inertial settling: large step → smaller → near-frozen dwell
  (ease-out bottom) → renewed large step. Throughout, **scale + opacity are a continuous
  function of vertical position** — front cover full-size/bright, rear covers shrunk/dimmed,
  offset up behind the Island.
- **7.5–8.0s (frame 16, list end):** "THE ECAL MANUAL OF STYLE" dominant in front (colophon
  line legible), "DESIGN EMERGENCY" and "NEW UTILITARIAN" receding above.
- **8.0–9.7s (frames 17–19, loop back to hero):** The surface wraps to the top. The receding
  black slab pins briefly at the top revealing its colophon, then exits while the white
  chapter-title card is uncovered beneath it — "UPCOMING RELEASES" **darkens from light grey
  to bold near-black as it reaches its resting position**. A new crimson book rises from a
  grey concrete-look "OPTIC" shelf slot at the bottom. Frames 18–19 re-establish the original
  staircase — back at the start, ready to scroll again. (Caveat: frames 16↔17 also include a
  mockup-renderer reframe/zoom that is presentation chrome, not in-app motion.)

## Distinct UI states (one surface, not pages)

1. **Hero / chapter-title start state** — editorial title block above the resting staircase
   (frames 1–3, 18–19).
2. **Title-receding zoom state** — title scrolls off while the stack scales toward the
   viewer; touch dot tracks a fixed artwork point (frames 3–6).
3. **Mid-list scroll state** — header gone; depth-stacked carousel with momentum; front
   cover large/bright, rear covers small/dim behind the Island (frames 6–10).
4. **Deep-list scroll state** — same carousel, two flicks with inertial dwell (frames 11–16).
5. **List-end state** — final cover dominant in the front slot (frame 16).
6. **Loop-back / reflow transition** — wrap to top; header settle-darkens; new cover rises
   from the shelf slot (frame 17).

## Component inventory

- **Chapter-title header block** — ghosted large serif display ("ART / SPACE"), tiny
  letterspaced small-caps section label ("CHAPTER 4"), darker serif caps headline
  ("UPCOMING / RELEASES") with a grey→near-black contrast state change on settle.
- **Depth-stacked book-cover carousel (vertical)** — the core component: a single scroll
  surface where each item's scale + opacity + vertical offset is a continuous function of
  scroll position.
- **Book-cover card as physical hardback** — rounded-corner cloth/paper face,
  debossed/tone-on-tone or printed title type, optional author byline, soft contact shadow.
- **Page fore-edge detail** — layered stacked-page texture; thin gold/gilt edge stripe on
  the blue book.
- **Shelf slot / base block** — grey concrete-look anchor ("OPTIC" debossed) from which
  covers rise; the shared emit-anchor for the staircase.
- **Translucent touch/focus dot** — drag puck tracking the active pointer (or a fixed
  artwork point during transforms).
- **Dynamic-Island masking edge** — covers slide behind the Island as they recede off the
  top; acts as a fixed top occluder.
- Books seen (fidelity reference): OPTIC; DAVID CROW; HEY / DESIGN & / ILLUSTRATION (pink);
  DESIGN BY ACCIDENT: FOR A NEW HISTORY OF DESIGN (blue); DAVID THULSTRUP: A SENSE OF PLACE
  (yellow); DESIGN EMERGENCY (maroon); NEW UTILITARIAN (brown, magenta + hearts); THE ECAL
  MANUAL OF STYLE (black).
- **Not app components:** the iPhone-Pro device mockup and taupe surround.

## Motion grammar (named patterns, with implementation notes)

1. **Depth-stack parallax scroll** — the signature. Each card's transform is a pure
   continuous function of its viewport position: frontmost/lowest card ≈1.0 scale, bright,
   detailed; cards above shrink (≈0.75→0.6), dim/desaturate, gain a small upward y-offset to
   fake z-recede. As scroll advances every card interpolates scale+opacity+offset
   simultaneously — no crossfade, no discrete swap. SwiftUI: `ScrollView` with per-card
   `.scrollTransition(.interactive)` (or GeometryReader mapping `midY → scale/opacity/offset`
   + `zIndex`). Cap front scale at 1.0; clamp rear scale/opacity floors.
2. **Grow-to-front promotion** — a card crossing into the front slot scales UP and
   brightens while the displaced card scales DOWN and dims; reads as shared-element
   promotion within one surface. Steeper scale curve near the front; deepen the shadow as
   scale → 1.0 to sell foreground contact.
3. **Recede-and-clip behind the top occluder** — top-exiting cards slide up, shrink, dim,
   and pass behind a fixed top occluder (Island/scrim). Fade the last ~15% of travel.
4. **Slot-emit / staircase fan-up** — on the hero state, covers rise sequentially out of a
   shared bottom shelf anchor and fan into a stepped staircase. Insertion from a fixed
   bottom anchor (`.move(edge: .bottom)` + `.scale`), staggered per item, **driven by scroll
   offset rather than time** so it stays scrubbable; springy but no overshoot.
5. **Coupled scroll+zoom hero settle** — title block translates up and off while the whole
   artwork scales toward the viewer as one rigid group, ease-in-out (barely moves at start,
   peak velocity mid, damps to rest). Anchor the zoom so a chosen point stays fixed.
6. **Inertial flick with dwell** — momentum scrolling that lands softly: large step →
   smaller → near-frozen dwell → renewed flick. Native ScrollView inertia tuned to settle
   with **no bounce/spring overshoot**; back-to-back flicks stack velocity. Touch puck
   appears on finger-down before the fling.
7. **Settle contrast shift** — the headline transitions light-grey → near-black as it
   reaches rest. Animate `foregroundStyle` as a function of distance-to-rest (scroll-driven,
   not a timer).

## Visual language

- **Palette (reference's own):** warm-neutral matte — taupe/greige surround (presentation
  only) and a pure off-white/cream page (~#F2EFE9). All saturated color comes from the book
  covers (crimson, grey, navy, pink, cobalt, mustard, chocolate, near-black). Accents:
  magenta text, tiny heart glyphs, thin gilt page-edge stripe.
  *(The Vimarsha Swift client replaces this canvas with its own 4-color palette — see
  `apple/CLAUDE.md`.)*
- **Typography:** type-forward, high-design. Display = high-contrast Didone-ish serif caps,
  light/regular weight, tight leading, centered; labels = tiny letterspaced small-caps;
  cover titles tone-on-tone debossed so they read as physical print.
- **Radii:** book covers carry only subtle hardback rounding; the in-app UI shows **no
  rounded cards/panels** — content is full-bleed.
- **Depth:** built from scale + opacity + soft diffuse contact shadows, **not blur**.
  Recessed cards scaled-down and dimmed; the front card full-size and bright.
- **Materials:** essentially absent in the reference — no frosted panels; only the
  translucent touch dot and incidental motion blur. (This is the headroom Liquid Glass
  exploits.)
- **Spacing:** generous editorial negative space around the header; dense overlapped imagery
  in the stack; single centered column; calm, gallery-like, low-chrome.

## Liquid Glass elevation opportunities (beyond the reference)

1. **Glass top-scrim dissolve** — make the top occluder a real Liquid Glass capsule that
   refracts the receding cover's color as it slides under; the recede reads as the book
   dissolving into glass rather than hard-clipping.
2. **Lensing drag puck** — replace the flat dot with a small `glassEffect` puck that
   lenses/refracts the cover beneath it — a literal magnifying drop of glass tracking the drag.
3. **Floating glass header plane** — render the chapter-title header on glass that the book
   tower scrolls *under*: passing covers bloom color through and tint the ghosted serif —
   turning the settle contrast shift into continuous material refraction.
4. **`GlassEffectContainer` merge on promotion** — adjacent cards' glass edges meld as they
   scale to the front and split as they recede; grow-to-front feels like one liquid surface.
5. **Glass control cluster from the hero cover** — surface Vimarsha's actual functions
   (Play/Narrate, Figures, Voice note, Discuss) as glass controls that morph out of the
   focused cover, then re-absorb on scroll. Adds the interactivity the reference lacks while
   keeping zero-chrome calm.
6. **Glass-meniscus shelf slot** — covers surface up through a pool of glass at the bottom,
   the glass bulging and settling as each emerges.
7. **Velocity-reactive specular sheen** — gilt edges and debossed type get glass highlights
   that sweep with fast flings.
8. **Figure overlay as glass** (Vimarsha feature, not in reference) — the synced figure
   morphs out of the narrated passage as a floating glass card with depth/refraction, then
   morphs back; extends the single-surface grammar to figures.

## Open questions (TBD — decide during implementation specs)

- **Driven vs scripted:** the clip reads mostly as user flicks (touch puck + inertia), but
  the opening zoom may be scripted/mockup motion. Build interactive scroll first; treat the
  hero zoom as a scroll-driven effect.
- **Loop vs stop at list end:** the clip wraps back to the hero; intentional infinite wrap
  or recording loop? Decide: loop, snap, or stop.
- **Tap-through behavior:** the reference never selects a book. Per the prime directive, a
  selection should morph the hero cover into the reading surface on the same canvas.
- **Hero zoom authenticity:** frames 16↔17 contain a mockup-renderer reframe; don't copy
  that literally.
- **Literal 3D vs 2.5D:** analysts saw both; we standardize on 2.5D (scale+offset+shadow) —
  see `apple/CLAUDE.md` §Physical book rendering.
- **Cover art source:** reference covers are bespoke; Vimarsha maps real EPUB cover art onto
  the hardback template (user decision).
- **Settle contrast shift:** intended emphasis cue or artifact? We adopt it as a deliberate
  scroll-driven settle state.
