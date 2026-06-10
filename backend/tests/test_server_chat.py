from fastapi.testclient import TestClient

from vimarsha.server import app, get_llm


class _FakeLlm:
    def __init__(self):
        self.last_system = None

    def reply(self, system: str, messages: list[dict]) -> str:
        self.last_system = system
        return "the passage says the team trusted each other"


def test_chat_returns_grounded_reply():
    fake = _FakeLlm()
    app.dependency_overrides[get_llm] = lambda: fake
    client = TestClient(app)
    resp = client.post("/chat", json={
        "messages": [{"role": "user", "text": "what is this about?"}],
        "context": {
            "passage": "The team trusted each other completely.",
            "bookTitle": "The Culture Code",
            "chapterTitle": "The Christmas Truce",
        },
    })
    assert resp.status_code == 200
    assert resp.json() == {"reply": "the passage says the team trusted each other"}
    # the passage is grounded into the system prompt
    assert "The team trusted each other completely." in fake.last_system
    app.dependency_overrides.clear()
