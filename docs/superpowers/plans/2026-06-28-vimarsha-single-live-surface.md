# Single Live Surface — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the device-only Discuss 100% CPU hang by guaranteeing at most one live, observing surface at a time.

**Architecture:** Extract surface orchestration out of the 1,301-line `LibraryStackView` god-view into a `SurfaceCoordinator` (app-lifetime: `activeSurface` + routing) holding a `BookSession` (book-lifetime: the player/chat/memo/voice/speaker objects). A `SurfaceHost` root view mounts exactly one surface over a frozen `ImageRenderer` snapshot backdrop. Discuss returns from a `.sheet` to an in-canvas keyboard-local plane.

**Tech Stack:** Swift 6 / SwiftUI (iOS 26 + macOS 26), Observation framework, Swift Testing (`@Test`), SwiftData, folder-synchronized Xcode project.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-06-28-vimarsha-single-live-surface-design.md`.
- Test command (must stay green at every commit):
  `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
  and `-destination 'platform=macOS'`.
- New Swift files drop into `apple/Vimarsha/` / `apple/VimarshaTests/`; folder-synchronized project — NO `project.pbxproj` edits.
- TDD: failing test → minimal impl → green → commit. Commit trailer:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` and the `Claude-Session:` line.
- Invariant under test: **exactly one surface live at a time**; `BookSession` survives surface switches, dies on book-close.
- Two seams only (`BackendClient`, audio/mic) keep their existing test doubles; everything else is real code.
- The hang is **device-only** — unit tests cannot catch it. The committed repro harness
  (`Debug/DiscussLoopRepro.swift`, `-VimarshaReproMode surface`) is the mandatory device gate
  before chunks 2 and 4 merge (capture via `devicectl --console`; bounded `ReadingSurfaceView`
  renders = pass).

---

## File Structure

- **Create** `apple/Vimarsha/Surface/Surface.swift` — the `Surface` enum + return-target logic.
- **Create** `apple/Vimarsha/Surface/BookSession.swift` — `@Observable @MainActor` book-session object (owns player/chat/memo/voice/speaker).
- **Create** `apple/Vimarsha/Surface/SurfaceCoordinator.swift` — `@Observable @MainActor` app-lifetime router (`activeSurface`, `backdrop`, transitions).
- **Create** `apple/Vimarsha/Surface/SurfaceHost.swift` — root view: single-mount switch + snapshot backdrop.
- **Modify** `apple/Vimarsha/Library/LibraryStackView.swift` — strip surface/session state + plane overlays; keep the tower.
- **Modify** `apple/Vimarsha/VimarshaApp.swift` — mount `SurfaceHost` instead of the bare paging library.
- **Modify** `apple/Vimarsha/Reading/ReadingSurfaceView.swift` — Discuss off `.sheet` → in-canvas plane (chunk 4).
- **Create** `apple/VimarshaTests/SurfaceCoordinatorTests.swift`, `BookSessionTests.swift` — state-machine + lifetime tests.

---

## Chunk 1 — Surface model + ownership move (no behavior change)

Goal: introduce `Surface`/`SurfaceCoordinator`/`BookSession` and move the session/plane state
out of `LibraryStackView` into the coordinator. Rendering still happens via the existing
overlays, now reading coordinator state. Behavior identical; full suite green.

### Task 1.1: `Surface` enum + return targets

**Files:**
- Create: `apple/Vimarsha/Surface/Surface.swift`
- Test: `apple/VimarshaTests/SurfaceTests.swift`

**Produces:** `enum Surface: Equatable { case library, chapterList(Book), bookMemos(Book), bookConversations(Book), voicePicker(Book), reading, figures, notes, discuss }`; `var returnTarget: Surface` (`.discuss/.figures/.notes → .reading`; everything opened from the library → `.library`; `.reading → .library`).

- [ ] **Step 1: failing test** — `apple/VimarshaTests/SurfaceTests.swift`
```swift
import Testing
@testable import Vimarsha

@MainActor
struct SurfaceTests {
    @Test func readingLevelPlanesReturnToReading() {
        #expect(Surface.discuss.returnTarget == .reading)
        #expect(Surface.figures.returnTarget == .reading)
        #expect(Surface.notes.returnTarget == .reading)
    }
    @Test func readingReturnsToLibrary() {
        #expect(Surface.reading.returnTarget == .library)
    }
    @Test func libraryIsTerminal() {
        #expect(Surface.library.returnTarget == .library)
    }
}
```
- [ ] **Step 2: run, expect FAIL** (`Surface` undefined).
- [ ] **Step 3: implement** `Surface.swift`:
```swift
import Foundation

/// The single source of truth for which ONE surface is live (apple/CLAUDE.md Prime Directive;
/// spec 2026-06-28-single-live-surface). Library-level planes carry their `Book`.
enum Surface: Equatable {
    case library
    case chapterList(Book)
    case bookMemos(Book)
    case bookConversations(Book)
    case voicePicker(Book)
    case reading
    case figures
    case notes
    case discuss

    /// Where "close" lands: reading-level planes recede to the reading surface; everything
    /// opened from the library (and reading itself) recedes to the library tower.
    var returnTarget: Surface {
        switch self {
        case .discuss, .figures, .notes: return .reading
        case .library, .reading, .chapterList, .bookMemos, .bookConversations, .voicePicker:
            return .library
        }
    }
}
```
- [ ] **Step 4: run, expect PASS** (both destinations).
- [ ] **Step 5: commit** `feat(apple): Surface enum + return targets (single-live-surface chunk 1)`.

### Task 1.2: `BookSession`

**Files:**
- Create: `apple/Vimarsha/Surface/BookSession.swift`
- Test: `apple/VimarshaTests/BookSessionTests.swift`

**Consumes:** `LibraryStore.make{Player,MemoCapture,MemoNotes,ChatStore,VoiceInput,ReplySpeaker}`, `PlayerController.load`, `ReadingContext`.
**Produces:** `@Observable @MainActor final class BookSession` with `let context: ReadingContext`, `let player: PlayerController`, and `memoCapture/memoNotes/chatStore/voiceInput/replySpeaker` (optional where the seam may be absent), plus `static func open(store:audioEngine:recorder:book:chapter:) -> BookSession?` (mirrors the current `openReadingSurface` construction; `nil` when the chapter won't load) and `func close()` (pause player, stop memo/reply playback, cancel holds).

- [ ] **Step 1: failing test** — build a session from an in-memory store + `FakeAudioEngine` + a `.ready` chapter with a written bundle (reuse the `PlayerControllerTests.makeFixture` pattern), assert `session.player.bundle != nil` and that `close()` pauses the player. (Full test code authored against the fixture pattern at execution.)
- [ ] **Step 2: run, expect FAIL.**
- [ ] **Step 3: implement** `BookSession.open(...)` by lifting the body of `LibraryStackView.openReadingSurface` (lines ~830-849) verbatim into the factory, and `close()` by lifting `closeReadingSurface`'s teardown (lines ~862-873) minus the `reading = nil` animation (the coordinator owns `activeSurface`).
- [ ] **Step 4: run, expect PASS.**
- [ ] **Step 5: commit** `feat(apple): BookSession owns the book-lifetime objects`.

### Task 1.3: `SurfaceCoordinator`

**Files:**
- Create: `apple/Vimarsha/Surface/SurfaceCoordinator.swift`
- Test: `apple/VimarshaTests/SurfaceCoordinatorTests.swift`

**Consumes:** `Surface`, `BookSession`.
**Produces:** `@Observable @MainActor final class SurfaceCoordinator` with `var activeSurface: Surface = .library`, `private(set) var session: BookSession?`, `var backdrop: Image?`, and transitions: `openChapterList(_:)`, `openReading(book:chapter:store:audioEngine:recorder:) -> Bool`, `openDiscuss/Figures/Notes()`, `openBookMemos/BookConversations/VoicePicker(_:)`, `close()` (→ `activeSurface.returnTarget`; releases `session` when landing on `.library`).

- [ ] **Step 1: failing tests** covering: opening a chapter sets `.reading` + creates a `session`; `openDiscuss()` sets `.discuss` and **keeps the same session**; `close()` from `.discuss` returns to `.reading` with the session intact; `close()` from `.reading` returns to `.library` and releases the session (`session == nil`); the **invariant** that `session != nil` iff `activeSurface` is a reading-level surface.
- [ ] **Step 2: run, expect FAIL.**
- [ ] **Step 3: implement** the coordinator (transitions set `activeSurface`; `close()` uses `returnTarget`; session released only when landing on `.library`).
- [ ] **Step 4: run, expect PASS.**
- [ ] **Step 5: commit** `feat(apple): SurfaceCoordinator state machine + session lifetime`.

### Task 1.4: Route `LibraryStackView` through the coordinator (still overlays)

**Files:**
- Modify: `apple/Vimarsha/Library/LibraryStackView.swift`
- Modify: `apple/Vimarsha/VimarshaApp.swift` (own + inject the `SurfaceCoordinator`)

**Operation:** replace the 14 surface/session `@State` vars (`chapterBook`, `memoBook`, `bookMemoPlayer`, `voiceBook`, `voicePreview`, `conversationsBook`, `openThreadId`, `reading`, `player`, `memoCapture`, `memoNotes`, `chatStore`, `voiceInput`, `replySpeaker`) with reads of an injected `coordinator` / `coordinator.session`. `openReadingSurface`/`closeReadingSurface` and the plane open/close closures delegate to coordinator methods. `anyOverlayOpen` becomes `coordinator.activeSurface != .library`. The five `.overlay { …Plane }` stay, now driven by `coordinator.activeSurface`. Tower-only `@State` (`focus`, `cardTops`, `cardVisualTops`, `distanceToRest`, `scrollAtRest`, `tappedIndex`, `galleryMode`, `metadataRevealShown`, `clusterGlobalFrame`, `scrollOriginGlobalY`, `showsEpubPicker`, `pendingDeleteBook`, `coverMorph`) stays.

- [ ] **Step 1:** make the edits (no new test — guarded by the existing suite).
- [ ] **Step 2: run the FULL suite (both destinations), expect PASS** — behavior unchanged.
- [ ] **Step 3:** run the existing snapshot/widget tests specifically; confirm green.
- [ ] **Step 4: commit** `refactor(apple): route LibraryStackView surfaces through SurfaceCoordinator`.

---

## Chunk 2 — `SurfaceHost` single-mount + snapshot backdrop (reading + discuss)

**Files:** create `apple/Vimarsha/Surface/SurfaceHost.swift`; modify `VimarshaApp.swift`, `LibraryStackView.swift`.

**Operation:** `SurfaceHost` renders `ZStack { backdropImage; switch coordinator.activeSurface { … } }`, mounting exactly one surface. For `.reading/.figures/.notes/.discuss` it mounts the reading-family views (currently `readingSurface`/overlays); for `.library` and the library-level planes it mounts the library/those planes. On every transition, capture the outgoing surface via `ImageRenderer` into `coordinator.backdrop` (helper `captureBackdrop()`), cleared once settled; fallback to `Palette.canvas` when capture is nil.

- [ ] **Test (unit):** `SurfaceHost` mounts exactly one surface for each `activeSurface` value (assert via a test that inspects which child is built — or a coordinator-level invariant test if the view is hard to introspect). Snapshot tests for each surface stay green.
- [ ] **Device gate:** run `-VimarshaReproMode surface`; opening Discuss shows **bounded** `ReadingSurfaceView` renders (was 7,656). MUST pass before merge.
- [ ] **Commit** per the host + per the reading/discuss migration.

---

## Chunk 3 — Migrate the four library-level planes to the host

**Files:** `SurfaceHost.swift`, `LibraryStackView.swift`.

**Operation:** move `chapterListPlane`/`bookMemosPlane`/`bookConversationsPlane`/`voicePickerPlane` rendering from `LibraryStackView`'s `.overlay`s into `SurfaceHost`'s switch (cases `.chapterList/.bookMemos/.bookConversations/.voicePicker`), backed by snapshots of the library. `LibraryStackView` loses these overlays.

- [ ] Existing plane snapshot/widget tests stay green; commit per plane group.

---

## Chunk 4 — Discuss `.sheet` → in-canvas keyboard-local plane

**Files:** `ReadingSurfaceView.swift` (remove the `.sheet`), `DiscussPanelView.swift` (own keyboard avoidance), `SurfaceHost.swift` (mount `.discuss`).

**Operation:** delete the `.sheet(isPresented:)` block (lines ~182-206) and the `showDiscuss` `@State`; `.discuss` is now a `SurfaceHost` case rendering `DiscussPanelView` as a bottom-anchored glass plane over the reading snapshot. `DiscussPanelView` gets `.safeAreaInset`/keyboard-aware layout scoped to itself; remove the 450ms `inputFocused` defer hack. Remove the DEBUG `.task` auto-open seam's dependence on `showDiscuss` (point it at the coordinator).

- [ ] **Device gate again:** open Discuss via the real flow; bounded renders, no watchdog. MUST pass before merge.
- [ ] Existing Discuss snapshot tests green; commit.

---

## Chunk 5 — Cleanup

**Files:** `LibraryStackView.swift`, `ReadingSurfaceView.swift`, `Debug/DiscussLoopRepro.swift`, `plan/00-overview/decision-log.md`.

**Operation:** delete `anyOverlayOpen` + its `guard` gates (no longer needed — nothing else is live); delete the BookTower "don't render while reading" hack (`a566b66`, lines ~197-203); delete the four `_printChanges` `// DIAG` lines; keep the repro harness behind its DEBUG flag as the standing device gate (or delete the ReadingSurfaceView `.task` seam if pointed at the coordinator suffices). Add ADR ("single live surface — no simultaneously-observing surfaces") to `plan/00-overview/decision-log.md` citing the spec.

- [ ] Full suite green both destinations; final device gate; commit; `--no-ff` merge to `main`.

---

## Self-review notes

- **Spec coverage:** §4 architecture → Tasks 1.1-1.3 + chunk 2 host; §5 lifetime → Task 1.2/1.3 + tests; §6 backdrop → chunk 2; §7 Discuss-in-canvas → chunk 4; §8 landing order → chunks 1-5; §9 testing → per-chunk unit tests + device gate; ADR → chunk 5. All covered.
- **Device-only caveat** is encoded as an explicit per-chunk device gate, since unit tests structurally cannot catch the AttributeGraph loop.
- View-migration steps (Tasks 1.4, chunks 2-4) are mechanical moves of existing code; exact diffs are finalized against the live file at execution (the file is read immediately before each edit), not pre-fabricated, to avoid drift from the 1,301-line source.
