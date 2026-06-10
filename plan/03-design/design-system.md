# Design System — Pointer + Gaps

> **Status:** Living · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md).

**The canonical design system lives in [`apple/CLAUDE.md`](../../apple/CLAUDE.md)** —
palette tokens (+WCAG text rules), typography (New York display / SF body, Dynamic Type),
Liquid Glass usage rules and the eight named glass moments, physical book rendering, and
the motion grammar. Code: `apple/Vimarsha/Design/Palette.swift` (the ONLY place hexes live).

This doc tracks **gaps and additions** as they surface, so the canon stays curated rather
than accreted. Add a row when you notice a missing primitive; move it out when it lands in
the canon + code.

| Gap / addition | Needed by | Notes | Status |
|---|---|---|---|
| Exact palette hexes confirmation | any visual polish pass | current values are sampled estimates from the palette image; correcting them is a one-line `Palette.swift` change | open |
| Pressed/disabled states for glass controls | V07 control cluster | glass interactive states beyond default (pressed tint? sheen?) undefined | open |
| Chapter-status iconography (pending/ready/error) | V14 | needs a paper-not-glass treatment consistent with principle 2 | open |
| Reading-surface type scale (body serif?, measure, leading) | V18 | apple/CLAUDE.md defers reading body font to the reading-view spec | open |
| Waveform/recording visual language | P4 memos | aqua "live" glow is named in the palette roles; the actual component is undesigned | open |
| App icon | P10 ship | unexplored (SPEKO icons in Downloads belong to the *other* project) | open |
