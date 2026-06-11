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
