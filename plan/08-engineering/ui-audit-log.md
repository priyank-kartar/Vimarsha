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
