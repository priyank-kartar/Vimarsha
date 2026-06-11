import Testing
@testable import Vimarsha

/// V43 — ui-audit round 2: the metadata band must GUARANTEE WCAG contrast over ANY cover
/// art. Pure WCAG math (relative luminance, contrast ratio, worst-case-cover blend) plus
/// the pinned plate/text constants the view actually renders with.
@Suite("BandContrast — WCAG guarantee for the metadata band (V43)")
struct BandContrastTests {
    let white = BandContrast.rgb(hex: 0xFFFFFF)
    let black = BandContrast.rgb(hex: 0x000000)

    @Test("white on black is the canonical 21:1; a color against itself is 1:1")
    func canonicalRatios() {
        #expect(abs(BandContrast.contrastRatio(white, black) - 21) < 0.01)
        let sky = BandContrast.rgb(hex: Palette.Hex.sky)
        #expect(abs(BandContrast.contrastRatio(sky, sky) - 1) < 1e-9)
    }

    @Test("luminance is monotone per channel (worst covers live at the cube corners)")
    func luminanceMonotone() {
        let dim = BandContrast.RGB(r: 0.2, g: 0.2, b: 0.2)
        let brighter = BandContrast.RGB(r: 0.2, g: 0.6, b: 0.2)
        #expect(BandContrast.luminance(brighter) > BandContrast.luminance(dim))
    }

    @Test("audit regression: the V38 sky-0.30 plate cannot guarantee AA in either mode")
    func oldPlateFails() {
        let sky = BandContrast.rgb(hex: Palette.Hex.sky)
        // Dark mode: warm paper text over whatever blooms through 30% sky.
        let dark = BandContrast.guaranteedContrast(
            text: BandContrast.rgb(hex: Palette.Hex.paper), textAlpha: 1,
            plate: sky, plateOpacity: 0.30
        )
        #expect(dark < 3)
        // Light mode: ink text, same weak plate.
        let light = BandContrast.guaranteedContrast(
            text: BandContrast.rgb(hex: Palette.Hex.ink0), textAlpha: 1,
            plate: sky, plateOpacity: 0.30
        )
        #expect(light < 3)
    }

    @Test("audit regression: the measured blue-cover state fails under the old plate")
    func oldPlateFailsOnBlueCover() {
        // The seeds' "Design by Accident" cloth — the cover the audit measured ≈2.6:1.
        let blue = BandContrast.rgb(hex: 0x3C55B4)
        let band = BandContrast.blend(
            BandContrast.rgb(hex: Palette.Hex.sky), alpha: 0.30, over: blue
        )
        let ratio = BandContrast.contrastRatio(BandContrast.rgb(hex: Palette.Hex.paper), band)
        #expect(ratio < 4.5)
    }

    @Test("dark mode: title and subtitle clear 4.5:1 over ANY cover with the shipped plate")
    func darkModeGuarantee() {
        let plate = BandContrast.rgb(hex: Palette.Hex.ink1)  // Palette.surface, dark
        let text = BandContrast.rgb(hex: Palette.Hex.paper)  // Palette.textPrimary, dark
        let title = BandContrast.guaranteedContrast(
            text: text, textAlpha: 1,
            plate: plate, plateOpacity: FocusMetadataView.plateUnderlayOpacity
        )
        #expect(title >= 4.5)
        let subtitle = BandContrast.guaranteedContrast(
            text: text, textAlpha: FocusMetadataView.subtitleOpacity,
            plate: plate, plateOpacity: FocusMetadataView.plateUnderlayOpacity
        )
        #expect(subtitle >= 4.5)
    }

    @Test("light mode: title and subtitle clear 4.5:1 over ANY cover with the shipped plate")
    func lightModeGuarantee() {
        let plate = BandContrast.rgb(hex: Palette.Hex.aqua)  // Palette.surface, light
        let text = BandContrast.rgb(hex: Palette.Hex.ink0)   // Palette.textPrimary, light
        let title = BandContrast.guaranteedContrast(
            text: text, textAlpha: 1,
            plate: plate, plateOpacity: FocusMetadataView.plateUnderlayOpacity
        )
        #expect(title >= 4.5)
        let subtitle = BandContrast.guaranteedContrast(
            text: text, textAlpha: FocusMetadataView.subtitleOpacity,
            plate: plate, plateOpacity: FocusMetadataView.plateUnderlayOpacity
        )
        #expect(subtitle >= 4.5)
    }

    @Test("the guarantee covers the audit's blue and a hostile mid-luminance cover")
    func specificCoversClear() {
        for coverHex: UInt32 in [0x3C55B4, 0x808080, 0xE9A0B6] {
            let cover = BandContrast.rgb(hex: coverHex)
            // Dark mode band on this cover.
            let band = BandContrast.blend(
                BandContrast.rgb(hex: Palette.Hex.ink1),
                alpha: FocusMetadataView.plateUnderlayOpacity, over: cover
            )
            let text = BandContrast.rgb(hex: Palette.Hex.paper)
            let subtitle = BandContrast.blend(text, alpha: FocusMetadataView.subtitleOpacity, over: band)
            #expect(BandContrast.contrastRatio(text, band) >= 4.5)
            #expect(BandContrast.contrastRatio(subtitle, band) >= 4.5)
        }
    }
}
