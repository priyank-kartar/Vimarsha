import Foundation

/// The network seam (V13) — one of exactly two protocols that get test doubles
/// (apple/CLAUDE.md §Tech conventions; the other is the audio/mic engine). Grows one
/// endpoint per V-item; V13 wires `POST /toc`. Mirrors the Flutter `BackendClient` design.
protocol BackendClient: Sendable {
    /// `POST /toc` — multipart EPUB upload → book meta + chapter list (no audio, fast).
    func fetchToc(epubAt url: URL) async throws -> TocResponse
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

// MARK: - Real implementation

nonisolated enum BackendError: Error {
    case badStatus(Int)
}

/// URLSession implementation of the seam. Stateless like the backend itself; the base
/// URL defaults to the local dev server (repoint for LAN/RunPod — a settings surface
/// comes later, mirroring the Flutter `AppSettings`).
nonisolated struct URLSessionBackendClient: BackendClient {
    var baseURL = URL(string: "http://localhost:8000")!
    var session = URLSession.shared

    func fetchToc(epubAt url: URL) async throws -> TocResponse {
        let request = Multipart.request(
            url: baseURL.appending(path: "toc"),
            field: "file",
            filename: "book.epub",
            mimeType: "application/epub+zip",
            fileData: try Data(contentsOf: url)
        )
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw BackendError.badStatus(http.statusCode)
        }
        return try JSONDecoder().decode(TocResponse.self, from: data)
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
