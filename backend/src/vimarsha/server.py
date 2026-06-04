from __future__ import annotations

import tempfile
from pathlib import Path

from fastapi import Depends, FastAPI, File, HTTPException, UploadFile
from fastapi.responses import FileResponse

from vimarsha.ingest import ingest_epub
from vimarsha.narrate import narrate_bundle
from vimarsha.tts import ChatterboxSynth, Synthesizer

app = FastAPI(title="Vimarsha backend")
app.state.audio_dir = tempfile.mkdtemp(prefix="vimarsha-audio-")


def get_synth() -> Synthesizer:
    """Default to the real Chatterbox synth; overridden in tests."""
    return ChatterboxSynth()


@app.post("/import")
async def import_chapter(
    chapter_index: int = 0,
    file: UploadFile = File(...),
    synth: Synthesizer = Depends(get_synth),
):
    with tempfile.NamedTemporaryFile(suffix=".epub", delete=True) as tmp:
        tmp.write(await file.read())
        tmp.flush()
        bundles = ingest_epub(tmp.name)
    if not (0 <= chapter_index < len(bundles)):
        raise HTTPException(status_code=404, detail="chapter_index out of range")
    narrated = narrate_bundle(bundles[chapter_index], synth, app.state.audio_dir)
    return narrated.model_dump(by_alias=True, exclude_none=True)


@app.get("/audio/{name}")
def get_audio(name: str):
    path = Path(app.state.audio_dir) / name
    if not path.is_file():
        raise HTTPException(status_code=404, detail="audio not found")
    return FileResponse(str(path), media_type="audio/mpeg")
