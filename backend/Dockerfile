# Vimarsha backend with real Chatterbox TTS (CUDA). For RunPod or any GPU host.
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3.11 python3-pip ffmpeg git curl \
    && rm -rf /var/lib/apt/lists/*

# uv for fast, reproducible installs
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

WORKDIR /app
COPY pyproject.toml uv.lock ./
COPY src ./src
# Install with the real-TTS extra (chatterbox-tts + torch).
RUN uv sync --extra tts --frozen

EXPOSE 8000
CMD ["uv", "run", "uvicorn", "vimarsha.server:app", "--host", "0.0.0.0", "--port", "8000"]
