# Progress — Track A (Apple client)

> Part of the [knowledge base](../README.md) · roadmap: [build-roadmap](build-roadmap.md).
> **File scope:** all of `apple/**` (sole track for now — split scopes when a second track
> opens, e.g. backend/hosted work → `_progress-B.md`). Append one entry per finished V-item:
> **What / Wiring / Evidence / Device-gated**. Newest entries on top of their phase.

**Verification conventions (from [apple/CLAUDE.md](../../apple/CLAUDE.md)):**
```bash
cd apple
xcodebuild -scheme Vimarsha -destination 'platform=macOS' test
xcodebuild -scheme Vimarsha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```
Motion items also record a simulator/device capture for the motion review.

---

## V34 — Discuss voice input (hold-to-talk) ✅

**What:** the panel's secondary input affordance (spec §4; typed stays the default).
`VoiceInput` (@Observable, `Discuss/VoiceInput.swift`): finger down = permission (the
system prompt is the primer) → **pause narration** (pause-on-audio-conflict) → record a
temp m4a through the shared mic seam, with a 100ms level/elapsed ticker; finger up =
stop → **resume narration immediately if it was playing** (the design call: the
transcription *wait* is not an audio conflict — only the open mic is) → `POST
/transcribe` → the trimmed text lands via `onTranscript`. Tap-length holds (<400ms,
the MemoCapture rule) discard with no backend round-trip; `denied`/`failed` phases
drive honest captions ("type your question instead" — spec §6 fallback, panel state
never lost; failed auto-resets after 2.5s); the begin/end permission race guard is
ported from MemoCapture. `DiscussPanelView`: `HoldToTalkButton` (the MemoRecordControl
hold-gesture pattern at 38pt; sky glass → aqua while live; matte under Reduce
Transparency; VoiceOver start/stop action) sits left of the field; while recording the
field slot becomes the `Listening…` row (aqua waveform glyph driven by mic level +
monospaced clock), then `Transcribing…`; the transcript APPENDS to the draft (review
then send — never auto-sent) and refocuses the field.

**Wiring:** `LibraryStore.makeVoiceInput(recorder:player:)`; `LibraryStackView` creates
it at surface open with the app-lifetime recorder, `cancelHold()`s + releases at book
close; the panel's close chevron also cancels a live hold. `ReadingSurfaceView` passes
it through (nil hides the mic — previews/snapshots).

**Evidence:**
- 9 `VoiceInputTests` (real `PlayerController` over `FakeAudioEngine`; fake recorder +
  backend): pause-on-hold, **resume-before-transcript**, paused-stays-paused, denied
  (playback untouched), too-short discard (no round-trip, `Issue.record` tripwire),
  failure fallback, recorder-start failure, the release-during-permission-prompt race,
  cancel mid-record. **Both suites green** (post-revert re-run).
- Captures (temp `CaptureRoot`, reverted): `01-panel-mic-dark.png` + `02-…-light.png` —
  the mic in the input row, both modes. `.agent-loop/artifacts/V34/`.

**Visual audit findings (whole-frame):** same pre-existing plate-title ellipsis as the
V33 entry (filed there); the light-mode mic's sky 0.3 tint over butter is subtle but
legible. Nothing new.

**Device-gated:** real-mic capture quality + the hold feel inside the panel, and the
pause/resume seam heard live → V36.

---

## V33 — Discuss panel ✅

**What:** the Discuss state of the reading surface (apple/CLAUDE.md §UI map state 6;
spec §4 binding rules). `DiscussPanelView` — a sky-tinted glass plane that morphs up
*within* the canvas (move-from-bottom + opacity; RM cross-dissolves; `Palette.surface`
matte under Reduce Transparency), top-rounded, holding: small-caps DISCUSS header +
close chevron, the transcript, and a keyboard-default input row (multiline TextField,
`@FocusState` focused on appear; aqua send disabled while empty/sending).
`DiscussTranscriptView` (extracted for snapshots — the ScrollView/ImageRenderer gotcha):
matte paper bubbles on the glass plane (content is paper, controls are glass) — user
turns trailing with a sky accent border in SF, assistant turns leading in the reading
serif; honest `Thinking…` row while sending; an error row ("No reply…") with an aqua
Retry that re-sends the unanswered turn (spec §6 — prior turns intact). Entry =
**the record control's dual gesture** (spec §4): `MemoRecordControl` gains
`onDoubleTap` via `simultaneousGesture(TapGesture(count: 2))` — two quick taps never
arm the 0.25s hold, so memo-hold and discuss-double-tap coexist — plus a VoiceOver
"Discuss this passage" action (gesture-only interactions rule).

**Wiring:** opening sets `showDiscuss` ONLY — narration is never paused (the binding
no-pause rule); the panel replaces the bottom transport overlay while up (extracted
`transportOverlay`; the reading body keeps playing behind the plane).
`ChatStore.recordAnchor` pins the block at FIRST panel open (reopening doesn't move
it); `makeChatStore` no longer takes an at-creation anchor. `LibraryStackView` owns the
chapter's `ChatStore` — created with the player, discarded only at book close
(save-on-demand: closing the panel keeps the thread; closing the book discards).

**Evidence:**
- `DiscussPanelSnapshotTests` (3 — turns + error-row raster diff, thinking row, empty
  state) + the anchor-pin rule in `ChatStoreTests`; **both suites green** on macOS +
  iPhone 17 Pro sim (post-revert re-run).
- Forced-state captures (temp `CaptureRoot`, reverted): `01-discuss-panel-dark.png` +
  `02-discuss-panel-light.png` — glass plane over the reading shell, bubbles, input
  row, both modes; `03-rest-dark-regression.png` — the library rest state is intact.
  `.agent-loop/artifacts/V33/`.

**Visual audit findings (whole-frame):**
1. The reading plate's debossed cover title truncates with an ellipsis ("DESIGN BY
   ACCI…") on the small V17 cover plate — both modes. Pre-existing (V44 fixed the
   tower card; the plate may need the same block-level `minimumScaleFactor`). Candidate
   polish V-item.
2. Light mode: the panel reads as a flat mint block more than glass over the butter
   canvas (sky 0.22 tint); placeholder text contrast in the input capsule is low-ish
   (placeholder, not content). Judge on device in V36.
3. The capture shows no raised keyboard (sim hardware-keyboard default) — the
   keyboard-default focus rule needs the live V36 check.

**Device-gated:** the double-tap-vs-hold gesture feel, the panel's morph-up feel, and
keyboard-default focus → V36 (the P5 verify gate runs live anyway).

---

## V32 — Discuss chat data layer ✅

**What:** the P5 foundation, mirroring the frozen Flutter Plan-6a design (port the
design, not the code). `BackendClient` grows the last two endpoints — `chat(messages:
context:)` (`POST /chat`, JSON body `{messages, context}` → `{reply}`) and `speak(text:)`
(`POST /speak` → MP3 bytes); `ChatMessageDTO`/`ChatContextDTO` mirror the backend
pydantic shapes exactly (camelCase aliases; `figureCaption` omitted when absent —
contract-asserted in `ChatBackendTests` via raw JSON key inspection).
`ChatContextSnapshot` is the grounding math (pure, no clocks): live paragraph ± 1
text-bearing neighbor joined as the passage + the active figure's caption; chapter-edge
clamps and missing-bundle fallbacks tested. `ChatStore` (@Observable, in-memory) ports
the Flutter `ChatController` semantics: synchronous send-guard (double-send ignored —
gated-continuation test), context snapshotted at EACH send so grounding follows playback,
failure keeps the unanswered user turn behind `error` + `retry()`, `hasExchange` gates
Save. `ChatThread`/`ChatLine` @Models land the data-model.md "Later" slice (book cascade,
explicit per-thread line `index` ordering — `createdAt` can tie inside one save);
`LibraryStore` gains `saveChatThread` (each Save inserts a NEW thread; empty refused),
`chatThreads(for:chapterIndex:)` (newest first), `deleteChatThread`, and the
`makeChatStore(player:)` factory (snapshot closure reads the live player; anchor = the
block at open).

**Wiring:** `VimarshaApp`'s `ModelContainer` adds `ChatThread`/`ChatLine` (additive,
lightweight migration). No UI yet — the panel is V33. Design note: the spec (§3, Flutter
parity) grounds **per send**; `conversation-ai.md` says "when the panel opens" — built
per-send (strictly more capable: follow-ups ride the playhead), with `anchorBlockId`
recording the open point, per spec §5.

**Evidence:**
- 23 new tests (`ChatBackendTests` 4, `ChatContextSnapshotTests` 6, `ChatStoreTests` 7,
  `ChatPersistenceTests` 6); **both suites green** (macOS 278/278, iOS sim suite green).
- **Live round-trip against the running backend + Ollama `llama3.2:3b`:** `/chat` with a
  real DOET passage returned a grounded one-sentence reply; `/speak` returned a valid
  42.4KB 24kHz mono MP3 (real Chatterbox). Request JSON = byte-shape the client builds
  (the unit-tested `jsonRequest` form). Artifacts: `.agent-loop/artifacts/V32/`
  (chat-request.json / chat-reply.json / speak-reply.mp3).
- Commit `cf22429`, merged `b446ff4`.

**Device-gated:** nothing — data layer only; the conversational feel gate is V36.

---

## V31 — [verify] Memos end-to-end ✅ (machine half; human review deferred to final)

**What:** the P4-closing verify gate, run as far as a machine can take it. A standalone
harness ([`artifacts/V31/harness/main.swift`](../../.agent-loop/artifacts/V31/harness/main.swift),
the V21/V29 precedent — but compiling the **entire production tree** minus the app entry:
store, models, player, MemoNotes, seams, views) drove the real memo pipeline against the
LIVE local backend (real Chatterbox + faster-whisper), **22/22 PASS**
([harness-run.log](../../.agent-loop/artifacts/V31/harness-run.log)):
1. **Production import flow live:** `store.addBook(from: sample.epub)` → `/toc` → book +
   chapter rows; `store.downloadChapter` → `/import` (real Chatterbox, 77s warm) → cache;
   the real `PlayerController`/`AVFoundationAudioEngine` loads the 24.3s chapter.
2. **Fixture-audio memo:** `/speak` rendered a known sentence (28.5KB) saved into
   `Library/Books/<id>/memos/<id>.m4a` — exactly where `MemoCapture` saves clips (the
   recorder seam is the sanctioned double; the clip feeds the same path a mic hold would).
3. **Live transcript on the row:** `store.transcribeMemo` → `/transcribe` → faster-whisper
   returned the sentence **verbatim** ("Remember to compare this passage with the figure
   on memory."), status `ready`.
4. **Notes over real rows/files:** lists the memo; `play()` runs the clip on its own
   engine, **pauses narration** (audio-conflict rule) while the chapter MP3 stays loaded;
   `openAtPin()` stops the clip and seeks narration to the **exact** pinned ms
   (12144 == 12144); `delete()` removes row + audio file.

**Wiring:** no app code changed — the gate passed clean on the first run (V21's timeout
fix and the V28–V30 TDD held).

**Evidence:** harness source + ALL PASS log in
[`artifacts/V31/`](../../.agent-loop/artifacts/V31/); post-batch launch-rest regression
captures (dark+light, medium) clean — the V42/V43 fixes visible (labeled band, AA
contrast). Both suites green on this tree (V44 merge runs). Marked ✅ under the
2026-06-11 deferred-review directive.

**Visual audit findings:** none new — rest frames match the V43/V44 post-fix state;
known nits (shelf-edge clip, XXXL cluster-over-subtitle) stand as filed.

**Deferred to the final human review** ([final-review-checklist §V31](final-review-checklist.md)):
real-mic hold-to-record feel + permission primer, live transcript honesty with YOUR
voice + offline error/retry, the Notes morph + clip playback by ear, open-at-pin UX
feel, VoiceOver sweep over the memo flows.

**P4 (Memos) complete — next eligible: P5 Discuss (V32), needs Ollama for live testing.**

---

## V44 — XXXL deboss block fitted to the cover face ✅

**What:** ui-audit round 2: the blue cover's debossed bottom line ("OF DESIGN") rode
into the fore-edge page-texture lines at XXXL. Cause: `minimumScaleFactor(0.4)` sat on
the **title Text alone**, so the un-scalable author/subtitle line pushed the centered
overlay block past the board face. Fix in `HardbackCoverView.titleBlock`: block-level
`lineLimit(3) + minimumScaleFactor(0.4)` (covers both texts) + a 12pt vertical inset —
every glyph stays above the page-edge strip at any type size.

**Wiring:** none beyond the view — pure layout fix.

**Evidence:** new `HardbackCoverDebossFitSnapshotTests` renders the REAL cover at
`.xxxLarge` and asserts zero title-ink pixels in the fore-edge strip; **red before the
fix (iOS), green after**. Both suites green both destinations. XXXL captures dark+light
+ seam crops in [`artifacts/V44/`](../../.agent-loop/artifacts/V44/) — looked at:
"OF DESIGN" sits clear of the fore-edge lines in both modes.

**Gotcha worth keeping:** the regression test is **iOS-destination only** — macOS has
no Dynamic Type, `@ScaledMetric` never grows under the macOS runner, so the overflow
*cannot reproduce* there (the first macOS attempt passed spuriously; artifact
`00-red-attempt.png` documents it). Pixel sampling redraws the `CGImage` into a known
RGBA8 context (byte-order safe), not raw `dataProvider` bytes.

**Visual audit findings (whole frame):** the V42 nit stands (cluster pill occludes the
deboss subtitle mid-line at XXXL on the focused cover — readable but scruffy); bottom
shelf cover still clips at the screen edge (known nit). Nothing new in either mode.

**Device-gated:** nothing — static layout, machine-verified. Commit `6b47e5d`,
merged `582a35d`. **P-FIX round 2 complete.**

---

## V43 — metadata band guarantees WCAG AA over any cover (measured) ✅

**What:** ui-audit round 2 measured the band failing on the blue cover (dark ≈2.6/2.0,
light ≈1.65/1.44). TWO compounding causes found:
1. The V38 sky-0.30 glass tint let cover art bloom straight through (plate ≠ guarantee).
2. **The real killer:** the whole band — text included — rendered at
   `opacity == promotion`, and launch rest only reaches ~0.5, so the band sat permanently
   half-transparent. (Proven empirically: with the underlay fix alone the measured title
   was still 2.98/2.32 — captures `01/02` in the artifacts.)

Fixes: `Design/BandContrast.swift` — pure WCAG math (relative luminance, contrast ratio,
worst-case-cover blend minimized over the RGB-cube corners; 7 tests) pinning
`FocusMetadataView.plateUnderlayOpacity 0.85` + `subtitleOpacity 0.7→0.8` to a
**guaranteed ≥4.5:1 over ANY cover, both modes**; a matte `surface` underlay beneath the
band's sky glass (Reduce Transparency path unchanged); and
`BookFocus.metadataRevealOpacity` — smoothstep saturating at promotion 0.5, so the band
is FULLY opaque at rest and before the cluster shows (5 tests). `Palette.Hex` now holds
the raw UInt32s (still the one hex place — Color tokens and contrast math share them).

**Evidence:** both suites green both destinations. **Measured on-sim** (blue cover,
medium rest, [`contrast-measurements.txt`](../../.agent-loop/artifacts/V43/contrast-measurements.txt)):
dark title **7.63:1** / subtitle **5.57:1**; light **10.64:1** / **6.39:1** — all AA.
Captures `03/04-medium-*-fixed.png` + crops reviewed: crisp token text on a solid
slate/aqua plate with a glass rim, both modes. Pink-cover case covered by the
worst-case guarantee tests (rest always focuses the blue seed; no gesture injection).
Commit `3c6b01d`, merged `7ec0089`.

**Visual audit findings (whole frame):** dark-mode plate reads slightly blue-shifted
(sky glass over blue cover) but solidly within AA per the measurements; no new defects
spotted at medium rest either mode; the XXXL deboss bottom-clip (V44) and shelf-edge
nits remain as filed.

**Device-gated:** the reveal ramp's live scrub feel (band fading up while a cover
settles) → deferred final review.

---

## V42 — XXXL focused card keeps its label (deboss ↔ metadata-yield coupling) ✅

**What:** ui-audit round 2's composition defect: V37's metadata-yield (`ViewThatFits`
drops the title band when the focused cover's visible band only fits the cluster) and
V41's deboss-fade (printed title → 0 with promotion) composed into a **completely
unlabeled focused card at XXXL** — empty pink slab + anonymous icon pill, while the
unfocused neighbor's full-strength deboss read as the focus label.
`BookFocus.debossTitleOpacity(promotion:metadataVisible:)` now takes the actual
metadata visibility: **when the metadata reveal isn't rendered, the deboss title stays
at 1 — it IS the label** (3 new tests incl. the exact XXXL audit state; the V41 suite
re-pinned with `metadataVisible: true`).

**Wiring:** the affordance `ViewThatFits`'s metadata branch carries
`.preference(FocusMetadataVisibleKey, true)` — only the *rendered* branch emits, so a
yielded band resolves to the default `false`. `LibraryStackView` reads it (above the
overlay in the modifier chain, where the preference actually arrives) into
`metadataRevealShown` → `BookTower` → the focused card's `titleOpacity`. The branch
flip is discrete, so the deboss opacity change rides a 0.2s ease (no hard cut).

**Evidence:** both suites green both destinations. Captures in
[`artifacts/V42/`](../../.agent-loop/artifacts/V42/), all four looked at:
`01-xxxl-dark.png`/`02-xxxl-light.png` — the focused pink card shows its debossed
"HEY / DESIGN & ILLUSTRATION" under the cluster pill, exactly one title; medium
regression `03/04` — V41 single-title behavior intact (metadata band shows, deboss
faded). Commit `88ca107`, merged `3bd998b`.

**Visual audit findings (whole frame, beyond scope):**
- XXXL both modes: the cluster pill **occludes the deboss subtitle line** ("DESIGN &"
  sits behind the glass pill) — label readable but the overlap is scruffy; candidate
  fix is nudging the cluster anchor below the deboss block at accessibility sizes (nit,
  filing here only).
- XXXL both modes: the blue cover's "OF DESIGN" still clips the bottom edge — that is
  **V44**, confirmed still live in these captures.
- Medium both modes: metadata band on the blue cover visibly low-contrast — **V43**,
  confirmed still live.
- Bottom shelf cover still clips its lines at the screen edge (known round-1/2 nit).

**Device-gated:** the 0.2s deboss ease on a live band-height flip (scroll through the
yield threshold at XXXL) — motion feel, queued for the deferred final review.

---

## V30 — Notes state: voice memos as a morphed list of the reading surface ✅

**What:** `Player/MemoNotes.swift` (@Observable, 6 tests) — the Notes state's controller:
- **Playback on its own ephemeral engine** (the Flutter spec's sanctioned "separate
  handler instance"): the chapter's shared engine keeps its loaded MP3 + resume position
  untouched (asserted in tests). Play pauses narration (audio-conflict rule,
  sound-design.md) — but the clip is load-checked FIRST so a missing file never pauses
  anything (self-review fix). Tap-again stops; another row switches; `onFinish` clears.
- **Open-at-pin** stops the clip and seeks narration to the memo's exact `positionMs`
  (more precise than the paragraph start); the view morphs back to reading.
- **Retry** routes to V29's `store.transcribeMemo`; **delete** = new
  `LibraryStore.deleteMemo` (cancel in-flight transcript → sweep audio file → delete row).
`Reading/MemoNotesView.swift` — the morphed list state (the FiguresGallery pattern,
never a sheet): matte paper rows with the serif transcript (honest Transcribing…/
Transcription failed states; retry shows on error only), an italic paragraph snippet
(pin context, derived from the bundle), `¶N · m:ss` pin line, and labeled actions
(play/stop with aqua live accent, open-at-pin, delete). Empty state = guidance line.

**Wiring:** a glass `note.text` toggle rides the reading surface's closeBar (mutually
exclusive with the Figures gallery; leaving Notes stops the clip via `onChange`);
`LibraryStackView` builds `MemoNotes` at chapter open with a fresh
`AVFoundationAudioEngine` and stops + releases it at close; factory `makeMemoNotes` on
the store.

**Scope note:** Notes is **chapter-scoped** on the reading surface (every action —
open-at-pin, the pin snippets — needs the open chapter's bundle/player). The Flutter
client's *cross-book* top-level Notes screen is a parity gap deliberately not taken
here; if wanted it's a later item (the library cluster's Memo control, still a stub,
is its natural opener). Logged for the P9/parity sweep.

**Evidence:** +8 tests (6 `MemoNotesTests` + 2 row snapshots), both suites green both
destinations. Artifacts in [`artifacts/V30/`](../../.agent-loop/artifacts/V30/):
`memo-notes-rows/playing.png` (three transcript states, retry-on-error-only, aqua
playing accent — reviewed) + a clean launch-rest regression capture. Commit `8277c97`,
merged `5b6568b`.

**Device-gated:** the live morph feel (body ⇄ notes reflow), VoiceOver action sweep on
device, and the real memo-clip playback path (ephemeral AVAudioPlayer over m4a) — all
queued for V31's machine run + deferred checklist.

---

## V29 — Memo transcription wiring (live `/transcribe` proven) ✅

**What:** the seam grows `transcribe(audioAt:) → String` (`POST /transcribe`, multipart
m4a, `TranscribeResponse {text}` contract DTO; reuses the narration-length session) +
`FakeBackendClient.onTranscribe`. `LibraryStore.transcribeMemo(_:)` owns the job exactly
like `downloadChapter` (store-owned `transcriptionTasks` keyed by memo id — closing the
reading surface never kills the fetch): `pending → ready` (whitespace-trimmed transcript)
or `error` ("Transcription failed", audio + row kept — recording never depends on the
backend). The SAME call is the retry path (error / stranded-pending rows re-submit);
`ready` rows and in-flight ids are refused. `MemoCapture.onSaved` hands each successfully
saved memo straight to transcription (wired in `makeMemoCapture`; discarded clips never
reach the hook); the saved chip now reads "Voice note saved · transcribing…".

**Wiring:** no new types beyond the DTO — the chapter-status pattern reused end-to-end.
Stranded `pending` rows (app killed mid-fetch) are NOT auto-healed at load (unlike
chapters): retry from Notes (V30) is the recovery, mirroring the Flutter design — noted
for V30 to surface pending-without-task as retryable.

**Evidence:** +8 tests (5 `MemoTranscriptionTests` incl. retry-after-error and the
in-flight guard; onSaved flow incl. discard; contract decode), both suites green both
destinations. **Live round-trip ALL PASS** through the PRODUCTION
`URLSessionBackendClient` against the running backend
([harness-run.log](../../.agent-loop/artifacts/V29/harness-run.log), harness source
alongside): `/speak` rendered the fixture sentence with real Chatterbox (32KB MP3, 33s)
→ `transcribe(audioAt:)` → faster-whisper returned it essentially verbatim ("The quick
brown fox jumps over the lazy dog near the riverbank.") — fox/lazy/dog/river all present.
Commit `8c81b5c`, merged `76d94fa`.

**Device-gated:** nothing new beyond V28's mic-feel items (the transcript pipeline is
fully machine-proven); the visible transcript lifecycle UI (pending/ready/error rows +
retry affordance) is V30's Notes state.

---

## V28 — Hold-to-record voice memos (mic seam + Memo model + recording UI) ✅

**What:** P4's first item, porting the frozen Flutter Plan-5 *design*. Three layers:
1. **Mic seam:** `Audio/RecorderEngine.swift` — the record half of the audio/mic seam
   (apple/CLAUDE.md §Seams): `requestPermission/start/stop/isRecording/level`;
   `AVAudioRecorderEngine` (AAC m4a, metering for the waveform, iOS session juggling
   record↔playback); `FakeRecorderEngine` is the sanctioned double (writes a real temp
   file so the save path is real IO).
2. **Model + capture:** `Memo` @Model (data-model.md P4 slice: chapter cascade-inverse,
   `paragraphIndex` = reading-order index of the narrated block, `positionMs`,
   container-relative `audioPath` under the BOOK's subtree so deletion sweeps it,
   pending/ready/error raw-string status — transcription lands in V29 so rows save
   `.pending`). `Player/MemoCapture.swift` (@Observable) owns the Flutter-contract
   choreography: hold → permission (the system prompt is the primer) → pause narration
   (the pin can't drift) → record; release → save (≥400ms) or discard → resume ONLY if
   it was playing. Recovery: denied phase, recorder-start failure, release-during-
   permission-prompt (the `holdActive` race), cancel-on-surface-close.
3. **UI:** `MemoRecordControl` (sky-glass mic beside the V19 transport; hold gesture =
   short long-press armed then open-ended press via `@GestureState`; VoiceOver start/stop
   actions) + `MemoPuckView` (aqua live-level waveform + clock) which takes the
   transport's slot while recording — the mic stays in the hierarchy throughout (removing
   it mid-hold cancels the gesture — found in self-review). Saved/denied chips on the
   surface, never alerts.

**Wiring:** app-lifetime `AVAudioRecorderEngine` in `VimarshaApp` (the one-mic-owner rule);
`LibraryStore.makeMemoCapture`; `LibraryStackView` creates capture with the player at open
and `cancelHold()`s + releases at close. `ModelContainer` now lists `Memo.self` (additive
migration). Entitlement `com.apple.security.device.audio-input` (macOS) +
`INFOPLIST_KEY_NSMicrophoneUsageDescription` (both configs).

**Scope note:** the roadmap line says "the cluster's Memo control", but a paragraph pin
needs an open chapter + live playhead — screen-flows pins memo record to READING ("Reading
↔ Memo record: hold gesture on the mic control"), and the Flutter reference records in the
player. The mic therefore lives on the reading surface; the library cluster's Memo control
stays a stub until Notes (V30) gives it a sensible target. Flag if this reads wrong.

**Evidence:** 10 `MemoCaptureTests` (real in-memory SwiftData + real file IO; both fakes)
+ 2 snapshot tests (level-reactive waveform, idle-vs-recording mic) — both suites green
both destinations. Artifacts in [`artifacts/V28/`](../../.agent-loop/artifacts/V28/):
`memo-puck-quiet/loud.png` (the waveform visibly reacts) + a launch-rest regression
capture (clean, V41 intact). Commits `6e332f1` (data) + `a506aac` (UI), merged `dd2144c`.

**Visual audit findings:** rest frame unchanged from V41's (same nits: XXXL half-melded
cluster, bottom-edge author clip). The puck renders matte in snapshots (ImageRenderer
can't composite glass) — its live glass + the hold FEEL are device-gated.

**Device-gated:** real-mic hold-to-record feel (gesture arm time 0.25s, waveform
liveliness, session handoff back to narration volume) and the permission prompt flow —
queued for the V31 [verify] deferred checklist.

---

## V41 — Deboss title fade keyed to affordance visibility (no double title) ✅

**What:** the last ui-audit round-1 item. The V24 deboss fade was linear `1 - promotion`,
so at launch rest (promotion ≈ 0.5) the focused cover's printed title sat at half strength
while the metadata reveal (opacity == promotion) repeated the same strings — a double
title; at XXXL the control cluster sat directly on the un-faded deboss. New
`BookFocus.debossTitleOpacity(promotion:)` (pure, smoothstep 1 → 0 over promotion
0…`titleFadeOutPromotion 0.4`): the printed title is fully GONE before the cluster's
effective visibility promotion (≈ 0.53, where `ControlCluster.at(promotion:).isVisible`
first turns on) and while the metadata reveal is still faint — so no state ever shows two
titles or a pill on printed type. Scrubbable, gentle at both ends (slope ~0 at 0 and at
the fade-out point).

**Wiring:** one call site — `BookTower.card` passes
`titleOpacity: BookFocus.debossTitleOpacity(promotion:)` instead of `1 - promotion`
(`LibraryStackView.swift`). `HardbackCoverView` unchanged (still takes `titleOpacity`;
real cover art keeps its own art-title rule). +5 tests in `BookFocusTests.swift`
(`DebossTitleFadeTests`): full at 0/clamped negative, gone at fade-out + the launch-rest
0.5 regression + 1, monotone across the band, the cluster-overlap invariant (∀ promotion
where the cluster is visible, deboss == 0 — sweeps the exact XXXL audit state), eased
near rest.

**Evidence:** both suites green (macOS + iPhone 17 Pro sim). Rest captures medium + XXXL
× dark + light in [`artifacts/V41/`](../../.agent-loop/artifacts/V41/): at medium the
focused blue cover shows ONLY the metadata reveal (deboss gone, both modes); at XXXL the
cluster sits on a blank pink cover (the audit's "pill over un-faded HEY" is gone, both
modes). Commits `bd6d939`, merged `9c4bf6f`.

**Visual audit findings (whole frame, beyond this item's scope):**
- XXXL rest, both modes: the cluster renders **half-melded** (four overlapping circle
  outlines visible inside the capsule) — a designed mid-morph state, but at *rest* it
  reads unresolved/dangling. Candidate: snap emerge toward 1 once visible at rest, or
  raise the visibility floor. File for the next audit round.
- XXXL dark: the unfocused blue card's deboss line "OF DESIGN" tucks under the next
  cover's seam (clipped text-on-seam). Pre-existing layout-vs-overlap nit.
- Bottom shelf card still clips "A SENSE OF PLACE" author line mid-glyph at the screen
  edge — the known round-1 nit (no meniscus treatment yet), unchanged.

**Device-gated:** the live crossfade feel (deboss out / metadata in while scrolling onto
the slot) — folds into the deferred final review like the rest of the P-FIX motion states.

---

## V37 — [blocker] Metadata reveal clamped inside the focused cover ✅

**What:** the ui-audit round-1 blocker (metadata reveal straddling the cover seam,
text-on-text over the neighbor cover). Root causes found and fixed:
1. **Layout-vs-rendered drift:** the V24 affordance anchor used LAYOUT card tops
   (`GeometryReader`), but covers draw under `visualEffect` transforms (StackTransform
   recede + SlotEmit rise + promotion bump, bottom-anchored scale then y-offset) — at rest
   the sink/shrink of below-slot cards made the anchor overshoot by ~30pt. New
   `Library/CardVisualTop.swift` (pure, 5 tests) recomputes the rendered top from the same
   math the card draws with; `BookTower` publishes it as `CardVisualTopKey` and the
   affordances anchor against the seams the user actually sees.
2. **No height bound:** the affordance VStack was bottom-anchored but grew upward without
   limit — at XXXL the metadata crossed the seam onto the cover above.
   `FocusAffordancePlacement.maxHeight` (+5 tests, `insetBelowTop 8`) bounds the stack
   inside the focused cover's own visible band; `ViewThatFits(.vertical)` drops the
   metadata (cluster wins — it's the affordance) when both can't fit; `.clipped()` is the
   hard backstop. VStack spacing 18 → 14 so metadata + cluster fit the medium-type band.

**Wiring:** the V27 top scrim deliberately keeps consuming LAYOUT tops (`CardTopYKey`) —
its visibility was tuned against those in V27; switching it to rendered tops is a separate
re-tune if ever wanted. Hero-settle scale (V25) is outside the per-card math: at rest it's
1.0 (captures unaffected); mid-scroll the anchor can drift ≤6% — invisible in practice
since affordances fade out while scrolling.

**Evidence:** both suites green (macOS + iPhone 17 Pro sim). Rest captures medium + XXXL ×
dark + light in [`artifacts/V37/`](../../.agent-loop/artifacts/V37/): the collision is gone
in all four frames — medium shows metadata fully inside the blue cover; XXXL shows
cluster-only inside the pink cover (metadata correctly yielded). Commits `7cc3797` (math) +
`1b606f0` (wiring), merged `aeb943b`.

**Visual audit findings (whole-frame, beyond this item):**
- Ghost cluster pill still floats mid-cover at medium rest (V39, this batch).
- Double title at medium rest: the reveal overlays the un-faded debossed title (V41).
- Light mode: metadata `textPrimary` resolves to ink — dark text on the dark-blue focused
  cover, poor contrast (V38's plate will carry it).
- XXXL cluster pill reads grey/pink, untinted (V40).
- Bottom shelf cover still clips its author line at the screen edge (known nit, unfiled).

**Device-gated:** mid-scroll affordance tracking feel (anchor follows rendered seams during
recede/emit) — rolls into the next live-scroll review.

---

## V38 — Metadata reveal legibility plate ✅

**What:** `FocusMetadataView` gains a backing plate so the token text never rides bare
cover art (ui-audit: white-on-pink ≈2:1 both modes; light mode was worse — `textPrimary`
resolves to ink, i.e. dark text straight on the dark-blue cover). Glass path:
`.regular.tint(Palette.sky.opacity(0.30))` in a continuous rounded-rect, deliberately
**not** `.interactive()` (the reveal is decorative, not a control); Reduce Transparency:
`Palette.surface` matte. Author-line opacity 0.6 → 0.7 for the same reason.

**Wiring:** plate paddings tight (18h/8v) and the affordance VStack spacing 14 → 12 so
metadata + cluster still fit the medium-type band V37 clamped (the V37 `ViewThatFits`
guard means an oversized plate would silently drop the metadata — checked the capture to
confirm it didn't). `BookFocusSnapshotTests` renders the matte-plate path (ImageRenderer
can't composite live glass — same convention as cluster/puck snapshots).

**Evidence:** both suites green. Rest captures dark + light in
[`artifacts/V38/`](../../.agent-loop/artifacts/V38/): the plate reads as a cool sky band
under the serif title in both modes, text legible over the blue cover. Commit `c968968`,
merged `bd703af`.

**Visual audit findings (whole-frame):** plate at rest sits at partial reveal opacity
(~0.45) — legible but soft; full settle strengthens it. Ghost pill (V39) + grey XXXL pill
(V40) + double-title (V41) unchanged, as scoped. Bottom-edge author-line clipping nit
persists.

**Device-gated:** glass refraction strength of the plate over busy real cover art — next
live review.

---

## V39 — Ghost control cluster fully gated ✅

**What:** the ui-audit residual-ghost fix. `ControlCluster.emerge` is a continuous curve,
so a half-settled book (launch rest, promotion ≈ 0.5 → emerge ≈ 0.2) leaked a ~20px melded
glass pill mid-cover because the view rendered `opacity == emerge`. `ControlCluster` gains
`visibilityFloor` (0.25 on emerge), `isVisible`, and a remapped `opacity` (0 exactly at the
floor → 1 at full emerge, linear); `ControlClusterView` renders **nothing** below the floor
— opacity 0 AND removed from the hierarchy, per the roadmap fix direction. The insertion
can't pop: opacity is 0 at the moment the subtree appears. +4 `ControlClusterTests`
including a regression test pinning the exact audit state (`at(promotion: 0.5)` partially
emerged but not visible).

**Wiring:** the gate composes with V37's `ViewThatFits` (an invisible cluster leaves just
the metadata, which bottom-anchors into the band) and doesn't touch the hit-test /
accessibility guards (emerge > 0.5, unchanged).

**Evidence:** both suites green. Captures in
[`artifacts/V39/`](../../.agent-loop/artifacts/V39/): medium rest dark + light — ghost
gone, metadata plate now sits alone near the cover's visible bottom (reads cleaner);
XXXL light — the legitimately-settled cluster still renders fully fanned. Commit
`4b95f07`, merged `e0d2b46`.

**Visual audit findings (whole-frame):** with the cluster gated at medium rest, the
double title (V41) reads less colliding but is still a double title — the V41 fix
direction ("fade deboss when any focus affordance is visible") should key off the
metadata reveal too, not just the cluster. XXXL pill tint still grey-over-pink (V40,
next). Bottom-edge author clipping nit persists.

**Device-gated:** the cluster's appear/disappear during live scroll (crossing the floor
mid-gesture should read as a clean morph-out, not a pop) — next live review.

---

## V40 — Cluster glass tint (sky pill, token icons, fan that splits) ✅

**What:** the ui-audit "untinted grey pill" had THREE causes, all fixed in
`ControlClusterView`:
1. **Tints too weak to own the surface** over light covers — sky 0.26 → 0.45, aqua
   0.32 → 0.52 (third raise; V24's 0.26 still lost to the pink cover).
2. **Glass adapts content rendering to the cover's luminance**, flipping the mode-aware
   `textPrimary` icons dark over the light pink cover (the audit's "monochrome dark-grey
   icons" in dark mode). Glass path now uses `Palette.ink0` icons — the palette's own
   ink-on-sky pairing, cover-independent; the Reduce Transparency matte keeps
   `textPrimary` on `surface`.
3. **The XXXL diameter (~100pt, unclamped ScaledMetric) outgrew the fixed 64pt fan
   spacing**, so the four controls could never split — one permanently melded pill at
   large type. Diameter clamps at 68 (icon 24; still a generous touch target), spacing
   derives from it (`diameter + 14`).

**Found + fixed en route (V37 regression):** the fan is rendered with `offset`, which
doesn't grow layout — the cluster's layout box stayed ONE circle wide, and V37's
`.clipped()` backstop amputated the outer controls at full emerge (invisible until now
because the V39-gated rest state never reaches full emerge; the forced-emerge capture
exposed it). The cluster now declares its fan width as its layout frame.

**Evidence:** both suites green. Forced-emerge (`ControlCluster(emerge: 1)`, temp, then
reverted — the V24 precedent) over the pink cover at XXXL, dark + light, in
[`artifacts/V40/`](../../.agent-loop/artifacts/V40/) (`crop-emerged-*.png`): four distinct
glass controls, aqua play + sky trio, crisp ink icons, no clipping. Rest-state
regression capture clean (`05-rest-medium-dark.png`). Commit `5ee1fcf`, merged `ba000b7`.

**Visual audit findings (whole-frame):** at XXXL the fan (~314pt) slightly overhangs the
281pt cover's side edges — reads as floating glass, acceptable, but worth an eye in the
next human pass. Sky tint over pink refracts slightly violet (physics of tinted glass —
the tint reads, not grey). Double-title (V41) and bottom-edge clipping nit unchanged.

**Device-gated:** live meld/split during scroll-settle with the new derived spacing
(the blob should split later/cleaner now) — next live review.

---

## V21 — [verify] Eyes-free run ✅ (machine half; human review deferred to final)

**What:** the P3-closing verify gate, run as far as a machine can take it. A standalone
harness (`.agent-loop/artifacts/V21/harness/main.swift`, the V13/V15 spike-harness
precedent) compiled the **production** client files — `BackendClient.swift`,
`ChapterBundle.swift`, `ChapterDownloader.swift`, `TimingIndex.swift`,
`AudioEngine.swift` — and drove the real core loop against the live local backend
(real Chatterbox on MPS):
1. **Live pipeline through the production seam:** `/toc` (1 chapter) → `/import` via
   `ChapterDownloader` (50s warm; all-or-nothing cache layout) → real `bundle.json` +
   `chapter.mp3` on disk.
2. **Highlight tracks (machine equivalent):** every timed block (9/9) owns its span
   midpoint via `TimingIndex.currentBlockId`; a 100ms sweep of the whole chapter is
   monotonic in reading order.
3. **Figures pop on cue:** all spanned figures (3/3) active at span midpoints, zero
   leaks past `endMs`.
4. **The eyes-free listen:** the real cached MP3 through the real
   `AVFoundationAudioEngine` — duration matches the last paraTiming (±64ms), seek
   lands, rate 2.0, then the WHOLE chapter **played through to `onFinish`** with a
   250ms ticker recording the live block/figures at every tick: every timed block was
   the live highlight at some tick (9/9), every spanned figure popped (3/3), playhead
   monotonic mid-play.
5. **Resume + offline replay:** post-finish reload + mid-chapter seek holds; a fresh
   engine + TimingIndex replays purely from cache (backend untouched).
**ALL PASS** — [`harness-run.log`](../../.agent-loop/artifacts/V21/harness-run.log).

**Found + fixed (the gate doing its job):**
- **Real client bug:** `URLSessionBackendClient` used `URLSession.shared`, whose **60s
  idle timeout kills any real `/import`** — narration is minutes of server silence
  (V15's live half went through `curl`, so the production path had never been
  exercised). First harness run failed with `NSURLErrorDomain -1001`. Fix:
  `narrationSession` (`timeoutIntervalForRequest = 30min`) as the client default +
  a guard test (`defaultSessionOutlivesRealNarrationTimes`). Branch
  `fix/v21-import-timeout`, commit `0e9a007`, merged `187a287`.
- **Recorded race (not fixed, by scope):** after a natural end `AVAudioPlayer` resets
  `currentTime` to 0 *before* the delegate's MainActor hop lands — one
  `PlayerController.tick()` can read position 0 (flicker the highlight to block 1, even
  persist 0) before `handleFinish` pins the position to the end. Transient and
  self-correcting (finish persists last), but worth a one-line guard in a polish item:
  ignore ticks when `!engine.isPlaying`.

**Wiring:** no app code changed beyond the timeout fix. Suites re-run green on merged
`main` both destinations (macOS + iPhone 17 Pro) — before and after the fix merge.

**Evidence:** [`artifacts/V21/`](../../.agent-loop/artifacts/V21/) — `harness/main.swift`
(the exact program run) + `harness-run.log` (ALL PASS, 15 checks). Suite outputs in the
loop transcript. No new captures — no visual surface changed; V20's captures stand.

**Deferred to the final human review** (appended to
[final-review-checklist §V21](final-review-checklist.md), per the 2026-06-11 directive):
the with-ears listen (does the wash land on what you HEAR), auto-scroll/figure-pop feel,
gallery round-trip + V20 morphs, transport under fingers, offline-UX honesty, real
`GET /image` figures (needs an illustrated EPUB — fixture gap carried from V15), and the
V20 light-mode polish calls.

---

## V20 — Figure overlay on the glass carrier + Figures gallery ✅

**What:** the synced-figures half of the core loop (apple/CLAUDE.md §UI map state 4 /
glass moment #8) — auto-pop at `startMs`, recede at `endMs`, stacked when spans overlap;
the gallery as a morphed grid state. Flutter `FigureOverlay`/`FiguresGallery` design
ported, not the code.
- `Reading/FigureOverlaySelection.swift` — pure stack rules (6 tests): the selection over
  the active set survives ticks while the set is stable (key = joined figure ids), resets
  to the top card when the set changes, recovers a stale out-of-range index, and pages
  with wrap-around (`next`/`previous`).
- `PlayerController.activeFigures` (spans containing the playhead, via the V18
  `TimingIndex` — unresolved nil-ms figures never activate) + `allFigures` (the whole
  figureMap regardless of timing — the gallery's source). +2 tests on a new
  `figuredFixture` bundle.
- `Reading/FigureCarrierView.swift` — the glass carrier: aqua-tinted glass FRAME
  (live/active role), the figure image itself **matte paper** inside it (the rule's one
  sanctioned content-adjacent glass case); caption-only fallback (downloader best-effort
  parity); label line + wrap-around pager ("1 / 2" + chevrons) when stacked, with matte
  backing edges peeking behind the top card (depth = scale+offset+shadow, no blur).
  Reduce Transparency = token-tinted matte + aqua stroke. 3 snapshot tests.
- `Reading/FiguresGalleryView.swift` — the morphed grid state (never a sheet): paper
  reflows into matte figure tiles (`FigureGridView` extracted for ImageRenderer — the
  V14 ScrollView gotcha); tap a tile → `seekToBlock(startPara)` + morph back to reading;
  timed figures carry a small aqua waveform glyph; honest "No figures in this chapter".
  2 snapshot tests.
- Wiring in `ReadingSurfaceView`: the carrier rides the bottom overlay VStack above the
  V19 transport (pop/recede = interruptible spring keyed on the active-set identity;
  insertion rises from the bottom with scale 0.92; Reduce Motion cross-dissolves). The
  rendered selection is *derived* every frame (`reconciled(figurePaging, with:)`) —
  state only remembers paging. Gallery toggles via a new glass control top-trailing
  (shown only when the chapter has figures; icon flips to "back to reading"); narration
  keeps playing in the gallery; the carrier hides there (the grid already shows every
  figure). Close chevron refactored into a shared `glassControl`.

**Evidence:**
- Both suites `** TEST SUCCEEDED **` (macOS + iPhone 17 Pro). +13 tests (6 selection
  rules, 2 player figure props, 3 carrier snapshots incl. paging swaps the top card,
  2 gallery snapshots).
- Forced-state sim captures (temp `V20CaptureRoot` root via launch-arg switch, reverted;
  binary 17:17): [`artifacts/V20/`](../../.agent-loop/artifacts/V20/)
  `01-carrier-dark` / `02-gallery-dark` / `03-carrier-light` / `04-gallery-light` —
  **looked at:** real-glass aqua carrier floating over the serif body with matte figure
  + pager in both modes; gallery grid with FIGURES masthead, matte tiles, transport
  persisting underneath.
- Commits `2cd0d6e` (rules) `784d93c` (player) `269ec6d` (carrier+wiring) `17c158c`
  (gallery), merged `a893402`.

**Visual audit findings (whole frame):**
- In the forced frame the carrier overlaps the live paragraph's last line — live, the
  auto-scroll anchor (0.3) should hold the narrated block above it; judge in V21 and
  consider growing the body's bottom padding while the carrier is up if it bites.
- Light-mode gallery tiles read **loud saturated aqua** (`Palette.surface` light = aqua
  secondary-surface role) — token-correct but heavier than the editorial calm elsewhere;
  candidate polish: a quieter butter-derived tile. Also the aqua waveform glyph is
  near-invisible **aqua-on-aqua** in light mode (fine in dark).
- Carried: V17 plate subtitle truncation; rest-state metadata ghost.

**Device-gated (→ V21 verify):** the pop/recede *feel* over a REAL playing chapter
(spring character, stacking with real overlapping spans, paging mid-play), gallery
morph + tap-to-seek round-trip, and real `GET /image` figure images (the V15 fixture
gap — needs an illustrated EPUB).

---

## V19 — Tap-to-seek + compact glass transport ✅

**What:** the reading surface becomes drivable — seek by touching the text, transport on
glass (apple/CLAUDE.md §UI map state 3: "transport lives in a compact glass cluster, not
a chrome bar").
- `Reading/Transport.swift` — pure rules (4 tests): the speed ladder
  `[0.75, 1, 1.25, 1.5, 1.75, 2]` cycling/wrapping (off-ladder values recover to the
  ladder), `skipMs 15_000`, `timeString` (m:ss / h:mm:ss, negative clamps), speed-chip
  labels ("1×"/"1.25×").
- `PlayerController.seekToBlock(_:)` — tap-a-paragraph-to-seek through the `TimingIndex`;
  untimed blocks (figures, un-narrated headings) are not seek targets (no-op). +2 tests.
- `Reading/TransportClusterView.swift` — ONE glass capsule (deliberately no
  glass-in-glass nesting): slim **butter** progress line + monospaced clocks (paper
  readout), back-15 / **aqua play-pause pill** (the live/active accent riding ON the
  glass) / forward-15 / speed chip. Reduce Transparency = token-tinted matte + sky
  stroke. Full VoiceOver labels; the speed chip hints its cycling.
- `ReadingBlocksView` text rows: `contentShape` + tap → `onTapBlock` + an explicit
  **"Read from here"** accessibility action (gesture-only interactions must have one).
- Wiring: the cluster floats `overlay(alignment: .bottom)` over the paper body (max 380w)
  only when a chapter is loaded; play/pause/skip/rate bind straight to the player; the
  V18 bottom padding (150) keeps the last lines clear of it.

**Evidence:**
- Both suites `** TEST SUCCEEDED **` (macOS + iPhone 17 Pro). +9 tests (4 Transport, 2
  seekToBlock, 3 `TransportClusterSnapshotTests`: play/pause glyphs differ, the playhead
  moves the butter line, the rate chip renders the ladder).
- Forced-state sim captures (temp root, reverted; fresh binary 17:01):
  [`artifacts/V19/01-transport-forced-dark.png` + `02-…-light.png`](../../.agent-loop/artifacts/V19/)
  — **looked at:** real-glass capsule over the serif body in both modes; butter progress
  + aqua pause pill + "1.25×" chip legible on ink and butter canvases.
- Commits `b20b20e` (rules) `1aaafc2` (seekToBlock) `6469910` (cluster+wiring),
  merged `b4b67fb`.

**Visual audit findings (whole frame):** none new — the cluster sits clear of the body
text; light-mode glass reads pale aqua-green (consistent with the "+"/cluster tints).
Carried: V17 plate subtitle truncation; rest-state metadata ghost.

**Device-gated (→ V21 verify):** live tap-to-seek + transport over a REAL playing chapter
(playhead motion, highlight cadence, speed change mid-play, skip clamps at the ends) —
no sim tap injection; everything is unit/snapshot-proven here.

---

## V18 — Reading body: blocks + narration highlight + auto-scroll ✅

**What:** the core-loop reading surface — the cached bundle rendered and synced to the
playhead (Flutter `ReadingView` design ported, not the code):
- `Reading/TimingIndex.swift` — the ONE `paraTimings`/figure-span lookup owner
  (app-architecture.md: "never four parallel implementations"): `currentBlockId(atMs:)`
  (latest start ≤ ms — the Flutter `_recompute` rule, deterministic reading-order
  tie-break), `startMs(forBlock:)` (tap-to-seek, V19 consumes), `activeFigures(atMs:)`
  (closed spans; unresolved nil-ms figures never activate — V20 consumes),
  `blockIndex(forId:)`. Pure value math, 8 tests.
- `PlayerController` grows content: `load()` decodes `bundle.json` (the content source
  of truth) BEFORE touching the engine (a failed decode loads nothing), builds the
  `TimingIndex`, exposes `currentBlockId` off the live playhead, and decodes cached
  figure images **off-main at load, never during scroll** into `blockImages` keyed by
  source block id (backend `figure_id = block.id`; `LibraryStore.covers` precedent).
- `Reading/ReadingBlocksView.swift` — typed blocks as matte paper: serif body
  (New York warmth) with `lineSpacing 6`, headings by `level`, blockquote/pullquote
  italic behind a slate rule, **figures inline as paper** (matte rounded image +
  quiet caption; caption-only when no image cached — downloader best-effort parity),
  table/list degrade to their text. The narrated block carries the new
  `Palette.narrationHighlight` wash (butter glow 0.13 on ink / aqua wash 0.40 on
  butter — both modes' "highlight/progress" roles).
- `ReadingSurfaceView` — the body replaces the ready mark when a player has the bundle:
  cover plate + masthead scroll away with the text (max content width 600), close
  chevron pinned; **auto-scroll** follows `currentBlockId` (anchor y=0.3, ease 0.35s,
  4s user-scroll cooldown via `onScrollPhaseChange(.interacting)`, no re-scroll to the
  same block, Reduce Motion jumps instead of glides) and lands on the resume block at
  open without animating through the chapter.
- Wiring: `LibraryStore.makePlayer(engine:)`; `LibraryStackView` holds the open
  chapter's player (created at open — an unreadable cache refuses to open a dead
  surface; close **pauses + releases** the controller, never the shared engine);
  `VimarshaApp` hands the app-lifetime engine down.

**Evidence:**
- Both suites `** TEST SUCCEEDED **` (macOS + iPhone 17 Pro). +12 tests: 8
  `TimingIndexTests` + 4 `PlayerControllerTests` (bundle decoded + timing built, live
  block follows ticks/seeks, resume lands in the right block, missing bundle file fails
  the load) on a REAL bundle.json written to a temp container.
- `ReadingBlocksSnapshotTests` (2): highlight visibly renders + moves block-to-block;
  PNG **looked at** ([`artifacts/V18/18-reading-blocks-live.png`](../../.agent-loop/artifacts/V18/)).
- Forced full-frame sim captures (temp root, reverted): `01-reading-body-forced-dark.png`
  + `02-…-light.png` — **looked at:** masthead, serif body, butter/aqua wash on the live
  paragraph, slate-ruled quote, quiet caption; clean both modes. Rest regression
  `03-rest-dark.png` (fresh binary 16:54): stack unchanged.
- Commits `11a2737` (TimingIndex) `c5fe0f9` (player content) `ffa8e4a` (body+wiring),
  merged `31ad540`.

**Visual audit findings (whole frame):**
- Caption-only figure rows (no cached image) read slightly orphaned between text blocks —
  acceptable degraded path; revisit if real books show many image-less figures.
- Carried: plate subtitle truncation (V17 finding); mid-stack metadata ghost at rest.

**Known debt / device-gated (→ V21):** body uses a plain `VStack` (scrollTo-to-unbuilt-row
correctness over LazyVStack memory) — fine for normal chapters, profile on a huge one;
auto-scroll *feel* (cooldown, anchor, glide) and the live highlight cadence need a real
playing chapter on device; `onAppear` scrollTo assumes laid-out rows (verify deep-resume
live).

---

## V17 — Cover→reading-surface morph ✅

**What:** the Prime-Directive transition — the focused hardback opens into the reading
canvas as a state of the one surface (screen-flows: "the cover is the shared element —
hardback opens into the canvas (matched geometry); back-morph on close, never a
dismiss-pop").
- `Reading/ReadingSurfaceView.swift` — the opened-book shell: small cover plate (the
  shared element, ~0.40w cap 200), "CHAPTER NN" small-caps + chapter title in the
  editorial serif (matte paper), glass close-chevron (sky interactive tint, matte
  fallback), and an honest aqua-waveform "NARRATION READY" mark holding the spot the
  narrated body (V18) + transport (V19) fill next.
- **The morph:** `@Namespace coverMorph` in `LibraryStackView`; each tower card carries
  `matchedGeometryEffect(id: "cover-<shelfId>", isSource: openedBookId != book.id)` and
  hides (`opacity 0`) while its book is open — the hardback "leaves" the stack, flies to
  the plate, and back-morphs on close (card regains source). The canvas itself
  cross-fades (`.opacity` transition); spring `response 0.5 / damping 0.88`,
  interruptible. **Reduce Motion:** cross-dissolve only (no matched geometry, `nil`
  namespace), per the discrete-state-morph fallback rule.
- **Trigger:** `ChapterListView` ready rows are now actionable (`onOpen`); pending stays
  inert (the spinner is the story). Opening closes the chapter plane in the same
  animation beat (`openReadingSurface`: only `ready` chapters pass). VoiceOver: ready
  rows read "ready, double-tap to read".
- `ReadingContext` carries `{book, chapter, shelfBook}` from the opening moment — V18
  loads the cached bundle + audio off those rows.

**Wiring:** one new full-viewport overlay above the chapter plane; nothing else moved.
Seeds never reach it (no chapters → no plane → no open).

**Evidence:**
- Both suites `** TEST SUCCEEDED **` (macOS + iPhone 17 Pro sim).
  `ReadingSurfaceSnapshotTests` (ImageRenderer): distinct chapters render distinct
  rasters; PNG written + looked at.
- Forced-state sim captures (V07 precedent: root temporarily swapped to the surface,
  reverted after): [`artifacts/V17/01-reading-forced-dark.png` + `02-…-light.png`]
  (../../.agent-loop/artifacts/V17/) — **looked at:** glass chevron top-left, blue
  hardback plate with fore-edge + gilt, serif masthead, aqua ready mark; clean on both
  ink and butter canvases.
- Rest regression capture (`03-rest-dark.png`, fresh binary 16:38): the stack renders
  identically with the matched-geometry modifiers attached — no rest-state change.
- Commits `c6d1f4f` (surface) `2924665` (morph wiring), merged `bc125a2`.

**Visual audit findings (whole frame):**
- The cover plate's debossed *subtitle* truncates with an ellipsis at plate width
  ("FOR A NEW HISTORY OF DE…") — `HardbackCoverView` prints full subtitle regardless of
  width. Candidate polish: hide/scale the subtitle below a width threshold (also affects
  V18's persistent plate if kept).
- Carried (pre-existing): faint "Hey / DESIGN & ILLUSTRATION" metadata ghost mid-stack
  at rest — the reveal's missing emerge threshold; unchanged by V17.

**Device-gated (→ V21 verify):** the morph *feel* — card→plate flight, interruptibility,
back-morph landing — needs a real tap (no sim gesture injection); the matched frame is
the card's **layout** frame (visualEffect transforms are render-only), so the flight
origin can sit slightly off the visually-transformed cover when promotion < 1 — judge
live whether it reads as "the cover opening".

---

## V16 — Audio engine (seam + player controller) ✅ (P3 opens)

**What:** the playback half of the core loop, design-ported from the frozen Flutter
`PlayerController`/`AudioHandler` pair:
- `Audio/AudioEngine.swift` — the audio seam (the **second of exactly two** sanctioned
  doubles): `load(url) → durationMs`, `play/pause/seek(toMs:)/setRate`,
  `positionMs/durationMs/isPlaying`, `onFinish`. Integer-millisecond API throughout (the
  contract's unit). Real impl `AVFoundationAudioEngine` = `AVAudioPlayer` over the cached
  chapter file: `enableRate`, rate persists across loads, delegate finish hops to
  MainActor; iOS sets the `.playback`/`.spokenAudio` session at load (macOS needs none).
- `Player/PlayerController.swift` (@Observable) — `load(_ chapter:)` (only `ready` +
  `audioPath`; throws `LoadError.chapterNotReady`), restores `Chapter.progressMs` clamped
  to `[0, duration]` (no seek at 0), records true `durationMs` on the row (scrubber
  length); `play/pause/togglePlayPause/seek/skip/setRate`; a 250ms ticker Task pulls the
  playhead while playing and persists every **5s of movement** (Flutter's save throttle),
  plus persist on `pause()` and natural finish (position pinned to the end). Paragraph/
  figure derivation deliberately NOT here — `TimingIndex` owns that in V18
  (app-architecture.md §Figure & timing flow).
- **Shared-player rule honored:** the controller pauses the engine, never disposes it;
  `VimarshaApp` owns the ONE app-lifetime `AVFoundationAudioEngine` (@State).
- `VimarshaTests/FakeAudioEngine.swift` — the sanctioned double: hand-advanced playhead
  (`advance(byMs:)`/`finish()`), recorded seeks/rate/loads.

**Wiring:** none UI-visible yet by design — V17 morphs the surface open, V18 wires the
controller + bundle into it. The engine instance simply exists app-lifetime from now on.

**Evidence:**
- Both suites `** TEST SUCCEEDED **` (macOS 155 test cases + iPhone 17 Pro sim). +16
  tests: 4 `AVFoundationAudioEngineTests` against a **real generated WAV** (spec-minimal
  PCM bytes — duration ±50ms, missing-file throw, seek, play/pause `isPlaying`; the real
  impl tests real, the double is for consumers) and 12 `PlayerControllerTests` on real
  in-memory SwiftData (duration recorded on row, resume/no-seek-at-0/stale-progress
  clamp, non-ready rejected, play-pause mirror, pause persists, **tick throttling** (3s
  no save → 6s saved), seek/skip clamps, rate forward, finish persists at end).
- Review fix: the ticker loop now exits (not just no-ops) when the controller
  deallocates mid-play — no orphaned forever-loop Task.
- Commits `01d22b5` (seam+impl) `79122ff` (controller) + ticker fix, merged `424264e`.

**Device-gated (→ V21 verify):** real MP3 playback feel (rate change mid-play,
AVAudioPlayer seek-while-playing behavior), audio session/route behavior. No captures —
no visual surface changed this item (rest frames would be byte-identical to V15's).

---

## V15 — [verify] Real EPUB end-to-end 🚧 (machine half done; NEEDS HUMAN)

**What (machine-verified):** the full P2 pipeline proven against the **live local backend**
(real Chatterbox on MPS, `uvicorn vimarsha.server:app --port 8000`):
- `POST /toc` with `shared/fixtures/sample.epub` → book meta + 1 chapter
  ([`artifacts/V15/toc.json`](../../.agent-loop/artifacts/V15/toc.json)).
- `POST /import?chapter_index=0` → full narrated bundle in **3m18s** (real MPS synth):
  9 blocks, 3 figures with ms spans, paraTimings for all 9 blocks
  ([`bundle.json`](../../.agent-loop/artifacts/V15/bundle.json)).
- `GET /audio/chap1.mp3` → valid MPEG-III mono 24kHz, **24.576s** — consistent with the
  last paraTiming (24520ms; timings exact-by-construction holds live)
  ([`chapter.mp3`](../../.agent-loop/artifacts/V15/chapter.mp3)).
- **The live bundle decodes through the client's actual `ChapterBundleDTO`** (compiled
  `apple/Vimarsha/Backend/ChapterBundle.swift` standalone against the live JSON) and
  survives the downloader's re-encode round trip losslessly.
- Both suites green on merged `main` (macOS + iPhone 17 Pro sim) after the V14 merge.

**Why the rest is human:** the on-device half needs gestures the loop can't inject —
document-picker tap ("+" → pick a real EPUB), scroll-to-focus, Play-tap (chapter plane),
chapter-row tap (download), relaunch check.

**Human run-book (the V15 sign-off):**
1. Backend up: `cd backend && uv run uvicorn vimarsha.server:app --port 8000` (needs
   `uv sync --extra tts` once). It was running during the machine half.
2. Launch the app (iPhone 17 Pro sim or macOS), tap the glass "+", pick a **real EPUB
   with a cover** (the V11 Penguin/Atomic-Habits downloads are no longer on disk — any
   real book works; sample.epub at `shared/fixtures/` works but has a generated cloth
   cover and no images).
3. Check: real cover art renders on the hardback in the stack (V11/V12); scroll the book
   to focus → Play raises the **chapter plane** (V14) listing the `/toc` chapters; tap a
   chapter → aqua spinner for **minutes** (MPS is ~7–8× slower than realtime; the model
   also reloads per request — known debt Q-SYNTH) → filled aqua check.
4. Relaunch: the chapter stays `ready` (self-heal only fires if cache files vanish).
5. Error path: a part-divider/empty chapter should land as retry + "Narration failed"
   (backend raises for un-narratable chapters).
6. Both modes (dark canonical + light), Reduce Transparency matte plane if convenient.

**Findings / limitations for the record:**
- `sample.epub` contains **no image files**, so its figures' `image` stays null
  (backend `extract_images` skips unresolvable assets) — the live `GET /image` caching
  path is **unverified live**; verify with a real illustrated book (V20/V21 needs it
  anyway).
- Carried visual-audit finding (pre-existing, also in the V26 sign-off captures): the
  focus metadata reveal renders faintly mid-stack at launch rest (stray
  "Hey / DESIGN & ILLUSTRATION" over the cards) — the reveal's opacity has no emerge
  threshold like the cluster's. Candidate one-line fix in a polish item.
- Housekeeping: crashed test runs leave `LibraryStoreTests-*` temp dirs in the macOS
  test host's sandbox container tmp (`~/Library/Containers/com.vimarsha.apple/Data/tmp`);
  harmless, purge if disk matters.
- No delete-book UI affordance exists yet (store API only) — fine for V15, worth a row
  in a later polish item.

---

## V14 — Lazy chapter download + status UI ✅

**What:** one chapter narrates and caches on demand; the chapter list surfaces the
lifecycle honestly.
- `Backend/ChapterBundle.swift` — `ChapterBundleDTO`/`BlockDTO`/`FigureDTO` mirror
  `shared/bundle.schema.json` exactly (camelCase, nullable `audio`, `paraTimings`
  defaulting `{}`; block/figure `kind` stays a raw string so a future backend kind
  degrades instead of failing the decode). Lossless encode round-trip (the cached JSON
  is the content source of truth, data-model.md §Rules).
- `BackendClient` grows the download trio: `importChapter(epubAt:chapterIndex:)`
  (multipart + `chapter_index` query — the FastAPI signature), `downloadAudio(named:)`,
  `downloadImage(named:)`; shared HTTP-status validation. `FakeBackendClient` grows
  matching closures + `.narrating()`/`.fixture()` presets (unconfigured endpoints fail
  loudly; defaults are static funcs — closure-literal defaults get MainActor-inferred
  under the project's default isolation and won't compile).
- `Backend/ChapterDownloader.swift` — `/import` → `chapters/<index>/bundle.json` +
  `chapter.mp3` + best-effort `images/<name>` (backend-supplied names reduced to
  `lastPathComponent` — never a path), **all-or-nothing**: nil-audio (`noAudio`) and
  empty-audio (`emptyAudio`) rejected, any failure removes the partial chapter dir.
- `LibraryStore.downloadChapter` — `none/error → pending → ready/error("Narration
  failed")`; the job is a **cancellable store-owned Task** (`downloadTasks` by chapter
  id; `deleteBook` cancels; a cancelled job never touches the row — it may be deleted).
  `load()` self-heals: `ready` with missing cache files → `none` (+paths nil), orphaned
  `pending` (relaunch killed the job) → `none`.
- `Library/ChapterListView.swift` — the chapter plane: a glass-backed list plane
  (sky-tint `glassEffect`, the sanctioned "morphed list state" — never a sheet) with
  matte serif rows; status affordances: download arrow (sky) → spinner (aqua, live) →
  filled check (aqua) / retry + reason. Whole row tappable when actionable;
  non-actionable rows are NOT disabled Buttons (a disabled plain Button dims the title
  and `ready` must not read inactive). Reduce Transparency matte fallback.

**Wiring:** the focused book's **Play** control raises the plane (the stand-in trigger
until the audio engine V16 / reading morph V17 take it over; seeds have no chapters →
no-op). Backdrop-tap or X closes. Rise/settle is an interruptible spring from the bottom
(where the cluster lives); Reduce Motion gets the cross-dissolve (discrete-state-morph
rule). `focusedBook` maps `focus.index` straight into `store.books` (shelf mirrors it
one-to-one when non-empty).

**Evidence:**
- Both suites green (macOS + iPhone 17 Pro sim). +18 tests: 5 contract
  (bundle decode incl. null audio, cache round-trip, import URL query), 6
  `ChapterDownloaderTests` (cache layout + relative paths, images cached/best-effort,
  noAudio/emptyAudio/network-failure leave nothing), 7 `LibraryStoreTests` (ready+paths
  recorded, error+reason, retry-from-error only, **deleteBook cancels in-flight** (60s
  fake import returns promptly only when cancelled), ready-missing-files heal, orphaned
  pending heal, healed-ready survives when files exist).
- `ChapterListSnapshotTests` (macOS `ImageRenderer`): all-four-statuses vs all-fresh
  rasters differ; PNGs **looked at** — `08-chapters-lifecycle.png` shows arrow/spinner-
  placeholder/aqua-check/retry+reason rows at full title contrast. Artifacts in
  [`artifacts/V14/`](../../.agent-loop/artifacts/V14/).
- Live launch (iPhone 17 Pro sim, fresh binary): rest captures dark+light
  (`01-rest-dark.png`/`02-rest-light.png`) — stack/header/scrim unchanged, no V14
  regression at rest.
- Commits `16b7d77` (seam) `d489112` (downloader) `6105b5b` (store) `bdb4c22` (UI),
  merged `fd320ed`.

**Gotchas hit (recorded so nobody relearns):**
- A SwiftData `ModelContainer` created in a test helper and not returned/held got
  deallocated before `ImageRenderer` ran → `Book.title` getter asserted (crashed the
  whole parallel test process — unrelated suites "failed" at 0.000s). Hold the container.
- An **unsaved** to-many relationship can momentarily read back empty → both snapshot
  variants rendered zero rows and compared equal (flaky). `save()` before rendering.
- `ImageRenderer` does not rasterize `ScrollView` content (header drew, rows blank) —
  rows extracted into `ChapterRowsView` and snapshot directly.

**Device-gated (→ V15 verify):** opening the plane needs a real tap on the Play control
(promotion ~0 at launch rest; no sim gesture injection), live download progress over a
real backend, and the spinner (ImageRenderer draws a placeholder glyph for
`ProgressView`).

**Visual audit findings (whole-frame, beyond V14's scope):**
- Pre-existing (identical in the signed-off V26 captures): at launch rest the focus
  metadata reveal renders faintly mid-stack — a stray "Hey / DESIGN & ILLUSTRATION"
  floats over the DAVID CROW/HEY cards (promotion is partial at rest, and the reveal's
  opacity has no emerge threshold like the cluster's). Reads as accidental double text;
  carried to the V15 review list.
- Light mode: same float, plus the seed covers' debossed subtitles double with the
  reveal text in the same eyeline. Same root cause.

---

## V13 — `BackendClient` seam + `POST /toc` ✅

**What:** the network seam exists and import talks to the real backend.
- `Backend/BackendClient.swift` — the protocol (Sendable; grows one endpoint per V-item,
  V13 = `fetchToc(epubAt:)`), the `/toc` contract DTOs (`TocResponse`/`BookMetaDTO`/
  `ChapterSummaryDTO`, camelCase `chapterId`, author defaults `""` — mirrors
  `backend/src/vimarsha/models.py`), `Multipart` (single-file form-data builder, unique
  boundary per request — `/toc`/`/import`/`/transcribe` all need it), and
  `URLSessionBackendClient` (default `http://localhost:8000`; a settings surface mirrors
  Flutter `AppSettings` later).
- `LibraryStore.addBook` is now the full Flutter `LibraryRepository.addBook` port:
  copy → cover → **`/toc`** → persist book + chapter rows (status `.none`) in one save —
  **all-or-nothing**: backend failure rolls the copied files back, no row, honest
  `importError`. Backend meta is the authority; OPF `EpubInfo` fills empty fields
  (last resort: filename).
- `VimarshaTests/FakeBackendClient.swift` — the sanctioned network double
  (closure-configured struct; `.returning(...)` / `.failing()` presets).

**Evidence:**
- Both suites green. 4 `BackendClientTests` (contract decode incl. missing-author,
  byte-exact multipart body, unique default boundary); `LibraryStoreTests` reworked
  (+2): toc-driven persist (chapters land, backend title overrides OPF), empty-backend-
  title → OPF fallback, **toc-failure rollback leaves `Library/Books` empty**.
- **Live round-trip against the running backend** (spike harness compiling the
  production `BackendClient.swift`): `sample.epub` → `LIVE TOC OK -> title=Test Book
  author=Ada Lovelace chapters=["0:The Engine"]` — the URLSession multipart + decode
  path works against real FastAPI, not just fixtures.
- Commits `ea0cf2c`, merged `38e0453`. No UI change (no new captures; V12's stand).

**Device-gated / next:** V14 (lazy `/import` chapter download + status UI) then the V15
[verify] runs the whole picker→cover→toc→narrate loop live on device.

---

## V12 — SwiftData models + persisted shelf ✅

**What:** the library becomes real data; the seed shelf becomes the empty-state/demo path.
- `Persistence/Models.swift` — `Book` (unique UUID, title/author, container-relative
  `epubPath`/`coverPath?`, `addedAt`/`lastOpenedAt?`, cascade `chapters`) + `Chapter`
  (backend `index`, `status` over a raw-string column — `none|pending|ready|error`,
  `errorReason?`, `bundlePath?`/`audioPath?`, `progressMs`/`durationMs?`) — the
  data-model.md v1 slice mirroring the Drift lineage.
- `Library/LibraryStore.swift` (@Observable, MainActor): `load()` (sorted `addedAt`) →
  `shelf` (books, or `ShelfBook.seeds` when empty); `addBook(from:)` = detached V10 copy +
  V11 cover + **`EpubInfo`** (NEW: `dc:title`/`dc:creator` via the shared `EpubPackage`
  container→OPF navigation) → persisted row; `deleteBook` = row (cascades) + container
  subtree (data-model.md deletion rule). Honest `importError` status, no alerts.
- `BookSeed` → **`ShelfBook`** display model (string id, optional pre-rendered `cover`
  Image; persisted books get stable slate/sky-derived fallback cloth — launch-stable
  derivation, NOT `hashValue` which is per-process seeded). `HardbackCoverView` draws real
  art over the board (clipped to the board shape, sheen on top, debossed title yields to
  art); `CoverArt` (ImageIO downsample, 920px cap) decodes covers **off-main at load,
  never during scroll** (apple/CLAUDE.md performance budget).
- `VimarshaApp` opens the `ModelContainer`; open-failure degrades to the seed shelf with
  no import affordance (no crash). `LibraryStackView(store:)` — previews/snapshots pass
  nil and render seeds.

**Wiring:** the `+` button now imports through `store.addBook`; the shelf re-renders live
when `books`/`covers` mutate (Observation). `BookTower`/`focusAffordances` consume the
dynamic `shelf` (focus/midY plumbing unchanged, index-keyed).

**Evidence:**
- Both suites green (macOS + iPhone 17 Pro sim): 9 `LibraryStoreTests` (real in-memory
  SwiftData + temp-dir files: round-trip, raw-status persistence, cascade, addBook
  end-to-end incl. cover file on disk, failure-persists-nothing, delete-removes-subtree,
  sort), 3 `EpubInfoTests` (real fixture: "Test Book"/"Ada Lovelace"), 2 `CoverArtTests`
  (downsample cap + junk→nil), art-vs-cloth `ImageRenderer` snapshot — **looked at**
  (`artifacts/V12/12-cover-real-art.png`): art fills the board, fore-edge + sheen intact,
  no debossed title over art.
- Fresh-binary sim captures (dark+light, `artifacts/V12/01/02-empty-state-*.png`): the
  empty-state seed shelf + glass "+" render exactly as before — the store is live
  underneath (empty DB → seeds).
- Commits `61797d5` + `c3a5805` + `3c3e1af`, merged `3710c6d`.

**Debug note (for the next agent):** an early version of the art snapshot test did
`ModelContainer(...).mainContext` on a *temporary* container — SwiftData traps (SIGTRAP)
and the whole parallel test host goes down as instant 0.000s failures across unrelated
suites. Keep the container alive, or avoid SwiftData where a plain value will do.

**Visual audit findings:** unchanged from V10 (the faint "Hey" metadata ghost mid-stack
at rest in dark mode persists — the open `frontSlot` calibration debt; light mode clean).

**Device-gated:** live picker→shelf round-trip with a real EPUB (real cover in the
stack) — that is exactly V15's [verify]; machine-side equivalents are all test-covered.

---

## V11 — [SPIKE] Client-side EPUB cover extraction ✅ (ADR-006 proven)

**What:** the client reads covers out of the EPUB it already holds — no backend change.
- `Import/ZipArchive.swift` — minimal read-only zip reader (5 tests): central-directory
  parse (EOCD back-scan), stored + deflate entries (Compression `COMPRESSION_ZLIB` ==
  zip's headerless DEFLATE). No zip64/encryption/multi-disk (EPUBs never need them).
- `Import/EpubCover.swift` — the cover ladder (7 tests): `META-INF/container.xml` →
  rootfile OPF → manifest; **EPUB3** `properties="cover-image"` → **EPUB2**
  `meta[name=cover]` → cover-ish image id (`cover`/`cover-image`) → **first image** item;
  hrefs resolved against the OPF dir (`.`/`..` + percent-decoding), extension from
  media-type. Namespace-prefix-tolerant XML matching (`opf:item`). Best-effort: anything
  broken → `nil`, the generated cloth cover stays the UI fallback — an import never fails
  over a cover.
- `EpubImporter` writes `Library/Books/<id>/cover.<ext>` beside the EPUB and returns
  `coverRelativePath?` on `ImportedEpub` (+2 importer tests).

**Wiring:** extraction runs inside `importEpub` (already off-main). Nothing renders it yet —
V12 persists `coverPath`, and the stack swaps generated covers for real art when the seeds
give way to SwiftData books.

**Evidence:**
- 14 new tests green on macOS + iPhone 17 Pro sim (zip reader incl. real `sample.epub`
  fixture + truncation/garbage; ladder rungs incl. `../` href resolution; importer
  cover-write + coverless-nil). Test EPUBs are real zip bytes built by
  `VimarshaTests/ZipFixture.swift` (spec-valid CRCs, genuinely deflated entries).
  `sample.epub` is duplicated into `VimarshaTests/Fixtures/` because the **sandboxed**
  (V10) macOS test host can't read repo paths.
- **SPIKE proof on real books** (standalone harness compiling the two production files):
  a real Penguin EPUB (Atomic Habits preview, ISBN 9781473537804) → its actual cover art,
  `.agent-loop/artifacts/V11/preview-9781473537804_A2-cover.jpg` — looked at, it's the
  real cover. Books-app *unpacked-directory* "EPUB" → correctly nil (not a zip).
- Commits `6649f86` (zip) + `a6d5026` (ladder) + `92c8885` (importer), merged `69aa1c5`.

**Findings (for the record):**
1. A pirate/Ebook-lib EPUB with NO declared cover fell to first-image and got a **blank
   A4 scan page** (`.agent-loop/artifacts/V11/Atomic Habits…-cover.jpg`). Designed
   degradation, but a possible later rung: spine `idref="cover"` XHTML → its `<img>`.
   Not built — YAGNI until a real library shows more of these.
2. iCloud Books storage keeps EPUBs as **unpacked directories**; the document picker can
   hand one over on macOS. The importer copies a file; directory-EPUB support is an
   open question for V15 if it bites.

---

## V10 — EPUB import (picker → container copy → entitlements) ✅ (P2 opens)

**What:** the first real-books item — a user-picked EPUB lands in the app container.
- `Import/EpubImporter.swift` — `importEpub(at:)` copies the picked file into the
  data-model cache layout `Library/Books/<bookId>/book.epub` and returns a
  **container-relative** path (`ImportedEpub`); the security-scoped origin is accessed only
  for the copy and released after (no persistent bookmark — we keep our own copy, per
  app-architecture.md). Failure rolls back the half-created book dir (Flutter
  `LibraryRepository` parity). `nonisolated` struct (file IO off the main actor),
  injectable `makeId` for tests, `.live` rooted at `.applicationSupportDirectory`.
- `LibraryStackView`: a glass **"+"** at top-trailing (sky `0.26` interactive tint, matte +
  sky-stroke Reduce Transparency fallback, `accessibilityLabel("Add book")`) presents
  `.fileImporter(allowedContentTypes: [.epub])`. The system document picker is OS-driven
  chrome (keyboard-style exemption from the morph rule) and the only sandbox-sanctioned
  path to a user file. Import failure surfaces as a small status line under the button
  (honest states, no alerts); success is silent until V12 wires persistence → shelf.
- `Config/Vimarsha.entitlements` (NEW, outside the synced groups so it isn't bundled as a
  resource), wired `"CODE_SIGN_ENTITLEMENTS[sdk=macosx*]"` on both app configs:
  app-sandbox + `files.user-selected.read-only` + `network.client` — the exact pair the
  Flutter macOS client needed (root CLAUDE.md gotcha), network for the V13 seam. iOS needs
  none of these (always sandboxed; `fileImporter` grants per-pick access).

**Wiring:** `handlePickedEpub` runs the copy in `Task.detached` (importer is `Sendable`;
compiles clean under Swift 6 strict concurrency). No interaction with the motion system —
the button is a static overlay above the scrim plane.

**Evidence:**
- 3/3 `EpubImporterTests` green on macOS + iPhone 17 Pro sim (container layout + byte-equal
  copy, distinct dirs per import, failed import leaves no half-state) — real temp-dir IO,
  no doubles (house rule: only `BackendClient`/audio get doubles).
- Full suites green on both destinations **with the sandbox entitlements applied** (test
  host is the sandboxed app; snapshot tests write to `temporaryDirectory`, which stays
  writable in-sandbox — checked before enabling).
- Fresh-binary launch captures (dark + light) in `.agent-loop/artifacts/V10/` — looked at:
  the glass "+" floats in the top-trailing corner inside the safe area in both modes;
  scrim still invisible at rest (V27 holds).
- Commits `40edc6e` + `abd998a`, merged `bd67c3b`.

**Visual audit findings (whole frame, both modes):**
1. **Faint metadata ghost mid-stack at rest** — "Hey / DESIGN & ILLUSTRATION" floats over
   the David Crow/Hey card seam at low opacity in BOTH modes (a second rendering of the
   HEY title in the same eyeline). This is the focus affordance leaking at rest via a
   small nonzero promotion on the behind-stack book — the open `frontSlot 0.72` vs
   dominant-cover calibration carried from V24/V26. Out of V10 scope; belongs to the
   V15/V21 review-debt pile (or a P1.5 follow-up if it grates earlier).
2. The "+" button overlaps the top-scrim band's area; at rest the scrim is invisible so it
   reads clean, but mid-recede both glass layers will stack at the corner — eyeball at V15.

**Device-gated:** the document picker itself (an OS surface — can't be driven by simctl):
pick-an-EPUB → file lands in `Library/Books/` needs a human (or the V15 verify) to run
live. The copy path, rollback, and entitlements wiring are test/build-verified.

---

## V27 — Glass top-scrim redesign (contextual visibility) ✅

**What:** the top-scrim no longer reads as a giant empty pill dangling at the top at rest
(the user finding — both modes, worst on the butter/light canvas; it had been in every
screenshot since V03 with only spec-compliance audited, never whether it looked right).
Redesigned to earn its place (glass moment #1 / motion grammar #3):
- `Library/TopScrim.swift` — pure math (9 tests): scrim opacity is a scroll-driven function
  of the nearest cover's **top-edge** proximity to the viewport top — a triangular window per
  card (`enterFraction 0.16` → `peakFraction 0.0` → `exitFraction −0.18`), strongest taken
  across the stack. **Invisible at rest** (at rest the topmost cover's top edge sits ~0.26vh
  down, below `enter`), fades in only as a cover approaches/dissolves under the top, fades
  back out after it passes above. Empty input (Reduce Motion flat list / pre-layout) → 0.
- View reshape (`LibraryStackView.topScrim(in:)`): from a horizontally-padded floating
  `Capsule` (h54, ±100 pad) to a **full-width, bottom-rounded band hugging the top safe
  area** (`UnevenRoundedRectangle` bottom radius 26, h84, `ignoresSafeArea(.top)`), with
  `.opacity(visibility)`.
- Tint re-tuned per mode (`scrimTint`): `sky 0.22` dark / `sky 0.13` light. The Reduce
  Transparency matte fallback (`Palette.surface`) follows the **same** visibility rule.

**Wiring:** opacity reuses the already-published `cardTops` (`CardTopYKey`, per-card viewport
`minY`); no new measurement. `colorScheme` env added for the per-mode tint. The dissolve
target (V23 `StackTransform` scrim-dissolve term) is unchanged — covers still dissolve, now
into a scrim that only shows while they do.

**Evidence:**
- 9/9 `TopScrimTests` green on macOS + iPhone 17 Pro sim; both full suites `** TEST
  SUCCEEDED **`. Commit `fbff4f2`, merged `e412a15`.
- Fresh **rest** captures (iPhone 17 Pro, dark + light) in
  [`artifacts/V27/`](../../.agent-loop/artifacts/V27/) — `01-rest-dark.png`,
  `02-rest-light.png`: the empty pill is **gone** in both modes; the top region is clean
  canvas above "VIMARSHA".

**Visual audit findings (whole frame, both modes — incl. out of scope):**
- ✅ V27 target met: no top pill at rest, dark + light.
- Covers read uniform-width (ADR-011) and neatly stacked; front (blue) "DESIGN BY ACCIDENT"
  dominant low-center — focus metadata/cluster not shown at rest (promotion ~0 at launch),
  same device-gated state as V26 (not a regression).
- Minor, pre-existing/out-of-scope: HEY (pink) cover's debossed "HEY" title is low-contrast
  on the pink cloth. Not touched here.

**Device-gated:** the **appears-during-recede** behavior (scrim fading in/out as a cover
dissolves under the top) needs a live scroll — no sim gesture injection in the agent loop.
Folded into the **V26** human re-review, which explicitly lists "verify the V27 scrim
behavior (invisible at rest, appears only during recede)". The rest-state half (the actual
user complaint) is machine-verified above.

---

## V26 — Library quality re-review 🚧 needs human review (motion feel + focused-state scrub)

**What:** the **[verify]** checkpoint that closes Phase P1.5 — re-judge the library after
V22 (uniform cards) → V23 (depth/dissolve) → V24 (focus/cluster fixes) → V25 (hero zoom)
against [ADR-011](../00-overview/decision-log.md#adr-011--uniform-book-card-geometry-in-the-library-stack)
and the [V09 findings](V09-motion-review.md). Like V09/V21, this is a human-judgement gate:
the agent-loop environment **cannot inject scroll/drag gestures into the simulator** (no
idb/assistive access), so the motion *feel* and every scroll-revealed state is fundamentally a
human scrub. The loop did every machine-verifiable part and left this findings entry + fresh
captures for the human.

**Wiring:** no code changed — a verify item. Both suites were already green on `main` (V25's
merge) and re-confirmed this run; the rest captures were refreshed from the current binary.

**Evidence (machine-verifiable):**
- Both suites green this run: `xcodebuild … -destination 'platform=macOS' test` and
  `… 'platform=iOS Simulator,name=iPhone 17 Pro' test` → both `** TEST SUCCEEDED **`.
- Fresh rest captures, iPhone 17 Pro, binary mtime confirmed fresh (14:14, not the
  stale-binary trap), read back and **looked at**:
  [`artifacts/V26/01-rest-dark.png`](../../.agent-loop/artifacts/V26/) (ink canvas) +
  [`02-rest-light.png`](../../.agent-loop/artifacts/V26/) (butter canvas — relaunched so the
  app re-read the appearance trait; the first light shot was stale-dark).
- **Confirmed at rest (static quality, both modes):**
  - **Uniform cards (ADR-011) ✅** — every card is one width; the pile reads as a calm, even
    editorial staircase (OPTIC → DAVID CROW → HEY → DESIGN BY ACCIDENT → A SENSE OF PLACE),
    no per-book size scatter. The V09 "not good / messy sizes" verdict is addressed.
  - **Scrim dissolve (V23) ✅** — the top OPTIC cover fades/melts under the glass top-scrim
    capsule (lighter top edge, dissolving into the canvas) rather than hard-clipping, in both
    dark and light.
  - **Neat stacking ✅** — the tightened overlap (−0.052 vh) reads neat, not scattered.

**Device-gated → NEEDS HUMAN** (each needs a scroll/drag the loop can't inject):
1. **Hero zoom (V25, motion grammar #5)** — a **rest no-op** by design (`distanceToRest 0` →
   scale 1.0), so it is *invisible at rest* and untestable headless. Scroll the header off and
   judge: does the whole tower scale toward the viewer as one rigid group, front cover held on
   the front-slot anchor, ease-in-out, 1.06 peak the right strength? Watch the in-bounds anchor
   approximation (`scaleEffect` anchor is in the tower's own bounds — the "fixed point" may
   drift across a long scroll).
2. **Focus/cluster fixes (V24)** — **not exercised at rest:** at the imperfect launch alignment
   the front-slot promotion is ~0 (DESIGN BY ACCIDENT prints its title in full, no metadata
   reveal / cluster visible). Settle a book onto the slot and judge: debossed title fades as the
   serif metadata reveal rises (no double title), the glass cluster reads **sky/aqua** (not
   butter) and sits **inside the focused cover's bottom edge** (above the next book), and
   grow-to-front at `scaleBoost 0.07` reads as a real promotion. Isolated static proof of these
   already exists in [`artifacts/V24/`](../../.agent-loop/artifacts/V24/) (title fade + forced
   `emerge:1` cool-glass cluster).
3. **Open V24 finding — front-slot vs dominant cover:** `StackTransform.frontSlot 0.72` can land
   focus on the *behind-stack* book rather than the front-most fully-visible cover. Judge live
   whether `frontSlot` wants nudging toward the front card; everything is keyed to `focus.index`
   so the fixes stay correct, but the *dominant* cover isn't always the focused one.
4. **Slot-emit landing (V08) + recede desaturation (V23) feel** — scroll down and judge the
   ease-out "springy but no overshoot" rise off the bottom shelf, and whether the 0.85 recede
   desaturation reads strong enough mid-scroll.
5. **V05 lensing puck glass strength** — drag on a cover and judge whether the lens reads as a
   refractive glass drop (V09 noted it looked flat in the `ImageRenderer` snapshot — likely a
   renderer limitation; confirm live) and stays on the 120Hz flick budget.

**Verdict:** static library quality (uniform sizing, neat stacking, scrim dissolve) is
**confirmed good** in both modes. Everything scroll-/gesture-revealed (hero zoom, the focused
state, slot-emit/recede feel, the puck) and the front-slot calibration are a human scrub. Item
left 🚧; `V26` written to `.agent-loop/NEEDS_HUMAN`. **Human run-book:** the V09 "How to run the
human review" steps (scroll slowly top→bottom; flick ×2; settle a book onto the slot; scroll the
header off and back; drag on a cover) — [V09-motion-review.md §How to run](V09-motion-review.md).

**Re-confirmation 2026-06-11 (loop iteration N+1):** a fresh agent re-entered the loop and found
V26 still the first non-✅ item. `NEEDS_HUMAN` had been cleared externally but **no human verdict
is recorded** and V26 is still 🚧, so the gate is still open. Re-ran both suites on current `main`
(HEAD `8bc4e0a`, i.e. post-V27 — code moved since the original V26 machine pass) →
**both `** TEST SUCCEEDED **`** (macOS + iPhone 17 Pro). No new machine-verifiable work exists for
this item (the static captures + findings above stand). Per the roadmap's P1.5-before-P2 rule
(don't build real-book plumbing onto a stack the owner hasn't signed off), the loop must **not**
advance to V10/P2 until a human closes V26. Re-asserted `V26` → `.agent-loop/NEEDS_HUMAN` and
stopped. **To unblock the loop:** a human runs the run-book above, then either marks V26 ✅ in the
roadmap (look-and-feel approved → P2 may start) or files a new fix-item phase (as V09→P1.5 did).

---

## V25 — Coupled scroll+zoom hero settle (motion grammar #5) ✅

**What:** Phase P1.5 #4 — the missing motion grammar **#5**. As the editorial header
translates off the top, the whole book tower scales toward the viewer **as one rigid group**.
New `HeroSettle` pure math maps the scroll **distance-to-rest** → a tower scale: `baseScale`
1.0 at the top (the zoomed-out hero state) easing **in-out** (smoothstep) up to `peakScale`
1.06 once the header has scrolled off (`settleBand` 0.55 vh), then holding at peak through the
browsing scroll. No timers, fully scrubbable, and it un-zooms on the loop-back to top
(distance → 0). The zoom is anchored on the front slot (`StackTransform.frontSlot` 0.72) so
the dominant front cover holds while the receding stack grows toward the viewer — the
reference's fixed-point zoom.

**Wiring:** one `scaleEffect(_:anchor:)` on `BookTower` *as a whole* (the per-card depth-stack
parallax + slot-emit ride inside the group), driven by the already-tracked `distanceToRest`
and anchored at `UnitPoint(0.5, frontSlot)` via new `heroSettle(in:)` / `heroAnchor(in:)`
helpers in `LibraryStackView`. **Reduce Motion exempt** — pinned to `.rest` (no hero zoom, per
the accessibility static fallback). At rest the scale is exactly 1.0, so the effect is a no-op
until scroll engages it — no change to the resting layout. `HeroSettle.swift` + its tests are
new files; no other library math touched.

**Evidence:** both suites `** TEST SUCCEEDED **` (macOS + iPhone 17 Pro sim); 10 new
`HeroSettleTests` (degenerate viewport, base/peak clamps, overscroll→rest, hold-past-band,
monotonic growth, no-overshoot, ease-in-out shape + symmetric midpoint, front-slot anchor,
viewport-fraction scaling), all prior suites stayed green. Rest capture reviewed in
[`artifacts/V25/v25-rest-dark.png`](artifacts/V25/) — **looked at:** the editorial header +
uniform-card staircase render identically to V24 (confirming the rest no-op). Commits
`c7b4d86` (math+tests) + `7df43b3` (wiring), merged `1c31b84`.

**Device-gated:** the scroll-driven zoom **feel** (does the front cover read as held? is the
1.06 peak the right strength? does it couple cleanly with the header translate-off and the
slot-emit landing?) and the anchor approximation — `scaleEffect`'s anchor is in the tower's
*own* bounds, not viewport space, so the "fixed point" drifts slightly across a long scroll;
kept subtle and flagged for **V26** live re-review (where hero zoom is on the checklist). A
scrolled/zoomed capture could not be produced headless (simctl injects no scroll gesture).

---

## V24 — Focus & cluster fixes (from V09) ✅

**What:** Phase P1.5 #3 — the four focus/cluster deviations the V09 human review filed
([V09-motion-review](V09-motion-review.md) findings #2 + monitoring notes):
1. **Double title killed** — the focused front cover printed its own debossed title *and* the
   serif metadata reveal in the same eyeline. `HardbackCoverView` gains `titleOpacity`
   (default 1); the focused card passes `1 - promotion`, so the debossed title fades out
   exactly as the metadata reveal fades in. Only the focused card promotes → only it fades;
   Reduce Motion (focus `.none`) leaves every title fully printed.
2. **Cluster glass cooled to sky/aqua** — the controls *looked* butter/gold (V09 monitoring
   note). Root cause confirmed in `artifacts/V07/03-cluster-emerged-live.png`: the cluster sat
   over the gold "A SENSE OF PLACE" board and its weak tint (sky 0.16) let that cover refract
   through. Tint opacities raised (sky 0.16→0.26, aqua/play 0.22→0.32) so the intended tint
   reads regardless of the cover beneath. (The tint *choice* was already sky/aqua per the glass
   rules — the bug was strength + substrate, not a butter tint.)
3. **Cluster anchored inside the focused cover's bottom edge** — new `FocusAffordancePlacement`
   (pure math, 7 tests) maps the next (occluding) book's top edge → the bottom padding that
   lifts the metadata + cluster to sit just inside the focused cover's *visible* bottom (the
   next book's top), above the book that overlaps it; clamped to a resting margin (cover bottom
   below the fold → rests at the viewport bottom as before) and a mid-viewport ceiling.
   `BookTower` publishes each card's top edge via a new `CardTopYKey` alongside the existing
   midY; `LibraryStackView` feeds `cardTops[focus.index + 1]` into the placement function. The
   metadata + cluster now read as extruded from the focused cover rather than floating over the
   book below it.
4. **Grow-to-front strengthened** — `BookFocus.scaleBoost` 0.04 → 0.07; the +4% promotion read
   too faint against the uniform-card stack.

**Wiring:** `HardbackCoverView(book:titleOpacity:)` (new param, applied to the title block);
`BookTower` passes `1 - promotion` for the focused card + emits `CardTopYKey`; `LibraryStackView`
gains `@State cardTops`, an `onPreferenceChange(CardTopYKey)`, and `focusAffordances(in:)` (now a
function taking the viewport size for the placement math). `FocusAffordancePlacement` + its tests
are new files. No StackTransform/SlotEmit/HeaderContrast constants touched (the front-slot
calibration noted below is out of V24 scope).

**Evidence:** both suites `** TEST SUCCEEDED **` (macOS + iPhone 17 Pro sim); `FocusAffordancePlacementTests`
(7) + `HardbackCoverTitleFadeSnapshotTests` (printed vs faded rasters differ) added, all prior
suites stayed green. Captures reviewed in [`artifacts/V24/`](artifacts/V24/) — **looked at:**
- `01-rest-dark.png`: the focused **HEY** (pink) cover's debossed title is now visibly **faded**
  (cf. V23 where it was bold) and its metadata reveal sits on the cover, not at the viewport
  bottom over the gold board.
- `02-cluster-emerged-live.png` (cluster temporarily forced `emerge: 1` to capture real Liquid
  Glass, then reverted): the four controls read as **cool sky/aqua glass** (play ▶ aqua-rimmed,
  rest sky) sitting **on the focused pink cover, above the blue book** — no longer the warm
  butter/gold of `V07/03` over the gold board. Both V24 wins (tint + placement) visible at once.
- `03-rest-light.png`: title fade holds on the butter canvas too (HEY debossed title dimmed,
  metadata revealing); the unfocused blue "Design by Accident" keeps its full bold title.
Binary mtime confirmed fresh before each shot. Merge `899e234` (commits `1654a89` placement,
`1fd5b4b` title fade, `eb86266` scaleBoost + tint).

**Device-gated:** the live *feel* of grow-to-front at 0.07 and the cluster's cover-anchored
travel as you scroll a book through the slot need an injectable scroll the agent-loop lacks —
math-tested + verified at the (partial) rest focus. Folds into **V26**. **Finding logged for
V26/follow-up (out of V24 scope):** at rest the front-slot (StackTransform.frontSlot 0.72) sits
*between* HEY and the dominant front cover (Design by Accident), so focus can land on the
behind-stack book rather than the front-most fully-visible cover. The double-title fix + anchoring
stay correct (everything is keyed to `focus.index`), but the *dominant* cover isn't always the
focused one — re-judge whether frontSlot wants nudging toward the front-most card when V25 (hero
zoom) or V26 tune the stack.

---

## V23 — Stack depth polish ✅

**What:** Phase P1.5 #2 — make depth read strong now that cards are one uniform size
(ADR-011), addressing V09 audit rows #1 (no desaturation) and #3 (opacity floored, didn't
dissolve). Two new `StackTransform` behaviours on recede + a tuning pass:
1. **Desaturation** (motion grammar #1 / §Physical book rendering "recessed covers may
   desaturate slightly; the front cover is full-chroma"): new `saturation` field lerps
   full chroma `1.0` at the front → `rearSaturationFloor 0.85` at the floor (`saturationFalloff
   0.25`). Applied via `.saturation(t.saturation)` in the `visualEffect` chain (render-side,
   no layout thrash).
2. **Scrim dissolve** (recede-and-clip #3 / glass moment #1): over the last `dissolveBand`
   (0.15vh) of travel — the cover passing under the glass top-scrim, ending at the top edge
   where `travel == frontSlot` — the (already floored) opacity ramps **below the 0.35 floor
   to 0**, so a cover melts into the scrim instead of clipping at the floor. Below the band
   the mid-recede plateau is untouched.
3. **Tuning:** `rearScaleFloor 0.62 → 0.60` so the staircase reads deeper now that size
   carries no meaning (within the reference's 0.75→0.6 rear-shrink range). Tuck/falloffs
   unchanged (already in range); the per-card contact shadows (keyed to promotion, in the
   view) left as-is — out of this item's scope.

**Wiring:** `StackTransform.at(...)` gains the `saturation` field + the dissolve term;
`identity` carries `saturation: 1`. `LibraryStackView`'s `BookTower` visualEffect adds one
`.saturation(t.saturation)` between opacity and offset. No other call sites; Reduce-Motion
branch (flat list, no transforms) untouched.

**Evidence:** both suites `** TEST SUCCEEDED **` (macOS + iPhone 17 Pro sim). `StackTransformTests`
gained `desaturatesOnRecede` (full→floor lerp + clamp) and `dissolvesUnderScrim` (plateau
before the band, below-floor inside it, ~0 at the top edge); `floorsClamp` updated (opacity now
dissolves far above, so it asserts the scale + saturation floors). Rest screenshots reviewed in
[`artifacts/V23/`](artifacts/V23/): `01-rest-dark.png` + `02-rest-light.png` — **looked at:** the
top **OPTIC** cover dissolves/dims under the glass scrim capsule (fading toward the canvas, no
longer a solid floored slab) and the receded covers read slightly muted; the staircase below
is intact in both modes. Binary mtime confirmed fresh (13:50) before the shots — not the
stale-binary trap. Commit `2559eb1`, merged `76ca193`.

**Device-gated:** the full dissolve-to-0 at the very top edge and the live *feel* of covers
desaturating/melting under the scrim mid-scroll need an injectable scroll the agent-loop env
lacks (no idb/assistive gesture injection) — math-tested + verified at the rest position
(OPTIC already visibly dissolving). Folds into the **V26** library quality re-review (scroll a
cover up under the scrim, confirm it melts cleanly with no hard edge; judge whether 0.85
desaturation reads strong enough or wants deepening). V24's double-title + cluster tint still
visible at rest (its scope, untouched).

---

## V22 — Uniform book cards ✅

**What:** Phase P1.5 #1 ([ADR-011](../00-overview/decision-log.md#adr-011--uniform-book-card-geometry-in-the-library-stack))
— ONE card geometry for every book in the library stack, replacing the scattered per-book
sizes the V09 human review called "not good". New `Library/CardGeometry.swift` (pure math):
`widthFraction 0.70` · `widthCap 460` · `aspect 0.50` + `width(forViewportWidth:)` (fraction,
capped, clamped ≥ 0). 5 Swift Testing cases (`CardGeometryTests`).

**Wiring:** `HardbackCoverView.aspectRatio` now uses `CardGeometry.aspect` (no longer
`BookSeed.aspect` — the seed field is retained for future cover-art fitting, not layout).
`BookTower`'s stacked + Reduce-Motion branches both frame to
`CardGeometry.width(forViewportWidth:)`; the per-index `widthFactor` helper is deleted.
Stack overlap tightened (`-0.04` → `-0.052` of viewport height) so the now-uniform slabs
read as a calm, neat editorial staircase. The depth-stack transform alone supplies the
staircase; size carries no meaning anymore.

**Evidence:** both suites `** TEST SUCCEEDED **` (macOS + iPhone 17 Pro sim); the existing
snapshot suites stayed green through the geometry change. Rest screenshots reviewed in
[`artifacts/V22/`](artifacts/V22/): `01-rest-dark.png` (pre-tighten), `02-rest-dark-tighter.png`
(shipped 0.052 — five even, uniform-width cards stepping neatly), `03-rest-light.png`. Commits
`45de6dd` (CardGeometry + tests) + `85f6945` (wiring), merged `53d7dec`.

**Device-gated:** the V09 double-title (debossed cover title + metadata reveal overlapping)
and the butter-tinted cluster are still visible at rest — both are explicitly **V24**'s
scope, untouched here. Live scroll *feel* of the tighter stack → re-judged at the V26
quality re-review.

---

## V09 — Motion review vs the reference 🚧 needs human review (motion feel + 1 gap)

**What:** the **[verify]** checkpoint for Phase P1 — audit every named motion-grammar
pattern against [the reference analysis](../../apple/docs/reference/ref-books-video-analysis.md)
and file deviations. This is a human-judgement gate (the agent-loop environment **cannot
inject scroll/drag gestures into the simulator** — no idb/assistive access — so *feel in
motion* is fundamentally a human scrub). The agent loop did every machine-verifiable part and
left a full findings doc for the human.

**Wiring:** no code changed. **No `StackTransform`/`SlotEmit`/`BookFocus`/`HeaderContrast`
constants were touched** — they sit within the reference-described ranges and tuning the
*feel* is exactly the decision this gate exists for, so proposed tweaks are filed as findings
rather than applied blind.

**Evidence:**
- Both suites green this run: `xcodebuild … -destination 'platform=macOS' test` and
  `… 'platform=iOS Simulator,name=iPhone 17 Pro' test` → both `** TEST SUCCEEDED **`.
- Rest/hero state captured on iPhone 17 Pro (dark + light) →
  `.agent-loop/artifacts/V09/01-rest-hero-dark.png`, `02-rest-hero-light.png`; read back and
  confirmed: editorial header + glass top-scrim + clean depth staircase, front slot at 0.72
  reads right.
- Static audit of all **7** named patterns → constants → reference expectation in
  [`.agent-loop/artifacts/V09-review-notes.md`](../../.agent-loop/artifacts/V09-review-notes.md)
  (table + suggested-but-unapplied tweaks + the live how-to-run script).
- **6/7 patterns implemented.** Screenshot-confirmed finding: **V07 double-title** (front
  cover's debossed title + the metadata reveal overlap in one eyeline) is visible even at
  plain rest. Carried-forward monitoring notes (V05 puck flatness, V07 butter tint, V07
  cluster placement) folded into the same doc for the live check.

**Device-gated → NEEDS HUMAN:** (1) live scroll/flick/focus scrub for motion *feel* —
grow-to-front promotion (#2), recede-and-clip dissolve (#3), slot-emit landing springiness
(#4), inertial flick dwell/no-overshoot (#6), and whether #1 needs the reference's
desaturation; (2) the V05 glass puck + V07 tint/double-title/placement fixes; (3) one genuine
**gap** — **motion grammar #5 (coupled scroll+zoom hero settle) is NOT implemented** (the
per-card scaleEffect at `LibraryStackView:203` is the depth-stack, not a rigid-group hero
zoom); the reference's signature opening zoom should be scoped as its own future V-item. Item
left 🚧; `V09` written to `.agent-loop/NEEDS_HUMAN`.

---

## V08 — Slot-emit staircase fan-up ✅ both suites green + snapshot + live launch verified

**What:** `Library/SlotEmit.swift` — pure `midY → {scale, opacity, yOffset}` for the entrance
(motion grammar #4 / apple/CLAUDE.md §Motion grammar #4). The counterpart to `StackTransform`'s
recede: the emit band runs from the viewport **bottom edge** (anchor, progress 0) up to the
front slot (arrived, progress 1), so `progress = clamp((vh − midY) / ((1 − frontSlot)·vh), 0, 1)`
— a cover travels its full rise exactly as it scrolls from first appearance to the slot. An
**ease-out** soft landing (`1 − (1 − p)²`, strictly monotonic, **no overshoot past identity**)
lifts the cover from the shelf anchor (`scale 0.86`, `opacity 0` → rises into existence,
`yOffset +0.12·vh` sunk toward the shelf) to identity at the slot. Above the slot emit is
identity and `StackTransform` owns the recede — the two meet at the slot with no jump, so the
staircase is one continuous surface. **Stagger is intrinsic** (no scripted per-item phase):
overlapping cards have staggered midYs, so each emits just after the one below it — the stepped
fan-up falls out of the geometry. No state, no time — scrubbable like the rest of the library
math.

**Wiring:** `BookTower`'s `visualEffect` composes `SlotEmit.at(...)` with the existing
`StackTransform` + grow-to-front promotion in one pass — `scale = t.scale·emit.scale·(1 +
promotion·scaleBoost)` (bottom anchor, so the cover grows up off the shelf), `opacity =
t.opacity·emit.opacity`, `offset = t.yOffset + emit.yOffset`. At the slot the focused card is
fully opaque/full-size (emit identity there), so V06/V07 focus + cluster are untouched. Reduce
Motion's flat full-size list is the other `card(...)` branch — emit only runs in the depth-stack
branch, so the static fallback is unchanged.

**Evidence:**
- 9/9 `SlotEmitTests` green on macOS + iPhone 17 Pro sim (degenerate viewport → identity; at/above
  the slot → identity; bottom edge → anchor with the exact `riseFraction·vh` sink; clamp below the
  edge — no sinking past the shelf; monotonic rise as midY climbs; **no overshoot** across the band
  — scale ≤ 1, opacity ∈ [0,1], yOffset ≥ 0; ease-out front-loaded past the linear midpoint;
  continuity at the slot).
- `SlotEmitSnapshotTests` (macOS `ImageRenderer`): a real `HardbackCoverView` rendered anchored
  vs arrived; rasters differ. PNGs in `.agent-loop/artifacts/V08/08-slot-emit-anchored.png` +
  `09-slot-emit-arrived.png` — **looked at:** anchored is the blank ink canvas (the cover hasn't
  appeared — opacity 0 at the shelf); arrived is the full *Design by Accident* blue hardback,
  full size + opacity + gilt edge. The rise-into-view is unmistakable.
- Live launch on iPhone 17 Pro sim (dark): `.agent-loop/artifacts/V08/01-rest-launch.png` —
  **looked at:** the staircase renders intact (OPTIC receding at top → DAVID CROW → HEY pink →
  DESIGN BY ACCIDENT blue at the front) with a faint cover just emerging from the bottom shelf
  edge (the emit anchor). Binary mtime confirmed fresh (02:18) before the shot — not the stale-binary
  trap. Both full suites `** TEST SUCCEEDED **` on macOS + iPhone 17 Pro.
- Commits `2cd8766` (math+tests) + `be98e98` (wiring+snapshot), merged `4d06e01`.

**Device-gated:** the live *feel* of scrubbing the fan-up — scrolling down and watching covers
rise sequentially from the shelf into the staircase, the ease-out landing reading as "springy but
no overshoot" at flick velocity — needs an injectable scroll the agent-loop env lacks (no
idb/assistive gesture injection), so it's math-tested + snapshot-rendered + verified at the rest
position rather than captured mid-scroll. Folds into the **V09** motion review (record a scroll-down
on device/sim, confirm covers emit cleanly with no bounce and stay on the 120Hz deadline). The
math, the seamless slot handoff, and the rise-into-view are proven here.

## V07 — Glass control cluster ✅ both suites green + live glass verified

**What:** `Library/ControlCluster.swift` — pure `promotion → {emerge}` (glass moment #5 /
apple/CLAUDE.md §UI map state 2). `emerge` is a smoothstep above an `emergeThreshold` (0.3):
the four controls stay melded into one glass blob (absorbed into the cover) until the focused
book is meaningfully settled, then fan apart; scrolling away reverses it. `xOffset(forControl:
of:spacing:)` fans the controls symmetrically about the centre, scaled by `emerge` (offset 0
when absorbed). A nested `Control` enum (`play, figures, memo, discuss`) carries each control's
SF Symbol + VoiceOver label. No state, no timers — scrubbable like `StackTransform`/`BookFocus`.
`Library/ControlClusterView.swift` renders it: a `GlassEffectContainer` of four controls, each
with a `glassEffectID`, so low emerge melds them into one blob and rising emerge splits them
(the glass analogue of grow-to-front). Play is tinted `aqua` (active), the rest `sky`
(interactive); Reduce Transparency swaps token-tinted matte fallbacks; the cluster is inert +
`accessibilityHidden` until `emerge > 0.5`. Stub `onActivate` (the reading/figures/memo/discuss
morphs land in later items).

**Wiring:** `LibraryStackView`'s bottom overlay became `focusAffordances` — a `VStack` of the
V06 `FocusMetadataView` reveal with the `ControlClusterView` beneath it, both fed the same eased
`focus.promotion`, so metadata + controls grow and recede together. This hosts the metadata with
the cluster (addressing the V06 note that the bare caption grazed the next rising cover). Under
Reduce Motion `focus` is `.none`, so the whole affordance (and cluster) is absent — consistent
with V06.

**Evidence:**
- 11/11 `ControlClusterTests` green on macOS + iPhone 17 Pro sim (control order; at/below
  threshold absorbed; full promotion → emerge 1; clamp ≤1 past full; monotonic across the band;
  smoothstep-eased mid-band; melded-at-centre when absorbed; symmetric fan summing to zero;
  spread scales with emerge; degenerate single-control = no offset).
- `ControlClusterSnapshotTests` (macOS `ImageRenderer`, opaque fallback): absorbed vs emerged
  rasters differ; PNGs in `.agent-loop/artifacts/V07/06-cluster-absorbed.png` +
  `07-cluster-emerged.png` — **looked at:** emerged shows the four controls (play ▶ w/ aqua rim,
  figures, mic, discuss bubbles w/ sky rims) fanned out; absorbed is the melded near-empty state.
- Live on iPhone 17 Pro sim (dark): `03-cluster-emerged-live.png` (cluster temporarily forced
  `emerge: 1` to capture the **real Liquid Glass** controls, since scroll-settle injection isn't
  available in the agent-loop) — **looked at:** four tinted glass circles fanned beneath the
  focused *Design by Accident* cover, paper-coloured icons, play left. `01-rest-launch.png` (real
  wiring) — **looked at:** at the imperfect launch rest-alignment the focused book's promotion is
  partial, so the cluster is correctly absorbed/faint (re-absorbed). Both full suites
  `** TEST SUCCEEDED **`.
- Commits `025b0e1` (math+tests) + `4b98b0b` (view+wiring+snapshot), merged `780b36b`.

**Device-gated:** the live *feel* of the controls morphing out as you scroll-settle a book onto
the slot — the meld→split timing, the emerge ramp, the 120Hz glass cost — needs an injectable
scroll the agent-loop env lacks (no idb/assistive gesture injection) and a live glass compositor
`ImageRenderer` doesn't run. Folds into the **V09** motion review (record a settle on device/sim,
confirm the cluster melds/splits cleanly and stays on the frame deadline). **Gotcha logged for
the next agent:** `xcodebuild … build` was repeatedly reporting `BUILD SUCCEEDED` **without
recompiling** edited Swift (stale binary, old mtime) — every "nothing renders" screenshot was a
stale install. Confirm the app binary mtime updated (or grep the build log for `Compiling
<File>.swift`) before trusting a simulator screenshot. **Tuning note for V09:** metadata +
cluster together (~y600–735 at launch) overlap the focused cover's lower third and the next
rising cover's top — revisit vertical placement / the cover→controls emergence anchor when V17
opens the cover into the reading surface.

## V06 — Book-focus state ✅ both suites green + live focus verified

**What:** `Library/BookFocus.swift` — pure `at(midYs: [Int: CGFloat], viewportHeight:) →
{index, emphasis}`: the card whose viewport midY is nearest the front slot
(`StackTransform.frontSlot` 0.72) **owns** it; `emphasis` (0…1) peaks when the card sits on
the slot line and falls to 0 at the `settleWindow` edge (0.18·viewport). An eased `promotion`
(`emphasis²`, "steeper curve near the front") drives the grow-to-front bump, the deepening
contact shadow, and the metadata reveal. Deterministic lower-index tie-break, degenerate /
empty inputs → `.none`. No state, no time — scrubbable like `StackTransform`/`HeaderContrast`
(motion grammar #2). `FocusMetadataView` renders the focused book's title (editorial New York
serif) + small-caps author on the **matte** canvas (content is paper, never glass), faded by
`reveal`; decorative → `accessibilityHidden`.

**Wiring:** each card publishes its `frame(in: .scrollView).midY` via a `CardMidYKey`
PreferenceKey (background GeometryReader); `LibraryStackView.onPreferenceChange` computes
`BookFocus.at(...)` into `@State focus` and feeds it to `BookTower`. The focused card alone
gets the grow-to-front scale (`t.scale · (1 + promotion·scaleBoost)`, `scaleBoost` 0.04,
bottom-anchored on top of the depth-stack transform, still inside the same render-side
`visualEffect`) and a contact shadow that deepens with `promotion` (opacity 0.30→0.48, radius
16→26, y 12→18). The reveal is a `.overlay(alignment: .bottom)`. **Reduce Motion** (flat
full-size list, no front slot) pins `focus = .none` → no promotion, no reveal.

**Evidence:**
- 9/9 `BookFocusTests` green on macOS + iPhone 17 Pro sim (empty/degenerate → none, on-slot =
  full emphasis, beyond-window → none, nearest-wins, monotonic fall-off, above/below
  symmetry, promotion eased ≤ emphasis with exact endpoints, continuity near the slot).
- `BookFocusSnapshotTests` (macOS-only, `ImageRenderer`) renders the real `FocusMetadataView`
  at `reveal: 0` vs `1` and asserts the rasters differ; PNGs in
  `.agent-loop/artifacts/V06/04-focus-hidden.png` + `05-focus-revealed.png` — **looked at:**
  revealed shows "Design by Accident" in the warm off-white serif + "FOR A NEW HISTORY OF
  DESIGN" small-caps author on ink; hidden is the opacity-0 (near-empty) state.
- Live launch on iPhone 17 Pro sim (dark): `.agent-loop/artifacts/V06/01-launch-top.png` —
  **looked at:** at rest the front-slot book (index 3, *Design by Accident*) is detected and
  its metadata reveal fades up at the bottom; the blue board reads as the promoted card. Both
  full suites `** TEST SUCCEEDED **` on macOS + iPhone 17 Pro.
- Commits `0c14a24` (math+tests) + `671f97f` (wiring+snapshot), merged `40aea2b`.

**Device-gated:** the live *feel* of grow-to-front as you flick a book into the slot (the
emphasis ramp, shadow deepening, reveal timing) folds into the **V09** human motion review —
scroll injection into the simulator isn't available in the agent-loop env, so focus is
math-tested + snapshot-rendered + verified at the rest position rather than captured
mid-flick. Tuning note for V07/V09: the bottom-anchored metadata caption currently sits low
enough to graze the next rising cover — revisit placement when the V07 glass control cluster
grows from the focused cover (it may host the metadata instead).

## V05 — Lensing drag puck [SPIKE] ✅ both suites green + look snapshot-verified

**What:** `Library/LensingPuck.swift` — pure `drag location + speed → {center, diameter,
opacity}` for the glass drop (glass moment #2 / motion grammar #6). The lens lifts above the
touch point (`lift` 30pt) so the finger doesn't occlude the refraction, clamps fully inside
the viewport at every edge, and swells with drag velocity (`speedDiameterGain` 0.04, clamped
at `maxDiameter` 132). `hidden` default = opacity 0. No state, no time — fully scrubbable.
`Library/LensingPuckView.swift` renders it: an interactive `glassEffect` circle with an
`aqua` meniscus rim, plus the Reduce Transparency opaque fallback (token-tinted matte). The
view is decorative — `allowsHitTesting(false)` + `accessibilityHidden(true)`.

**Wiring:** `LibraryStackView` drives the puck from a zero-distance `simultaneousGesture` on
the ScrollView (`DragGesture(minimumDistance: 0)`) so it rides *alongside* the scroll —
appears on finger-down, tracks the fling (`value.location` + `value.velocity`), and on
release fades out **in place** (keeps the last center/diameter, opacity → 0; only opacity is
animated so the position tracks the finger directly without sliding). The puck floats in
viewport space, so both the gesture and the `LensingPuckView` overlay live on the ScrollView,
outside the scrolling tower. **Reduce Motion suppresses it** (decorative continuous effect —
`onChanged` early-returns, puck stays hidden). At rest the puck is `diameter 0`/opacity 0, so
no live glass effect persists when idle.

**Evidence:**
- 7/7 `LensingPuckTests` green on macOS + iPhone 17 Pro sim (hidden invisible, active drag
  visible at base diameter, lift above touch, clamp at all four edges, velocity swell, max
  clamp on a hard flick, degenerate-bounds no-invert).
- `LensingPuckSnapshotTests` (macOS `ImageRenderer`): puck-present vs puck-absent rasters
  differ; PNGs in `.agent-loop/artifacts/V05/01-puck-absent.png` + `02-puck-present.png` —
  **looked at:** the present raster shows the lifted, sky-rimmed drop sitting above the cover
  title; the absent raster has no drop. (Opaque fallback used — `ImageRenderer` can't
  composite live Liquid Glass refraction.)
- Live launch on iPhone 17 Pro sim (dark): `.agent-loop/artifacts/V05/03-rest-launch.png` —
  app builds/installs/launches with the wiring; library + glass top-scrim render, puck hidden
  at rest (correct, no drag).
- Commits `a9c8dd4` + `b72deaf`, merged `c904379`.

**Device-gated:** the SPIKE's second half — the live **glass refraction look** under a moving
finger and its **cost** (the 120Hz flick budget, Instruments profiling) — needs a real drag
the agent-loop environment can't inject (no idb/assistive gesture injection) and a live glass
compositor `ImageRenderer` doesn't run. Both fold into the **V09** motion review (record a
flick on device/sim, confirm the lens reads + stays on the frame deadline). The geometry,
the opaque fallback, and that the drop draws over a cover are proven here; the glass *feel* is
the V09 sign-off.

---

## V04 — Settle contrast shift ✅ both suites green + snapshot-verified

**What:** `Library/HeaderContrast.swift` — pure `distanceToRest → {ghost, label, headline}`
opacities (motion grammar #7). Full contrast at rest (the V03 editorial baseline: ghost
0.26 / label 0.6 / headline 1.0); as the header scrolls away from the top it lerps to light
floors over a settle span of 0.5 viewport-heights, with the **ghost display title fading
furthest** (floor 0.05 vs label 0.18 vs headline 0.32 — the headline keeps the most
contrast). Negative/overscroll distance and degenerate viewport clamp to rest. No timers,
fully scrubbable, settle-darkens on the loop-back to top.

**Wiring:** `LibraryStackView` drives it via `onScrollGeometryChange(for: CGFloat)` reading
`contentOffset.y` (clamped ≥ 0) into a `@State distanceToRest`; the header is the only thing
that depends on it, so the depth-stack `ForEach` is extracted into a `BookTower` subview
(stable `size`/`reduceMotion` inputs → SwiftUI skips re-rendering it on the per-frame scroll
tick — the heavy `visualEffect` path is untouched). Header pulled into a parameterized
`LibraryHeader(contrast:)` so it renders identically from the live scroll state and from
tests. **Reduce Motion pins `.rest`** (no scroll-driven dimming — continuous-effect fallback
rule). Scope note: kept the header *in* the scroll content (matches the reference, where the
header exits the top); the full "covers bloom color through the ghosted serif" glass
header-plane refraction (glass moment #3) is the deferred V04 *extension*, a candidate for
V09/polish — not built here.

**Evidence:**
- 7/7 `HeaderContrastTests` green on macOS + iPhone 17 Pro sim (rest = baseline, overscroll
  clamp, degenerate viewport, monotonic dimming away from rest, floors reached at the span +
  clamp beyond, ghost-dims-most floor ordering, continuity near rest).
- `HeaderContrastSnapshotTests` (macOS-only, `ImageRenderer`) renders the real `LibraryHeader`
  at rest vs `distanceToRest: 600/800` and asserts the rasters differ; PNGs in
  `.agent-loop/artifacts/V04/02-header-rest.png` + `03-header-scrolled.png` — **looked at:**
  rest shows bright off-white MY BOOKS + legible ghost; scrolled shows the ghost nearly
  dissolved into the canvas, LIBRARY faint, MY BOOKS dimmed-but-most-legible. Exactly #7.
- Live launch on iPhone 17 Pro sim (dark) rest state screenshot:
  `.agent-loop/artifacts/V04/01-rest-top.png`.
- Commits `46883a1` + `57f0a84`, merged `532ffd2`.

**Device-gated:** the live *scroll feel* of the shift (and any covers-bloom-through glass
extension) folds into the **V09** human motion review — gesture injection into the simulator
isn't available in the agent-loop environment (no idb/assistive access), so the dimmed state
is math-tested + snapshot-rendered rather than captured mid-flick.

---

## V03 — Depth-stack parallax scroll (static books) ✅ verified both platforms

**What:** `Library/StackTransform.swift` — pure `midY → {scale, opacity, yOffset}` with
clamped rear floors (0.62/0.35), front slot at 0.72, **upward** recede tuck; `BookSeed`
static shelf (8 reference books, cloth/ink/aspect/gilt as stand-in cover assets);
`HardbackCoverView` (cloth sheen, debossed serif via dual text shadows, fore-edge page
capsules, gilt stripe, `@ScaledMetric` type); `LibraryStackView` (editorial ghost/label/
headline header, negative-spacing overlap with document-order z, `visualEffect` transforms,
glass top-scrim capsule, Reduce Motion → flat full-size list, Reduce Transparency → matte
capsule).

**Wiring:** transforms run render-side only (`visualEffect`), no layout thrash; widths vary
by shelf *index* (not id); all hexes in `Palette.swift` (incl. `pageEdge`/`gilt` tokens).

**Evidence:**
- 7/7 `StackTransformTests` green on macOS + iPhone 17 Pro sim (front-slot identity,
  below-front identity, recede direction *negative-y locked by test*, monotonic recede,
  floor clamps, continuity at the slot, degenerate viewport).
- Dark + light screenshots reviewed (canonical dark: ink canvas, staircase tucks up under
  the glass capsule). Commits `d3c4248` (+ fixes) merged `0134d10`.
- 12-agent review pass: confirmed-and-fixed — recede tuck direction was inverted vs the
  reference (the tests had baked in the wrong sign), orphan hexes, RM fallback width,
  id-keyed rhythm, missing `SWIFT_DEFAULT_ACTOR_ISOLATION`.

**Device-gated:** inertial-flick *feel* (grammar #6) — needs a human scroll on
device/simulator; queued into V09.

---

## V02 — Palette tokens ✅

**What:** `Design/Palette.swift` — raw palette (butter/aqua/sky/slate), derived ink ramp
(0x101F26/0x16262D/0x1C313A), warm `paper`, semantic mode-aware tokens (canvas/surface/
textPrimary/tint) via a cross-platform `Color(light:dark:)` dynamic provider; `Color(hex:)`.

**Evidence:** compiles into V03's render; WCAG text rules encoded in
[apple/CLAUDE.md §Color palette](../../apple/CLAUDE.md) (slate/sky never body text).
Commit `d3c4248`.

---

## V01 — Xcode scaffold ✅

**What:** Hand-authored `apple/Vimarsha.xcodeproj` (objectVersion 77,
`PBXFileSystemSynchronizedRootGroup` — files auto-join targets), app + unit-test targets,
shared scheme, multiplatform (`SUPPORTED_PLATFORMS` iphoneos/iphonesimulator/macosx,
deployment 26.0), `GENERATE_INFOPLIST_FILE`, ad-hoc macOS signing,
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, bundle id `com.vimarsha.apple`
(Flutter keeps `com.vimarsha.vimarsha`).

**Evidence:** `xcodebuild … test` green on both destinations on first scaffold build;
app installs + launches on the iPhone 17 Pro simulator. Commit `d3c4248`, merged `0134d10`.
