# Integration tests (real backend, real Chatterbox)

These are NOT run by `flutter test` (which only runs `test/`). Run them explicitly,
against a backend serving real Chatterbox.

1. Start the backend with the real TTS extra (see `backend/docs/runpod.md`):
       cd backend
       uv sync --extra tts
       uv run uvicorn vimarsha.server:app --port 8000
   (First run downloads the Chatterbox model and is slow.)

2. From `app/`, run the integration suite:
       flutter test test_integration/real_backend_test.dart
   Or against a RunPod URL:
       VIMARSHA_BACKEND_URL=https://<pod>-8000.proxy.runpod.net \
         flutter test test_integration/real_backend_test.dart

What it proves: `/toc` metadata, real narration with paragraph timings + figure
ms spans, and that the downloaded audio is a real MP3 over a second long (via ffprobe).
