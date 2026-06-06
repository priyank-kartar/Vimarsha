# Vimarsha backend with real Chatterbox TTS (CUDA). For RunPod or any GPU host.
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

# System deps only. Python itself is provided by uv (the project requires
# >=3.13, which Ubuntu 22.04 does not ship), so we do NOT apt-install python.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg git curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# uv for fast, reproducible installs (also manages the Python toolchain)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

WORKDIR /app
COPY pyproject.toml uv.lock .python-version ./
COPY src ./src
# uv installs managed CPython 3.13 (per .python-version / requires-python),
# then resolves the locked deps with the real-TTS extra (chatterbox-tts + torch).
RUN uv python install 3.13 && uv sync --extra tts --frozen

EXPOSE 8000
CMD ["uv", "run", "uvicorn", "vimarsha.server:app", "--host", "0.0.0.0", "--port", "8000"]
