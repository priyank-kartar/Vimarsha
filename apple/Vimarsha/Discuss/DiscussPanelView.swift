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
    /// Spoken replies (V35) — /speak on its own ephemeral engine; nil hides the
    /// speaker controls.
    var speaker: ReplySpeaker?
    /// Saved-conversation persistence (V35) — Save + the Conversations state; nil
    /// hides both (previews/snapshots).
    var archive: DiscussArchive?
    var reduceTransparency: Bool = false
    var onClose: () -> Void = {}

    /// Which face of the plane is showing (V35): the live chat, the saved list, or
    /// one saved thread read-only — morphs of the SAME plane, never a new surface.
    private enum PanelState: Equatable {
        case live, conversations, thread(UUID)
    }

    @State private var draft = ""
    @State private var panelState: PanelState = .live
    /// Brief Save confirmation on the header chip.
    @State private var savedFlash = false
    @FocusState private var inputFocused: Bool

    @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 10)
            switch panelState {
            case .live:
                transcript
                inputRow
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            case .conversations:
                conversationsList
            case .thread(let id):
                savedThread(id: id)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: panelState)
        .background(plane)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        // Keyboard-default input (spec §4): the field is focused the moment the plane arrives.
        // This is now safe because the library underneath ignores the keyboard and freezes all
        // its geometry observers while covered (see LibraryStackView) — so the keyboard no
        // longer drives a reflow loop. The spoken transcript also lands in the field for review.
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
        HStack(spacing: 10) {
            Text(headerTitle)
                .font(.system(size: labelSize, weight: .medium))
                .tracking(4)
                .foregroundStyle(Palette.textPrimary.opacity(0.55))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            switch panelState {
            case .live:
                if archive != nil, chat.hasExchange {
                    saveChip
                }
                if archive != nil {
                    headerControl(
                        symbol: "bookmark", label: "Saved conversations"
                    ) { panelState = .conversations }
                }
            case .conversations:
                headerControl(symbol: "bubble.left.and.text.bubble.right", label: "Back to discussion") {
                    panelState = .live
                }
            case .thread:
                headerControl(symbol: "chevron.left", label: "Back to saved conversations") {
                    panelState = .conversations
                }
            }
            headerControl(symbol: "chevron.down", label: "Close Discuss") {
                speaker?.stop()
                onClose()
            }
        }
    }

    private var headerTitle: String {
        switch panelState {
        case .live: "DISCUSS"
        case .conversations: "CONVERSATIONS"
        case .thread: "SAVED CONVERSATION"
        }
    }

    private func headerControl(
        symbol: String, label: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Palette.textPrimary.opacity(0.08)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Save persists the live conversation as a NEW thread (spec: ephemeral until
    /// saved; enabled once there's an exchange). The chip flashes the confirmation.
    private var saveChip: some View {
        Button {
            guard let archive, archive.save() else { return }
            savedFlash = true
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                savedFlash = false
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: savedFlash ? "checkmark" : "square.and.arrow.down")
                    .font(.system(size: 11, weight: .semibold))
                Text(savedFlash ? "Saved" : "Save")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(savedFlash ? Palette.ink0 : Palette.textPrimary)
            .padding(.horizontal, 11)
            .frame(height: 32)
            .background(
                Capsule().fill(
                    savedFlash ? Palette.aqua.opacity(0.92) : Palette.textPrimary.opacity(0.08)
                )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(savedFlash)
        .accessibilityLabel(savedFlash ? "Conversation saved" : "Save conversation")
    }

    /// The Conversations face (V35): saved threads as a morphed list state of the
    /// same plane; tap reopens read-only, trash deletes.
    private var conversationsList: some View {
        ScrollView(showsIndicators: false) {
            ConversationsListView(
                threads: archive?.threads() ?? [],
                onOpen: { panelState = .thread($0.id) },
                onDelete: { thread in
                    archive?.deleteThread(thread)
                    // Deleting the open thread would strand the read-only face; the
                    // list face is where deletes happen, so just stay here.
                }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    /// One saved thread, read-only (spec: review, not edit) — the transcript without
    /// an input row; a vanished id (deleted meanwhile) falls back to the list.
    @ViewBuilder
    private func savedThread(id: UUID) -> some View {
        if let thread = archive?.threads().first(where: { $0.id == id }) {
            ScrollView(showsIndicators: false) {
                DiscussTranscriptView(
                    messages: thread.lines
                        .sorted { $0.index < $1.index }
                        .map { ChatMessageDTO(role: $0.role, text: $0.text) }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        } else {
            conversationsList
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
                    onRetry: { Task { await chat.retry() } },
                    speakingIndex: speaker?.speakingIndex,
                    fetchingIndex: speaker?.fetchingIndex,
                    failedIndex: speaker?.failedIndex,
                    onSpeak: speaker == nil ? nil : { index, text in
                        Task { await speaker?.speak(text, at: index) }
                    }
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
                    TalkButton(
                        isRecording: voice.phase == .recording,
                        reduceTransparency: reduceTransparency,
                        onTap: { Task { await voice.toggle() } }
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
/// Tap-to-toggle voice question: tap to start recording (the listening indicator counts up),
/// tap again to stop and transcribe. A plain `Button` — the old hold gesture (a sequenced
/// `LongPressGesture`) was finicky on device: a tap was too short to ever start, and rapid
/// taps churned the recorder. The mic glows aqua while recording.
private struct TalkButton: View {
    let isRecording: Bool
    var reduceTransparency: Bool = false
    var onTap: () -> Void = {}

    private var tint: Color { isRecording ? Palette.aqua : Palette.sky }

    var body: some View {
        Button(action: onTap) {
            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? "Stop and transcribe" : "Voice question")
        .accessibilityHint("Tap to talk")
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
    /// Spoken-reply state per transcript index (V35); `onSpeak == nil` hides the
    /// speaker controls (read-only saved threads, previews).
    var speakingIndex: Int? = nil
    var fetchingIndex: Int? = nil
    var failedIndex: Int? = nil
    var onSpeak: ((Int, String) -> Void)? = nil

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
            ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                bubble(message, at: index)
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

    private func bubble(_ message: ChatMessageDTO, at index: Int) -> some View {
        let isUser = message.role == "user"
        return VStack(alignment: .leading, spacing: 8) {
            Text(message.text)
                .font(isUser ? .system(size: bodySize) : .system(size: bodySize, design: .serif))
                .foregroundStyle(Palette.textPrimary)
            if !isUser, onSpeak != nil {
                speakerControl(for: message, at: index)
            }
        }
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

    /// Read-the-reply-aloud (V35): same narrator voice via /speak. Honest states —
    /// fetching shows the wait, speaking toggles to stop (aqua = live), a failed
    /// fetch flags briefly and the text answer stays.
    @ViewBuilder
    private func speakerControl(for message: ChatMessageDTO, at index: Int) -> some View {
        let speaking = speakingIndex == index
        let fetching = fetchingIndex == index
        let failed = failedIndex == index
        Button {
            onSpeak?(index, message.text)
        } label: {
            HStack(spacing: 5) {
                if fetching {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: failed
                        ? "speaker.slash"
                        : speaking ? "stop.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 10, weight: .semibold))
                }
                if failed {
                    Text("Couldn't speak")
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .foregroundStyle(speaking ? Palette.ink0 : Palette.textPrimary.opacity(0.7))
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(
                Capsule().fill(
                    speaking ? Palette.aqua.opacity(0.92) : Palette.textPrimary.opacity(0.08)
                )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(fetching)
        .accessibilityLabel(
            failed ? "Couldn't speak the reply"
                : speaking ? "Stop speaking" : "Speak the reply aloud"
        )
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
