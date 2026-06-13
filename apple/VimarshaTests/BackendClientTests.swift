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

    // MARK: ChapterBundle contract decode (V14)

    @Test func decodesTheChapterBundleContractShape() throws {
        // Exactly what `POST /import` emits (bundle.schema.json — camelCase, nullable fields).
        let json = Data("""
        {
          "chapterId": "chap-2",
          "title": "The Lens",
          "blocks": [
            {"id": "b0", "index": 0, "kind": "heading", "text": "The Lens", "level": 1},
            {"id": "b1", "index": 1, "kind": "paragraph", "text": "See figure 2.1."},
            {"id": "b2", "index": 2, "kind": "figure", "src": "img/lens.png",
             "alt": "A lens", "caption": "Figure 2.1 — A lens"}
          ],
          "figureMap": [
            {"figureId": "fig-2.1", "kind": "figure", "asset": "img/lens.png",
             "caption": "Figure 2.1 — A lens", "label": "2.1",
             "startPara": "b1", "endPara": "b1", "startMs": 1200, "endMs": 5400,
             "image": "lens-abc123.png"}
          ],
          "audio": "chap-2-deadbeef.mp3",
          "paraTimings": {"b1": [1200, 5400]}
        }
        """.utf8)
        let bundle = try JSONDecoder().decode(ChapterBundleDTO.self, from: json)
        #expect(bundle.chapterId == "chap-2")
        #expect(bundle.blocks.count == 3)
        #expect(bundle.blocks[0].kind == "heading")
        #expect(bundle.blocks[0].level == 1)
        #expect(bundle.blocks[2].src == "img/lens.png")
        let figure = try #require(bundle.figureMap.first)
        #expect(figure.startMs == 1200)
        #expect(figure.endMs == 5400)
        #expect(figure.image == "lens-abc123.png")
        #expect(bundle.audio == "chap-2-deadbeef.mp3")
        #expect(bundle.paraTimings["b1"] == [1200, 5400])
    }

    @Test func bundleSurvivesACacheRoundTrip() throws {
        // The downloader re-encodes the DTO into bundle.json — the round trip must be
        // lossless (the cached JSON is the source of truth for chapter content).
        let original = ChapterBundleDTO.fixture()
        let revived = try JSONDecoder().decode(
            ChapterBundleDTO.self, from: try JSONEncoder().encode(original)
        )
        #expect(revived == original)
    }

    @Test func nullAudioAndMissingTimingsDecode() throws {
        let json = Data(
            #"{"chapterId": "c", "title": "t", "blocks": [], "figureMap": [], "audio": null}"#
            .utf8
        )
        let bundle = try JSONDecoder().decode(ChapterBundleDTO.self, from: json)
        #expect(bundle.audio == nil)
        #expect(bundle.paraTimings.isEmpty)
    }

    @Test func importURLCarriesTheChapterIndexQuery() {
        let url = URLSessionBackendClient.importURL(
            baseURL: URL(string: "http://localhost:8000")!, chapterIndex: 3
        )
        #expect(url.absoluteString == "http://localhost:8000/import?chapter_index=3")
    }

    @Test func importURLCarriesTheEngineWhenSet() {
        let url = URLSessionBackendClient.importURL(
            baseURL: URL(string: "http://localhost:8000")!, chapterIndex: 3, engine: "kokoro"
        )
        #expect(url.absoluteString == "http://localhost:8000/import?chapter_index=3&engine=kokoro")
    }

    @Test func defaultClientNarratesWithKokoro() {
        // The frontend drives the engine; Kokoro is the wired default until a settings UI lands.
        #expect(URLSessionBackendClient().engine == "kokoro")
    }

    @Test func defaultSessionOutlivesRealNarrationTimes() {
        // The V21 live harness caught this: `URLSession.shared`'s 60s request timeout
        // killed every real `/import` (MPS narration is minutes of server silence).
        let client = URLSessionBackendClient()
        #expect(client.session.configuration.timeoutIntervalForRequest >= 600)
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

    // MARK: /transcribe contract decode (V29)

    @Test func decodesTheTranscribeContractShape() throws {
        // Exactly what `POST /transcribe` emits: {"text": "..."}.
        let json = Data(#"{"text": "A thought about the passage."}"#.utf8)
        let response = try JSONDecoder().decode(TranscribeResponse.self, from: json)
        #expect(response.text == "A thought about the passage.")
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
