from __future__ import annotations

import os
import tempfile
from pathlib import Path

import numpy as np
from fastapi import Depends, FastAPI, File, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import FileResponse
from starlette.background import BackgroundTask

from vimarsha.audio_io import write_mp3
from vimarsha.epub_reader import read_chapters
from vimarsha.figure_images import extract_images
from vimarsha.ingest import ingest_epub
from vimarsha.llm import LlmClient, OllamaLlmClient
from vimarsha.metadata import read_book_meta
from vimarsha.models import ChatContextModel, ChatRequest, ChapterSummary, SpeakRequest, TocResponse
from vimarsha.narrate import narrate_bundle
from vimarsha.stitch import assemble
from vimarsha.transcribe import FasterWhisperTranscriber, Transcriber
from vimarsha.tts import Synthesizer, chunk_text, synth_class

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


# One cached instance per engine class (loaded ONCE, like the transcriber) so switching
# engines per request never reloads a model — reloading on every call ballooned memory/disk.
_synth_cache: dict[str, Synthesizer] = {}


def _cached_synth(engine: str | None, voice: str | None) -> Synthesizer:
    cls = synth_class(engine)  # raises ValueError on an unknown name
    key = f"{cls.__name__}:{voice or ''}"
    if key not in _synth_cache:
        _synth_cache[key] = cls(voice=voice) if voice else cls()
    return _synth_cache[key]


def get_synth() -> Synthesizer:
    """The default-engine synth (``VIMARSHA_TTS`` → ``vimarsha.tts.synth_class``); cached and
    dependency-injected so tests can override it with a fake."""
    return _cached_synth(os.environ.get("VIMARSHA_TTS"), None)


def synth_for(engine: str | None, voice: str | None, default: Synthesizer) -> Synthesizer:
    """Per-request engine/voice override (the client picks via ``?engine=`` / ``?voice=``).
    Blank engine AND voice keep the injected ``default`` (so the env default and test overrides
    win); otherwise a cached instance for that (engine, voice). Raises ``ValueError`` on an
    unknown engine name."""
    if not (engine and engine.strip()) and not (voice and voice.strip()):
        return default
    return _cached_synth(engine, voice)


def _resolve_synth(engine: str | None, voice: str | None, default: Synthesizer) -> Synthesizer:
    try:
        return synth_for(engine, voice, default)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from None


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
    engine: str | None = None,
    voice: str | None = None,
    file: UploadFile = File(...),
    synth: Synthesizer = Depends(get_synth),
):
    synth = _resolve_synth(engine, voice, synth)
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


@app.post("/speak")
async def speak(
    req: SpeakRequest,
    engine: str | None = None,
    voice: str | None = None,
    synth: Synthesizer = Depends(get_synth),
):
    synth = _resolve_synth(engine, voice, synth)
    if not req.text.strip():
        raise HTTPException(status_code=400, detail="empty text")

    def _render() -> str:
        out = tempfile.NamedTemporaryFile(suffix=".mp3", delete=False)
        out.close()
        try:
            wav = np.concatenate([synth.synthesize(c) for c in chunk_text(req.text)])
            full, _timings = assemble([("reply", wav)], synth.sample_rate, 0)
            write_mp3(full, synth.sample_rate, out.name)
        except BaseException:
            # Don't leak the temp file if synthesis/encoding fails.
            os.remove(out.name)
            raise
        return out.name

    path = await run_in_threadpool(_render)
    return FileResponse(
        path, media_type="audio/mpeg", background=BackgroundTask(os.remove, path)
    )
