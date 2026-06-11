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
    private(set) var anchorBlockId: String?

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

    /// Pin where Discuss was first opened (V33; the panel calls this on open). The
    /// first open wins — reopening the panel mid-conversation doesn't move the anchor.
    func recordAnchor(_ blockId: String?) {
        guard anchorBlockId == nil else { return }
        anchorBlockId = blockId
    }

    /// The saved thread's default title (V35): the opening question, trimmed to a
    /// list-row length.
    var suggestedTitle: String? {
        guard let first = messages.first(where: { $0.role == "user" })?.text else { return nil }
        return first.count <= 60 ? first : String(first.prefix(59)) + "…"
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
