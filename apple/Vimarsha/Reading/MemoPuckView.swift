import SwiftUI

/// The aqua waveform puck shown while a memo records (V28; apple/CLAUDE.md §UI map
/// state 5 — "an aqua waveform puck while recording"). One aqua-tinted glass capsule
/// (live/active role) carrying a live level waveform and the recording clock; matte
/// token fallback under Reduce Transparency. Parameterized (not self-tracking) so it
/// renders identically live and in snapshots.
struct MemoPuckView: View {
    /// Live mic level 0…1 (drives the bar heights).
    let level: CGFloat
    let elapsedMs: Int
    var reduceTransparency: Bool = false

    @ScaledMetric(relativeTo: .caption2) private var clockSize: CGFloat = 11

    /// Fixed per-bar emphasis so the waveform reads organic, not a flat meter.
    private static let barWeights: [CGFloat] = [0.45, 0.8, 1.0, 0.65, 0.9, 0.55, 0.75]
    private static let barMaxHeight: CGFloat = 22

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Palette.aqua)
                .frame(width: 8, height: 8)
            waveform
            Text(Transport.timeString(ms: elapsedMs))
                .font(.system(size: clockSize, weight: .medium).monospacedDigit())
                .foregroundStyle(Palette.textPrimary.opacity(0.85))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background {
            let shape = Capsule()
            if reduceTransparency {
                shape.fill(Palette.surface)
                    .overlay(shape.strokeBorder(Palette.aqua.opacity(0.6), lineWidth: 1))
            } else {
                // Aqua = the live/active glass tint (apple/CLAUDE.md §Liquid Glass rules).
                Color.clear.glassEffect(.regular.tint(Palette.aqua.opacity(0.35)), in: shape)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recording voice note, \(Transport.timeString(ms: elapsedMs))")
    }

    /// Level-driven bars: each bar keeps a floor so the puck never reads dead, and
    /// scales with the live level by its own weight.
    private var waveform: some View {
        HStack(spacing: 3) {
            ForEach(Array(Self.barWeights.enumerated()), id: \.offset) { _, weight in
                Capsule()
                    .fill(Palette.aqua.opacity(0.9))
                    .frame(
                        width: 3,
                        height: max(4, Self.barMaxHeight * weight * (0.25 + 0.75 * level))
                    )
            }
        }
        .frame(height: Self.barMaxHeight)
        .animation(.easeOut(duration: 0.1), value: level)
    }
}

#Preview("Memo puck — dark") {
    VStack(spacing: 20) {
        MemoPuckView(level: 0.2, elapsedMs: 3_000)
        MemoPuckView(level: 0.9, elapsedMs: 61_000)
    }
    .padding(40)
    .background(Palette.canvas)
    .preferredColorScheme(.dark)
}
