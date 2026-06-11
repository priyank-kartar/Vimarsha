import Foundation
import Testing
@testable import Vimarsha

/// V13 — the `BackendClient` seam: the `/toc` contract decode and the multipart upload
/// encoding (the two halves of `URLSessionBackendClient.fetchToc` that don't need a live
/// server; the live round-trip is the V15 verify / opt-in integration run).
struct BackendClientTests {
    // MARK: contract decode

    @Test func decodesTheTocContractShape() throws {
        // Exactly what the backend emits (camelCase chapterId — bundle.schema.json style).
        let json = Data("""
        {
          "book": {"title": "Test Book", "author": "Ada Lovelace"},
          "chapters": [
            {"index": 0, "chapterId": "chap1", "title": "Chapter One"},
            {"index": 1, "chapterId": "chap2", "title": "Chapter Two"}
          ]
        }
        """.utf8)
        let toc = try JSONDecoder().decode(TocResponse.self, from: json)
        #expect(toc.book.title == "Test Book")
        #expect(toc.book.author == "Ada Lovelace")
        #expect(toc.chapters.count == 2)
        #expect(toc.chapters[1].index == 1)
        #expect(toc.chapters[1].chapterId == "chap2")
        #expect(toc.chapters[1].title == "Chapter Two")
    }

    @Test func missingAuthorDecodesAsEmpty() throws {
        let json = Data(#"{"book": {"title": "T"}, "chapters": []}"#.utf8)
        let toc = try JSONDecoder().decode(TocResponse.self, from: json)
        #expect(toc.book.author == "")
    }

    // MARK: multipart encoding

    @Test func buildsAWellFormedMultipartUpload() throws {
        let fileBytes = Data([0x50, 0x4B, 0x03, 0x04, 9, 9])
        let request = Multipart.request(
            url: URL(string: "http://localhost:8000/toc")!,
            field: "file",
            filename: "book.epub",
            mimeType: "application/epub+zip",
            fileData: fileBytes,
            boundary: "test-boundary"
        )

        #expect(request.httpMethod == "POST")
        #expect(
            request.value(forHTTPHeaderField: "Content-Type")
                == "multipart/form-data; boundary=test-boundary"
        )
        let body = try #require(request.httpBody)
        let head = Data("""
        --test-boundary\r
        Content-Disposition: form-data; name="file"; filename="book.epub"\r
        Content-Type: application/epub+zip\r
        \r

        """.utf8)
        let tail = Data("\r\n--test-boundary--\r\n".utf8)
        #expect(body == head + fileBytes + tail)
    }

    @Test func defaultBoundaryIsUniquePerRequest() {
        let url = URL(string: "http://localhost:8000/toc")!
        let a = Multipart.request(
            url: url, field: "file", filename: "f", mimeType: "m", fileData: Data()
        )
        let b = Multipart.request(
            url: url, field: "file", filename: "f", mimeType: "m", fileData: Data()
        )
        #expect(a.value(forHTTPHeaderField: "Content-Type")
            != b.value(forHTTPHeaderField: "Content-Type"))
    }
}
