# Final Human Review — Consolidated Checklist

> **Status:** Living · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). Per user directive (2026-06-11) the loop no
> longer stops at `[verify]` gates — every check that genuinely needs human eyes/hands is
> APPENDED here by the verify agents and done **once, at the end**. Do these on the
> simulator/device with the latest `main`. Tick items off as you go; anything that fails
> becomes a fix V-item.

## Carried review debt (pre-directive)

- [ ] **V26 motion-feel scrub (P1.5):** scroll/flick/focus on the sim — hero zoom strength
  (1.06 peak, rigid group), grow-to-front promotion reads real, slot-emit landing character,
  recede dissolve under the contextual scrim, V05 puck glass strength on drag, flick lands
  soft with no bounce. Compare `apple/docs/reference/frames/`.
- [ ] **V15 device UX run (P2):** import a real EPUB via the document picker → its real
  cover appears in the stack → narrate a chapter from the chapter plane (backend up) →
  status pending→ready → audio plays. (Pipeline already proven live via curl + DTO decode;
  this checks the on-device UX path.)
- [ ] **UI-audit pre-log items:** off-palette chapter-status icon; metadata-reveal ghosting
  in motion ([ui-audit-log](ui-audit-log.md)).

## Appended by verify agents (newest at bottom)

<!-- verify agents: append one actionable line per deferred check — what to do, what to
judge, artifact refs. Never delete completed history; tick instead. -->

### V21 — eyes-free run (P3 core loop; appended 2026-06-11)

- [ ] **Listen to a real chapter with ears + eyes:** backend up → open a ready chapter →
  Play; judge that the butter/aqua narration wash lands on the paragraph you're HEARING
  (machine proof only says block ids match `paraTimings`), the auto-scroll glide
  (anchor 0.3, 0.35s ease, 4s read-ahead cooldown) feels calm not yanky, and deep-resume
  lands without animating through the chapter. Ref: `artifacts/V18/`, `artifacts/V15/`.
- [ ] **Figure pop cadence + feel (V20):** during the same listen, judge the carrier's
  spring pop at `startMs` / recede at `endMs` (response 0.45/0.85 — does it read as
  "morphs out of the passage"?), page a stacked pair mid-play (wrap-around chevrons),
  and check the carrier never sits over the line being read (V20 audit flag: forced
  frame showed overlap; live auto-scroll should hold the live block at ~30% height).
  Ref: `artifacts/V20/01–04`.
- [ ] **Figures gallery round-trip:** glass toggle top-right → grid morphs in (narration
  keeps playing — verify by ear) → tap a timed figure tile → it seeks there and morphs
  back to reading at that passage. Judge the morph (scale 0.97 + fade) against the
  Prime Directive bar.
- [ ] **Transport under fingers (V19):** tap-a-paragraph-to-seek mid-play, skip ±15 at
  both ends (clamps), speed chip through the ladder while playing (chipmunk check —
  AVAudioPlayer rate quality), scrub-resume after kill.
- [ ] **Offline replay:** narrate a chapter, kill the backend, relaunch, replay from
  cache (machine-proven in `artifacts/V21/harness-run.log`; judge the UX honesty of any
  unreachable-backend states while offline).
- [ ] **Real `GET /image` figures:** import a real ILLUSTRATED EPUB (fixture has no
  images — V15 gap still open) and check real figure images render matte in the carrier,
  the gallery tiles, and inline paper rows.
- [ ] **V20 light-mode polish calls:** gallery tiles read loud saturated aqua on butter,
  and the tiles' aqua waveform glyph is invisible aqua-on-aqua (`artifacts/V20/04`) —
  decide if a quieter butter-derived tile token is wanted (file a polish V-item if so).

### V31 — memos end-to-end (P4; appended 2026-06-11)

- [ ] **Real-mic hold-to-record feel (V28):** in a ready chapter, long-press the mic on the
  transport → judge the aqua waveform puck's live metering against your voice, the
  pause-while-recording → resume beat, the ≥400ms too-short discard, and the mic-permission
  primer flow on a fresh install. Ref: `artifacts/V28/` puck snapshots.
- [ ] **Live transcript honesty:** record a real memo with the backend up — the saved chip
  should read "Voice note saved · transcribing…" and the Notes row flip pending → ready with
  YOUR words (machine proof used a Chatterbox-rendered clip: verbatim —
  `artifacts/V31/harness-run.log`). Then kill the backend, record another, judge the error
  row + retry affordance.
- [ ] **Notes morph + clip playback by ear (V30):** toggle Notes on the closeBar — judge the
  body ⇄ notes reflow as a morph (never a sheet), play a memo clip (narration must pause and
  NOT auto-resume), and check the chapter keeps its position after the clip (machine-proven:
  MP3 stays loaded, `harness-run.log`).
- [ ] **Open-at-pin UX:** from Notes, open-at-pin → reading view returns at the pinned
  paragraph with the highlight there (the seek itself is machine-exact: 12144 == 12144ms);
  judge that the morph-back + scroll position read as "taken to the right place".
- [ ] **VoiceOver sweep over memo flows (V28/V30):** record control, Notes rows
  (play/open-at-pin/retry/delete actions), honest pending/error labels.

### V36 — Discuss end-to-end (P5; appended 2026-06-11)

- [ ] **Double-tap entry + panel feel (V33):** in a ready chapter, double-tap the record
  control → the Discuss panel must morph up WITHIN the canvas (never read as a sheet),
  keyboard up by default, and narration must keep playing underneath. Judge the morph and
  that the transport hand-off back on close feels continuous. Ref: `artifacts/V33/`.
- [ ] **Grounded conversation feel:** with Ollama + backend up, ask about the passage
  being narrated — judge response latency honesty ("Thinking…"), whether the answer reads
  *grounded in that passage* (machine proof: reply matched
  engine/stroke/crankshaft/rotation/motion — `artifacts/V36/harness-run.log`), and ask a
  follow-up a minute later to feel the per-send re-grounding follow playback.
- [ ] **Hold-to-talk by mouth (V34):** hold the talk button and speak — narration pauses
  while the mic is open, resumes at release while transcription continues, transcript
  appends to the draft (never auto-sends); judge the Listening…/Transcribing… states and
  the <400ms discard. Needs a real mic — machine-untestable.
- [ ] **Spoken reply by ear (V35):** tap a reply's speaker — narration pauses exactly when
  the voice starts (not during the fetch wait), the reply speaks in the narrator's
  Chatterbox voice, narration resumes where it left off after (machine-proven:
  pause/resume/stays-paused all PASS — `artifacts/V36/harness-run.log`); judge the wait
  honesty on the speaker chip (a real /speak render is ~10–60s on MPS).
- [ ] **Save → Conversations morph:** Save a thread, reopen it from Conversations
  (read-only), delete it — judge the list ⇄ thread ⇄ panel morphs as faces of ONE plane
  (never pushes). Machine-proven: exact lines/title/anchor round-trip
  (`artifacts/V36/harness-run.log`).
- [ ] **VoiceOver sweep over Discuss (V33–V35):** double-tap alternative action on the
  record control, input/send labels, hold-to-talk action, speaker chips, Save/Conversations
  navigation, honest Thinking…/error/retry announcements.
