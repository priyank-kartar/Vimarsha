import Compression
import Foundation

/// A minimal read-only zip reader — just enough to open an EPUB (V11 SPIKE, ADR-006:
/// covers are client-side, so the client must look *inside* the EPUB it already holds).
///
/// Reads the central directory (the authoritative entry list — entries with streaming
/// data-descriptors still carry real sizes there) and inflates method-8 entries via
/// Compression (`COMPRESSION_ZLIB` == headerless DEFLATE, zip's wire format). Supports
/// what EPUBs actually use: methods 0 (stored) and 8 (deflate). No zip64 (EPUB covers
/// are far below 4 GB), no encryption, no multi-disk.
nonisolated struct ZipArchive {
    struct Entry {
        let name: String
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        /// Offset of the entry's local file header in the archive.
        let localHeaderOffset: Int
    }

    enum ZipError: Error {
        case notAZip
        case truncated
        case unsupportedCompression(UInt16)
        case corruptEntry(String)
    }

    let entries: [Entry]
    private let data: Data

    init(data: Data) throws {
        // Re-base so absolute offsets read from the file are valid Data indices even if
        // the caller handed us a slice.
        self.data = Data(data)
        self.entries = try Self.parseCentralDirectory(self.data)
    }

    init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }

    /// Exact-name lookup (zip names are case-sensitive by spec; EPUB hrefs match exactly).
    func entry(named name: String) -> Entry? {
        entries.first { $0.name == name }
    }

    /// Decompressed contents of an entry.
    func contents(of entry: Entry) throws -> Data {
        // The central directory's offset points at the local header; its name/extra
        // lengths can differ from the central record's, so re-read them here.
        let lho = entry.localHeaderOffset
        guard lho + 30 <= data.count, read32(at: lho) == 0x0403_4B50 else {
            throw ZipError.corruptEntry(entry.name)
        }
        let nameLength = Int(read16(at: lho + 26))
        let extraLength = Int(read16(at: lho + 28))
        let start = lho + 30 + nameLength + extraLength
        guard start + entry.compressedSize <= data.count else { throw ZipError.truncated }
        let payload = data.subdata(in: start..<(start + entry.compressedSize))

        switch entry.method {
        case 0:
            return payload
        case 8:
            return try inflate(payload, uncompressedSize: entry.uncompressedSize, name: entry.name)
        default:
            throw ZipError.unsupportedCompression(entry.method)
        }
    }

    // MARK: parsing

    private static func parseCentralDirectory(_ data: Data) throws -> [Entry] {
        // End-of-central-directory record: scan back over the (possibly commented) tail.
        let eocdSignature: UInt32 = 0x0605_4B50
        guard data.count >= 22 else { throw ZipError.notAZip }
        var eocd = -1
        let lowest = max(0, data.count - 22 - 65535)
        var i = data.count - 22
        while i >= lowest {
            if data.readLE32(at: i) == eocdSignature { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw ZipError.notAZip }

        let entryCount = Int(data.readLE16(at: eocd + 10))
        let directoryOffset = Int(data.readLE32(at: eocd + 16))

        var entries: [Entry] = []
        entries.reserveCapacity(entryCount)
        var cursor = directoryOffset
        for _ in 0..<entryCount {
            guard cursor + 46 <= data.count, data.readLE32(at: cursor) == 0x0201_4B50 else {
                throw ZipError.truncated
            }
            let nameLength = Int(data.readLE16(at: cursor + 28))
            let extraLength = Int(data.readLE16(at: cursor + 30))
            let commentLength = Int(data.readLE16(at: cursor + 32))
            guard cursor + 46 + nameLength <= data.count else { throw ZipError.truncated }
            let name = String(
                decoding: data.subdata(in: (cursor + 46)..<(cursor + 46 + nameLength)),
                as: UTF8.self
            )
            entries.append(Entry(
                name: name,
                method: data.readLE16(at: cursor + 10),
                compressedSize: Int(data.readLE32(at: cursor + 20)),
                uncompressedSize: Int(data.readLE32(at: cursor + 24)),
                localHeaderOffset: Int(data.readLE32(at: cursor + 42))
            ))
            cursor += 46 + nameLength + extraLength + commentLength
        }
        return entries
    }

    private func read16(at offset: Int) -> UInt16 { data.readLE16(at: offset) }
    private func read32(at offset: Int) -> UInt32 { data.readLE32(at: offset) }

    private func inflate(_ payload: Data, uncompressedSize: Int, name: String) throws -> Data {
        guard uncompressedSize > 0 else { return Data() }
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: uncompressedSize)
        defer { destination.deallocate() }
        let written = payload.withUnsafeBytes { (source: UnsafeRawBufferPointer) -> Int in
            guard let base = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_decode_buffer(
                destination, uncompressedSize, base, payload.count, nil, COMPRESSION_ZLIB
            )
        }
        guard written == uncompressedSize else { throw ZipError.corruptEntry(name) }
        return Data(bytes: destination, count: written)
    }
}

nonisolated private extension Data {
    func readLE16(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func readLE32(at offset: Int) -> UInt32 {
        UInt32(self[offset]) | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16) | (UInt32(self[offset + 3]) << 24)
    }
}
