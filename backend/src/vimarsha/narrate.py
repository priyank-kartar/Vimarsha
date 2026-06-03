from __future__ import annotations

from pathlib import Path
from typing import Optional

import numpy as np

from vimarsha.audio_io import write_mp3
from vimarsha.models import Block, ChapterBundle
from vimarsha.stitch import assemble
from vimarsha.tts import Synthesizer, chunk_text


def narratable_text(block: Block) -> Optional[str]:
    """Return the text to read for a block, or None to skip it."""
    if block.kind in ("heading", "paragraph", "blockquote", "pullquote", "list"):
        return block.text or None
    if block.kind in ("figure", "image", "table"):
        return block.caption or None
    return None


def _synthesize_block(text: str, synth: Synthesizer) -> np.ndarray:
    parts = [synth.synthesize(c) for c in chunk_text(text)]
    if not parts:
        return np.zeros(0, dtype=np.float32)
    return np.concatenate(parts)


def _resolve_ms(
    block_id: str, blocks: list[Block], timings: dict[str, list[int]], edge: str
) -> int:
    """Map a span endpoint block id to a millisecond position.

    If the block itself was narrated, use its own timing; otherwise fall back to
    the nearest narrated block (prior for 'start', following for 'end').
    """
    if block_id in timings:
        return timings[block_id][0 if edge == "start" else 1]
    index_of = {b.id: b.index for b in blocks}
    target = index_of[block_id]
    narrated = sorted((b.index, b.id) for b in blocks if b.id in timings)
    if not narrated:
        return 0
    if edge == "start":
        prior = [bid for (i, bid) in narrated if i <= target]
        chosen = prior[-1] if prior else narrated[0][1]
        return timings[chosen][0]
    after = [bid for (i, bid) in narrated if i >= target]
    chosen = after[0] if after else narrated[-1][1]
    return timings[chosen][1]


def narrate_bundle(
    bundle: ChapterBundle,
    synth: Synthesizer,
    out_dir: str,
    para_gap_ms: int = 400,
) -> ChapterBundle:
    """Synthesize narration, stitch audio, and fill audio/timings/figure ms."""
    segments: list[tuple[str, np.ndarray]] = []
    for b in bundle.blocks:
        text = narratable_text(b)
        if text is None:
            continue
        segments.append((b.id, _synthesize_block(text, synth)))

    waveform, timings = assemble(segments, synth.sample_rate, para_gap_ms)

    audio_name = f"{bundle.chapter_id}.mp3"
    write_mp3(waveform, synth.sample_rate, str(Path(out_dir) / audio_name))

    out = bundle.model_copy(deep=True)
    out.audio = audio_name
    out.para_timings = timings
    for fig in out.figure_map:
        fig.start_ms = _resolve_ms(fig.start_para, out.blocks, timings, "start")
        fig.end_ms = _resolve_ms(fig.end_para, out.blocks, timings, "end")
    return out
