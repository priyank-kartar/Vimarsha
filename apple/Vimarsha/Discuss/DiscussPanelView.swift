import SwiftUI

/// The Discuss panel (V33; apple/CLAUDE.md §UI map state 6, spec §4): a glass plane
/// that morphs up *within* the reading canvas — a state of the surface, never a
/// `.sheet` (the system keyboard is the one sanctioned OS surface). Opening does NOT
/// pause narration; the conversation is ephemeral until saved (V35). Keyboard-default
/// input; replies are text-first. The plane is glass (a control surface); the
/// conversation bubbles on it are matte paper — content is paper, controls are glass.
struct DiscussPanelView: View {
    /// The live conversation (V32) — owned by the surface's opener, not the panel,
    /// so the thread survives the panel closing and reopening.
    let chat: ChatStore
    /// Hold-to-talk (V34) — the secondary input affordance; nil (previews/snapshots/
    /// no recorder) hides the mic. Pause-on-audio-conflict lives in the controller.
    var voice: VoiceInput?
    var reduceTransparency: Bool = false
    var onClose: () -> Void = {}

    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 10)
            transcript
            inputRow
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
        }
        .background(plane)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        // Keyboard-default input (spec §4): the field is focused the moment the
        // plane arrives. The spoken question drops into the field for review/send —
        // never auto-sent (the user may have been misheard).
        .onAppear {
            inputFocused = true
            voice?.onTranscript = { text in
                draft = draft.isEmpty ? text : draft + " " + text
                inputFocused = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Discuss this passage")
    }

    /// The plane is the glass element; Reduce Transparency gets the matte token.
    @ViewBuilder
    private var plane: some View {
        if reduceTransparency {
            Palette.surface
        } else {
            Color.clear.glassEffect(
                .regular.tint(Palette.sky.opacity(0.22)),
                in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
            )
        }
    }

    private var header: some View {
        HStack {
            Text("DISCUSS")
                .font(.system(size: labelSize, weight: .medium))
                .tracking(4)
                .foregroundStyle(Palette.textPrimary.opacity(0.55))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Palette.textPrimary.opacity(0.08)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Discuss")
        }
    }

    /// The conversation, following its newest turn (discrete content changes; the
    /// scroll is informational, so Reduce Motion jumps).
    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                DiscussTranscriptView(
                    messages: chat.messages,
                    sending: chat.sending,
                    error: chat.error,
                    onRetry: { Task { await chat.retry() } }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                Color.clear.frame(height: 1).id("discuss-end")
            }
            .onChange(of: chat.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("discuss-end", anchor: .bottom)
                }
            }
        }
    }

    private var inputRow: some View {
        VStack(spacing: 6) {
            voiceCaption
            HStack(spacing: 10) {
                if let voice {
                    HoldToTalkButton(
                        isRecording: voice.phase == .recording,
                        reduceTransparency: reduceTransparency,
                        onHoldChanged: { holding in
                            if holding {
                                Task { await voice.beginHold() }
                            } else {
                                voice.endHold()
                            }
                        }
                    )
                }
                inputField
                sendButton
            }
        }
    }

    /// The field is the default; while the mic is open (or its transcript is being
    /// fetched) its slot shows the honest listening/transcribing state instead.
    @ViewBuilder
    private var inputField: some View {
        switch voice?.phase {
        case .recording:
            listeningIndicator
        case .transcribing:
            interimRow(text: "Transcribing…")
        default:
            TextField("Ask about this passage…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .font(.system(size: 15))
                .foregroundStyle(Palette.textPrimary)
                .focused($inputFocused)
                .onSubmit(sendDraft)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.canvas.opacity(reduceTransparency ? 1 : 0.55))
                )
        }
    }

    /// Live aqua mic state (recording = live, so aqua): level-driven glyph + clock.
    private var listeningIndicator: some View {
        interimRow(
            text: "Listening… \(Transport.timeString(ms: voice?.elapsedMs ?? 0))",
            icon: "waveform",
            iconOpacity: 0.45 + 0.55 * (voice?.level ?? 0)
        )
        .accessibilityLabel("Listening")
    }

    private func interimRow(
        text: String, icon: String? = nil, iconOpacity: CGFloat = 1
    ) -> some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.aqua.opacity(iconOpacity))
            }
            Text(text)
                .font(.system(size: 15).italic().monospacedDigit())
                .foregroundStyle(Palette.textPrimary.opacity(0.7))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.canvas.opacity(reduceTransparency ? 1 : 0.55))
        )
    }

    /// Honest mic guidance under the input (spec §6: transcription failure falls back
    /// to the text field; the panel state is never lost).
    @ViewBuilder
    private var voiceCaption: some View {
        switch voice?.phase {
        case .failed:
            caption("Couldn't transcribe — type your question instead.")
        case .denied:
            caption("Microphone access needed — enable it in Settings.")
        default:
            EmptyView()
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(Palette.textPrimary.opacity(0.65))
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
    }

    private var sendButton: some View {
        Button(action: sendDraft) {
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(canSend ? Palette.ink0 : Palette.textPrimary.opacity(0.4))
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(
                        canSend ? Palette.aqua.opacity(0.92) : Palette.textPrimary.opacity(0.08)
                    )
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .accessibilityLabel("Send")
    }

    private var canSend: Bool {
        !chat.sending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendDraft() {
        guard canSend else { return }
        let text = draft
        draft = ""
        Task { await chat.send(text) }
    }
}

/// The panel's hold-to-talk mic (V34): the MemoRecordControl gesture pattern — a short
/// long-press arms it, the open-ended press holds it until the finger lifts. Aqua while
/// live, sky otherwise; VoiceOver gets a start/stop toggle (gesture-only rule).
private struct HoldToTalkButton: View {
    let isRecording: Bool
    var reduceTransparency: Bool = false
    var onHoldChanged: (Bool) -> Void = { _ in }

    @GestureState private var holding = false

    private var tint: Color { isRecording ? Palette.aqua : Palette.sky }

    var body: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Palette.textPrimary)
            .frame(width: 38, height: 38)
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
            .gesture(
                LongPressGesture(minimumDuration: 0.25)
                    .sequenced(before: LongPressGesture(minimumDuration: .infinity))
                    .updating($holding) { value, state, _ in
                        if case .second = value { state = true }
                    }
            )
            .onChange(of: holding) { _, isHolding in onHoldChanged(isHolding) }
            .accessibilityLabel("Voice question")
            .accessibilityHint("Hold to talk")
            .accessibilityAction(named: isRecording ? "Stop and transcribe" : "Start voice question") {
                onHoldChanged(!isRecording)
            }
    }
}

/// The conversation turns, extracted from the ScrollView so snapshots can render them
/// directly (`ImageRenderer` doesn't rasterize ScrollView content — the V14 gotcha).
/// Matte paper bubbles on the glass plane: user trailing with a sky accent border,
/// assistant leading in the reading serif; honest thinking/error states.
struct DiscussTranscriptView: View {
    let messages: [ChatMessageDTO]
    var sending: Bool = false
    var error: Bool = false
    var onRetry: () -> Void = {}

    @ScaledMetric(relativeTo: .footnote) private var bodySize: CGFloat = 14

    var body: some View {
        VStack(spacing: 12) {
            if messages.isEmpty && !sending {
                Text("Ask about the passage being read — the reply is grounded in it.")
                    .font(.system(size: bodySize))
                    .foregroundStyle(Palette.textPrimary.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 28)
            }
            ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                bubble(message)
            }
            if sending {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Thinking…")
                        .font(.system(size: bodySize).italic())
                        .foregroundStyle(Palette.textPrimary.opacity(0.55))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Waiting for the reply")
            }
            if error {
                errorRow
            }
        }
    }

    private func bubble(_ message: ChatMessageDTO) -> some View {
        let isUser = message.role == "user"
        return Text(message.text)
            .font(isUser ? .system(size: bodySize) : .system(size: bodySize, design: .serif))
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isUser ? Palette.sky.opacity(0.45)
                                    : Palette.textPrimary.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )
            .frame(
                maxWidth: .infinity,
                alignment: isUser ? .trailing : .leading
            )
            .accessibilityLabel(isUser ? "You: \(message.text)" : "Reply: \(message.text)")
    }

    /// The send failed (Ollama down / backend unreachable): the conversation and
    /// prior turns stay intact; retry re-sends the unanswered question (spec §6).
    private var errorRow: some View {
        HStack(spacing: 10) {
            Text("No reply — the conversation backend didn't answer.")
                .font(.system(size: bodySize).italic())
                .foregroundStyle(Palette.textPrimary.opacity(0.7))
            Button(action: onRetry) {
                Text("Retry")
                    .font(.system(size: bodySize, weight: .semibold))
                    .foregroundStyle(Palette.ink0)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Palette.aqua.opacity(0.92)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retry sending")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Discuss transcript — dark") {
    DiscussTranscriptView(
        messages: [
            .user("What does the passage claim about good design?"),
            .assistant("It claims good design is nearly invisible — it fits our needs so well it serves without drawing attention to itself."),
            .user("And poor design?"),
        ],
        sending: false,
        error: true
    )
    .padding(20)
    .background(Palette.canvas)
    .preferredColorScheme(.dark)
}
