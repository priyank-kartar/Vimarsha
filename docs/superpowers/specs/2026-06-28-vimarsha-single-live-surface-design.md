# Vimarsha — Single Live Surface (surface-composition restructure)

_Design spec · 2026-06-28 · branch `refactor/single-live-surface`_

## 1. Problem

Opening the **Discuss** panel on the native iPhone client pins the main thread at 100% CPU
and the watchdog kills the app (`EXC_CRASH / 0x8BADF00D`). It is a SwiftUI AttributeGraph
render loop, not a logic crash. It has survived **14+ targeted fixes** (drop glass → matte,
overlay → `.sheet`, defer focus, blank the body, remove `matchedGeometryEffect`, quantize
geometry).

### Root cause (proven on device, 2026-06-28)

The hang is a **pure `ReadingSurfaceView` self-re-render loop**, triggered the instant the
Discuss `.sheet` opens. Captured live on the iPhone 17 (iOS 26.5.1) via `devicectl --console`:

```
LibraryStackView: _chapterBook, _reading changed     ← open the chapter
ReadingSurfaceView: _showDiscuss changed             ← tap Discuss
DiscussPanelView: @self … changed                    ← panel renders ONCE
ReadingSurfaceView: @self changed.   ×7,656          ← then this, tight, forever
App terminated due to signal 9                        ← watchdog kill
```

7,656 consecutive `ReadingSurfaceView: @self changed` with **nothing interleaved** — no
parent, no panel, no library. In the Observation framework that signature means **an
`@Observable` object the view's body reads is being mutated in a tight synchronous loop**
while the body keeps re-reading it.

### Why every prior fix failed

The loop is **device-only** — it does **not** reproduce in the iOS 26 simulator (real
audio-session route/interruption events and real Metal/Liquid-Glass rendering differ from the
simulator). A reproduction harness (committed: `apple/Vimarsha/Debug/DiscussLoopRepro.swift`)
measured this across four configurations:

| Config | Sim | Device |
|---|---|---|
| Library at rest | settles (39 lines) | settles (heavy 929-line settle, then 0/sec) |
| Discuss panel + sheet + keyboard, alone | no loop | — |
| Real `ReadingSurfaceView` + loaded player + Discuss | no loop | no loop |
| …+ narration advancing under the sheet | — | no loop |
| …wrapped in the app's paging `ScrollView` root | — | no loop |
| **Real app, real navigation** | — | **7,656× → crash** |

No single surface loops in isolation. The loop is an **emergent property of the composition**:
the app keeps **multiple full-bleed, independently-`@Observable`-observing surfaces mounted and
rendering simultaneously**, and that composition has no fixed point on-device. Every prior fix
was simulator-blind and aimed at the wrong subtree.

### The structural smell

`LibraryStackView` is a 1,301-line god-view that owns **all** surface state
(`chapterBook` / `memoBook` / `voiceBook` / `conversationsBook` / `reading`) and stacks five
always-mounted `.overlay { plane }` layers; `reading` further nests the Discuss `.sheet`.
`anyOverlayOpen` is a band-aid that mutes the *library's* geometry observers but cannot stop
the inner surfaces from observing live state. This violates the app's own **Prime Directive**
(`apple/CLAUDE.md`: one continuously-morphing surface; no page-style modal sheets).

## 2. Goals / non-goals

**Goals**
- Eliminate the device hang by ensuring **at most one live, observing surface at a time**.
- Realize the Prime Directive's single-surface model for the whole composition (all planes).
- Untangle the `LibraryStackView` god-view as a natural consequence.
- Add a durable rule (ADR) so this class of hang cannot recur.

**Non-goals (explicitly deferred)**
- Rebuilding the motion choreography (the cover→reading morph, scrubbable transitions). Kept
  as today's simple cross-dissolve/spring. The snapshot backdrop introduced here is the asset
  a future morph effort will reuse.
- Any backend, narration, or feature change.

## 3. Decisions (locked during brainstorming)

1. **Scope:** one active live surface, covering **all** surfaces (library + the 5 planes +
   reading + discuss), not just reading↔discuss.
2. **Beneath surface:** when a plane opens, the surface beneath becomes a **frozen static
   snapshot** (visible context, zero observation); the real view unmounts.
3. **Approach A:** extract a `SurfaceCoordinator` + `SurfaceHost` out of the god-view.
4. **Discuss** returns to an **in-canvas plane** (off `.sheet`).
5. **Transitions** stay simple for this restructure (no morph rebuild).

## 4. Architecture

Three new units replace the god-view's overlay stack.

### `Surface` (enum) — the single source of truth for what's on screen
```swift
enum Surface: Equatable {
    case library                  // depth-stack tower + section pager (My Books ⇄ Sci-Lit)
    case chapterList(Book)        // ┐ library-level planes (open from a focused book)
    case bookMemos(Book)          // │
    case bookConversations(Book)  // │
    case voicePicker(Book)        // ┘
    case reading                  // ┐ reading-level surfaces (need a live BookSession)
    case figures                  // │
    case notes                    // │
    case discuss                  // ┘
}
```
Each case has a **return target** (`discuss`/`figures`/`notes` → `reading`; the library-level
planes → `library`; `reading` → `library`), so "close" is a derived transition, not a tangle
of nil-assignments.

### `SurfaceCoordinator` (`@Observable @MainActor`, app-lifetime)
Owns `activeSurface: Surface` and `session: BookSession?`, plus the routing methods
(`openChapterList(_:)`, `openReading(book:chapter:)`, `openDiscuss()`, `openFigures()`,
`openNotes()`, `closeToReading()`, `closeToLibrary()`, `closeBook()`, …). Each method sets
`activeSurface` (and, where a backdrop is wanted, requests a snapshot — §6).

### `BookSession` (`@Observable @MainActor`, book-lifetime)
Created when a chapter opens for reading; released on book-close. Owns the objects that must
**survive surface switches**: `player`, `chatStore`, `memoCapture`, `memoNotes`, `voiceInput`,
`replySpeaker`, `discussArchive`. This is what preserves the parity rules — switching
reading→discuss tears down the *view*, but the `player` keeps playing and the `chatStore`
thread persists, because they live in the session, not the view. (`player` already pauses via
the shared-engine rule; the engine itself is app-lifetime and untouched.)

### `SurfaceHost` (root view)
Renders **exactly one** live surface (`switch coordinator.activeSurface`) over the frozen
backdrop (§6). Replaces `VimarshaApp`'s current direct mount of the library. The root keeps
`.ignoresSafeArea(.keyboard)` and the safe-area-inset environment.

### Result for `LibraryStackView`
Shrinks to **the tower only** — depth-stack math, focus/affordances, section pager. It loses:
the five `.overlay { plane }` mounts, the session `@State`, `openReadingSurface` /
`closeReadingSurface`, the plane open/close methods, and `anyOverlayOpen` (nothing else is
alive to gate). Each surface view becomes a peer the host mounts, not a nested overlay.

## 5. Lifetime model

| Object(s) | Lifetime | Owner |
|---|---|---|
| `activeSurface`, routing | app | `SurfaceCoordinator` |
| `player`, `chatStore`, `memoCapture/Notes`, `voiceInput`, `replySpeaker`, `discussArchive` | book session (chapter-open → book-close) | `BookSession` |
| each surface **view** | mounted only while it is the active surface | `SurfaceHost` |

Invariant: **exactly one surface view is mounted/observing at any time.** Background audio
continues without a mounted reading view because playback lives in `BookSession.player` (and
the app-lifetime audio engine), not in the view.

## 6. Snapshot backdrop

On a transition, `SurfaceHost` captures the outgoing surface to a static image via
`ImageRenderer`, caches it on the coordinator (`backdrop: Image?`), and renders it beneath the
incoming surface. The outgoing view unmounts — **zero live observation behind.** On return /
once the transition settles, `backdrop` clears and the live surface stands alone.

The snapshot serves two purposes, both upholding the one-live-surface invariant:
- **Context behind context-revealing planes** (Discuss / Figures / Notes over reading; the
  library-level planes over the library): the snapshot is the visible, refractable backdrop
  for as long as the plane is up.
- **Transition safety for opaque replacements** (e.g. library ↔ reading): even though the
  incoming surface fully covers, the outgoing one is shown as its snapshot *during* the
  cross-dissolve, so two surfaces are never both live for even one frame. The snapshot is
  discarded the moment the dissolve completes.

- The reading surface is mostly matte paper (content-is-paper rule), so `ImageRenderer`
  captures it faithfully; the only glass is the transport cluster, which need not refract live
  behind a plane.
- **Fallback:** if a capture is ever empty/unfaithful, the backdrop degrades to flat
  `Palette.canvas` — never a live view. (The plane is legible either way.)
- The snapshot is also the asset a future cover→reading morph will animate, so the
  choreography deferral loses nothing.

## 7. Discuss as an in-canvas plane

Discuss moves off `.sheet` to a glass plane that morphs up within the canvas (Prime
Directive). Because it is now the **only** live surface, there is no cross-surface layout for
the keyboard to feed, and keyboard avoidance becomes a **local concern of the Discuss plane**:

- A bottom-anchored glass panel whose input row uses `.safeAreaInset(edge: .bottom)` / a
  keyboard-aware layout **scoped to the plane**, lifting only the input row, not any ancestor.
- The root keeps `.ignoresSafeArea(.keyboard)`; the backdrop (a static image) cannot reflow.
- The 450ms `inputFocused` defer hack is removed — focus-on-appear is safe with nothing else
  live.

Parity preserved: opening Discuss does **not** pause narration; the existing
pause-on-audio-conflict (pause while a reply is spoken / the user voice-types) stays in the
session controllers, reached via `BookSession`.

## 8. Decomposition & landing order

Small, independently-mergeable chunks (repo convention); tests green at each; each `--no-ff`.

1. **Ownership move (no behavior change).** Introduce `Surface`, `SurfaceCoordinator`,
   `BookSession`; move the session `@State` and routing out of `LibraryStackView` into the
   coordinator. Still rendered as overlays. Pure-Swift unit tests for the state machine.
2. **`SurfaceHost` single-mount + snapshot backdrop**; migrate **reading + discuss** first
   (the hang path). Device regression gate must pass here.
3. **Migrate the four library-level planes** (chapterList / bookMemos / bookConversations /
   voicePicker) to the host.
4. **Discuss `.sheet` → in-canvas keyboard-local plane.**
5. **Cleanup:** delete `anyOverlayOpen` + its guards, the BookTower "don't render while
   reading" hack (`a566b66`), the `_printChanges` DIAG; decide harness retention (keep the
   harness behind its DEBUG flag as the standing device gate).

## 9. Testing strategy (the bug is device-only)

- **Unit tests** on `SurfaceCoordinator` (pure, fast, no device): transitions and
  return-targets; `BookSession` lifetime (created on chapter-open, released on book-close,
  survives surface switches); and the **invariant that exactly one surface is live**.
- **Existing snapshot/widget tests** for each plane view stay green (views barely change).
- **Device regression gate:** the committed repro harness
  (`Debug/DiscussLoopRepro.swift`, `-VimarshaReproMode surface`). After chunk 2, opening
  Discuss must show **bounded** `ReadingSurfaceView` renders (not thousands), captured via
  `devicectl --console`. Unit tests structurally cannot catch a device-only AttributeGraph
  loop, so this manual gate is mandatory before chunks 2 and 4 merge.
- **ADR:** add "single live surface — no simultaneously-observing surfaces" to
  `plan/00-overview/decision-log.md` (next id), citing this spec.

## 10. Risks & mitigations

- **`ImageRenderer` faithfulness / cost.** Capturing a full surface each transition has a
  cost and may not reproduce glass exactly. Mitigation: capture once per transition (not per
  frame), the canvas fallback, and content-is-paper means the matte body captures well.
- **In-canvas keyboard regressions.** Returning Discuss off `.sheet` reintroduces keyboard
  handling. Mitigation: single live surface removes the feedback path; keyboard avoidance is
  scoped to the plane; verified on the device gate.
- **Large change to a central file.** Mitigation: the 5-chunk landing order keeps each step
  small and green; chunk 1 is a pure ownership move with no behavior change.

## 11. Open questions

- Exact return-target for `reading` when the book was opened from a library-level plane
  (chapter list) — likely `library`, confirmed during chunk 1.
- Whether `bookMemos`/`bookConversations`/`voicePicker` need a `BookSession` or just the
  `Book` (they predate reading) — they take only `Book`; no session required.
