from __future__ import annotations

import tempfile
from pathlib import Path

from fastapi import Depends, FastAPI, File, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import FileResponse

from vimarsha.ingest import ingest_epub
from vimarsha.metadata import read_book_meta
from vimarsha.models import ChapterSummary, TocResponse
from vimarsha.narrate import narrate_bundle
from vimarsha.tts import ChatterboxSynth, Synthesizer

app = FastAPI(title="Vimarsha backend")
app.state.audio_dir = tempfile.mkdtemp(prefix="vimarsha-audio-")


def get_synth() -> Synthesizer:
    """Default to the real Chatterbox synth; overridden in tests."""
    return ChatterboxSynth()


@app.post("/toc")
async def toc(file: UploadFile = File(...)):
    import tempfile
    from pathlib import Path as _Path

    tmp = tempfile.NamedTemporaryFile(suffix=".epub", delete=False)
    try:
        tmp.write(await file.read())
        tmp.flush()
        tmp.close()
        meta = await run_in_threadpool(read_book_meta, tmp.name)
        bundles = await run_in_threadpool(ingest_epub, tmp.name)
    finally:
        _Path(tmp.name).unlink(missing_ok=True)

    chapters = [
        ChapterSummary(index=i, chapter_id=b.chapter_id, title=b.title)
        for i, b in enumerate(bundles)
    ]
    return TocResponse(book=meta, chapters=chapters).model_dump(
        by_alias=True, exclude_none=True
    )


@app.post("/import")
async def import_chapter(
    chapter_index: int = 0,
    file: UploadFile = File(...),
    synth: Synthesizer = Depends(get_synth),
):
    data = await file.read()
    with tempfile.NamedTemporaryFile(suffix=".epub", delete=False) as tmp:
        tmp.write(data)
        tmp.flush()
        tmp_path_str = tmp.name
    try:
        bundles = await run_in_threadpool(ingest_epub, tmp_path_str)
    finally:
        Path(tmp_path_str).unlink(missing_ok=True)
    if not (0 <= chapter_index < len(bundles)):
        raise HTTPException(status_code=404, detail="chapter_index out of range")
    narrated = await run_in_threadpool(
        narrate_bundle, bundles[chapter_index], synth, app.state.audio_dir
    )
    return narrated.model_dump(by_alias=True, exclude_none=True)


@app.get("/audio/{name}")
def get_audio(name: str):
    base = Path(app.state.audio_dir).resolve()
    path = (base / name).resolve()
    if not path.is_file() or not path.is_relative_to(base):
        raise HTTPException(status_code=404, detail="audio not found")
    return FileResponse(str(path), media_type="audio/mpeg")
