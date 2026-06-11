import Foundation

/// WCAG contrast math for the metadata band's legibility guarantee (V43, ui-audit round 2).
///
/// The band floats over **arbitrary** cover art, so "looks fine on these seeds" is not a
/// guarantee — the V38 sky-0.30 glass plate bloomed a blue cover straight through and the
/// band measured ≈1.4–2.6:1. This models the shipped layering (plate at a known opacity
/// over an unknown cover; text — possibly translucent — over that band) and reports the
/// **minimum** contrast ratio over every possible cover color, so a constant can be chosen
/// that clears WCAG AA (≥4.5:1 small text) *by construction*. Pure math, no rendering —
/// the live glass layer above the underlay only ever sits between these extremes; the
/// captures' pixel-sample check is the empirical backstop.
enum BandContrast {
    /// Gamma-encoded sRGB components in 0…1 — the space SwiftUI alpha-compositing works in.
    struct RGB {
        var r: Double
        var g: Double
        var b: Double
    }

    static func rgb(hex: UInt32) -> RGB {
        RGB(
            r: Double((hex >> 16) & 0xFF) / 255,
            g: Double((hex >> 8) & 0xFF) / 255,
            b: Double(hex & 0xFF) / 255
        )
    }

    /// Source-over alpha compositing, per gamma-encoded channel (how the plate sits on the
    /// cover and the translucent subtitle sits on the plate).
    static func blend(_ top: RGB, alpha: Double, over bottom: RGB) -> RGB {
        RGB(
            r: top.r * alpha + bottom.r * (1 - alpha),
            g: top.g * alpha + bottom.g * (1 - alpha),
            b: top.b * alpha + bottom.b * (1 - alpha)
        )
    }

    /// WCAG 2.x relative luminance (linearized sRGB, Rec. 709 weights).
    static func luminance(_ c: RGB) -> Double {
        func lin(_ v: Double) -> Double {
            v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }

    /// WCAG contrast ratio, ≥ 1.
    static func contrastRatio(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a)
        let lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// The minimum contrast of `text` (composited at `textAlpha` onto the band) against the
    /// band itself, over **every** possible cover color beneath a `plate` of `plateOpacity`.
    ///
    /// Both the band blend and relative luminance are monotone per channel, so the extremes
    /// live at the RGB-cube corners — checked exhaustively (plus mid-gray for safety; it can
    /// never undercut the corners, but it documents the sweep).
    static func guaranteedContrast(
        text: RGB, textAlpha: Double, plate: RGB, plateOpacity: Double
    ) -> Double {
        var worst = Double.infinity
        var covers: [RGB] = [RGB(r: 0.5, g: 0.5, b: 0.5)]
        for r in [0.0, 1.0] {
            for g in [0.0, 1.0] {
                for b in [0.0, 1.0] {
                    covers.append(RGB(r: r, g: g, b: b))
                }
            }
        }
        for cover in covers {
            let band = blend(plate, alpha: plateOpacity, over: cover)
            let effectiveText = blend(text, alpha: textAlpha, over: band)
            worst = min(worst, contrastRatio(effectiveText, band))
        }
        return worst
    }
}
