# Agent Loop — autonomous V-item runner

Replaces "open a new Claude Desktop session and paste the prompt" with a loop: each
iteration launches a **fresh headless Claude Code session** (`claude -p`, its own clean
context window) that completes exactly **one** V-item from
[`plan/08-engineering/build-roadmap.md`](../../plan/08-engineering/build-roadmap.md) —
implement, test both platforms, merge `--no-ff`, push, log progress — then exits. The next
iteration gets the next item with a cold context, exactly like a new window.

## Run it

```bash
./scripts/agent-loop/run.sh                # up to 10 items, fully autonomous
MAX_RUNS=2 ./scripts/agent-loop/run.sh     # just a couple this sitting
tail -f .agent-loop/logs/run-*.log         # watch the current agent think
touch .agent-loop/STOP                     # graceful stop between items
```

Backend-dependent items (P2+) want the local backend up first:
`cd backend && uv run uvicorn vimarsha.server:app --port 8000`.

## How it stops (in priority order)

| Signal | Meaning |
|---|---|
| `.agent-loop/COMPLETE` | agent found no eligible items — detailed phases done 🎉 |
| `.agent-loop/NEEDS_HUMAN` | a `[verify]` item needs your eyes (artifacts in `.agent-loop/artifacts/VXX/`) — review, mark ✅ yourself, rerun |
| `.agent-loop/BLOCKED` | something the item couldn't resolve — read the note, fix, rerun |
| 2 runs with no recorded progress | safety brake; read the last log |
| `MAX_RUNS` / `STOP` file | your throttle |

Progress is *recorded* = a new commit touching the roadmap/progress files; an agent that
burns a session without logging counts as a failure.

## Permissions

Default is `--dangerously-skip-permissions` (the loop is useless if it stalls on prompts).
That means the agent can run anything your shell can — keep the loop on this repo, on this
machine, and glance at logs early on. `PERMS=safe` switches to `--permission-mode
acceptEdits` (edits auto-approved; unlisted Bash commands fail instead of prompting — the
agent will work around or report Blocked).

## The contract the agents follow

[`prompt.md`](prompt.md) — selection rule (first non-✅ item with all deps ✅, P1→P3 only),
house rules (TDD, branch, both-platform suites, `--no-ff` merge, push), progress logging to
`_progress-A.md`, the `[verify]`/blocked protocols, one-item-then-stop. Edit that file to
change agent behavior; the loop script only sequences and brakes.

## Nightly option

Cron it (e.g. `0 2 * * *` with `MAX_RUNS=3`) and wake up to merged V-items + artifacts.
Make sure the simulator machine stays awake (`caffeinate -s ./scripts/agent-loop/run.sh`).
