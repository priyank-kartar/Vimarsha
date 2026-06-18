import base64

from vimarsha.remote_narrator import RemoteResult, RunPodNarrator


class _StubClient:
    def __init__(self, output):
        self._output = output
        self._polls = 0

    def submit(self, payload):
        self.payload = payload
        return "rpjob-1"

    def status(self, job_id):
        self._polls += 1
        if self._polls < 2:
            return {"status": "IN_PROGRESS"}
        return {"status": "COMPLETED", "output": self._output}


def test_runpod_narrator_returns_decoded_result():
    output = {
        "bundle": {"chapterId": "c1", "audio": "c1.mp3"},
        "audio_b64": base64.b64encode(b"MP3BYTES").decode(),
        "images": {"fig.png": base64.b64encode(b"\x89PNG").decode()},
    }
    stub = _StubClient(output)
    narrator = RunPodNarrator(stub, poll_interval=0.0)
    result = narrator.narrate(b"EPUBDATA", chapter_index=0, engine="chatterbox", voice="cb_steady")
    assert isinstance(result, RemoteResult)
    assert result.bundle["chapterId"] == "c1"
    assert result.audio == b"MP3BYTES"
    assert result.images["fig.png"] == b"\x89PNG"
    assert base64.b64decode(stub.payload["epub_b64"]) == b"EPUBDATA"
    assert stub.payload["voice"] == "cb_steady"


def test_runpod_narrator_raises_on_failed():
    class _Failing(_StubClient):
        def status(self, job_id):
            return {"status": "FAILED", "error": "boom"}

    narrator = RunPodNarrator(_Failing(None), poll_interval=0.0)
    try:
        narrator.narrate(b"x", 0, "chatterbox", "cb_steady")
        raise AssertionError("expected failure")
    except RuntimeError as exc:
        assert "boom" in str(exc)
