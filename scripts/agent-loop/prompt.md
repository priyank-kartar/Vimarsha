You are one iteration of an autonomous build loop on the Vimarsha repo. Your job: complete
EXACTLY ONE V-item from the build roadmap, end-to-end, then stop. A fresh agent runs after
you — leave the repo in a state where it can pick up cold.

## Select your item

1. Read `plan/08-engineering/build-roadmap.md` (and `plan/README.md` if you need bearings).
2. Pick the FIRST item in the detailed `## Phase P*` sections **in file order, top to
   bottom** (phases may be numbered out of sequence, e.g. P1.5 sits before P2 — file order
   wins) that is NOT marked ✅ and whose `(needs Vxx)` dependencies are ALL ✅. Skip the
   expansion buckets.
3. If an eligible item is marked 🚧, read `plan/08-engineering/_progress-A.md` for its
   half-done state and CONTINUE it rather than starting over.
4. If NO item is eligible: write the single word DONE to `.agent-loop/COMPLETE` and stop.

## Do the work

- Read the item's `↳` context docs FIRST, plus `apple/CLAUDE.md` (the UI bible) and root
  `CLAUDE.md`. Follow the house rules exactly: TDD where there is logic (Swift Testing),
  feature branch `feat/vXX-<slug>` off `main`, small commits with the repo's
  `Co-Authored-By` trailer.
- Stay strictly inside the item's scope. If you discover missing groundwork, do the
  minimum, note it in the progress log, and move on. Do not refactor opportunistically.
- Verify before merging: `cd apple && xcodebuild -scheme Vimarsha -destination
  'platform=macOS' test && xcodebuild -scheme Vimarsha -destination 'platform=iOS
  Simulator,name=iPhone 17 Pro' test` — both must be green. For visual work, build, install
  and launch on the booted simulator, take screenshots with
  `xcrun simctl io <device> screenshot`, save them under `.agent-loop/artifacts/VXX/`, and
  LOOK at them (Read the files) to confirm the result before declaring success.
- **Whole-screen visual audit (mandatory with every capture):** judge the ENTIRE frame,
  not just your item — anything that looks empty, broken, misaligned, redundant, dangling,
  or unexplained gets filed in your progress entry under "Visual audit findings", even when
  it's out of your item's scope and even if it was "designed" that way. "It matches the
  spec" is not the same as "it looks right" — flag both kinds of wrong. Check dark AND
  light mode.
- Review your own diff critically before merging (correctness, scope, the named motion
  pattern if applicable).
- Merge with `git merge --no-ff` to `main` and push.

## Record and hand off

- Append a full entry to `plan/08-engineering/_progress-A.md` (What / Wiring / Evidence /
  Device-gated) with commit hashes.
- Mark the item ✅ (or 🚧 with a precise "state + next step" note if genuinely incomplete)
  in `plan/08-engineering/build-roadmap.md`, and tick the matching milestone progress in
  `plan/08-engineering/build-plan.md` if a milestone completed. Commit these doc updates
  too (on main, directly, as `docs(progress): ...`).

## Special cases

- **`[verify]` items needing human judgment** (e.g. V09 motion feel): do every part that is
  machine-verifiable (run suites, capture screenshots/recordings into
  `.agent-loop/artifacts/VXX/`), write your findings to the progress log, mark the item 🚧
  with "needs human review: <what to look at>", then write the item id to
  `.agent-loop/NEEDS_HUMAN` and stop. Do NOT mark such items ✅ yourself.
- **Blocked** (missing dependency, broken main, anything you cannot resolve inside this
  item's scope): write a description to `.agent-loop/BLOCKED`, commit nothing half-broken
  to main, and stop.
- **Backend needed** (P2+ items): check `curl -s http://localhost:8000/docs >/dev/null`;
  if the backend is down and the item truly needs it, do the parts that don't, then treat
  as Blocked with the note "start the backend: cd backend && uv run uvicorn
  vimarsha.server:app --port 8000".

Never push directly to main except the doc/progress updates and the `--no-ff` merge.
Never mark an item ✅ without green suites. One item, then stop.
