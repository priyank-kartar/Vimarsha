import SwiftUI

/// The glass mic control on the reading surface (V28; apple/CLAUDE.md §UI map state 5,
/// screen-flows "Reading ↔ Memo record: hold gesture on the mic control"). Hold to
/// record — aqua (live) while recording, sky (interactive) otherwise. Gesture-only
/// interactions need an accessibility action (apple/CLAUDE.md §Accessibility), so
/// VoiceOver gets a start/stop toggle.
struct MemoRecordControl: View {
    let isRecording: Bool
    var reduceTransparency: Bool = false
    /// `true` on hold start, `false` on release — the surface drives `MemoCapture`.
    var onHoldChanged: (Bool) -> Void = { _ in }

    /// Set while the hold gesture is active; resets to false on release/cancel.
    @GestureState private var holding = false

    private var tint: Color { isRecording ? Palette.aqua : Palette.sky }

    var body: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Palette.textPrimary)
            .frame(width: 44, height: 44)
            .background {
                if reduceTransparency {
                    Circle().fill(Palette.surface)
                        .overlay(Circle().strokeBorder(tint.opacity(0.6), lineWidth: 1))
                } else {
                    Color.clear.glassEffect(
                        .regular.tint(tint.opacity(isRecording ? 0.5 : 0.3)).interactive(),
                        in: .circle
                    )
                }
            }
            .contentShape(Circle())
            .gesture(holdGesture)
            .onChange(of: holding) { _, isHolding in onHoldChanged(isHolding) }
            .accessibilityLabel("Voice note")
            .accessibilityHint("Hold to record")
            .accessibilityAction(named: isRecording ? "Stop recording" : "Start recording") {
                onHoldChanged(!isRecording)
            }
    }

    /// Press-and-hold: a short long-press arms it, then an open-ended press keeps the
    /// gesture state true until the finger lifts (`@GestureState` resets on release).
    private var holdGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: LongPressGesture(minimumDuration: .infinity))
            .updating($holding) { value, state, _ in
                if case .second = value { state = true }
            }
    }
}

#Preview("Mic — idle vs recording") {
    HStack(spacing: 24) {
        MemoRecordControl(isRecording: false)
        MemoRecordControl(isRecording: true)
    }
    .padding(40)
    .background(Palette.canvas)
    .preferredColorScheme(.dark)
}
