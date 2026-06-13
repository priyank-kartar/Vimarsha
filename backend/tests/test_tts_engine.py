"""Engine selection for the pluggable TTS backend (Chatterbox vs Kokoro).

Only the *selection* logic is unit-tested here — constructing a real engine loads a
multi-hundred-MB model, so that stays an opt-in integration concern (like real Chatterbox).
"""
import pytest

from vimarsha.tts import ChatterboxSynth, KokoroSynth, synth_class


def test_synth_class_selects_by_name():
    assert synth_class("chatterbox") is ChatterboxSynth
    assert synth_class("kokoro") is KokoroSynth


def test_synth_class_is_case_insensitive_and_trims_whitespace():
    assert synth_class("  Kokoro ") is KokoroSynth
    assert synth_class("CHATTERBOX") is ChatterboxSynth


def test_synth_class_default_is_chatterbox():
    # None / empty preserves the existing default so current deployments don't change.
    assert synth_class(None) is ChatterboxSynth
    assert synth_class("") is ChatterboxSynth


def test_synth_class_unknown_raises_valueerror():
    with pytest.raises(ValueError):
        synth_class("bogus-engine")


class _Fake:
    sample_rate = 16000

    def synthesize(self, text):  # noqa: ARG002
        import numpy as np

        return np.zeros(1, dtype=np.float32)


def test_get_synth_honors_env(monkeypatch):
    """get_synth() picks the engine named by VIMARSHA_TTS, via synth_class."""
    import vimarsha.server as server

    seen = {}

    def _fake_class(name):
        seen["name"] = name
        return _Fake

    server._synth_cache.clear()
    monkeypatch.setenv("VIMARSHA_TTS", "kokoro")
    monkeypatch.setattr(server, "synth_class", _fake_class)
    try:
        s = server.get_synth()
        assert seen["name"] == "kokoro"
        assert isinstance(s, _Fake)
    finally:
        server._synth_cache.clear()


def test_synth_for_override_caches_per_engine(monkeypatch):
    """A per-request engine builds a cached instance; blank keeps the injected default."""
    import vimarsha.server as server

    default = _Fake()
    server._synth_cache.clear()
    monkeypatch.setattr(server, "synth_class", lambda name: _Fake)
    try:
        # blank/None → the injected default object is returned unchanged
        assert server.synth_for(None, default) is default
        assert server.synth_for("  ", default) is default
        # a named engine → a *different* cached instance, stable across calls
        a = server.synth_for("kokoro", default)
        b = server.synth_for("kokoro", default)
        assert a is b and a is not default
    finally:
        server._synth_cache.clear()


def test_speak_rejects_unknown_engine():
    """An unknown ?engine= surfaces as 400, not a 500."""
    from fastapi.testclient import TestClient

    from vimarsha.server import app, get_synth

    app.dependency_overrides[get_synth] = lambda: _Fake()
    try:
        client = TestClient(app)
        resp = client.post("/speak?engine=bogus", json={"text": "hello"})
        assert resp.status_code == 400
    finally:
        app.dependency_overrides.clear()


from vimarsha.tts import kokoro_lang


def test_kokoro_lang_from_voice_prefix():
    assert kokoro_lang("af_heart") == "a"   # American
    assert kokoro_lang("am_michael") == "a"
    assert kokoro_lang("bf_emma") == "b"     # British
    assert kokoro_lang("bm_george") == "b"
    assert kokoro_lang("") == "a"            # empty → default American
    assert kokoro_lang("B_weird") == "b"     # case-insensitive prefix
