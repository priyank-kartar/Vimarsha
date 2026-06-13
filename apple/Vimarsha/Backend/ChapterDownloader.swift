import Foundation

/// Why a cached chapter failed to land — surfaced as the chapter's `errorReason`
/// (honest states, app-architecture.md §Error posture).
nonisolated enum ChapterDownloadError: Error, Equatable {
    /// The backend returned a bundle with no audio name (it normally raises instead —
    /// this is the client-side guard, Flutter `ChapterRepository` parity).
    case noAudio
    /// `GET /audio/{name}` returned zero bytes — never cache an unplayable chapter.
    case emptyAudio
}

/// V14 — lazy chapter download. Re-uploads the book's EPUB with a `chapter_index`
/// (the backend is stateless), then caches the narrated chapter into the container
/// following data-model.md's cache layout:
///
///     Library/Books/<bookId>/chapters/<index>/bundle.json   (source of truth for content)
///     Library/Books/<bookId>/chapters/<index>/chapter.mp3
///     Library/Books/<bookId>/chapters/<index>/images/<name> (best-effort)
///
/// All-or-nothing: any failure removes the partial chapter dir and rethrows (no
/// half-state). Figure images are best-effort — a miss never fails the chapter (the
/// figure card just shows without its image). File/network IO stays off the main actor.
nonisolated struct ChapterDownloader: Sendable {
    let containerRoot: URL
    let backend: any BackendClient

    struct CachedChapter: Equatable, Sendable {
        let bundleRelativePath: String
        let audioRelativePath: String
    }

    func download(
        epubRelativePath: String, bookId: UUID, chapterIndex: Int, engine: String?, voice: String?
    ) async throws -> CachedChapter {
        let chapterRelativePath = "Library/Books/\(bookId.uuidString)/chapters/\(chapterIndex)"
        let chapterDir = containerRoot.appending(path: chapterRelativePath)
        let fm = FileManager.default
        do {
            let bundle = try await backend.importChapter(
                epubAt: containerRoot.appending(path: epubRelativePath),
                chapterIndex: chapterIndex,
                engine: engine,
                voice: voice
            )
            guard let audioName = bundle.audio else { throw ChapterDownloadError.noAudio }
            let audioData = try await backend.downloadAudio(named: audioName)
            guard !audioData.isEmpty else { throw ChapterDownloadError.emptyAudio }

            try fm.createDirectory(at: chapterDir, withIntermediateDirectories: true)
            try JSONEncoder().encode(bundle).write(to: chapterDir.appending(path: "bundle.json"))
            try audioData.write(to: chapterDir.appending(path: "chapter.mp3"))
            await cacheFigureImages(from: bundle, into: chapterDir)

            return CachedChapter(
                bundleRelativePath: "\(chapterRelativePath)/bundle.json",
                audioRelativePath: "\(chapterRelativePath)/chapter.mp3"
            )
        } catch {
            // No half-state (Flutter parity): a failed chapter leaves no files behind.
            try? fm.removeItem(at: chapterDir)
            throw error
        }
    }

    /// Best-effort: a failed/empty image download never fails the chapter.
    private func cacheFigureImages(from bundle: ChapterBundleDTO, into chapterDir: URL) async {
        let names = Set(bundle.figureMap.compactMap(\.image))
        guard !names.isEmpty else { return }
        let imagesDir = chapterDir.appending(path: "images")
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        for name in names {
            // The name comes from the backend — keep it a plain filename, never a path.
            let filename = (name as NSString).lastPathComponent
            guard !filename.isEmpty,
                  let data = try? await backend.downloadImage(named: name),
                  !data.isEmpty
            else { continue }
            try? data.write(to: imagesDir.appending(path: filename))
        }
    }
}
