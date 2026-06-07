# Vimarsha

A talking EPUB reader that **narrates books aloud**, **shows the right
figure/diagram/quote on screen the moment it's discussed**, and (in progress)
lets you **record voice notes and discuss passages with an AI**.

- **Client:** Flutter (macOS today; built to extend to phone).
- **Backend:** Python / FastAPI on a local GPU, using
  [Chatterbox TTS](https://github.com/resemble-ai/chatterbox) for narration.
- **Format:** EPUB first (internal model is format-agnostic for MOBI/PDF later).

> Vimarsha (विमर्श) — "reflection / deliberation / discussion."

## How it works

When you add a book, the backend parses the EPUB, detects figures/quotes and the
text span where each is discussed, and narrates a chapter with Chatterbox into a
single audio file plus a paragraph→millisecond timing map. The app caches that
bundle and plays it back offline, surfacing each figure during its time range.
The backend is stateless and only does work at import time.

## Quickstart

Prereqs: Python 3.13 + [uv](https://docs.astral.sh/uv/), Flutter 3.44+, `ffmpeg`,
and Apple Silicon (MPS) or an NVIDIA GPU for Chatterbox.

```bash
# 1. Backend (first run downloads the Chatterbox model)
cd backend
uv sync --extra tts
uv run uvicorn vimarsha.server:app --port 8000

# 2. App (in another terminal, with the backend running)
cd app
flutter run -d macos
```

In the app: **+** to add an EPUB → open the book → download a chapter (badge goes
spinner → ✓) → tap it to play (play/pause, scrub, 0.75–2× speed, resume).

## Tests

```bash
cd backend && uv run pytest                         # backend, no GPU needed
cd app && flutter analyze && flutter test           # client
# optional, exercises the real Chatterbox pipeline (backend must be running):
cd app && flutter test test_integration/real_backend_test.dart
```

## Project layout

| Path | What |
|---|---|
| `backend/` | EPUB ingestion, figure detection, Chatterbox narration, FastAPI |
| `app/` | Flutter client (Riverpod, just_audio, drift) |
| `shared/` | `bundle.schema.json` contract + fixtures |
| `docs/superpowers/` | design specs and implementation plans |
| `CLAUDE.md` | guide for AI coding agents (architecture, conventions, gotchas) |

## Status

Core reading loop is complete and working end-to-end (import → narrate → cache →
play). Next: on-screen figure overlay, voice notes (on-device Whisper), and the
deep-dive AI conversation. See `CLAUDE.md` for details.
