import Foundation

/// The network seam (V13) — one of exactly two protocols that get test doubles
/// (apple/CLAUDE.md §Tech conventions; the other is the audio/mic engine). Grows one
/// endpoint per V-item; V13 wired `POST /toc`, V14 the chapter-download trio. Mirrors the
/// Flutter `BackendClient` design.
protocol BackendClient: Sendable {
    /// `POST /toc` — multipart EPUB upload → book meta + chapter list (no audio, fast).
    func fetchToc(epubAt url: URL) async throws -> TocResponse
    /// `POST /import?chapter_index=N` — narrate ONE chapter → the full `ChapterBundle`
    /// (blocks, figureMap with ms spans, audio name, paraTimings). Minutes-long on a dev
    /// backend (MPS ~7–8× slower than realtime) — callers surface `pending`, never a
    /// bare spinner (narration-pipeline.md).
    func importChapter(epubAt url: URL, chapterIndex: Int) async throws -> ChapterBundleDTO
    /// `GET /audio/{name}` — the stitched chapter MP3 bytes.
    func downloadAudio(named name: String) async throws -> Data
    /// `GET /image/{name}` — figure image bytes.
    func downloadImage(named name: String) async throws -> Data
    /// `POST /transcribe` — multipart audio upload → Whisper transcript (V29). The
    /// backend decodes any ffmpeg-readable container (our memos are AAC m4a).
    func transcribe(audioAt url: URL) async throws -> String
}

// MARK: - /toc contract (mirrors backend/src/vimarsha/models.py; camelCase, no remapping)

nonisolated struct TocResponse: Codable, Equatable, Sendable {
    let book: BookMetaDTO
    let chapters: [ChapterSummaryDTO]
}

nonisolated struct BookMetaDTO: Codable, Equatable, Sendable {
    let title: String
    var author: String = ""

    init(title: String, author: String = "") {
        self.title = title
        self.author = author
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
    }
}

nonisolated struct ChapterSummaryDTO: Codable, Equatable, Sendable {
    let index: Int
    let chapterId: String
    let title: String
}

// MARK: - /transcribe contract (V29)

nonisolated struct TranscribeResponse: Codable, Equatable, Sendable {
    let text: String
}

// MARK: - Real implementation

nonisolated enum BackendError: Error {
    case badStatus(Int)
}

/// URLSession implementation of the seam. Stateless like the backend itself; the base
/// URL defaults to the local dev server (repoint for LAN/RunPod — a settings surface
/// comes later, mirroring the Flutter `AppSettings`).
nonisolated struct URLSessionBackendClient: BackendClient {
    var baseURL = URL(string: "http://localhost:8000")!
    var session = URLSessionBackendClient.narrationSession

    /// `URLSession.shared`'s 60s idle timeout kills any real `/import` — Chatterbox
    /// narration is MINUTES of server silence before the bundle arrives (MPS is ~7–8×
    /// slower than realtime; the V21 live harness caught the timeout). Allow a long
    /// quiet wait; the 7-day resource ceiling stays at its default.
    static let narrationSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30 * 60
        return URLSession(configuration: config)
    }()

    func fetchToc(epubAt url: URL) async throws -> TocResponse {
        try JSONDecoder().decode(
            TocResponse.self, from: try await uploadEpub(at: url, to: baseURL.appending(path: "toc"))
        )
    }

    func importChapter(epubAt url: URL, chapterIndex: Int) async throws -> ChapterBundleDTO {
        try JSONDecoder().decode(
            ChapterBundleDTO.self,
            from: try await uploadEpub(
                at: url, to: Self.importURL(baseURL: baseURL, chapterIndex: chapterIndex)
            )
        )
    }

    func downloadAudio(named name: String) async throws -> Data {
        try await get(baseURL.appending(path: "audio").appending(path: name))
    }

    func downloadImage(named name: String) async throws -> Data {
        try await get(baseURL.appending(path: "image").appending(path: name))
    }

    func transcribe(audioAt url: URL) async throws -> String {
        let request = Multipart.request(
            url: baseURL.appending(path: "transcribe"),
            field: "file",
            filename: url.lastPathComponent,
            mimeType: "audio/mp4",
            fileData: try Data(contentsOf: url)
        )
        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        return try JSONDecoder().decode(TranscribeResponse.self, from: data).text
    }

    /// `chapter_index` rides as a query parameter (the FastAPI signature), not form data.
    static func importURL(baseURL: URL, chapterIndex: Int) -> URL {
        baseURL.appending(path: "import")
            .appending(queryItems: [URLQueryItem(name: "chapter_index", value: "\(chapterIndex)")])
    }

    private func uploadEpub(at url: URL, to endpoint: URL) async throws -> Data {
        let request = Multipart.request(
            url: endpoint,
            field: "file",
            filename: "book.epub",
            mimeType: "application/epub+zip",
            fileData: try Data(contentsOf: url)
        )
        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        return data
    }

    private func get(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        try Self.validate(response)
        return data
    }

    private static func validate(_ response: URLResponse) throws {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw BackendError.badStatus(http.statusCode)
        }
    }
}

/// Single-file multipart/form-data encoding (what every upload endpoint needs:
/// `/toc`, `/import`, `/transcribe`).
nonisolated enum Multipart {
    static func request(
        url: URL,
        field: String,
        filename: String,
        mimeType: String,
        fileData: Data,
        boundary: String = "vimarsha-\(UUID().uuidString)"
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type"
        )
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data(
            "Content-Disposition: form-data; name=\"\(field)\"; filename=\"\(filename)\"\r\n".utf8
        ))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(fileData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body
        return request
    }
}
