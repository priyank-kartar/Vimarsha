# Tech Stack

> **Status:** Reviewed · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). What everything is built with and why.
> Engineering conventions live with the code: [`CLAUDE.md`](../../CLAUDE.md) (repo) ·
> [`apple/CLAUDE.md`](../../apple/CLAUDE.md) (Swift client).

## Client (the product) — `apple/`

- **Swift 6 / SwiftUI**, multiplatform target: **iOS 26 + macOS 26** minimum (real Liquid
  Glass APIs only — [ADR-004](../00-overview/decision-log.md#adr-004--client-pivot-native-swiftui--liquid-glass-ios-26--macos-26)).
- **SwiftData** persistence; **AVFoundation** audio (playback + record); **URLSession**
  networking; **Swift Testing** for tests.
- Xcode project is folder-synchronized (new files auto-join targets); MainActor-default
  isolation. Build/run commands: [apple/CLAUDE.md §Project setup](../../apple/CLAUDE.md).

## Backend (dev/power path) — `backend/`

- **Python 3.13 + FastAPI**, managed by `uv` (`uv sync --extra tts`).
- **Chatterbox** TTS (the narration voice) · **faster-whisper** STT (memos/hold-to-talk) ·
  **Ollama** (`llama3.2:3b`) behind the `LlmClient` seam (Discuss).
- Runs on Apple Silicon MPS for dev (~7–8× slower than realtime) or CUDA via
  `backend/Dockerfile` + `backend/docs/runpod.md`.
- Final scope adds the **hosted service** around this same pipeline —
  [hosted-backend](hosted-backend.md) ([ADR-009](../00-overview/decision-log.md#adr-009--final-scope-backend-hosted-gpu-narration-service)).

## The contract (the seam between tiers)

- **`ChapterBundle`** — [`shared/bundle.schema.json`](../../shared/bundle.schema.json) is
  the schema; Swift `Codable` structs mirror it exactly (camelCase, no remapping).
- Endpoints (full client-facing set): `POST /toc` · `POST /import?chapter_index=N` ·
  `GET /audio/{name}` · `GET /image/{name}` · `POST /transcribe` · `POST /chat` ·
  `POST /speak`. Only ChapterBundle is schema-backed; other shapes are mirrored from the
  Flutter reference client.
- Backend is **stateless**; the client re-uploads the EPUB per chapter
  ([ADR-001](../00-overview/decision-log.md#adr-001--two-tier-architecture-stateless-backend-client-re-uploads-the-epub)).

## Frozen reference — `app/`

Flutter/Dart client (Riverpod, drift, just_audio): **feature-frozen**
([ADR-007](../00-overview/decision-log.md#adr-007--freeze-the-flutter-client-all-new-feature-work-is-swift-only)),
kept green as the behavioral spec for parity work. Port designs, not code.

## Topologies

| | Dev (now) | Final (hosted) |
|---|---|---|
| Narration | local backend on `localhost:8000` (or LAN/RunPod, repointable) | managed GPU workers + thin API ([hosted-backend](hosted-backend.md)) |
| Identity | none | Sign in with Apple |
| The client seam | same `BackendClient` protocol either way — the topology is a base-URL + auth concern, not an architecture fork | |

## Choices we're explicitly NOT making (yet)

No cross-platform framework round 2 (the pivot was the decision); no server-side library;
no WebSocket/streaming narration (chapter-granular jobs are simpler — revisit if Q-QUEUE
finds polling painful); no third-party analytics SDK (privacy posture first —
[privacy-security](privacy-security.md)).
