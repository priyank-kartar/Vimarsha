# Spec: Apple client scaffold — static library depth-stack (2026-06-11)

The first Swift milestone of the `apple/` client (see `apple/CLAUDE.md` for the design
language this implements). Goal: the signature **depth-stack parallax scroll** rendering on
iOS 26 + macOS 26 with static data — no backend wiring yet.

## Decisions (user, 2026-06-11)

- **Cover art is client-side.** The Swift client extracts/renders covers itself; the
  backend contract stays untouched. (Resolves the open question in `apple/CLAUDE.md`.)
- **Static data first:** book "assets" are generated client-side from a static seed list
  (title / author / cloth color) — the generated cloth-bound hardback design from
  `apple/CLAUDE.md` §Physical book rendering. Real EPUB cover extraction comes with the
  library/`/toc` wiring in a later plan.
- **Start rendering now:** scaffold the Xcode project and get the stack moving.

## Scope

1. `apple/Vimarsha.xcodeproj` — SwiftUI multiplatform app (iOS 26 + macOS 26), target
   `Vimarsha`, bundle id `com.vimarsha.apple`, tests target `VimarshaTests` (Swift Testing),
   shared scheme; layout per `apple/CLAUDE.md` §Project setup.
2. `Design/Palette.swift` — the canonical tokens (only place hexes live), light/dark
   semantic colors, dark-first.
3. `Library/BookSeed.swift` — static shelf of 8 books (the reference video's books) with
   cloth/ink colors as stand-in cover assets.
4. `Library/HardbackCoverView.swift` — generated physical hardback: cloth face, debossed
   tone-on-tone serif title, fore-edge page stack, optional gilt stripe.
5. `Library/StackTransform.swift` — the depth-stack math (motion grammar #1) as a **pure
   function** `midY → {scale, opacity, yOffset}` with clamped floors. Unit-tested.
6. `Library/LibraryStackView.swift` — editorial serif header (ghost title / small-caps
   label / headline) scrolling into the depth-stacked tower; overlap via negative spacing
   (document order gives front-card-on-top); transforms applied with `visualEffect`
   (no layout thrash); glass top-scrim capsule (`glassEffect`, moment #1, subtle);
   Reduce Motion → flat full-size list fallback.

## Acceptance

- `xcodebuild … test` green on iOS simulator and macOS destinations.
- App launches on both; stack scrolls with depth (scale/opacity/tuck as a continuous
  function of position), front card overlapping on top; header scrolls away like the
  reference; dark-first canvas (`ink`), light mode on `butter`.
- Screenshot captured from the iOS simulator for the motion-review record.

## Out of scope

Backend wiring, real EPUB covers, book focus / control cluster, reading surface, the other
glass moments, slot-emit loop. Each is a later plan per `apple/CLAUDE.md` §UI map.
