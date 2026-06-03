# Manual Chatterbox smoke test (needs GPU/MPS)

    cd backend
    uv sync --extra tts
    uv run python - <<'PY'
    from vimarsha.tts import ChatterboxSynth
    from vimarsha.audio_io import write_mp3
    s = ChatterboxSynth()
    wav = s.synthesize("Hello from Chatterbox, reading your book aloud.")
    write_mp3(wav, s.sample_rate, "/tmp/chatterbox_smoke.mp3")
    print("wrote /tmp/chatterbox_smoke.mp3", s.sample_rate)
    PY

Listen to `/tmp/chatterbox_smoke.mp3`. Expect a clear spoken sentence.
