import Foundation

/// Client-side EPUB cover extraction (V11 SPIKE — ADR-006: the contract has no cover
/// field; the client looks inside the EPUB it already holds).
///
/// Resolution ladder, mirroring how real EPUBs declare covers:
/// 1. **EPUB3:** manifest item whose `properties` include `cover-image`.
/// 2. **EPUB2:** `<meta name="cover" content="…"/>` pointing at an image manifest item.
/// 3. Cover-ish id: an image item literally id'd `cover`/`cover-image`.
/// 4. First image manifest item (document order).
/// Anything missing/broken → `nil` — covers are best-effort; the import never fails over
/// one, and the generated cloth cover (`HardbackCoverView`) stays the UI fallback.
nonisolated enum EpubCover {
    struct ExtractedCover: Equatable {
        let data: Data
        /// Lower-case extension for the cache file (`cover.<ext>`, data-model.md).
        let fileExtension: String
    }

    static func extract(fromEpubAt url: URL) -> ExtractedCover? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return extract(fromEpubData: data)
    }

    static func extract(fromEpubData epubData: Data) -> ExtractedCover? {
        guard
            let zip = try? ZipArchive(data: epubData),
            let containerEntry = zip.entry(named: "META-INF/container.xml"),
            let containerXML = try? zip.contents(of: containerEntry),
            let opfPath = ContainerParser.rootfilePath(in: containerXML),
            let opfEntry = zip.entry(named: opfPath),
            let opfXML = try? zip.contents(of: opfEntry)
        else { return nil }

        let opf = OpfParser.parse(opfXML)
        let opfDirectory = opfPath.contains("/")
            ? opfPath.split(separator: "/").dropLast().joined(separator: "/")
            : ""

        for item in candidates(in: opf) {
            let path = resolve(href: item.href, against: opfDirectory)
            guard let entry = zip.entry(named: path), let data = try? zip.contents(of: entry)
            else { continue }
            return ExtractedCover(data: data, fileExtension: fileExtension(for: item))
        }
        return nil
    }

    // MARK: ladder

    private static func candidates(in opf: OpfParser.Document) -> [OpfParser.Item] {
        let images = opf.items.filter { $0.mediaType.hasPrefix("image/") }
        var ladder: [OpfParser.Item] = []
        if let epub3 = opf.items.first(where: {
            $0.properties.split(separator: " ").contains("cover-image")
        }) { ladder.append(epub3) }
        if let metaId = opf.coverMetaId,
           let epub2 = images.first(where: { $0.id == metaId }) { ladder.append(epub2) }
        if let coverish = images.first(where: { $0.id == "cover" || $0.id == "cover-image" }) {
            ladder.append(coverish)
        }
        ladder.append(contentsOf: images)
        return ladder
    }

    /// Join an OPF-relative href onto the OPF's directory, normalizing `.`/`..` and
    /// percent-encoding (zip entry names are stored decoded).
    private static func resolve(href: String, against directory: String) -> String {
        let decoded = href.removingPercentEncoding ?? href
        var parts = directory.isEmpty ? [] : directory.split(separator: "/").map(String.init)
        for component in decoded.split(separator: "/") {
            switch component {
            case ".": continue
            case "..": if !parts.isEmpty { parts.removeLast() }
            default: parts.append(String(component))
            }
        }
        return parts.joined(separator: "/")
    }

    private static func fileExtension(for item: OpfParser.Item) -> String {
        switch item.mediaType {
        case "image/jpeg": return "jpg"
        case "image/png": return "png"
        case "image/gif": return "gif"
        case "image/svg+xml": return "svg"
        case "image/webp": return "webp"
        default:
            let ext = (item.href as NSString).pathExtension.lowercased()
            return ext.isEmpty ? "img" : ext
        }
    }
}

/// Pulls the first `<rootfile full-path="…">` out of `META-INF/container.xml`.
nonisolated private final class ContainerParser: NSObject, XMLParserDelegate {
    private var path: String?

    static func rootfilePath(in xml: Data) -> String? {
        let delegate = ContainerParser()
        let parser = XMLParser(data: xml)
        parser.delegate = delegate
        parser.parse()
        return delegate.path
    }

    func parser(
        _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
        qualifiedName: String?, attributes: [String: String]
    ) {
        guard path == nil, elementName.isXMLElement("rootfile") else { return }
        path = attributes["full-path"]
    }
}

/// Pulls the manifest items + the EPUB2 `<meta name="cover">` id out of an OPF package.
nonisolated private final class OpfParser: NSObject, XMLParserDelegate {
    struct Item {
        let id: String
        let href: String
        let mediaType: String
        let properties: String
    }

    struct Document {
        var items: [Item] = []
        var coverMetaId: String?
    }

    private var document = Document()

    static func parse(_ xml: Data) -> Document {
        let delegate = OpfParser()
        let parser = XMLParser(data: xml)
        parser.delegate = delegate
        parser.parse()
        return delegate.document
    }

    func parser(
        _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
        qualifiedName: String?, attributes: [String: String]
    ) {
        if elementName.isXMLElement("item"), let id = attributes["id"],
           let href = attributes["href"] {
            document.items.append(Item(
                id: id,
                href: href,
                mediaType: attributes["media-type"] ?? "",
                properties: attributes["properties"] ?? ""
            ))
        } else if elementName.isXMLElement("meta"), attributes["name"] == "cover",
                  let content = attributes["content"] {
            document.coverMetaId = content
        }
    }
}

nonisolated private extension String {
    /// Matches an element regardless of namespace prefix (`item` and `opf:item` both
    /// appear in the wild; XMLParser reports names un-stripped by default).
    func isXMLElement(_ local: String) -> Bool {
        self == local || hasSuffix(":" + local)
    }
}
