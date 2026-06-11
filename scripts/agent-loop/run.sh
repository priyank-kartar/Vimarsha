#!/usr/bin/env bash
# Vimarsha autonomous build loop.
# Each iteration launches a FRESH `claude -p` session (its own context window) that
# completes exactly one V-item from plan/08-engineering/build-roadmap.md, then exits.
# The loop continues until: roadmap exhausted, human review needed, a blocker, repeated
# failures, MAX_RUNS, or you `touch .agent-loop/STOP`.
#
# Usage:
#   ./scripts/agent-loop/run.sh                 # default: up to 10 items
#   MAX_RUNS=3 ./scripts/agent-loop/run.sh      # cap the number of items this sitting
#   PERMS=safe ./scripts/agent-loop/run.sh      # require pre-approved tools instead of
#                                               # --dangerously-skip-permissions
#
# Watch progress:  tail -f .agent-loop/logs/run-*.log
# Stop gracefully: touch .agent-loop/STOP   (takes effect between items)

set -u
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

LOOP_DIR=".agent-loop"
ROADMAP="plan/08-engineering/build-roadmap.md"
PROMPT_FILE="scripts/agent-loop/prompt.md"
MAX_RUNS="${MAX_RUNS:-10}"
MAX_CONSECUTIVE_FAILURES=2
PERMS="${PERMS:-full}"
MODEL="${MODEL:-claude-fable-5[1m]}"   # Fable 5, 1M context — batches need the headroom

mkdir -p "$LOOP_DIR/logs" "$LOOP_DIR/artifacts"
rm -f "$LOOP_DIR/COMPLETE" "$LOOP_DIR/NEEDS_HUMAN" "$LOOP_DIR/BLOCKED"

eligible_items() {
  # Detailed-phase V-item lines not yet marked done (✅ anywhere on the line).
  sed -n '/^## Phase P/,/^## Expansion buckets/p' "$ROADMAP" \
    | grep -E '^- \*\*V[0-9]+\*\*' | grep -cv '✅'
}

roadmap_fingerprint() { git log -1 --format=%H -- "$ROADMAP" "plan/08-engineering/_progress-A.md"; }

failures=0
run=0
while :; do
  [ -f "$LOOP_DIR/STOP" ]        && { echo "[loop] STOP file present — exiting.";        break; }
  [ -f "$LOOP_DIR/NEEDS_HUMAN" ] && { echo "[loop] Needs human review: $(cat "$LOOP_DIR/NEEDS_HUMAN") — exiting."; break; }
  [ -f "$LOOP_DIR/BLOCKED" ]     && { echo "[loop] Blocked: $(cat "$LOOP_DIR/BLOCKED") — exiting."; break; }
  [ "$run" -ge "$MAX_RUNS" ]     && { echo "[loop] MAX_RUNS=$MAX_RUNS reached — exiting."; break; }

  remaining=$(eligible_items)
  if [ "$remaining" -eq 0 ]; then
    echo "[loop] Roadmap detailed phases complete 🎉 — exiting."
    break
  fi

  run=$((run + 1))
  before=$(roadmap_fingerprint)
  log="$LOOP_DIR/logs/run-$(date +%Y%m%d-%H%M%S).log"
  echo "[loop] Run #$run — $remaining item(s) remaining — fresh agent session → $log"

  if [ "$PERMS" = "full" ]; then
    claude -p "$(cat "$PROMPT_FILE")" --model "$MODEL" --dangerously-skip-permissions >"$log" 2>&1
  else
    claude -p "$(cat "$PROMPT_FILE")" --model "$MODEL" --permission-mode acceptEdits >"$log" 2>&1
  fi
  status=$?

  git fetch -q origin 2>/dev/null || true
  after=$(roadmap_fingerprint)

  if [ -f "$LOOP_DIR/COMPLETE" ]; then
    echo "[loop] Agent reports roadmap complete — exiting."
    break
  fi

  if [ "$status" -ne 0 ] || [ "$before" = "$after" ]; then
    failures=$((failures + 1))
    echo "[loop] Run #$run made no recorded progress (exit=$status). Failure $failures/$MAX_CONSECUTIVE_FAILURES."
    if [ "$failures" -ge "$MAX_CONSECUTIVE_FAILURES" ]; then
      echo "[loop] Two runs without progress — stopping so a human can look. See $log"
      break
    fi
  else
    failures=0
    echo "[loop] Run #$run recorded progress ✓"
  fi
done

echo "[loop] Done. Summary:"
sed -n '/^## Phase P/,/^## Expansion buckets/p' "$ROADMAP" | grep -E '^- \*\*V[0-9]+\*\*' \
  | sed -E 's/ ·.*$//' | sed 's/^- //'
