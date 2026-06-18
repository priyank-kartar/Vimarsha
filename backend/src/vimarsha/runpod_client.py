from __future__ import annotations

import httpx


class RunPodClient:
    """Minimal RunPod serverless REST client: submit a job and poll its status.

    https://docs.runpod.io/serverless/endpoints/job-operations — POST /v2/{id}/run,
    GET /v2/{id}/status/{job}. ``http`` is injectable so tests use ``httpx.MockTransport``.
    """

    def __init__(
        self,
        endpoint_id: str,
        api_key: str,
        http: httpx.Client | None = None,
        base_url: str = "https://api.runpod.ai/v2",
    ):
        self._base = f"{base_url}/{endpoint_id}"
        self._headers = {"Authorization": f"Bearer {api_key}"}
        self._http = http or httpx.Client(timeout=60.0)

    def submit(self, payload: dict) -> str:
        resp = self._http.post(f"{self._base}/run", json={"input": payload}, headers=self._headers)
        resp.raise_for_status()
        return resp.json()["id"]

    def status(self, job_id: str) -> dict:
        resp = self._http.get(f"{self._base}/status/{job_id}", headers=self._headers)
        resp.raise_for_status()
        return resp.json()
