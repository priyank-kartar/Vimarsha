#!/usr/bin/env bash
# Stage the flash worker + a fresh copy of the vimarsha package into _stage/, then run flash
# from there. Staging is needed because flash only EXCLUDES paths in the project's .gitignore —
# so to bundle vimarsha (without committing a duplicate copy into git) we build in a throwaway
# dir whose .gitignore does not exclude it.
#
# Usage:
#   ./deploy.sh build      # free: validate packaging
#   ./deploy.sh deploy     # provision/update the serverless endpoint
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
stage="$here/_stage"
rm -rf "$stage"
mkdir -p "$stage"
cp "$here/narrate_worker.py" "$here/pyproject.toml" "$here/README.md" "$stage/"
cp -R "$here/../src/vimarsha" "$stage/vimarsha"
# Drop modules the narration worker never imports — they pull deps (fastapi, faster-whisper,
# httpx) we don't want flash's local import-scan to need. See README for the import closure.
rm -f "$stage"/vimarsha/{server,transcribe,llm,runpod_client,remote_narrator,metadata}.py
printf '.flash/\n__pycache__/\n*.tar.gz\n' > "$stage/.gitignore"
echo "staged worker + vimarsha ($(ls "$stage"/vimarsha/*.py | wc -l | tr -d ' ') modules) → $stage"
cd "$stage"
exec flash "$@"
