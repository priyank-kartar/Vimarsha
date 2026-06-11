import Foundation
import Testing
@testable import Vimarsha

/// V11 [SPIKE] — client-side cover extraction (ADR-006): container.xml → OPF → cover
/// manifest item, with the fall-back ladder (EPUB3 properties → EPUB2 meta → cover-ish
/// id → first image). EPUBs are built in-test by `ZipFixture` (real zip bytes).
struct EpubCoverTests {
    private let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3])
    private let jpg = Data([0xFF, 0xD8, 0xFF, 0xE0, 9, 9, 9])

    private func opf(manifest: String, metadataExtra: String = "") -> String {
        """
        <?xml version="1.0" encoding="utf-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>Test Book</dc:title>
            \(metadataExtra)
          </metadata>
          <manifest>
            \(manifest)
          </manifest>
          <spine/>
        </package>
        """
    }

    @Test func epub3CoverImageProperty() throws {
        let epub = ZipFixture.epub(
            opf: opf(manifest: """
            <item id="chap1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
            <item id="art" href="images/front.png" media-type="image/png" properties="cover-image"/>
            """),
            files: [
                .init(name: "OEBPS/chap1.xhtml", data: Data("<html/>".utf8), deflated: true),
                .init(name: "OEBPS/images/front.png", data: png, deflated: true),
            ]
        )
        let cover = try #require(EpubCover.extract(fromEpubData: epub))
        #expect(cover.data == png)
        #expect(cover.fileExtension == "png")
    }

    @Test func epub2MetaCoverReference() throws {
        let epub = ZipFixture.epub(
            opf: opf(
                manifest: """
                <item id="chap1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
                <item id="coverimg" href="front.jpg" media-type="image/jpeg"/>
                """,
                metadataExtra: #"<meta name="cover" content="coverimg"/>"#
            ),
            files: [.init(name: "OEBPS/front.jpg", data: jpg)]
        )
        let cover = try #require(EpubCover.extract(fromEpubData: epub))
        #expect(cover.data == jpg)
        #expect(cover.fileExtension == "jpg")
    }

    @Test func coverishManifestIdFallback() throws {
        // No properties, no meta — but the manifest has an image item literally id'd
        // "cover" (a common real-world EPUB2 shape).
        let epub = ZipFixture.epub(
            opf: opf(manifest: """
            <item id="chap1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
            <item id="cover" href="cover.png" media-type="image/png"/>
            """),
            files: [.init(name: "OEBPS/cover.png", data: png)]
        )
        let cover = try #require(EpubCover.extract(fromEpubData: epub))
        #expect(cover.data == png)
    }

    @Test func firstImageFallback() throws {
        // Nothing cover-flavored at all → the first image manifest item wins.
        let epub = ZipFixture.epub(
            opf: opf(manifest: """
            <item id="chap1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
            <item id="fig2" href="fig2.jpg" media-type="image/jpeg"/>
            <item id="fig9" href="fig9.png" media-type="image/png"/>
            """),
            files: [
                .init(name: "OEBPS/fig2.jpg", data: jpg),
                .init(name: "OEBPS/fig9.png", data: png),
            ]
        )
        let cover = try #require(EpubCover.extract(fromEpubData: epub))
        #expect(cover.data == jpg)
        #expect(cover.fileExtension == "jpg")
    }

    @Test func hrefResolvesAgainstOpfDirectoryWithDotDot() throws {
        // OPF nested a level deeper, href climbing out — path normalization must hold.
        let epub = ZipFixture.epub(
            opfPath: "OEBPS/package/content.opf",
            opf: opf(manifest: """
            <item id="art" href="../images/front.png" media-type="image/png" properties="cover-image"/>
            """),
            files: [.init(name: "OEBPS/images/front.png", data: png)]
        )
        let cover = try #require(EpubCover.extract(fromEpubData: epub))
        #expect(cover.data == png)
    }

    @Test func noImagesReturnsNil() throws {
        // The repo's real fixture EPUB has chapters but no images — the generated cloth
        // cover (HardbackCoverView) stays the UI fallback, so extraction reports nil.
        #expect(EpubCover.extract(fromEpubData: try sampleEpubData()) == nil)
    }

    @Test func garbageDataReturnsNil() {
        // Covers are best-effort: a broken EPUB must not fail the import.
        #expect(EpubCover.extract(fromEpubData: Data("junk".utf8)) == nil)
    }
}
