from vimarsha.tts import chunk_text


def test_short_text_is_one_chunk():
    assert chunk_text("Hello world.") == ["Hello world."]


def test_splits_on_sentence_boundaries_under_limit():
    text = "One sentence here. Two follows it. Three is last."
    chunks = chunk_text(text, max_chars=25)
    assert chunks == ["One sentence here.", "Two follows it.", "Three is last."]


def test_accumulates_until_limit():
    text = "A. B. C. D."
    # max_chars large enough to merge all
    assert chunk_text(text, max_chars=100) == ["A. B. C. D."]


def test_oversized_single_sentence_is_kept_whole():
    long = "word " * 100  # no sentence break
    chunks = chunk_text(long.strip(), max_chars=50)
    assert len(chunks) == 1
    assert chunks[0].startswith("word")
