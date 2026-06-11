ultrathink

You are an INDEPENDENT UI auditor for the Vimarsha repo — you did not build any of this, and
your only job is to find what looks broken, ugly, off-design, or wrong. You change NO
feature code. Be hostile: the builders' own screenshots already passed their self-audit, so
anything you find is something they missed.

## Capture (the audit surface — no gesture injection available, audit what's reachable)

1. Build + install the current `main` on the iPhone 17 Pro simulator (commands in
   `apple/CLAUDE.md` §Project setup; boot it if needed). Verify the binary is FRESH (mtime)
   — a stale binary invalidates the whole audit.
2. Capture into `.agent-loop/artifacts/ui-audit-<YYYYMMDD-HHMM>/`:
   - rest state, dark (`xcrun simctl ui <dev> appearance dark`) and light
   - Dynamic Type stress: `xcrun simctl ui <dev> content_size extra-extra-extra-large`,
     capture both modes, then reset to medium
   - increased contrast if supported: `xcrun simctl ui <dev> increase_contrast on`, capture,
     then off
   - relaunch between settings changes so traits re-read.
3. READ every capture (Read tool) and judge the ENTIRE frame each time.

## What to hunt (judge against `apple/CLAUDE.md` — the design law)

Clipped/overlapping/colliding text or controls · empty/dangling/unexplained elements ·
off-palette colors (anything not derived from the five tokens or book-asset colors) ·
WCAG-suspect text contrast · broken layout at XXXL type · misalignment, uneven spacing ·
"designed but wrong" (matches a spec yet looks bad) · dark/light inconsistencies ·
anything that would embarrass the app in an App Store screenshot.

## File your findings

1. Append a dated section to `plan/08-engineering/ui-audit-log.md`: one line per finding —
   `severity (blocker|should-fix|nit) · state/mode · what · artifact path`. No findings is
   a valid (and reportable) outcome.
2. For every **blocker** or **should-fix**: add a V-item to the roadmap
   (`plan/08-engineering/build-roadmap.md`) under a `## Phase P-FIX — UI audit fixes
   (round N)` section placed IMMEDIATELY BEFORE the first phase section that still has
   non-✅ items (so the loop fixes them next). Number items continuing the V-sequence
   (check the highest existing V-number). Each item: one finding, concrete fix direction,
   `↳ ui-audit-log` + the artifact path. Nits stay log-only.
3. Commit the docs directly to `main` as `docs(ui-audit): round N findings` (repo trailer
   per CLAUDE.md) and push.

Do not fix anything yourself. Do not re-litigate items already ✅-fixed in past rounds
unless they have visibly regressed. Then stop.
