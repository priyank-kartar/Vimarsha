import SwiftUI

/// Canonical color tokens — the ONLY place hex values live (apple/CLAUDE.md §Color palette).
/// Raw palette hexes are sampled estimates from the user's palette image.
enum Palette {
    // MARK: Raw palette

    static let butter = Color(hex: 0xF4F48F)
    static let aqua = Color(hex: 0x8FE5DC)
    static let sky = Color(hex: 0x6FAFD0)
    static let slate = Color(hex: 0x5A8C9D)

    /// Derived ink ramp — slate hue, deepened. Dark-mode canvas; light-mode text.
    static let ink0 = Color(hex: 0x101F26)
    static let ink1 = Color(hex: 0x16262D)
    static let ink2 = Color(hex: 0x1C313A)

    /// Warm off-white derived from butter at low saturation — dark-mode text.
    /// Never pure #FFFFFF (apple/CLAUDE.md).
    static let paper = Color(hex: 0xF2EFDE)

    // MARK: Book-rendering tokens (shared across all generated hardbacks)

    /// Fore-edge page stack off-white.
    static let pageEdge = Color(hex: 0xEDE8DA)
    /// Gilt fore-edge stripe gold.
    static let gilt = Color(hex: 0xC9A227)

    // MARK: Semantic (mode-aware, dark-first)

    static let canvas = Color(light: butter, dark: ink0)
    static let surface = Color(light: aqua, dark: ink1)
    /// Body text: one role in two modes — deepest ink on light canvases, warm paper on ink.
    /// slate/sky are decorative only (WCAG — see apple/CLAUDE.md).
    static let textPrimary = Color(light: ink0, dark: paper)
    static let tint = sky
}

extension Color {
    /// `Color(hex: 0xRRGGBB)`
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// A dynamic color that resolves per the active appearance.
    init(light: Color, dark: Color) {
        #if os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(isDark ? dark : light)
        })
        #else
        self.init(uiColor: UIColor { traits in
            UIColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
        #endif
    }
}
