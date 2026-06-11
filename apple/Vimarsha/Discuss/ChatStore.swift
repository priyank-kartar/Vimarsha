import Foundation

/// One live, in-memory conversation (V32; the frozen Flutter `ChatController`'s
/// semantics ported): snapshots the passage context at EACH send so grounding follows
/// playback — a follow-up asked a minute later is grounded on what's being read then.
/// Nothing is persisted here; saving a thread is the store's job, on explicit user
/// action (save-on-demand, conversation-ai.md).
@Observable
@MainActor
final class ChatStore {
    private let backend: any BackendClient
    private let contextSnapshot: () -> ChatContextDTO

    /// Where Discuss was opened — recorded on the saved thread for reference
    /// (spec §5); the per-send grounding rides `contextSnapshot`, not this.
    let anchorBlockId: String?

    private(set) var messages: [ChatMessageDTO] = []
    /// A request is in flight — the send affordance is held (the Flutter send-guard).
    private(set) var sending = false
    /// The last send failed; the unanswered user turn stays and `retry()` re-sends.
    private(set) var error = false

    init(
        backend: any BackendClient,
        anchorBlockId: String? = nil,
        contextSnapshot: @escaping () -> ChatContextDTO
    ) {
        self.backend = backend
        self.anchorBlockId = anchorBlockId
        self.contextSnapshot = contextSnapshot
    }

    /// Save is meaningful once there's at least one exchange (spec §6).
    var hasExchange: Bool {
        messages.contains { $0.role == "assistant" }
    }

    /// Append the user's turn and request a grounded reply. Empty input and
    /// double-sends are no-ops (`sending` is claimed synchronously).
    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !sending else { return }
        sending = true
        messages.append(.user(trimmed))
        await requestReply()
    }

    /// Re-send after a failure — the last turn is the unanswered user message.
    func retry() async {
        guard error, !sending else { return }
        sending = true
        await requestReply()
    }

    private func requestReply() async {
        error = false
        do {
            let reply = try await backend.chat(messages: messages, context: contextSnapshot())
            messages.append(.assistant(reply))
        } catch {
            self.error = true
        }
        sending = false
    }
}
