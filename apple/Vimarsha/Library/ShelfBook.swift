import SwiftUI

/// What the shelf renders — one display value per card, whether the book is a persisted
/// import (V12) or a static seed. Real cover art (V11 extraction, pre-downsampled by the
/// store — never decoded during scroll) rides in `cover`; `nil` falls back to the
/// generated cloth-bound cover. Cloth/ink colors are book *assets* (like real cover
/// art), not UI palette tokens.
struct ShelfBook: Identifiable {
    let id: String
    let title: String
    let author: String
    /// Hardback cloth color (the generated-cover fallback face).
    let cloth: Color
    /// Tone-on-tone title ink, picked per book like a printed cover.
    let ink: Color
    /// Cover height relative to its width — retained for future cover-art fitting
    /// (ADR-011: card geometry is uniform; this no longer drives layout).
    let aspect: CGFloat
    /// Gilt fore-edge stripe (the reference's blue book flourish).
    let gilt: Bool
    /// Pre-rendered real cover art; `nil` = generated cloth cover.
    var cover: Image?

    /// A persisted book on the shelf. Coverless books get a deterministic cloth derived
    /// from the slate/sky tokens (apple/CLAUDE.md §Physical book rendering: the
    /// missing-art fallback is a slate/sky-derived cloth), varied per book so a freshly
    /// imported library doesn't read as one flat color.
    init(book: Book, cover: Image?) {
        self.id = book.id.uuidString
        self.title = book.title
        self.author = book.author
        // Stable across launches (Hashable.hashValue is per-process seeded — it would
        // reshuffle cloth colors on every run).
        let variant = book.id.uuidString.unicodeScalars
            .reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF } % Self.fallbackCloths.count
        (self.cloth, self.ink) = Self.fallbackCloths[variant]
        self.aspect = CardGeometry.aspect
        self.gilt = false
        self.cover = cover
    }

    private init(
        id: String, title: String, author: String,
        cloth: Color, ink: Color, aspect: CGFloat, gilt: Bool
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.cloth = cloth
        self.ink = ink
        self.aspect = aspect
        self.gilt = gilt
        self.cover = nil
    }

    /// Slate/sky-derived cloth+ink pairs for coverless imports (tone-on-tone, dark-first).
    private static let fallbackCloths: [(cloth: Color, ink: Color)] = [
        (Color(hex: 0x46707E), Color(hex: 0x2E4D58)),  // slate
        (Color(hex: 0x577E96), Color(hex: 0x3A586C)),  // sky-leaning slate
        (Color(hex: 0x3D5E6B), Color(hex: 0x5E8696)),  // deep slate, lighter ink
        (Color(hex: 0x4E6B8B), Color(hex: 0x354B64)),  // dusk sky
    ]

    /// Static demo shelf — the empty-state path until the first real book is imported
    /// (and the reference look the motion work was built against).
    static let seeds: [ShelfBook] = [
        ShelfBook(
            id: "seed-1", title: "Optic", author: "Studio Feixen",
            cloth: Color(hex: 0xD8D6D0), ink: Color(hex: 0xBDBab2), aspect: 0.42, gilt: false
        ),
        ShelfBook(
            id: "seed-2", title: "David Crow", author: "Visible Signs",
            cloth: Color(hex: 0x2A3357), ink: Color(hex: 0x8E96B8), aspect: 0.34, gilt: false
        ),
        ShelfBook(
            id: "seed-3", title: "Hey", author: "Design & Illustration",
            cloth: Color(hex: 0xEFA8C4), ink: Color(hex: 0xC97D9F), aspect: 0.55, gilt: false
        ),
        ShelfBook(
            id: "seed-4", title: "Design by Accident", author: "For a New History of Design",
            cloth: Color(hex: 0x3C55B4), ink: Color(hex: 0x2C4093), aspect: 0.78, gilt: true
        ),
        ShelfBook(
            id: "seed-5", title: "A Sense of Place", author: "David Thulstrup",
            cloth: Color(hex: 0xD9A923), ink: Color(hex: 0xB8880F), aspect: 0.48, gilt: false
        ),
        ShelfBook(
            id: "seed-6", title: "Design Emergency", author: "Building a Better Future",
            cloth: Color(hex: 0x6E2F2A), ink: Color(hex: 0x9E5E54), aspect: 0.40, gilt: false
        ),
        ShelfBook(
            id: "seed-7", title: "New Utilitarian", author: "Beyond Function",
            cloth: Color(hex: 0x40302A), ink: Color(hex: 0xD557A0), aspect: 0.52, gilt: false
        ),
        ShelfBook(
            id: "seed-8", title: "The ECAL Manual of Style", author: "Olivares · Georgacopoulos",
            cloth: Color(hex: 0x191919), ink: Color(hex: 0xC9C5BC), aspect: 0.72, gilt: false
        ),
    ]
}
