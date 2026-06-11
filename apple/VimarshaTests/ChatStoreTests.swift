import Foundation
import Testing
@testable import Vimarsha

/// V32 — the live conversation's semantics (the frozen Flutter `ChatController`
/// ported): send appends user + grounded assistant turns, the context is snapshotted
/// at EACH send, failures keep the conversation intact behind `error` + `retry()`,
/// and the send-guard ignores empty input and double-sends.
@MainActor
struct ChatStoreTests {
    private static let context = ChatContextDTO(
        passage: "P", bookTitle: "B", chapterTitle: "C"
    )

    @Test func sendAppendsUserAndAssistantTurns() async {
        var fake = FakeBackendClient.returning()
        fake.onChat = { messages, _ in "Reply to: \(messages.last!.text)" }
        let store = ChatStore(backend: fake) { Self.context }

        await store.send("  What is this?  ")

        #expect(store.messages == [
            .user("What is this?"), .assistant("Reply to: What is this?"),
        ])
        #expect(!store.sending)
        #expect(!store.error)
        #expect(store.hasExchange)
    }

    @Test func emptyInputIsIgnored() async {
        let store = ChatStore(backend: FakeBackendClient.returning()) { Self.context }
        await store.send("   \n ")
        #expect(store.messages.isEmpty)
        #expect(!store.hasExchange)
    }

    @Test func contextIsSnapshottedPerSend() async {
        final class Playhead { var passage = "first" }
        let playhead = Playhead()
        var fake = FakeBackendClient.returning()
        fake.onChat = { _, context in "Grounded on \(context.passage)" }
        let store = ChatStore(backend: fake) {
            ChatContextDTO(passage: playhead.passage, bookTitle: "B", chapterTitle: "C")
        }

        await store.send("Q1")
        playhead.passage = "second"
        await store.send("Q2")

        #expect(store.messages[1] == .assistant("Grounded on first"))
        #expect(store.messages[3] == .assistant("Grounded on second"))
    }

    @Test func failureKeepsUserTurnAndSetsError() async {
        var fake = FakeBackendClient.returning()
        fake.onChat = { _, _ in throw URLError(.cannotConnectToHost) }
        let store = ChatStore(backend: fake) { Self.context }

        await store.send("Q")

        #expect(store.messages == [.user("Q")])
        #expect(store.error)
        #expect(!store.sending)
        #expect(!store.hasExchange)
    }

    @Test func retryResendsTheUnansweredTurn() async {
        final class Flag { var failing = true }
        let flag = Flag()
        var fake = FakeBackendClient.returning()
        fake.onChat = { @MainActor messages, _ in
            if flag.failing { throw URLError(.cannotConnectToHost) }
            return "Answered: \(messages.last!.text)"
        }
        let store = ChatStore(backend: fake) { Self.context }

        await store.send("Q")
        #expect(store.error)
        flag.failing = false
        await store.retry()

        #expect(store.messages == [.user("Q"), .assistant("Answered: Q")])
        #expect(!store.error)
    }

    @Test func retryWithoutErrorIsIgnored() async {
        var fake = FakeBackendClient.returning()
        fake.onChat = { _, _ in "R" }
        let store = ChatStore(backend: fake) { Self.context }
        await store.retry()
        #expect(store.messages.isEmpty)
    }

    @Test func secondSendWhileInFlightIsIgnored() async {
        let (gateStream, gate) = AsyncStream<Void>.makeStream()
        var fake = FakeBackendClient.returning()
        fake.onChat = { _, _ in
            for await _ in gateStream { break }
            return "Reply"
        }
        let store = ChatStore(backend: fake) { Self.context }

        let inFlight = Task { await store.send("One") }
        while !store.sending { await Task.yield() }
        await store.send("Two")
        #expect(store.messages == [.user("One")])

        gate.yield()
        await inFlight.value
        #expect(store.messages == [.user("One"), .assistant("Reply")])
    }
}
