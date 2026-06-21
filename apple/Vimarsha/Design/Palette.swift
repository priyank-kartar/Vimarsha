import SwiftUI

/// Canonical color tokens — the ONLY place hex values live (apple/CLAUDE.md §Color palette).
/// Raw palette hexes are sampled estimates from the user's palette image.
enum Palette {
    // MARK: Raw hexes (the single source — `Color` tokens below and the WCAG math in
    // `BandContrast` consume these same values, so a palette correction stays one edit).

    enum Hex {
        static let butter: UInt32 = 0xF4F48F
        static let aqua: UInt32 = 0x8FE5DC
        static let sky: UInt32 = 0x6FAFD0
        static let slate: UInt32 = 0x5A8C9D
        static let ink0: UInt32 = 0x101F26
        static let ink1: UInt32 = 0x16262D
        static let ink2: UInt32 = 0x1C313A
        static let paper: UInt32 = 0xF2EFDE
    }

    // MARK: Raw palette

    static let butter = Color(hex: Hex.butter)
    static let aqua = Color(hex: Hex.aqua)
    static let sky = Color(hex: Hex.sky)
    static let slate = Color(hex: Hex.slate)

    /// Derived ink ramp — slate hue, deepened. Dark-mode canvas; light-mode text.
    static let ink0 = Color(hex: Hex.ink0)
    static let ink1 = Color(hex: Hex.ink1)
    static let ink2 = Color(hex: Hex.ink2)

    /// Warm off-white derived from butter at low saturation — dark-mode text.
    /// Never pure #FFFFFF (apple/CLAUDE.md).
    static let paper = Color(hex: Hex.paper)

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
    /// Narrated-paragraph highlight (V18): butter glow on the ink canvas (dark-mode
    /// butter = highlights/progress), aqua wash on the butter canvas.
    static let narrationHighlight = Color(light: aqua.opacity(0.40), dark: butter.opacity(0.13))
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
    ///
    /// MUST be `nonisolated`: UIKit/AppKit invoke the trait-resolution closure on whatever
    /// thread is resolving the color, and SwiftUI resolves colors OFF the main actor during
    /// some view updates (e.g. the Discuss panel's keyboard/TextEditor layout). Under the
    /// project's default main-actor isolation, an isolated provider closure traps there with
    /// EXC_BREAKPOINT (swift_task_checkIsolatedSwift → dispatch_assert_queue). `nonisolated`
    /// makes the closure safe to call from any thread (it only reads Sendable Colors).
    nonisolated init(light: Color, dark: Color) {
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
