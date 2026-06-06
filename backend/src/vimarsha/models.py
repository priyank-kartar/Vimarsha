from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

BlockKind = Literal[
    "heading", "paragraph", "image", "figure",
    "blockquote", "pullquote", "table", "list",
]
FigureKind = Literal["figure", "diagram", "table", "pullquote"]


class Block(BaseModel):
    """One ordered, typed unit of a chapter in reading order."""
    model_config = ConfigDict(populate_by_name=True)

    id: str
    index: int
    kind: BlockKind
    text: Optional[str] = None
    level: Optional[int] = None          # heading level 1-6
    src: Optional[str] = None            # image/figure asset href
    alt: Optional[str] = None
    caption: Optional[str] = None
    html: Optional[str] = None           # raw html for table/list


class Figure(BaseModel):
    """A visual/special-display element and the paragraph span it belongs to."""
    model_config = ConfigDict(populate_by_name=True)

    figure_id: str = Field(alias="figureId")
    kind: FigureKind
    asset: Optional[str] = None          # None for pullquote
    caption: Optional[str] = None
    label: Optional[str] = None          # e.g. "Figure 3.2"
    start_para: str = Field(alias="startPara")
    end_para: str = Field(alias="endPara")
    start_ms: Optional[int] = Field(default=None, alias="startMs")  # filled in Plan 2
    end_ms: Optional[int] = Field(default=None, alias="endMs")      # filled in Plan 2


class ChapterBundle(BaseModel):
    """The cross-language contract between backend and Flutter client."""
    model_config = ConfigDict(populate_by_name=True)

    chapter_id: str = Field(alias="chapterId")
    title: str
    blocks: list[Block]
    figure_map: list[Figure] = Field(alias="figureMap")
    audio: Optional[str] = None                                     # filled in Plan 2
    para_timings: dict[str, list[int]] = Field(                     # filled in Plan 2
        default_factory=dict, alias="paraTimings"
    )


class BookMeta(BaseModel):
    """Book-level metadata from the EPUB OPF (distinct from chapter titles)."""
    model_config = ConfigDict(populate_by_name=True)

    title: str
    author: str = ""
