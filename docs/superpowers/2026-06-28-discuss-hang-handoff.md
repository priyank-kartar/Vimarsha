# Handoff — Discuss panel 100% CPU hang (UNRESOLVED)

> **Date:** 2026-06-28 · **Status:** NOT FIXED — paused for a fresh session.
> **Branch:** `main` (all work pushed). Symptom still reproduces on device.

## TL;DR

Opening the **Discuss** (AI chat) panel on a real iPhone (iPhone 17, iOS 26.5.1) pins the
**main thread at 100% CPU forever** → the app freezes / the watchdog kills it
(`EXC_CRASH / 0x8BADF00D "failed to terminate gracefully"`). It is a **SwiftUI AttributeGraph
render loop**, not a logic crash.

`Self._printChanges()` instrumentation (still in the code — see "Cleanup owed") proved the
**root cause is upstream in the library**, not in Discuss:

```
LibraryStackView: … _focus, _cardTops, _cardVisualTops … changed.
BookTower: @self changed.
LibraryStackView: _cardVisualTops changed.
BookTower: @self changed.
…forever (runs whenever the book tower is on screen)
```

A **floating-point preference-jitter feedback loop** in the depth-stack motion system. The
last fix (commit `20d1d80`, quantizing the published geometry to whole points) is the textbook
remedy for this signature but **was not confirmed working** before we paused. **Start the next
session by checking whether `20d1d80` settled it** (rebuild, watch the console at rest on the
library screen — the flood should stop when not scrolling).

## How to reproduce

1. Backend NOT required for the hang (it's pure client). But to get into the reading surface you
   need a **narrated chapter** cached on device (the bundled "Stolen Focus" book, one chapter
   narrated). Note: backend TTS is currently broken (see "Other known issues"), so narrating new
   content needs the venv fixed first.
2. Open a chapter → reading surface → tap the **chat-bubble button** (left of the transport) →
   Discuss opens → CPU pins at 100%, UI frozen.
3. Run from Xcode to see the `_printChanges` flood in the console; or Instruments → Time
   Profiler shows `AG::Graph::UpdateStack::update()` ~77% with `ForEachChild.updateValue`.

## The diagnosis (what we KNOW, with evidence)

- **It's a render loop / watchdog hang**, not an exception. Device crash report:
  `EXC_CRASH (SIGKILL)`, `0x8BADF00D`, "Failed to terminate gracefully after 5.0s", top of
  Thread 0 = `View.contextMenu(menuItems:)` → `BookTower.body` → `ForEachChild.updateValue()`.
- **Time Profiler** (during the spin): 77% in `AG::Graph::UpdateStack::update()`; leaves were
  `ReadingBlocksView.textRow → .accessibilityAction(named:) → AccessibilityProperties.init`
  (red herring — only ~2.4%; the dominant cost is the AttributeGraph cycle itself).
- **`_printChanges` (the breakthrough):** two interlocking loops:
  1. **EARLY / fundamental (reading == nil):** `LibraryStackView (_focus, _cardTops,
     _cardVisualTops) ⇄ BookTower` — never settles. This runs whenever the library tower is on
     screen. **This is the real root.**
  2. **LATE (reading != nil, Discuss open):** `BookTower ⇄ ReadingSurfaceView`, then after we
     stopped rendering BookTower while reading, `ReadingSurfaceView: @self changed` alone.
     Downstream of (1).
- **Mechanism (hypothesis, strongly supported):** each card publishes raw sub-pixel
  `frame.midY` / `frame.minY` / `CardVisualTop` via a `.background { GeometryReader { … } }`
  (`LibraryStackView.swift` ~line 1138). `onPreferenceChange` writes `focus`/`cardTops`/
  `cardVisualTops` (@State) → LibraryStackView re-renders → BookTower re-renders → republishes a
  **slightly different float** (sub-pixel jitter, and `CardVisualTopKey` also depends on
  `focus.promotion`) → `onPreferenceChange` fires again → infinite. `CardVisualTop.at(...,
  promotion: focus.promotion)` closes a focus→preference→focus dependency on the focused card.

## What was tried (commits, newest first) and the effect

All on `main`. Many are legitimate fixes for *real, separate* bugs found along the way; the core
hang persists.

| Commit | What | Result |
|---|---|---|
| `20d1d80` | **Quantize** published card geometry (`.rounded()`) — kill the jitter loop | **UNVERIFIED — check this first** |
| `a566b66` | Don't render `BookTower` while `reading != nil` | Removed BookTower from the late loop; library early-loop persists |
| `b54d2a1` | Remove cover-morph `matchedGeometryEffect` (both sides) | Did NOT stop the loop; **aesthetic regression** (cover→reading is now a cross-dissolve, no fly) |
| `e016f66` | **DIAG**: `_printChanges` on 4 bodies | Diagnostic — must be reverted |
| `87225f3` | Don't render chapter body behind the (opaque) Discuss sheet | Trimmed cost, didn't fix |
| `3c92864` | Drop glass plane in Discuss + defer `inputFocused` 450ms | Didn't fix; **Discuss panel is now matte, no glass** |
| `a003363` | Solid Discuss sheet background | Didn't fix |
| `c05d662` | **Present Discuss as a `.sheet`** (was in-canvas overlay) | Didn't fix the spin, but cleaner isolation; **changed the design** (see below) |
| `1c0b108` | Dedicated **AI-chat button** left of transport; drop the record double-tap | Good — keep (the double-tap gesture was unreliable) |
| `776d673` | Remove per-card `.contextMenu` in BookTower | Fixed the *original* watchdog crash signature; keep |
| `d49f2cf` | Lock section paging while a surface covers the library | Good — keep (fixes swipe-leak to Scientific Literature) |
| `a17ccf3` | Freeze library geometry observers + `ignoresSafeArea(.keyboard)` while covered | Good — keep |
| `d6255fe` | Don't auto-pop keyboard on Discuss open (later re-enabled, deferred) | superseded |
| `56bd428` / earlier | Gate focus affordances; safe-area + crash gates | Good — keep |

## Design/aesthetic regressions introduced as stopgaps (revisit after the fix)

These were taken to chase the hang and should be reconsidered once it's actually fixed:
1. **Discuss is now a `.sheet`** (commit `c05d662`), not the in-canvas morph the spec/`apple/CLAUDE.md`
   Prime Directive calls for. Revisit once the surfaces can be guaranteed non-simultaneous.
2. **Cover→reading `matchedGeometryEffect` removed** (`b54d2a1`) — the signature cover-fly morph
   is now a cross-dissolve. `morphNamespace`/`coverMorph` are now dead params.
3. **Discuss panel glass dropped** (`3c92864`) — matte plane now.
4. **BookTower not rendered while reading** (`a566b66`) — fine functionally (occluded), but it's a
   blunt instrument; the cover-morph can't return until this is reconsidered.

## Cleanup owed (do this once the hang is confirmed fixed)

- **Revert the `_printChanges` diagnostics** (commit `e016f66`): four `let _ = Self._printChanges()`
  lines in `ReadingSurfaceView.body`, `DiscussPanelView.body`, `ReadingBlocksView.body`,
  `BookTower.body` (the `// DIAG` comments). Note: ReadingSurfaceView/ReadingBlocksView use
  `let _ = …; return …` — restore the implicit-return bodies.
- Decide which stopgaps above to keep vs. revert.

## Recommended next steps (in order)

1. **Verify `20d1d80`** (quantization). Rebuild, run from Xcode, sit on the **library screen at
   rest** — does the `_focus/_cardTops/_cardVisualTops` + `BookTower` flood stop? If yes, the
   loop is beaten; test Discuss; then do the cleanup above.
2. **If still looping**, the jitter isn't the whole story — likely `CardVisualTopKey` depends on
   `focus.promotion` (a focus→preference→focus cycle). Options:
   - Make `CardVisualTopKey` **independent of `focus.promotion`** (publish the promotion-0 visual
     top; the focused card's dodge can derive promotion separately without feeding the preference).
   - Or **break the consumer→publisher coupling**: don't let `debossDodge` / `focus` recompute
     from values that the focused card's own render perturbs. The V37 (`FocusAffordancePlacement`)
     and V45 (`DebossDodge`) features are the consumers — consider disabling V45 deboss-dodge as a
     test (pass `debossDodge: nil`) to confirm it's the closing edge.
   - Or quantize/threshold in the **consumers** (`onPreferenceChange`) too, and round
     `distanceToRest` (feeds `heroSettle`) and the `.global` publishers (`clusterGlobalFrame`,
     `scrollOriginGlobalY`).
3. Consider whether the **`onScrollGeometryChange`/`onGeometryChange` + preference** architecture
   in `LibraryStackView` is fundamentally too feedback-prone (it's a lot of interacting geometry
   state). A more isolated/idempotent measurement approach may be warranted — this is the deeper
   "question the architecture" item.

## Key files

- `apple/Vimarsha/Library/LibraryStackView.swift` — the library; the loop lives here. Publishers
  ~line 1138 (now quantized); consumers `onPreferenceChange(CardMidYKey/CardTopYKey/
  CardVisualTopKey)`; `focus`/`debossDodge`/`cardVisualTops`; `BookTower` struct (~line 1040).
- `apple/Vimarsha/Reading/ReadingSurfaceView.swift` — reading surface; Discuss `.sheet` presentation
  (~line 560 `coverPlate`, the sheet block); chapter-body gate on `showDiscuss`.
- `apple/Vimarsha/Discuss/DiscussPanelView.swift` — the panel (matte now; deferred focus).
- `apple/Vimarsha/Reading/ReadingBlocksView.swift` — per-row `.accessibilityAction` (a perf hazard
  on long chapters even when not looping — worth optimizing separately).

## Other known issues (separate from the hang)

- **Backend narration broken:** the backend venv lost its TTS engine — `torch`/`chatterbox`/
  `kokoro` all missing, so `/speak` 500s and local narration/transcription/spoken-replies fail.
  Fix: `cd backend && uv sync --extra tts` (Chatterbox) or `--extra kokoro` (lighter) + restart.
  Needed before live Discuss replies or narrating new chapters/papers.
- **arXiv paper narration (Phase 2c)** is specced + planned but NOT built:
  `docs/superpowers/specs/2026-06-28-vimarsha-arxiv-paper-narration-design.md` and
  `docs/superpowers/plans/2026-06-28-vimarsha-arxiv-paper-narration.md`. Setup wrinkle: it adds the
  repo's first SPM dependency (SwiftMath) — add via Xcode once.
- **Math-to-speech (Phase 2b) shipped** earlier this session (backend, merged to `main`, 115
  tests green) — unrelated to the hang.
- Pre-existing failing snapshot test `HardbackCoverDodgeSnapshotTests/dodgeClearsTheBand()`
  (render-sensitive; not caused by this work).

## Device / tooling notes for next session

- Test device: **Sachmeet's iPhone 17**, iOS 26.5.1, connected. Bundle id `com.vimarshaa.apple`.
- Crash reports: Xcode → **Window → Devices and Simulators → View Device Logs** (this gave the
  watchdog report). Live syslog: `idevicesyslog` (Homebrew) works; `log stream --device` does NOT.
- A pure foreground freeze writes **no crash log** — use **Instruments → Time Profiler** or the
  `_printChanges` console flood (already wired) to diagnose.
- Build/run: see `apple/CLAUDE.md §Project setup`. SourceKit "Cannot find type" diagnostics in
  this folder-synchronized project are spurious — trust `xcodebuild`.
