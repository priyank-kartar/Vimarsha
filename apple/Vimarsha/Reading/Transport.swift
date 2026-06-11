import Foundation

/// Pure transport rules (V19): the speed ladder and clock formatting the glass cluster
/// renders. No state — the player owns the live values.
nonisolated enum Transport {
    /// The speed ladder (Flutter player parity); tapping the speed control cycles it.
    static let rates: [Double] = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    /// Skip step for the back/forward controls.
    static let skipMs = 15_000

    /// The next rate in the ladder (wraps); an off-ladder rate snaps back to 1.0's
    /// successor so a stray value can't strand the control.
    static func nextRate(after rate: Double) -> Double {
        guard let index = rates.firstIndex(where: { abs($0 - rate) < 0.001 }) else {
            return rates[(rates.firstIndex(of: 1.0)! + 1) % rates.count]
        }
        return rates[(index + 1) % rates.count]
    }

    /// "0:07", "3:25", "1:02:03" — hours only when needed; negative clamps to zero.
    static func timeString(ms: Int) -> String {
        let totalSeconds = max(0, ms) / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    /// "1.5×" — trailing zeros trimmed the way a speed chip reads ("1×", "1.25×").
    static func rateLabel(_ rate: Double) -> String {
        let text = rate == rate.rounded()
            ? String(format: "%.0f", rate)
            : String("\(rate)".prefix(4))
        return "\(text)×"
    }
}
