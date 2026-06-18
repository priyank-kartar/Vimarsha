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
from runpod_flash import Endpoint, GpuGroup

# Runtime pip deps installed on the worker (not bundled). chatterbox-vllm pulls vLLM + torch.
_DEPS = [
    "chatterbox-vllm",
    "ebooklib",
    "beautifulsoup4",
    "lxml",
    "soundfile",
    "pydantic",
]


@Endpoint(
    name="vimarsha-premium",
    gpu=GpuGroup.AMPERE_24,        # 24GB (A5000 / L4 / 3090) — headroom for batched vLLM
    workers=(0, 2),               # scale-to-zero; up to 2 concurrent chapters
    dependencies=_DEPS,
    system_dependencies=["ffmpeg"],  # write_mp3 shells out to ffmpeg/libmp3lame
    idle_timeout=10,
    flashboot=True,
)
async def narrate(input_data: dict) -> dict:
    import base64
    import tempfile
    from pathlib import Path

    from vimarsha.epub_reader import read_chapters
    from vimarsha.figure_images import extract_images
    from vimarsha.ingest import ingest_epub
    from vimarsha.narrate import narrate_bundle_batched
    from vimarsha.tts import VllmChatterboxSynth

    data = base64.b64decode(input_data["epub_b64"])
    chapter_index = int(input_data.get("chapter_index", 0))
    voice = input_data.get("voice")

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

    print(asyncio.run(narrate({"epub_b64": "", "chapter_index": 0, "voice": "cb_steady"})))
