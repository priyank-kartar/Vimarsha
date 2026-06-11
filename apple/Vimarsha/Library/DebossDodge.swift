import CoreGraphics

/// The deboss-dodge band (V45, ui-audit round 3).
///
/// At XXXL rest the focused cover's visible band is too short to hold both the debossed
/// label (which V42 keeps printed — it IS the focus label) and the glass control cluster,
/// so the cluster rendered directly across the deboss glyphs. There is no spatial fix: the
/// two genuinely contend for the same band. Instead the print **yields locally to the
/// glass** — the deboss lines the cluster actually covers fade out under it (soft-feathered,
/// so partially covered glyphs melt rather than slice), and everything above/below stays
/// printed. The cluster's measured viewport rect is mapped into the cover's local space
/// through the same rendered-transform math as `CardVisualTop`; dodge strength rides the
/// cluster's own visibility, so the whole thing scrubs with the scroll like every other
/// library motion. No state, no time.
enum DebossDodge {
    /// Soft transition above/below the dodged band, in cover-local points — wide enough
    /// that a glyph crossing the band edge melts gently instead of appearing cut.
    static let feather: CGFloat = 24

    /// Cluster opacity at which the dodge reaches full strength. Matches the cluster's
    /// interaction ramp: by the time the controls are live (emerge > 0.5), the print under
    /// them must already be fully dodged.
    static let strengthSaturationOpacity: CGFloat = 0.5

    /// A vertical cover-local band where the deboss fades, and how strongly.
    struct Band: Equatable {
        /// Top of the covered zone, in cover-local points.
        var top: CGFloat
        /// Bottom of the covered zone, in cover-local points.
        var bottom: CGFloat
        /// 0 = no dodge (full print), 1 = print fully faded inside the band.
        var strength: CGFloat
    }

    /// - Parameters:
    ///   - clusterTop/clusterBottom: the cluster's measured rect in viewport coordinates.
    ///   - clusterOpacity: the cluster's rendered opacity (`ControlCluster.opacity`).
    ///   - coverVisualTop: the focused cover's rendered top edge (`CardVisualTop.at`).
    ///   - coverScale: the focused cover's rendered scale (`CardVisualTop.scale`).
    /// - Returns: the cover-local dodge band, or `nil` when there is nothing to dodge.
    static func band(
        clusterTop: CGFloat, clusterBottom: CGFloat, clusterOpacity: CGFloat,
        coverVisualTop: CGFloat, coverScale: CGFloat
    ) -> Band? {
        guard clusterOpacity > 0, clusterBottom > clusterTop, coverScale > 0 else { return nil }
        let t = max(0, min(1, clusterOpacity / strengthSaturationOpacity))
        // Smoothstep so the dodge eases in/out with the cluster's own fade — no hard pop.
        let strength = t * t * (3 - 2 * t)
        return Band(
            top: (clusterTop - coverVisualTop) / coverScale,
            bottom: (clusterBottom - coverVisualTop) / coverScale,
            strength: strength
        )
    }

    /// Mask alpha at cover-local `y`: 1 outside the feathered band, `1 - strength` inside,
    /// linear ramps across the feather.
    static func alpha(at y: CGFloat, band: Band) -> CGFloat {
        let s = max(0, min(1, band.strength))
        if y <= band.top - feather || y >= band.bottom + feather { return 1 }
        if y < band.top { return 1 - s * (y - (band.top - feather)) / feather }
        if y <= band.bottom { return 1 - s }
        return 1 - s * ((band.bottom + feather - y) / feather)
    }

    /// The band as renderable gradient stops over the cover's height: piecewise-linear
    /// alpha sampled at the band's knots, clamped into 0…1 and non-decreasing — always a
    /// valid top-to-bottom gradient even when the band overflows the cover.
    static func maskStops(
        band: Band, coverHeight: CGFloat
    ) -> [(location: CGFloat, alpha: CGFloat)] {
        guard coverHeight > 0 else { return [] }
        let knots = [
            0, band.top - feather, band.top, band.bottom, band.bottom + feather, coverHeight
        ]
        return knots
            .map { max(0, min(coverHeight, $0)) }
            .sorted()
            .map { (location: $0 / coverHeight, alpha: alpha(at: $0, band: band)) }
    }
}
