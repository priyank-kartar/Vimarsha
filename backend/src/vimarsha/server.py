from __future__ import annotations

import tempfile
from pathlib import Path

from fastapi import Depends, FastAPI, File, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import FileResponse

from vimarsha.epub_reader import read_chapters
from vimarsha.figure_images import extract_images
from vimarsha.ingest import ingest_epub
from vimarsha.llm import LlmClient, OllamaLlmClient
from vimarsha.metadata import read_book_meta
from vimarsha.models import ChatContextModel, ChatRequest, ChapterSummary, SpeakRequest, TocResponse
from vimarsha.narrate import narrate_bundle
from vimarsha.transcribe import FasterWhisperTranscriber, Transcriber
from vimarsha.tts import ChatterboxSynth, Synthesizer

app = FastAPI(title="Vimarsha backend")
app.state.audio_dir = tempfile.mkdtemp(prefix="vimarsha-audio-")


_llm: LlmClient | None = None


def get_llm() -> LlmClient:
    """Cached Ollama client; overridden in tests."""
    global _llm
    if _llm is None:
        _llm = OllamaLlmClient()
    return _llm


def _chat_system(ctx: ChatContextModel) -> str:
    fig = f"\nA figure on screen is captioned: {ctx.figure_caption}" if ctx.figure_caption else ""
    return (
        f"You are a thoughtful reading companion discussing "
        f"\"{ctx.book_title}\" — chapter \"{ctx.chapter_title}\".\n"
        f"The reader is currently on this passage:\n\"\"\"\n{ctx.passage}\n\"\"\"{fig}\n"
        f"Answer their questions about it clearly and concisely. Ground your "
        f"answer in this passage; if it isn't covered, say so briefly."
    )


@app.post("/chat")
async def chat(req: ChatRequest, llm: LlmClient = Depends(get_llm)):
    system = _chat_system(req.context)
    messages = [{"role": m.role, "content": m.text} for m in req.messages]
    reply = await run_in_threadpool(llm.reply, system, messages)
    return {"reply": reply}


def get_synth() -> Synthesizer:
    """Default to the real Chatterbox synth; overridden in tests."""
    return ChatterboxSynth()


_transcriber: Transcriber | None = None


def get_transcriber() -> Transcriber:
    """Cached faster-whisper transcriber (loaded once); overridden in tests."""
    global _transcriber
    if _transcriber is None:
        _transcriber = FasterWhisperTranscriber()
    return _transcriber


@app.post("/transcribe")
async def transcribe(
    file: UploadFile = File(...),
    transcriber: Transcriber = Depends(get_transcriber),
):
    suffix = Path(file.filename or "audio").suffix or ".m4a"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(await file.read())
        tmp.flush()
        tmp_path_str = tmp.name
    try:
        text = await run_in_threadpool(transcriber.transcribe, tmp_path_str)
    finally:
        Path(tmp_path_str).unlink(missing_ok=True)
    return {"text": text}


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
        chapters = await run_in_threadpool(read_chapters, tmp_path_str)
        bundles = await run_in_threadpool(ingest_epub, tmp_path_str)
        if not (0 <= chapter_index < len(bundles)):
            raise HTTPException(status_code=404, detail="chapter_index out of range")
        narrated = await run_in_threadpool(
            narrate_bundle, bundles[chapter_index], synth, app.state.audio_dir
        )
        await run_in_threadpool(
            extract_images,
            tmp_path_str,
            narrated.chapter_id,
            chapters[chapter_index].href,
            narrated.figure_map,
            app.state.audio_dir,
        )
    finally:
        Path(tmp_path_str).unlink(missing_ok=True)
    return narrated.model_dump(by_alias=True, exclude_none=True)


@app.get("/image/{name}")
def get_image(name: str):
    base = Path(app.state.audio_dir).resolve()
    path = (base / name).resolve()
    if not path.is_file() or not path.is_relative_to(base):
        raise HTTPException(status_code=404, detail="image not found")
    return FileResponse(str(path))


@app.get("/audio/{name}")
def get_audio(name: str):
    base = Path(app.state.audio_dir).resolve()
    path = (base / name).resolve()
    if not path.is_file() or not path.is_relative_to(base):
        raise HTTPException(status_code=404, detail="audio not found")
    return FileResponse(str(path), media_type="audio/mpeg")
