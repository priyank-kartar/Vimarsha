import Foundation
@testable import Vimarsha

/// The network seam's test double — one of exactly two sanctioned doubles in the repo
/// (the other is the audio/mic engine). Permanent test-only code, closure-configured.
nonisolated struct FakeBackendClient: BackendClient {
    var onFetchToc: @Sendable (URL) async throws -> TocResponse
    // Endpoints a test didn't configure fail loudly (default-value closures would be
    // MainActor-inferred under the project's default isolation, so these are static funcs).
    var onImportChapter: @Sendable (URL, Int) async throws -> ChapterBundleDTO
        = Self.unconfiguredImport
    var onDownloadAudio: @Sendable (String) async throws -> Data = Self.unconfiguredDownload
    var onDownloadImage: @Sendable (String) async throws -> Data = Self.unconfiguredDownload
    var onTranscribe: @Sendable (URL) async throws -> String = Self.unconfiguredTranscribe
    var onChat: @Sendable ([ChatMessageDTO], ChatContextDTO) async throws -> String
        = Self.unconfiguredChat
    var onSpeak: @Sendable (String) async throws -> Data = Self.unconfiguredSpeak

    private static func unconfiguredImport(_: URL, _: Int) async throws -> ChapterBundleDTO {
        throw URLError(.unsupportedURL)
    }

    private static func unconfiguredChat(
        _: [ChatMessageDTO], _: ChatContextDTO
    ) async throws -> String {
        throw URLError(.unsupportedURL)
    }

    private static func unconfiguredSpeak(_: String) async throws -> Data {
        throw URLError(.unsupportedURL)
    }

    private static func unconfiguredDownload(_: String) async throws -> Data {
        throw URLError(.unsupportedURL)
    }

    private static func unconfiguredTranscribe(_: URL) async throws -> String {
        throw URLError(.unsupportedURL)
    }

    func fetchToc(epubAt url: URL) async throws -> TocResponse {
        try await onFetchToc(url)
    }

    func importChapter(epubAt url: URL, chapterIndex: Int) async throws -> ChapterBundleDTO {
        try await onImportChapter(url, chapterIndex)
    }

    func downloadAudio(named name: String) async throws -> Data {
        try await onDownloadAudio(name)
    }

    func downloadImage(named name: String) async throws -> Data {
        try await onDownloadImage(name)
    }

    func transcribe(audioAt url: URL) async throws -> String {
        try await onTranscribe(url)
    }

    func chat(messages: [ChatMessageDTO], context: ChatContextDTO) async throws -> String {
        try await onChat(messages, context)
    }

    func speak(text: String) async throws -> Data {
        try await onSpeak(text)
    }
}

extension FakeBackendClient {
    /// A canned, well-formed two-chapter TOC.
    static func returning(
        title: String = "Backend Title", author: String = "Backend Author"
    ) -> FakeBackendClient {
        FakeBackendClient { _ in
            TocResponse(
                book: BookMetaDTO(title: title, author: author),
                chapters: [
                    ChapterSummaryDTO(index: 0, chapterId: "chap1", title: "Chapter One"),
                    ChapterSummaryDTO(index: 1, chapterId: "chap2", title: "Chapter Two"),
                ]
            )
        }
    }

    static func failing() -> FakeBackendClient {
        FakeBackendClient { _ in throw URLError(.cannotConnectToHost) }
    }

    /// A canned, well-formed narrated chapter: `/import` returns `bundle`, `/audio` returns
    /// `audioData`, `/image` returns `imageData` (default: fails, which download treats as
    /// best-effort).
    static func narrating(
        bundle: ChapterBundleDTO = .fixture(),
        audioData: Data = Data("mp3-bytes".utf8),
        imageData: Data? = nil
    ) -> FakeBackendClient {
        var fake = FakeBackendClient.returning()
        fake.onImportChapter = { _, _ in bundle }
        fake.onDownloadAudio = { _ in audioData }
        if let imageData {
            fake.onDownloadImage = { _ in imageData }
        }
        return fake
    }
}

nonisolated extension ChapterBundleDTO {
    /// A minimal well-formed narrated bundle (one paragraph, one figure with an image).
    static func fixture(
        audio: String? = "chap1.mp3", image: String? = "fig1.png"
    ) -> ChapterBundleDTO {
        ChapterBundleDTO(
            chapterId: "chap1",
            title: "Chapter One",
            blocks: [BlockDTO(id: "b1", index: 0, kind: "paragraph", text: "Hello.")],
            figureMap: [
                FigureDTO(
                    figureId: "fig1", kind: "figure", startPara: "b1", endPara: "b1",
                    startMs: 0, endMs: 900, image: image
                )
            ],
            audio: audio,
            paraTimings: ["b1": [0, 900]]
        )
    }
}
