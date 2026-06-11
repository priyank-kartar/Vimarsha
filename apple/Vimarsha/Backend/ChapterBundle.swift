import Foundation

// The `ChapterBundle` contract (shared/bundle.schema.json) — what `POST /import` returns.
// Codable mirrors the schema exactly: camelCase keys, no remapping (apple/CLAUDE.md §Tech
// conventions). The cached bundle.json on disk is the source of truth for chapter content
// (data-model.md §Rules); SwiftData rows only hold *state about* chapters.

nonisolated struct ChapterBundleDTO: Codable, Equatable, Sendable {
    let chapterId: String
    let title: String
    let blocks: [BlockDTO]
    let figureMap: [FigureDTO]
    /// The stitched chapter MP3's name for `GET /audio/{name}` — nil when the backend
    /// produced no narration (it raises instead of caching junk, so this is defensive).
    var audio: String?
    /// Paragraph block id → `[startMs, endMs]` recorded during stitch (exact by construction).
    var paraTimings: [String: [Int]] = [:]

    init(
        chapterId: String, title: String, blocks: [BlockDTO], figureMap: [FigureDTO],
        audio: String? = nil, paraTimings: [String: [Int]] = [:]
    ) {
        self.chapterId = chapterId
        self.title = title
        self.blocks = blocks
        self.figureMap = figureMap
        self.audio = audio
        self.paraTimings = paraTimings
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        chapterId = try c.decode(String.self, forKey: .chapterId)
        title = try c.decode(String.self, forKey: .title)
        blocks = try c.decode([BlockDTO].self, forKey: .blocks)
        figureMap = try c.decode([FigureDTO].self, forKey: .figureMap)
        audio = try c.decodeIfPresent(String.self, forKey: .audio)
        paraTimings = try c.decodeIfPresent([String: [Int]].self, forKey: .paraTimings) ?? [:]
    }
}

/// One ordered, typed unit of a chapter in reading order. `kind` stays a raw string
/// (heading/paragraph/image/figure/blockquote/pullquote/table/list) so a future backend
/// kind degrades gracefully instead of failing the whole bundle decode.
nonisolated struct BlockDTO: Codable, Equatable, Sendable {
    let id: String
    let index: Int
    let kind: String
    var text: String?
    var level: Int?
    var src: String?
    var alt: String?
    var caption: String?
    var html: String?
}

/// A visual/special-display element and the narration window it belongs to.
nonisolated struct FigureDTO: Codable, Equatable, Sendable {
    let figureId: String
    let kind: String
    var asset: String?
    var caption: String?
    var label: String?
    let startPara: String
    let endPara: String
    var startMs: Int?
    var endMs: Int?
    /// Image name for `GET /image/{name}` — cached best-effort at download.
    var image: String?
}
