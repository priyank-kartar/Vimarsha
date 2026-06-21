from __future__ import annotations

import base64
import time
from dataclasses import dataclass, field
from typing import Protocol


@dataclass
class RemoteResult:
    """What a remote narration returns: the bundle dict + the mp3 + figure-image bytes.

    When the worker uploads audio/images out-of-band (the /upload callback that dodges RunPod's
    10MB job-result cap), ``audio``/``images`` are empty — the bytes are already on the backend
    disk — and only ``bundle`` is carried inline.
    """

    bundle: dict
    audio: bytes = b""
    images: dict[str, bytes] = field(default_factory=dict)


class RemoteNarrator(Protocol):
    """Narrate one chapter remotely (premium tier). Mirrors the local pipeline's output."""

    def narrate(
        self, epub: bytes, chapter_index: int, engine: str, voice: str | None
    ) -> RemoteResult: ...


class RunPodNarrator:
    """RemoteNarrator over a RunPodClient: submit a job, poll until terminal, decode the output."""

    _TERMINAL_OK = "COMPLETED"
    _TERMINAL_FAIL = {"FAILED", "CANCELLED", "TIMED_OUT"}

    def __init__(
        self,
        client,
        poll_interval: float = 3.0,
        timeout_s: float = 3 * 60 * 60,
        result_url: str | None = None,
        ingest_secret: str | None = None,
    ):
        self._client = client
        self._poll_interval = poll_interval
        self._timeout_s = timeout_s
        # When both are set, tell the worker to upload audio/images here instead of inlining them
        # in the job result (RunPod caps the result at 10MB — long chapters blow past it).
        self._result_url = result_url
        self._ingest_secret = ingest_secret

    def narrate(
        self, epub: bytes, chapter_index: int, engine: str, voice: str | None
    ) -> RemoteResult:
        payload = {
            "epub_b64": base64.b64encode(epub).decode(),
            "chapter_index": chapter_index,
            "engine": engine,
            "voice": voice,
        }
        if self._result_url and self._ingest_secret:
            payload["result_url"] = self._result_url
            payload["ingest_secret"] = self._ingest_secret
        job_id = self._client.submit(payload)
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
                # Callback mode: audio/images were uploaded out-of-band (no ``audio_b64``) — the
                # bytes are already on the backend disk, so carry only the bundle inline.
                audio_b64 = out.get("audio_b64")
                return RemoteResult(
                    bundle=out["bundle"],
                    audio=base64.b64decode(audio_b64) if audio_b64 else b"",
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
