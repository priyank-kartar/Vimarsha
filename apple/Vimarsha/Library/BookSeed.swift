import SwiftUI

/// Static placeholder shelf — stands in for real EPUB covers until the library plan wires
/// `/toc` + client-side cover extraction (decision 2026-06-11: covers are client-side).
/// Cloth/ink colors are book *assets* (like real cover art), not UI palette tokens.
struct BookSeed: Identifiable, Hashable {
    let id: Int
    let title: String
    let author: String
    /// Hardback cloth color.
    let cloth: Color
    /// Tone-on-tone title ink, picked per book like a printed cover.
    let ink: Color
    /// Cover height relative to its width (hardbacks vary; drives the staircase rhythm).
    let aspect: CGFloat
    /// Gilt fore-edge stripe (the reference's blue book flourish).
    let gilt: Bool

    static let shelf: [BookSeed] = [
        BookSeed(
            id: 1, title: "Optic", author: "Studio Feixen",
            cloth: Color(hex: 0xD8D6D0), ink: Color(hex: 0xBDBab2), aspect: 0.42, gilt: false
        ),
        BookSeed(
            id: 2, title: "David Crow", author: "Visible Signs",
            cloth: Color(hex: 0x2A3357), ink: Color(hex: 0x8E96B8), aspect: 0.34, gilt: false
        ),
        BookSeed(
            id: 3, title: "Hey", author: "Design & Illustration",
            cloth: Color(hex: 0xEFA8C4), ink: Color(hex: 0xC97D9F), aspect: 0.55, gilt: false
        ),
        BookSeed(
            id: 4, title: "Design by Accident", author: "For a New History of Design",
            cloth: Color(hex: 0x3C55B4), ink: Color(hex: 0x2C4093), aspect: 0.78, gilt: true
        ),
        BookSeed(
            id: 5, title: "A Sense of Place", author: "David Thulstrup",
            cloth: Color(hex: 0xD9A923), ink: Color(hex: 0xB8880F), aspect: 0.48, gilt: false
        ),
        BookSeed(
            id: 6, title: "Design Emergency", author: "Building a Better Future",
            cloth: Color(hex: 0x6E2F2A), ink: Color(hex: 0x9E5E54), aspect: 0.40, gilt: false
        ),
        BookSeed(
            id: 7, title: "New Utilitarian", author: "Beyond Function",
            cloth: Color(hex: 0x40302A), ink: Color(hex: 0xD557A0), aspect: 0.52, gilt: false
        ),
        BookSeed(
            id: 8, title: "The ECAL Manual of Style", author: "Olivares · Georgacopoulos",
            cloth: Color(hex: 0x191919), ink: Color(hex: 0xC9C5BC), aspect: 0.72, gilt: false
        ),
    ]
}
