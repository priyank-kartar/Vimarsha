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

    @ScaledMetric(relativeTo: .title2) private var diameter: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 20

    private let controls = ControlCluster.Control.allCases
    /// Centre-to-centre spacing at full emerge (≈ diameter + a hair of gap, so they melt
    /// cleanly into one blob when stacked at the centre).
    private let spacing: CGFloat = 64

    var body: some View {
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
        }
        // Fade + a subtle lift as the cluster grows out of the cover; re-absorb reverses it.
        .opacity(cluster.emerge)
        .scaleEffect(0.9 + 0.1 * cluster.emerge, anchor: .top)
        // Only live (and reachable) once meaningfully emerged — keeps the melded blob inert.
        .allowsHitTesting(cluster.emerge > 0.5)
        .accessibilityHidden(cluster.emerge < 0.5)
    }

    @ViewBuilder
    private func controlButton(_ control: ControlCluster.Control) -> some View {
        Button { onActivate(control) } label: { icon(control) }
            .buttonStyle(.plain)
            .accessibilityLabel(control.label)
    }

    @ViewBuilder
    private func icon(_ control: ControlCluster.Control) -> some View {
        let glyph = Image(systemName: control.symbol)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(Palette.textPrimary)
            .frame(width: diameter, height: diameter)

        if reduceTransparency {
            // Opaque fallback (apple/CLAUDE.md §Accessibility): token-tinted matte control.
            glyph
                .background(Circle().fill(Palette.surface))
                .overlay(Circle().strokeBorder(tint(for: control, opaque: true), lineWidth: 1))
        } else {
            glyph
                .glassEffect(.regular.tint(tint(for: control)).interactive(), in: Circle())
                .glassEffectID(control, in: glassNS)
        }
    }

    /// Play is the active action → `aqua` (live); the rest are interactive → `sky`
    /// (apple/CLAUDE.md §Liquid Glass: tint interactive with sky, live/active with aqua).
    private func tint(for control: ControlCluster.Control, opaque: Bool = false) -> Color {
        let base = control == .play ? Palette.aqua : Palette.sky
        return base.opacity(opaque ? 0.5 : (control == .play ? 0.22 : 0.16))
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
