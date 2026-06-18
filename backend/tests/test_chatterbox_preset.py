from vimarsha.tts import chatterbox_preset


def test_known_presets_map_to_generate_kwargs():
    assert chatterbox_preset("cb_storyteller") == {"exaggeration": 0.7, "cfg_weight": 0.3}
    assert chatterbox_preset("cb_steady") == {"exaggeration": 0.35, "cfg_weight": 0.5}
    assert chatterbox_preset("cb_intimate") == {"exaggeration": 0.5, "cfg_weight": 0.4}


def test_unknown_or_blank_voice_uses_chatterbox_defaults():
    assert chatterbox_preset("") == {}
    assert chatterbox_preset(None) == {}        # type: ignore[arg-type]
    assert chatterbox_preset("nope") == {}
