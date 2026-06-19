# Runpod Flash serverless worker: batched Chatterbox narration of one chapter.
#
# Deploy with `flash deploy` from this directory. The `vimarsha/` package is bundled alongside
# this file (copied from ../src/vimarsha by sync_vimarsha.sh) so the worker can import the real
# narration pipeline. Heavy CUDA deps (chatterbox-vllm -> vLLM/torch) are installed on the GPU
# worker at runtime via `dependencies` — never bundled into the artifact.
#
# Input payload (sent by the backend's RunPodNarrator):
#   {"epub_b64": <base64 epub>, "chapter_index": int, "engine": "chatterbox", "voice": "cb_*"}
# Returns: {"bundle": <ChapterBundle dict>, "audio_b64": <mp3>, "images": {name: b64}}
from runpod_flash import Endpoint, GpuGroup, NetworkVolume

# Heavy deps (chatterbox-vllm git + vLLM + torch) are multi-GB and git-only, so they can't be
# bundled into flash's 500MB artifact nor fetched from PyPI. Instead we install them ONCE into a
# persistent network volume and sys.path into it on every cold start. `_DEPS_DIR` is on the
# volume RunPod mounts at /runpod-volume. The light parsing deps live there too so all versions
# (esp. vLLM's numpy<2.3) stay consistent.
_DEPS_DIR = "/runpod-volume/deps"
_READY = _DEPS_DIR + "/.ready"
_INSTALL = [
    "chatterbox-vllm @ git+https://github.com/randombk/chatterbox-vllm",
    "ebooklib", "beautifulsoup4", "lxml", "soundfile", "pydantic",
]


def _ensure_deps() -> None:
    """Install the heavy/runtime deps into the network volume on first cold start (persisted),
    then put the volume on sys.path. Subsequent starts skip straight to the sys.path step."""
    import os
    import subprocess
    import sys

    if not os.path.exists(_READY):
        os.makedirs(_DEPS_DIR, exist_ok=True)
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "--target", _DEPS_DIR, *_INSTALL],
            check=True,
        )
        open(_READY, "w").close()
    if _DEPS_DIR not in sys.path:
        sys.path.insert(0, _DEPS_DIR)


# NOTE: flash statically AST-parses this decorator, so list/scalar args MUST be inline literals
# (a variable reference is silently dropped). The network volume holds the heavy deps.
@Endpoint(
    name="vimarsha-premium",
    gpu=GpuGroup.AMPERE_24,        # 24GB (A5000 / L4 / 3090) — headroom for batched vLLM
    workers=(0, 1),               # scale-to-zero; one chapter at a time (worker-quota friendly)
    volume=NetworkVolume(name="vimarsha-deps", size=40),  # persists vLLM/torch/chatterbox-vllm
    system_dependencies=["ffmpeg"],  # write_mp3 shells out to ffmpeg/libmp3lame
    idle_timeout=30,
    execution_timeout_ms=0,       # unlimited — the first run installs deps (~10-15 min)
    flashboot=True,
)
async def narrate(
    epub_b64: str, chapter_index: int = 0, engine: str = "chatterbox", voice: str | None = None
) -> dict:
    # Flash spreads the job input dict as kwargs (handler does narrate(**job_input)), so these
    # named params must match the backend's RunPodNarrator payload keys exactly.
    import base64
    import tempfile
    from pathlib import Path

    _ensure_deps()  # volume deps on sys.path before importing the pipeline (numpy/ebooklib/vllm)

    from vimarsha.epub_reader import read_chapters
    from vimarsha.figure_images import extract_images
    from vimarsha.ingest import ingest_epub
    from vimarsha.narrate import narrate_bundle_batched
    from vimarsha.tts import VllmChatterboxSynth

    data = base64.b64decode(epub_b64)
    chapter_index = int(chapter_index)

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
        synth = VllmChatterboxSynth(voice=voice)
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
    import asyncio

    print(asyncio.run(narrate(epub_b64="", chapter_index=0, voice="cb_steady")))
