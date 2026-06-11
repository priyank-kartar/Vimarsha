import Foundation
@testable import Vimarsha

/// The network seam's test double — one of exactly two sanctioned doubles in the repo
/// (the other is the audio/mic engine). Permanent test-only code, closure-configured.
nonisolated struct FakeBackendClient: BackendClient {
    var onFetchToc: @Sendable (URL) async throws -> TocResponse

    func fetchToc(epubAt url: URL) async throws -> TocResponse {
        try await onFetchToc(url)
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
}
