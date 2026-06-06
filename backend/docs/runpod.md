# Running the Vimarsha backend on a GPU box

The backend is a stateless FastAPI service. Two ways to run it with **real Chatterbox**:

## Local (Apple Silicon, MPS) — default for dev
    cd backend
    uv sync --extra tts          # first run downloads the Chatterbox model
    uv run uvicorn vimarsha.server:app --port 8000
The client's default base URL (`http://localhost:8000`) points here.

## RunPod (CUDA) — for heavier / CI runs
1. Build and push the image (from `backend/`):
       docker build -t <your-registry>/vimarsha-backend:latest .
       docker push <your-registry>/vimarsha-backend:latest
2. Create a RunPod GPU pod from that image, expose port 8000.
3. Point the client at the pod URL by constructing `AppSettings(backendBaseUrl: 'https://<pod>-8000.proxy.runpod.net')` (wired into settings in a later plan), or set it when running the integration test:
       VIMARSHA_BACKEND_URL=https://<pod>-8000.proxy.runpod.net flutter test test_integration/real_backend_test.dart

The first `/import` is slow (model load + narration); subsequent calls are faster.
