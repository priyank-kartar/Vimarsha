"""RunPod serverless handler — narrates one chapter with Chatterbox and returns the bundle.

Reuses the `vimarsha` package (installed in the image), so the worker IS the import pipeline
with Chatterbox. BATCHED synthesis via the patched petermg fork (`ChatterboxBatchSynth` +
`narrate_bundle_batched`) — ~3.4x faster than sequential on a full chapter, same audio. The
fork is overlaid over pip's chatterbox in the image (see Dockerfile.serverless). `runpod` is
imported only under __main__ so this module is unit-testable.
"""
from __future__ import annotations

import base64
import os
import tempfile
import urllib.request
from pathlib import Path

from vimarsha.chatterbox_batch import ChatterboxBatchSynth
from vimarsha.epub_reader import read_chapters
from vimarsha.figure_images import extract_images
from vimarsha.ingest import ingest_epub
from vimarsha.narrate import narrate_bundle_batched

# GPU-memory-bound batch width; tune per GPU (A40 48GB comfortably handles 16+).
MAX_BATCH = int(os.environ.get("VIMARSHA_MAX_BATCH", "16"))

# Warm worker: a RunPod worker process stays alive across requests (within the idle window), so
# cache the synth — and thus the loaded model — instead of rebuilding it every job. Keyed by
# (engine, voice); the common case is many chapters of one book → one voice → load once.
_synth_cache: dict[tuple[str, str], object] = {}


def make_batch_synth(engine: str, voice: str | None):
    """Construct the batched synth (overridable in tests)."""
    return ChatterboxBatchSynth(voice=voice)


def build_synth(engine: str, voice: str | None):
    """Cached batched-synth factory. Loads the model ONCE per (engine, voice) per worker
    process, eliminating the ~30-60s per-request model reload."""
    key = (engine or "chatterbox", voice or "")
    if key not in _synth_cache:
        _synth_cache[key] = make_batch_synth(engine, voice)
    return _synth_cache[key]


def _upload(url: str, secret: str, name: str, data: bytes) -> None:
    """PUT one artifact (mp3/image) to the backend's /upload sink — used in callback mode to
    bypass RunPod's 10MB job-result cap. ``url`` is the base (…/upload); ``name`` is the basename.

    The backend sits behind Cloudflare, which 403s urllib's default ``Python-urllib`` User-Agent
    (bot protection) — so a real User-Agent MUST be set or every upload fails at the edge."""
    req = urllib.request.Request(
        f"{url.rstrip('/')}/{name}",
        data=data,
        method="PUT",
        headers={
            "X-Ingest-Secret": secret,
            "Content-Type": "application/octet-stream",
            "User-Agent": "vimarsha-worker/1.0",
        },
    )
    with urllib.request.urlopen(req, timeout=120) as resp:  # noqa: S310 (our own backend)
        resp.read()


def handler(event: dict) -> dict:
    inp = event.get("input") or {}
    data = base64.b64decode(inp["epub_b64"])
    chapter_index = int(inp.get("chapter_index", 0))
    engine = inp.get("engine") or "chatterbox"
    voice = inp.get("voice")
    result_url = inp.get("result_url")
    ingest_secret = inp.get("ingest_secret")

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
        synth = build_synth(engine, voice)
        try:
            narrated = narrate_bundle_batched(bundles[chapter_index], synth, out_dir, max_batch=MAX_BATCH)
        except ValueError as exc:
            # e.g. a part-divider/front-matter chapter with no narratable text — report it as a
            # clean error (the client marks the chapter failed) rather than crashing the worker.
            return {"error": str(exc)}
        extract_images(
            epub_path, narrated.chapter_id, chapters[chapter_index].href,
            narrated.figure_map, out_dir,
        )
        bundle = narrated.model_dump(by_alias=True, exclude_none=True)
        audio_name = bundle["audio"]
        image_names = [
            fig["image"]
            for fig in bundle.get("figureMap", [])
            if fig.get("image") and (Path(out_dir) / fig["image"]).is_file()
        ]

        # Callback mode: upload audio + images out-of-band so the (possibly >10MB) bytes never
        # ride in the job result. Return only the small bundle. Falls back to inline base64 when
        # no callback is configured (small chapters / local tests).
        if result_url and ingest_secret:
            _upload(result_url, ingest_secret, audio_name, (Path(out_dir) / audio_name).read_bytes())
            for name in image_names:
                _upload(result_url, ingest_secret, name, (Path(out_dir) / name).read_bytes())
            return {"bundle": bundle}

        audio_b64 = base64.b64encode((Path(out_dir) / audio_name).read_bytes()).decode()
        images = {
            name: base64.b64encode((Path(out_dir) / name).read_bytes()).decode()
            for name in image_names
        }
        return {"bundle": bundle, "audio_b64": audio_b64, "images": images}
    finally:
        Path(epub_path).unlink(missing_ok=True)


if __name__ == "__main__":
    import runpod  # only needed when actually running as a worker

    runpod.serverless.start({"handler": handler})
