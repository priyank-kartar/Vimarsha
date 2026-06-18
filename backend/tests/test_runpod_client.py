import httpx

from vimarsha.runpod_client import RunPodClient


def _client_with(handler):
    transport = httpx.MockTransport(handler)
    http = httpx.Client(transport=transport)
    return RunPodClient(endpoint_id="ep123", api_key="rpa_test", http=http)


def test_submit_posts_to_run_with_bearer_and_input():
    seen = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen["url"] = str(request.url)
        seen["auth"] = request.headers.get("authorization")
        seen["body"] = request.read().decode()
        return httpx.Response(200, json={"id": "rpjob-1", "status": "IN_QUEUE"})

    rp = _client_with(handler)
    job_id = rp.submit({"epub_b64": "AAA", "chapter_index": 0})
    assert job_id == "rpjob-1"
    assert seen["url"] == "https://api.runpod.ai/v2/ep123/run"
    assert seen["auth"] == "Bearer rpa_test"
    assert '"input"' in seen["body"] and '"epub_b64"' in seen["body"]


def test_status_gets_status_endpoint():
    def handler(request: httpx.Request) -> httpx.Response:
        assert str(request.url) == "https://api.runpod.ai/v2/ep123/status/rpjob-1"
        return httpx.Response(200, json={"status": "COMPLETED", "output": {"ok": True}})

    rp = _client_with(handler)
    body = rp.status("rpjob-1")
    assert body["status"] == "COMPLETED"
    assert body["output"] == {"ok": True}
