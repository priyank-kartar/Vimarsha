from __future__ import annotations

import base64
import time
from dataclasses import dataclass
from typing import Protocol


@dataclass
class RemoteResult:
    """What a remote narration returns: the bundle dict + the mp3 + figure-image bytes."""

    bundle: dict
    audio: bytes
    images: dict[str, bytes]


class RemoteNarrator(Protocol):
    """Narrate one chapter remotely (premium tier). Mirrors the local pipeline's output."""

    def narrate(
        self, epub: bytes, chapter_index: int, engine: str, voice: str | None
    ) -> RemoteResult: ...


class RunPodNarrator:
    """RemoteNarrator over a RunPodClient: submit a job, poll until terminal, decode the output."""

    _TERMINAL_OK = "COMPLETED"
    _TERMINAL_FAIL = {"FAILED", "CANCELLED", "TIMED_OUT"}

    def __init__(self, client, poll_interval: float = 3.0, timeout_s: float = 3 * 60 * 60):
        self._client = client
        self._poll_interval = poll_interval
        self._timeout_s = timeout_s

    def narrate(
        self, epub: bytes, chapter_index: int, engine: str, voice: str | None
    ) -> RemoteResult:
        job_id = self._client.submit(
            {
                "epub_b64": base64.b64encode(epub).decode(),
                "chapter_index": chapter_index,
                "engine": engine,
                "voice": voice,
            }
        )
        deadline = time.monotonic() + self._timeout_s
        while time.monotonic() < deadline:
            body = self._client.status(job_id)
            status = body.get("status")
            if status == self._TERMINAL_OK:
                out = body.get("output") or {}
                # The worker reports recoverable problems (bad chapter index, no narratable text)
                # as a COMPLETED job with an ``error`` field instead of a bundle. Surface that
                # message instead of crashing on a cryptic ``KeyError('bundle')``.
                if "bundle" not in out:
                    raise RuntimeError(out.get("error") or "remote narration returned no bundle")
                return RemoteResult(
                    bundle=out["bundle"],
                    audio=base64.b64decode(out["audio_b64"]),
                    images={k: base64.b64decode(v) for k, v in (out.get("images") or {}).items()},
                )
            if status in self._TERMINAL_FAIL:
                raise RuntimeError(body.get("error") or f"remote narration {status}")
            time.sleep(self._poll_interval)
        raise TimeoutError("remote narration timed out")


class FakeRemoteNarrator:
    """Test double: returns a canned ``RemoteResult`` and records the call."""

    def __init__(self, result: RemoteResult):
        self._result = result
        self.calls: list[tuple] = []

    def narrate(self, epub, chapter_index, engine, voice) -> RemoteResult:
        self.calls.append((epub, chapter_index, engine, voice))
        return self._result
