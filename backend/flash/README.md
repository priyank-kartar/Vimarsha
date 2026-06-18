# Vimarsha premium narration worker (Runpod Flash)

Batched Chatterbox narration on Runpod serverless, deployed with [`runpod-flash`](https://github.com/runpod/flash).
Replaces the `Dockerfile.serverless` path — no Docker build, no registry.

## Deploy

```bash
cd backend/flash
export RUNPOD_API_KEY=...           # or: flash login
./deploy.sh build                   # free: stage + validate packaging
./deploy.sh deploy                  # stage + provision the serverless endpoint (scale-to-zero)
```

`deploy.sh` stages this worker plus a fresh copy of `../src/vimarsha` into `_stage/`
(gitignored) and runs flash from there, so the package is bundled without committing a
duplicate into git.

`flash deploy` prints the endpoint id. Point the backend at it:

```bash
export VIMARSHA_CHATTERBOX_ENDPOINT=<endpoint_id>
export RUNPOD_API_KEY=...
```

The backend's existing `RunPodNarrator`/`RunPodClient` then routes `engine=chatterbox`
imports to this worker via the standard `/v2/{id}/run` REST API.

## How it fits

- `narrate_worker.py` — the `@Endpoint` function; runs `ingest_epub` →
  `narrate_bundle_batched(VllmChatterboxSynth)` → `extract_images`, returns
  `{bundle, audio_b64, images}` (same contract as `serverless/rp_handler.py`).
- `vimarsha/` (in `_stage/` only) — a fresh copy of `../src/vimarsha`, bundled into the flash
  artifact so the worker can import the real pipeline. `deploy.sh` re-copies it every run.
- Heavy CUDA deps (`chatterbox-vllm` → vLLM/torch) are installed on the GPU worker at runtime
  via `dependencies=[...]`, never bundled.
