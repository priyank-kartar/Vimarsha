import Foundation
import Testing
@testable import Vimarsha

/// V12 — title/author straight from the EPUB's OPF metadata (`dc:title`/`dc:creator`),
/// so an imported book has real metadata before any backend call (`/toc` refines the
/// chapter list in V13; the book identity is client-readable today).
struct EpubInfoTests {
    @Test func readsTitleAndAuthorFromTheRealFixture() throws {
        // shared/fixtures/sample.epub: dc:title "Test Book", dc:creator "Ada Lovelace".
        let info = try #require(EpubInfo.extract(fromEpubData: try sampleEpubData()))
        #expect(info.title == "Test Book")
        #expect(info.author == "Ada Lovelace")
    }

    @Test func missingCreatorYieldsEmptyAuthor() throws {
        let epub = ZipFixture.epub(opf: """
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>  Lonely Title  </dc:title>
          </metadata>
          <manifest/>
        </package>
        """)
        let info = try #require(EpubInfo.extract(fromEpubData: epub))
        #expect(info.title == "Lonely Title")
        #expect(info.author == "")
    }

    @Test func garbageReturnsNil() {
        #expect(EpubInfo.extract(fromEpubData: Data("junk".utf8)) == nil)
    }
}
