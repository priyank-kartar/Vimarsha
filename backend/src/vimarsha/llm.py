from __future__ import annotations

from typing import Protocol


class LlmClient(Protocol):
    def reply(self, system: str, messages: list[dict]) -> str:
        """Return the assistant reply for a system prompt + chat messages
        (each {'role': 'user'|'assistant', 'content': str})."""
        ...


class OllamaLlmClient:
    """Talks to a local Ollama server. Run `ollama serve` and
    `ollama pull llama3.2:3b` first."""

    def __init__(
        self,
        model: str = "llama3.2:3b",
        base_url: str = "http://localhost:11434",
    ):
        self._model = model
        self._base = base_url

    def reply(self, system: str, messages: list[dict]) -> str:
        import httpx

        payload = {
            "model": self._model,
            "messages": [{"role": "system", "content": system}] + messages,
            "stream": False,
        }
        resp = httpx.post(f"{self._base}/api/chat", json=payload, timeout=120.0)
        resp.raise_for_status()
        return resp.json()["message"]["content"].strip()
