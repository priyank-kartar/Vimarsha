# Handoff — Discuss hang FIXED; return-from-Discuss state-reset (OPEN)

> **Date:** 2026-06-29 · **Status:** the device freeze is FIXED & on `main`; a UI polish
> regression on RETURN from Discuss is open. **Branch:** `main` (all pushed).

## TL;DR

The Discuss-panel **100% CPU watchdog freeze** (`0x8BADF00D`) is **fixed and device-confirmed**
(see [ADR-012](../../plan/00-overview/decision-log.md) + spec
`docs/superpowers/specs/2026-06-28-vimarsha-single-live-surface-design.md`). The fix:
**single live surface** — while Discuss is up, render NOTHING live behind the `.sheet` (the root
shows a flat `Palette.canvas`; the reading surface unmounts).

**What's left (this handoff):** because the fix UNMOUNTS the library + reading surface while
Discuss is up, they **rebuild on return**, and the rebuild has rough edges:
- the library's focus / scroll / depth-stack scaling reset (focus is re-pinned via
  `coordinator.libraryFocusIndex`, but scroll/scaling are not restored);
- the reading surface jumps / the transport can flash missing;
- a transient safe-area-0 read could ride VIMARSHA under the notch (now guarded).
Two low-risk mitigations shipped (`fcf6458`): safe-area-0 guard + reading scroll-restore via
`.task`. The deeper scroll/scaling restoration is NOT done.

## Why the surfaces have to rebuild (the key constraint — don't relearn this)

The freeze is a **device-only, non-converging SwiftUI layout loop** that fires when the keyboard
presents over a SECOND live, complex surface behind Discuss. It is NOT just text or glass:
**keeping the paging library mounted behind Discuss re-freezes even with ALL its text gated and
ALL its glass matted** (verified on device 2026-06-29 — the loop is the library's *layout itself*:
`GeometryReader` + negative-spacing depth-stack VStack + `containerRelativeFrame` in the paging
ScrollView, re-measured under the keyboard's window layout passes). So the ONLY thing that
reliably stops the loop is removing the heavy second surface from the live tree → it must unmount
→ it rebuilds on return. That is the whole tension.

Crash signatures relocated with every partial fix (the tell it was compositional, not one
element): `ReadingSurfaceView: @self changed ×7656` → `GlassEffectShapeSet` (Liquid Glass) →
`Text.resolve…`/`ResolvedTextFilter` (text) → (keep-mounted) the layout loop again.

## Dead ends — do NOT retry these

1. **Keep the library mounted behind Discuss + gate its text/glass.** Re-freezes (the layout
   loops, not the content). Tried fully (header + hidden placeholder + Sci-Lit text gated, all
   glass matted) — still froze. Reverted.
2. **In-canvas Discuss plane (no `.sheet`) with native keyboard avoidance.** Never converged —
   each attempt relocated the loop (glass → text). The `.sheet` is the pragmatic working
   presentation (ADR-012 defers the Prime-Directive in-canvas morph).
3. **Manual keyboard padding** (`.padding(.bottom, keyboardHeight)`) — fed the iOS
   "move-focused-field → keyboard re-reports frame" loop.
4. **Trusting the simulator / the `panel`-mode harness.** The freeze is DEVICE-ONLY; the sim and
   the nil-wired harness never reproduce it. Only the real app on device does.

## Recommended next approach for the return-state (start here)

The durable fix is to make the **rebuild seamless by owning the surfaces' view-state in the
coordinator**, not in the views (so a remount restores it):
1. **Library scroll** → the real cause of the "scaling messed up / stretches up-down" (the
   depth-stack scale derives from scroll; a fresh remount is at scroll 0). Lift the scroll offset
   into `SurfaceCoordinator` and restore it on the library's remount (iOS 18 `ScrollPosition` /
   `.scrollPosition`). `LibraryStackView` already tracks the offset via `onScrollGeometryChange`
   (→ `distanceToRest`); persist + restore it. Risk: it's a finely-tuned scroll (heroSettle +
   depth-stack) — change carefully.
2. **Reading transport "missing"** — verify whether it's a real miss or a remount flash;
   `transportOverlay` is gated only on `player.bundle != nil` (always true), so it *should*
   render. If it's a flash, smoothing the canvas→library swap (don't swap mid-keyboard-dismiss)
   may be enough.
3. Consider **delaying the `activeSurface` .discuss→.reading change** until the sheet + keyboard
   have fully dismissed, so the rebuild happens in the final (stable) window geometry rather than
   mid-animation (much of the "header too high / stretch" is the rebuild measuring a transient
   container size).

## Device gate / diagnostics (how to verify on device — reuse this)

- Build+run on the connected iPhone: `xcodebuild -scheme Vimarsha -destination 'platform=iOS,id=00008150-000E03A93C46401C' -allowProvisioningUpdates build`, then
  `xcrun devicectl device install app --device <UDID> <App>` +
  `xcrun devicectl device process launch --console --terminate-existing --device <UDID> com.vimarshaa.apple`.
- The `--console` session captures the app's stdout — the `_printChanges` flood (DIAG was removed,
  re-add `let _ = Self._printChanges()` to a body to re-enable) and "App terminated due to
  signal 9". Plain `print` does NOT reach `idevicesyslog`.
- Watchdog crash report: Xcode → Window → Devices and Simulators → View Device Logs → newest
  Vimarsha entry → Thread 0 names the stuck frame. This is what cracked it each time.
- DEBUG repro harness: `apple/Vimarsha/Debug/DiscussLoopRepro.swift`
  (`-VimarshaDiscussLoopRepro 1 -VimarshaReproMode panel|panelWired|surface`). `panel` (nil wiring)
  is device-stable; it does NOT reproduce the real loop (needs the real composition).

## Key files

- `apple/Vimarsha/VimarshaApp.swift` — `mainScene` (canvas while `.discuss`, else `pagingLibrary`),
  the Discuss `.sheet`, `refreshSafeAreaInsets` (now 0-guarded).
- `apple/Vimarsha/Surface/` — `Surface`, `SurfaceCoordinator` (+ `libraryFocusIndex`), `BookSession`.
- `apple/Vimarsha/Library/LibraryStackView.swift` — the library; `readingSurface` (Color.clear
  while `.discuss`), `openDiscussPanel`, the focus save/restore (`onChange(activeSurface)`).
- `apple/Vimarsha/Reading/ReadingSurfaceView.swift` — Discuss button → `onOpenDiscuss`; scroll
  restore is now a `.task` (line ~335).
- `apple/Vimarsha/Discuss/DiscussPanelView.swift` — the panel (matte mic, single-line field).

## Other open items (unrelated to the hang)

- Backend TTS needs `cd backend && uv sync --extra tts` (or `--extra kokoro`) for `/speak`.
- arXiv paper narration (Phase 2c) specced+planned, client unbuilt — `backend/src/vimarsha/arxiv_ingest.py`,
  `math_speech.py`; specs/plans dated 2026-06-27/28; adds the repo's first SPM dep (SwiftMath).
- Pre-existing flaky snapshot `HardbackCoverDodgeSnapshotTests/dodgeClearsTheBand()` (render-sensitive,
  not from this work — proven identical on the pre-work commit).
