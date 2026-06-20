import SwiftUI

/// The glass control cluster (glass moment #5): the focused book's four actions rendered as
/// glass controls that morph out of the cover and re-absorb on scroll. The choreography is
/// the pure `ControlCluster` value; this view is only its glass rendering.
///
/// The controls live in a `GlassEffectContainer` and each carries a `glassEffectID`, so when
/// `emerge` is low they overlap at the centre and the container renders them as **one melded
/// glass blob** (absorbed into the cover); as `emerge` rises they fan apart and the blob
/// **splits** into four separate controls — the glass analogue of grow-to-front (motion
/// grammar #2 / #4). Reduce Transparency swaps in token-tinted matte fallbacks.
struct ControlClusterView: View {
    let cluster: ControlCluster
    var reduceTransparency: Bool = false
    /// Stub actions for V07 — the reading-surface / figures / memo / discuss morphs land later.
    var onActivate: (ControlCluster.Control) -> Void = { _ in }

    @Namespace private var glassNS

    @ScaledMetric(relativeTo: .title2) private var rawDiameter: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var rawIconSize: CGFloat = 20

    private let controls = ControlCluster.Control.allCases

    /// Control size scales with Dynamic Type but clamps (V40): unclamped, the XXXL diameter
    /// (~100pt) outgrew the fixed fan spacing, so the four controls could never split — they
    /// rendered as ONE permanently melded pill (the ui-audit "untinted grey pill"). 68pt keeps
    /// a generous touch target at every type size while the fan still reads as four controls.
    private var diameter: CGFloat { min(rawDiameter, 68) }
    private var iconSize: CGFloat { min(rawIconSize, 24) }

    /// Centre-to-centre spacing at full emerge, derived from the (type-scaled) diameter so the
    /// controls always split: a 14pt gap — clear of the `GlassEffectContainer` meld radius by
    /// enough to read separate, close enough to re-meld quickly on absorb.
    private var spacing: CGFloat { diameter + 14 }

    /// The full fan's layout width. The per-control fan-out is rendered with `offset` (which
    /// doesn't grow layout), so without an explicit frame the cluster's layout box stays ONE
    /// circle wide — and V37's `.clipped()` backstop amputated the outer controls at full
    /// emerge. The frame makes layout match the rendered fan.
    private var fanWidth: CGFloat { CGFloat(controls.count - 1) * spacing + diameter }

    var body: some View {
        // Fully gated below the visibility floor (V39): not just transparent but absent —
        // partial-promotion states (e.g. launch rest) must never leak a miniature melded
        // pill mid-cover (ui-audit round 1). `opacity` is 0 exactly at the floor, so the
        // insertion itself is invisible and the gate stays scrubbable.
        if cluster.isVisible {
            GlassEffectContainer(spacing: 18) {
                ZStack {
                    ForEach(controls) { control in
                        controlButton(control)
                            .offset(
                                x: cluster.xOffset(
                                    forControl: control.rawValue,
                                    of: controls.count,
                                    spacing: spacing
                                )
                            )
                    }
                }
                .frame(width: fanWidth, height: diameter)
            }
            // Fade + a subtle lift as the cluster grows out of the cover; re-absorb reverses it.
            .opacity(cluster.opacity)
            .scaleEffect(0.9 + 0.1 * cluster.emerge, anchor: .top)
            // Only live (and reachable) once meaningfully emerged — keeps the melded blob inert.
            .allowsHitTesting(cluster.emerge > 0.5)
            .accessibilityHidden(cluster.emerge < 0.5)
        }
    }

    @ViewBuilder
    private func controlButton(_ control: ControlCluster.Control) -> some View {
        Button { onActivate(control) } label: { icon(control) }
            .buttonStyle(.plain)
            // The whole glass circle is tappable, not just the glyph.
            .contentShape(Circle())
            .accessibilityLabel(control.label)
    }

    @ViewBuilder
    private func icon(_ control: ControlCluster.Control) -> some View {
        if reduceTransparency {
            // Opaque fallback (apple/CLAUDE.md §Accessibility): token-tinted matte control.
            glyph(control, color: Palette.textPrimary)
                .background(Circle().fill(Palette.surface))
                .overlay(Circle().strokeBorder(tint(for: control, opaque: true), lineWidth: 1))
        } else {
            // Ink icons on the glass path (V40): glass adapts its content rendering to the
            // luminance of whatever cover sits beneath, so the mode-aware `textPrimary`
            // flipped dark over light covers (the audit's grey-pill icons). Ink-on-sky/aqua
            // is the palette's own pairing and is cover-independent.
            glyph(control, color: Palette.ink0)
                .glassEffect(.regular.tint(tint(for: control)).interactive(), in: Circle())
                .glassEffectID(control, in: glassNS)
        }
    }

    private func glyph(_ control: ControlCluster.Control, color: Color) -> some View {
        Image(systemName: control.symbol)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: diameter, height: diameter)
    }

    /// Play is the active action → `aqua` (live); the rest are interactive → `sky`
    /// (apple/CLAUDE.md §Liquid Glass: tint interactive with sky, live/active with aqua).
    /// V24 raised the tints (0.16/0.22 → 0.26/0.32) but the ui-audit still read the pill as
    /// untinted grey over the pink cover — V40 raises them to ownership strength (0.45/0.52):
    /// the pill must read sky/aqua over ANY cover (pink/butter included), per the glass rule
    /// "tint glass with sky or aqua; avoid untinted grey glass".
    private func tint(for control: ControlCluster.Control, opaque: Bool = false) -> Color {
        let base = control == .play ? Palette.aqua : Palette.sky
        return base.opacity(opaque ? 0.5 : (control == .play ? 0.52 : 0.45))
    }
}

#Preview("Control cluster — emerged (dark)") {
    ZStack {
        Palette.canvas.ignoresSafeArea()
        ControlClusterView(cluster: .at(promotion: 1))
    }
    .frame(width: 393, height: 200)
    .preferredColorScheme(.dark)
}
