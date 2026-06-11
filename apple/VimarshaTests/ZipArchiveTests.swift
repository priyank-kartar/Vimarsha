import Foundation
import Testing
@testable import Vimarsha

/// V11 — the minimal zip reader under the EPUB cover extractor. Fixtures are spec-valid
/// archives built by `ZipFixture` plus the repo's real `shared/fixtures/sample.epub`.
struct ZipArchiveTests {
    @Test func listsEntriesAndReadsStoredData() throws {
        let bytes = ZipFixture.archive([
            .init(name: "mimetype", data: Data("application/epub+zip".utf8)),
            .init(name: "OEBPS/cover.png", data: Data([0x89, 0x50, 0x4E, 0x47])),
        ])
        let zip = try ZipArchive(data: bytes)

        #expect(zip.entries.map(\.name) == ["mimetype", "OEBPS/cover.png"])
        let entry = try #require(zip.entry(named: "mimetype"))
        #expect(try zip.contents(of: entry) == Data("application/epub+zip".utf8))
    }

    @Test func inflatesDeflatedEntries() throws {
        // Compressible payload so deflate genuinely shrinks it (proves real inflation).
        let payload = Data(String(repeating: "vimarsha ", count: 200).utf8)
        let bytes = ZipFixture.archive([.init(name: "big.txt", data: payload, deflated: true)])
        let zip = try ZipArchive(data: bytes)

        let entry = try #require(zip.entry(named: "big.txt"))
        #expect(entry.compressedSize < payload.count)
        #expect(try zip.contents(of: entry) == payload)
    }

    @Test func readsTheRealSampleEpubFixture() throws {
        // The repo's cross-language fixture (canonical copy: shared/fixtures/sample.epub;
        // bundled in VimarshaTests/Fixtures because the sandboxed macOS test host can't
        // read repo paths) — a real zip from a real zip writer, not our own bytes
        // round-tripping.
        let zip = try ZipArchive(data: try sampleEpubData())

        let container = try #require(zip.entry(named: "META-INF/container.xml"))
        let xml = String(decoding: try zip.contents(of: container), as: UTF8.self)
        #expect(xml.contains("OEBPS/content.opf"))
    }

    @Test func rejectsNonZipData() {
        #expect(throws: (any Error).self) {
            _ = try ZipArchive(data: Data("not a zip at all".utf8))
        }
    }

    @Test func rejectsTruncatedArchive() throws {
        let bytes = ZipFixture.archive([.init(name: "a.txt", data: Data("hello".utf8))])
        #expect(throws: (any Error).self) {
            _ = try ZipArchive(data: bytes.prefix(bytes.count - 10))
        }
    }
}
