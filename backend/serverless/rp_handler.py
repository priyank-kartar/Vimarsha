"""RunPod serverless handler — narrates one chapter with Chatterbox and returns the bundle.

Reuses the `vimarsha` package (installed in the image), so the worker IS the import pipeline
with Chatterbox. `runpod` is imported only under __main__ so this module is unit-testable.
"""
from __future__ import annotations

import base64
import tempfile
from pathlib import Path

from vimarsha.epub_reader import read_chapters
from vimarsha.figure_images import extract_images
from vimarsha.ingest import ingest_epub
from vimarsha.narrate import narrate_bundle_batched
from vimarsha.tts import VllmChatterboxSynth


def build_batch_synth(engine: str, voice: str | None):
    """The worker's batched synthesizer (overridable in tests). Premium narration is Chatterbox
    via vLLM regardless of ``engine``; ``engine`` is accepted for symmetry with the API."""
    return VllmChatterboxSynth(voice=voice)


def handler(event: dict) -> dict:
    inp = event.get("input") or {}
    data = base64.b64decode(inp["epub_b64"])
    chapter_index = int(inp.get("chapter_index", 0))
    engine = inp.get("engine") or "chatterbox"
    voice = inp.get("voice")

    out_dir = tempfile.mkdtemp(prefix="rp-audio-")
    with tempfile.NamedTemporaryFile(suffix=".epub", delete=False) as tmp:
        tmp.write(data)
        tmp.flush()
        epub_path = tmp.name
    try:
        chapters = read_chapters(epub_path)
        bundles = ingest_epub(epub_path)
        if not (0 <= chapter_index < len(bundles)):
            return {"error": "chapter_index out of range"}
        synth = build_batch_synth(engine, voice)
        narrated = narrate_bundle_batched(bundles[chapter_index], synth, out_dir)
        extract_images(
            epub_path, narrated.chapter_id, chapters[chapter_index].href,
            narrated.figure_map, out_dir,
        )
        bundle = narrated.model_dump(by_alias=True, exclude_none=True)
        audio_b64 = base64.b64encode((Path(out_dir) / bundle["audio"]).read_bytes()).decode()
        images: dict[str, str] = {}
        for fig in bundle.get("figureMap", []):
            name = fig.get("image")
            if name and (Path(out_dir) / name).is_file():
                images[name] = base64.b64encode((Path(out_dir) / name).read_bytes()).decode()
        return {"bundle": bundle, "audio_b64": audio_b64, "images": images}
    finally:
        Path(epub_path).unlink(missing_ok=True)


if __name__ == "__main__":
    import runpod  # only needed when actually running as a worker

    runpod.serverless.start({"handler": handler})
