import Foundation
import Testing
@testable import Vimarsha

/// V14 — lazy chapter download: `/import` → bundle.json + chapter.mp3 (+ best-effort
/// figure images) cached in the container, all-or-nothing. Real temp-dir file IO; only
/// the network is doubled (house rule).
struct ChapterDownloaderTests {
    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "ChapterDownloaderTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private let bookId = UUID()

    private func chapterDir(_ root: URL, index: Int = 0) -> URL {
        root.appending(path: "Library/Books/\(bookId.uuidString)/chapters/\(index)")
    }

    @Test func cachesBundleAndAudioAndReturnsRelativePaths() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let downloader = ChapterDownloader(
            containerRoot: root, backend: FakeBackendClient.narrating()
        )

        let cached = try await downloader.download(
            epubRelativePath: "Library/Books/\(bookId.uuidString)/book.epub",
            bookId: bookId, chapterIndex: 0
        )

        let prefix = "Library/Books/\(bookId.uuidString)/chapters/0"
        #expect(cached.bundleRelativePath == "\(prefix)/bundle.json")
        #expect(cached.audioRelativePath == "\(prefix)/chapter.mp3")
        // The cached bundle round-trips to the DTO the backend sent (source of truth).
        let revived = try JSONDecoder().decode(
            ChapterBundleDTO.self,
            from: try Data(contentsOf: root.appending(path: cached.bundleRelativePath))
        )
        #expect(revived == ChapterBundleDTO.fixture())
        #expect(
            try Data(contentsOf: root.appending(path: cached.audioRelativePath))
                == Data("mp3-bytes".utf8)
        )
    }

    @Test func cachesFigureImagesWhenTheBackendServesThem() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let downloader = ChapterDownloader(
            containerRoot: root,
            backend: FakeBackendClient.narrating(imageData: Data("png-bytes".utf8))
        )

        _ = try await downloader.download(
            epubRelativePath: "x.epub", bookId: bookId, chapterIndex: 0
        )

        let image = chapterDir(root).appending(path: "images/fig1.png")
        #expect(try Data(contentsOf: image) == Data("png-bytes".utf8))
    }

    @Test func figureImageFailureDoesNotFailTheChapter() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        // .narrating() leaves /image unconfigured → it throws; the chapter must still land.
        let downloader = ChapterDownloader(
            containerRoot: root, backend: FakeBackendClient.narrating()
        )

        let cached = try await downloader.download(
            epubRelativePath: "x.epub", bookId: bookId, chapterIndex: 0
        )

        #expect(FileManager.default.fileExists(
            atPath: root.appending(path: cached.audioRelativePath).path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: chapterDir(root).appending(path: "images/fig1.png").path
        ))
    }

    @Test func bundleWithoutAudioThrowsAndLeavesNothing() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        // The backend raises for un-narratable chapters, but a nil-audio bundle is still
        // rejected client-side (Flutter parity) — never cache an unplayable chapter.
        let downloader = ChapterDownloader(
            containerRoot: root,
            backend: FakeBackendClient.narrating(bundle: .fixture(audio: nil))
        )

        await #expect(throws: ChapterDownloadError.noAudio) {
            _ = try await downloader.download(
                epubRelativePath: "x.epub", bookId: bookId, chapterIndex: 0
            )
        }
        #expect(!FileManager.default.fileExists(atPath: chapterDir(root).path))
    }

    @Test func emptyAudioBytesThrowAndLeaveNothing() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let downloader = ChapterDownloader(
            containerRoot: root, backend: FakeBackendClient.narrating(audioData: Data())
        )

        await #expect(throws: ChapterDownloadError.emptyAudio) {
            _ = try await downloader.download(
                epubRelativePath: "x.epub", bookId: bookId, chapterIndex: 0
            )
        }
        #expect(!FileManager.default.fileExists(atPath: chapterDir(root).path))
    }

    @Test func audioDownloadFailureRollsBackPartialFiles() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        var backend = FakeBackendClient.narrating()
        backend.onDownloadAudio = { _ in throw URLError(.networkConnectionLost) }
        let downloader = ChapterDownloader(containerRoot: root, backend: backend)

        await #expect(throws: (any Error).self) {
            _ = try await downloader.download(
                epubRelativePath: "x.epub", bookId: bookId, chapterIndex: 0
            )
        }
        // No half-state: no chapter dir, no stray bundle.json.
        #expect(!FileManager.default.fileExists(atPath: chapterDir(root).path))
    }
}
