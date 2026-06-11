# UI Audit Log

> **Status:** Living · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). Findings from the **independent UI-audit
> agent** that runs every few loop iterations (`scripts/agent-loop/ui-audit-prompt.md`) —
> fresh eyes hunting broken/ugly/off-design UI across appearance modes and Dynamic Type
> stress. Blocker/should-fix findings become `P-FIX` V-items in the
> [build-roadmap](build-roadmap.md); nits live here only. Builders' own per-item
> whole-screen audits live in their [_progress-A](_progress-A.md) entries.

Format per finding: `severity · state/mode · what · artifact`

---

## Pre-log findings (carried from monitoring, 2026-06-11)

- should-fix · chapter plane, dark · the "blocked/unavailable" chapter-status icon is a hard
  orange/yellow square — off-palette next to the sky/aqua status set; needs a token-derived
  treatment · `.agent-loop/artifacts/V14/08-chapters-lifecycle.png`
- nit · focus state · metadata reveal can ghost over neighbor covers in mid-scroll states
  (seen across V22–V27 captures); watch whether V24's anchoring fully killed it in motion ·
  `.agent-loop/artifacts/V24/02-cluster-emerged-live.png`

## Round 1 — 2026-06-11 (independent audit; fresh `main` build 17:31, iPhone 17 Pro sim, rest state only — no gesture injection)

- blocker · library rest · dark + light, all type sizes · the focused book's **metadata
  reveal (white serif title + letterspaced subtitle) straddles the cover seam and renders ON
  the neighbor cover above**, text-on-text with that cover's own debossed type — at medium,
  "Design by Accident" sits across the pink HEY card; at XXXL, "Hey" renders directly over
  "DAVID CROW" and "DESIGN & ILLUSTRATION" over "VISIBLE SIGNS". This is the pre-log
  "mid-scroll ghosting" nit, but it is present **at launch rest** → upgraded ·
  `.agent-loop/artifacts/ui-audit-20260611-1731/01-rest-dark.png`,
  `crop-dark-mid.png`, `crop-xxxl-dark-cluster.png`
- should-fix · library rest · light esp. · metadata reveal is **bare white text over
  arbitrary cover colors** — white on the pink HEY cover is ≈2:1, a WCAG fail in both modes
  (worst on the butter canvas in light); it needs a backing plate (sky-tinted glass or
  token-ink) instead of relying on whatever cover is behind it ·
  `.agent-loop/artifacts/ui-audit-20260611-1731/crop-light-mid.png`, `04-xxxl-light.png`
- should-fix · library rest, medium type · both modes · a **residual ghost of the glass
  control cluster** (tiny icon pill, ~20 px) floats dead-center on the focused cover at
  promotion≈0 — an unexplained dangling element between the cover title's two lines ·
  `.agent-loop/artifacts/ui-audit-20260611-1731/crop-dark-mid.png` (blob mid-card),
  `05-contrast-dark.png`
- should-fix · book focus (XXXL rest) · both modes · the **control cluster glass reads
  untinted grey** — monochrome dark-grey icons in a grey pill on the pink cover, no
  sky/aqua tint evident in either mode; violates the Liquid Glass rule "tint glass with
  sky (interactive) or aqua (live); avoid untinted grey glass" ·
  `.agent-loop/artifacts/ui-audit-20260611-1731/crop-xxxl-dark-cluster.png`,
  `crop-xxxl-light-cluster.png`
- should-fix · library rest · both modes · **double title / V24 title-fade not engaged at
  rest**: the focused cover's debossed title+subtitle stay full strength while the same
  strings render again in the metadata reveal ~150 px away ("FOR A NEW HISTORY OF DESIGN"
  appears twice at medium; at XXXL the cluster pill sits directly over the un-faded
  debossed "HEY") ·
  `.agent-loop/artifacts/ui-audit-20260611-1731/crop-dark-mid.png`,
  `crop-xxxl-dark-cluster.png`
- nit · library rest · both modes · the bottom shelf cover clips its author line mid-glyph
  at the hard screen edge ("DAVID THULSTRUP" half-cut) — no meniscus/fade treatment at the
  shelf slot, reads as accidental cropping ·
  `.agent-loop/artifacts/ui-audit-20260611-1731/01-rest-dark.png` (bottom edge)
- nit · increased contrast · dark · Increase Contrast produces no visible adaptation — the
  frame is pixel-equivalent to normal dark, including the failing white-on-pink metadata
  text; revisit when more glass surfaces are reachable ·
  `.agent-loop/artifacts/ui-audit-20260611-1731/05-contrast-dark.png`

## Round 2 — 2026-06-11 (independent audit; fresh `main` build 18:49, iPhone 17 Pro sim, rest state only — no gesture injection)

Round-1 fixes **hold at medium rest**: no seam collision (V37), glass plate present (V38),
no ghost pill (V39), single title (V41). The round-2 findings are new or composed defects.

- should-fix · library rest, XXXL · both modes · the **focused book is completely unlabeled**:
  the V37 metadata-yield drops the title band AND the V41 deboss-fade blanks the cover's own
  printed title, so the focused pink card is an empty slab with an anonymous icon pill —
  while the *unfocused* blue neighbor below shows its full-strength debossed "DESIGN BY
  ACCIDENT", which reads as the focus label. Not a V37/V41 regression — each behaves exactly
  as merged; their **composition** is the defect. When metadata yields, the deboss title must
  stay (it IS the label) ·
  `.agent-loop/artifacts/ui-audit-20260611-1849/crop-xxxl-dark-affordances.png`,
  `crop-xxxl-light-affordances.png`, `03-xxxl-light.png`, `04-xxxl-dark.png`
- should-fix · library rest, medium · both modes (measured) · **metadata-reveal text fails
  WCAG on the blue cover**: the V38 sky-glass plate blooms the cover's blue and the fixed
  text roles don't adapt — light mode title ≈1.65:1, subtitle ≈1.44:1 (ink-on-blue glass);
  dark mode title ≈2.6:1, subtitle ≈2.0:1 (off-white-on-blue glass). All below AA (3:1
  large / 4.5:1 small). V38 fixed pink; blue (and any mid-luminance cover) still fails —
  the plate needs enough opacity (or per-plate-luminance text) to *guarantee* the ratio ·
  `.agent-loop/artifacts/ui-audit-20260611-1849/crop-light-band.png`, `crop-dark-band.png`
- should-fix · library rest, XXXL · both modes · the blue cover's debossed subtitle bottom
  line **"OF DESIGN" clips into the cover's bottom edge** — glyph bottoms ride/cut into the
  fore-edge page-texture lines (dark) or sit flush against the edge (light); the deboss block
  isn't vertically fitted to the cover face at XXXL ·
  `.agent-loop/artifacts/ui-audit-20260611-1849/crop-xxxl-dark-seam.png`,
  `crop-xxxl-light-seam.png`
- nit · library rest, XXXL · both modes · bottom shelf cover clips its title mid-glyph at the
  hard screen edge ("OF PLACE" half-cut) — round-1's shelf-edge nit, now the title line at
  XXXL; still no meniscus/fade treatment at the shelf slot ·
  `.agent-loop/artifacts/ui-audit-20260611-1849/crop-xxxl-dark-shelf.png`
- nit · increased contrast · dark · unchanged from round 1 — `increase_contrast enabled`
  produces a frame pixel-equivalent to normal dark; carry-over, not re-filed ·
  `.agent-loop/artifacts/ui-audit-20260611-1849/05-contrast-dark.png` vs
  `06-rest-dark-medium.png`

## Round 3 — 2026-06-11 (independent audit; fresh `main` build 20:28, iPhone 17 Pro sim, rest state only — no gesture injection)

Round-1/2 fixes **hold**: medium rest is clean in both modes (no seam collision, no ghost
pill, single title, band contrast reads strong — V37–V39/V41/V43), V42's deboss label is
present at XXXL, V44's bottom inset keeps "OF DESIGN" off the cover's bottom edge. The
round-3 findings are all XXXL-rest composition defects on/around the focused card.

- should-fix · library rest, XXXL · both modes · the **control cluster renders directly on
  the focused cover's debossed text**: the glass pill row sits across the subtitle —
  "DESIGN &" reads through the glass between/behind the icons, "HEY" is partially behind
  the pill's upper bulges, "ILLUSTRATION" runs under its lower edge. V42 restored the
  deboss as the focus label, but the cluster still emerges at rest over that exact spot —
  controls-on-text collision at launch. (Visible in V42's own pass artifact
  `.agent-loop/artifacts/V42/01-xxxl-dark.png` — missed, not regressed.) ·
  `.agent-loop/artifacts/ui-audit-20260611-2028/crop-xxxl-dark-cluster.png`,
  `crop-xxxl-light-cluster.png`, `03-xxxl-light.png`, `04-xxxl-dark.png`
- should-fix · library rest, XXXL · both modes · the **cluster glass is frozen mid-meld**:
  the four control circles render half-merged into a lumpy scalloped blob — neither the
  discrete full-emergence circles (V40's `artifacts/V40/crop-emerged-dark.png`) nor a clean
  capsule. At rest the cluster sits between its visibility floor and full emergence and
  freezes in the in-between `GlassEffectContainer` merge shape; a static rest state should
  resolve to a terminal form, mid-meld shapes are for in-motion frames ·
  `.agent-loop/artifacts/ui-audit-20260611-2028/crop-xxxl-dark-cluster.png`,
  `crop-xxxl-light-cluster.png`
- should-fix · library rest, XXXL · dark (clear), light (faint) · the unfocused blue
  cover's **deboss title collides with the focused card's overhanging fore-edge strip**:
  the pink card's page-stack lines (which hang below its cover edge, over the card behind)
  run straight through the top serifs of "DESIGN BY". V44 inset the deboss block from the
  cover's *bottom* edge only; at XXXL the block now reaches the *top* overlap zone ·
  `.agent-loop/artifacts/ui-audit-20260611-2028/crop-xxxl-dark-bluetop.png`,
  `crop-xxxl-light-bluetop.png`
- nit · library rest, XXXL · both modes · carry-over (rounds 1–2): bottom shelf cover still
  clips "OF PLACE" mid-glyph at the hard screen edge; no meniscus/fade treatment yet ·
  `.agent-loop/artifacts/ui-audit-20260611-2028/crop-xxxl-dark-shelf.png`
- nit · increased contrast · dark · carry-over (rounds 1–2), this round measured: the
  Increase Contrast frame differs from normal dark by at most 20/255 per pixel
  (anti-aliasing jitter only — no adaptation) ·
  `.agent-loop/artifacts/ui-audit-20260611-2028/diff-contrast-amplified.png`,
  `05-contrast-dark.png` vs `06-rest-dark-medium.png`
