import SwiftUI

/// The compact glass transport (V19; apple/CLAUDE.md §UI map state 3 — "transport lives
/// in a compact glass cluster, not a chrome bar"). ONE glass capsule carries the whole
/// cluster (no glass-in-glass nesting): a slim butter progress line + clock, and
/// back-15 / play-pause / forward-15 / speed riding matte on it — controls are glass,
/// the readout is paper. Parameterized (not self-tracking) so it renders identically
/// live and in snapshots.
struct TransportClusterView: View {
    let positionMs: Int
    let durationMs: Int
    let isPlaying: Bool
    let rate: Double
    var reduceTransparency: Bool = false
    var onPlayPause: () -> Void = {}
    var onSkip: (Int) -> Void = { _ in }
    var onCycleRate: () -> Void = {}

    @ScaledMetric(relativeTo: .caption2) private var clockSize: CGFloat = 10

    private var fraction: CGFloat {
        durationMs > 0 ? CGFloat(positionMs) / CGFloat(durationMs) : 0
    }

    var body: some View {
        VStack(spacing: 8) {
            progressLine
            HStack(spacing: 22) {
                control("gobackward.15", label: "Back 15 seconds") {
                    onSkip(-Transport.skipMs)
                }
                playPause
                control("goforward.15", label: "Skip 15 seconds") {
                    onSkip(Transport.skipMs)
                }
                speedChip
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 13)
        .padding(.bottom, 9)
        .background {
            let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)
            if reduceTransparency {
                // Opaque fallback (apple/CLAUDE.md §Accessibility): token-tinted matte.
                shape.fill(Palette.surface)
                    .overlay(shape.strokeBorder(Palette.sky.opacity(0.5), lineWidth: 1))
            } else {
                Color.clear.glassEffect(
                    .regular.tint(Palette.sky.opacity(0.22)).interactive(), in: shape
                )
            }
        }
    }

    /// Elapsed / progress / total — butter is the progress role in both modes.
    private var progressLine: some View {
        HStack(spacing: 10) {
            Text(Transport.timeString(ms: positionMs))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.textPrimary.opacity(0.18))
                    Capsule()
                        .fill(Palette.butter.opacity(0.9))
                        .frame(width: max(3, geo.size.width * min(max(fraction, 0), 1)))
                }
            }
            .frame(height: 3)
            Text(Transport.timeString(ms: durationMs))
        }
        .font(.system(size: clockSize, weight: .medium).monospacedDigit())
        .foregroundStyle(Palette.textPrimary.opacity(0.75))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(Transport.timeString(ms: positionMs)) of \(Transport.timeString(ms: durationMs))"
        )
    }

    /// The primary control: an aqua (live/active) accent riding ON the glass.
    private var playPause: some View {
        Button(action: onPlayPause) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.ink0)
                .frame(width: 50, height: 38)
                .background(Capsule().fill(Palette.aqua.opacity(0.92)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
    }

    private func control(
        _ symbol: String, label: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 38, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var speedChip: some View {
        Button(action: onCycleRate) {
            Text(Transport.rateLabel(rate))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 44, height: 38)
                .background(Capsule().strokeBorder(Palette.textPrimary.opacity(0.30), lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Playback speed \(Transport.rateLabel(rate))")
        .accessibilityHint("Cycles through speeds")
    }
}

#Preview("Transport — dark") {
    TransportClusterView(positionMs: 161_000, durationMs: 1_475_000, isPlaying: true, rate: 1.25)
        .padding(40)
        .background(Palette.canvas)
        .preferredColorScheme(.dark)
}
