import Compression
import Foundation
import Testing

/// Class token so tests can locate their own bundle (Swift Testing has no `Bundle.module`
/// outside SPM).
private final class BundleToken {}

/// The repo's real cross-language EPUB fixture (canonical copy in `shared/fixtures/`;
/// bundled here because the sandboxed macOS test host can't read repo paths).
nonisolated func sampleEpubData() throws -> Data {
    let url = try #require(
        Bundle(for: BundleToken.self).url(forResource: "sample", withExtension: "epub")
    )
    return try Data(contentsOf: url)
}

/// Test-side zip *writer* — builds small, spec-valid archives (real CRC-32s, stored +
/// deflated entries) so `ZipArchive`/`EpubCover` tests run against real bytes instead of
/// canned binary fixtures. Test-only by design: the app never writes zips.
nonisolated enum ZipFixture {
    struct Entry {
        let name: String
        let data: Data
        /// Method 8 (deflate) when true, else method 0 (stored) — real EPUBs use both.
        var deflated: Bool = false
    }

    /// Build a zip archive (local headers + central directory + EOCD).
    static func archive(_ entries: [Entry]) -> Data {
        var out = Data()
        var central = Data()
        for entry in entries {
            let payload = entry.deflated ? deflate(entry.data) : entry.data
            let method: UInt16 = entry.deflated ? 8 : 0
            let name = Data(entry.name.utf8)
            let crc = crc32(entry.data)
            let headerOffset = UInt32(out.count)

            out.append(le32(0x04034B50))            // local file header signature
            out.append(le16(20))                    // version needed
            out.append(le16(0))                     // flags
            out.append(le16(method))
            out.append(le16(0)); out.append(le16(0))  // mod time/date
            out.append(le32(crc))
            out.append(le32(UInt32(payload.count))) // compressed size
            out.append(le32(UInt32(entry.data.count))) // uncompressed size
            out.append(le16(UInt16(name.count)))
            out.append(le16(0))                     // extra length
            out.append(name)
            out.append(payload)

            central.append(le32(0x02014B50))        // central directory signature
            central.append(le16(20))                // version made by
            central.append(le16(20))                // version needed
            central.append(le16(0))                 // flags
            central.append(le16(method))
            central.append(le16(0)); central.append(le16(0)) // mod time/date
            central.append(le32(crc))
            central.append(le32(UInt32(payload.count)))
            central.append(le32(UInt32(entry.data.count)))
            central.append(le16(UInt16(name.count)))
            central.append(le16(0))                 // extra length
            central.append(le16(0))                 // comment length
            central.append(le16(0))                 // disk number
            central.append(le16(0))                 // internal attrs
            central.append(le32(0))                 // external attrs
            central.append(le32(headerOffset))
            central.append(name)
        }
        let centralOffset = UInt32(out.count)
        out.append(central)
        out.append(le32(0x06054B50))                // EOCD signature
        out.append(le16(0)); out.append(le16(0))    // disk numbers
        out.append(le16(UInt16(entries.count)))     // entries this disk
        out.append(le16(UInt16(entries.count)))     // entries total
        out.append(le32(UInt32(central.count)))
        out.append(le32(centralOffset))
        out.append(le16(0))                         // comment length
        return out
    }

    /// A minimal EPUB-with-cover archive: mimetype + container.xml + an OPF (caller
    /// supplies the package XML) + extra files (images, xhtml). OPF path is `opfPath`.
    static func epub(
        opfPath: String = "OEBPS/content.opf",
        opf: String,
        files: [Entry] = []
    ) -> Data {
        let container = """
        <?xml version="1.0"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="\(opfPath)" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        return archive(
            [
                Entry(name: "mimetype", data: Data("application/epub+zip".utf8)),
                Entry(name: "META-INF/container.xml", data: Data(container.utf8), deflated: true),
                Entry(name: opfPath, data: Data(opf.utf8), deflated: true),
            ] + files
        )
    }

    // MARK: zip plumbing

    private static func le16(_ v: UInt16) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
    private static func le32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }

    /// Raw DEFLATE (zip method 8) via Compression — `COMPRESSION_ZLIB` is headerless deflate.
    private static func deflate(_ data: Data) -> Data {
        let capacity = data.count + 256
        let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { dst.deallocate() }
        let written = data.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
            compression_encode_buffer(
                dst, capacity,
                src.bindMemory(to: UInt8.self).baseAddress!, data.count,
                nil, COMPRESSION_ZLIB
            )
        }
        precondition(written > 0, "deflate failed in test fixture")
        return Data(bytes: dst, count: written)
    }

    /// Standard CRC-32 (the zip polynomial), table-free bitwise form — fixture-only.
    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
            }
        }
        return ~crc
    }
}
