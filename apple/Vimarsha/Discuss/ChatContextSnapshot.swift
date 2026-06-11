import Foundation

/// Builds the grounding snapshot for one `/chat` send (V32; spec §3 — "the live
/// paragraph + a window + any active figure"): the narrated paragraph with one
/// text-bearing neighbor each side, plus the caption of a figure on screen. Pure value
/// math over the decoded bundle — no clocks, no player reference; the caller supplies
/// the playhead.
nonisolated enum ChatContextSnapshot {
    /// Text-bearing neighbors included each side of the live paragraph.
    static let windowRadius = 1

    static func make(
        bundle: ChapterBundleDTO?,
        timing: TimingIndex?,
        positionMs: Int,
        bookTitle: String,
        chapterTitle: String
    ) -> ChatContextDTO {
        guard let bundle else {
            return ChatContextDTO(passage: "", bookTitle: bookTitle, chapterTitle: chapterTitle)
        }
        // The passage rides reading order over text-bearing blocks only (figures and
        // images contribute their caption separately, not passage lines).
        let textBlocks = bundle.blocks.filter { !($0.text ?? "").isEmpty }
        let currentId = timing?.currentBlockId(atMs: positionMs)
        // Before the first timed block (or with nothing timed) the reader is at the
        // chapter top — ground on its opening lines.
        let center = textBlocks.firstIndex { $0.id == currentId } ?? 0
        let window = max(0, center - windowRadius)...min(textBlocks.count - 1, center + windowRadius)
        let passage = textBlocks.isEmpty
            ? ""
            : textBlocks[window].compactMap(\.text).joined(separator: "\n\n")
        let activeFigure = timing?.activeFigures(atMs: positionMs).first
        return ChatContextDTO(
            passage: passage,
            figureCaption: activeFigure.flatMap { $0.caption ?? $0.label },
            bookTitle: bookTitle,
            chapterTitle: chapterTitle
        )
    }
}
