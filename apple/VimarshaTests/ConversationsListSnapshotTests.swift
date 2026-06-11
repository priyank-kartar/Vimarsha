#if os(macOS)
import Testing
import SwiftUI
@testable import Vimarsha

/// Renders the V35 Conversations rows (the saved-thread morphed list state) and the
/// transcript's speaker control so they can be seen, not just asserted. macOS-only
/// (`ImageRenderer` runs headless there); rows are matte paper.
@Suite("Conversations — row snapshots")
@MainActor
struct ConversationsListSnapshotTests {
    private func makeThreads() -> [ChatThread] {
        let first = ChatThread(
            chapterIndex: 0, anchorBlockId: "b3",
            title: "What does the passage claim about good design?",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        first.lines = [
            ChatLine(role: "user", text: "Q1", index: 0),
            ChatLine(role: "assistant", text: "A1", index: 1),
        ]
        let second = ChatThread(
            chapterIndex: 0, title: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_100_000)
        )
        second.lines = [ChatLine(role: "user", text: "Q", index: 0)]
        return [second, first]
    }

    private func render(_ threads: [ChatThread]) -> CGImage? {
        let view = ConversationsListView(threads: threads)
            .frame(width: 393)
            .padding(24)
            .background(Palette.canvas)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    @Test("saved threads render titled and untitled rows")
    func threadRows() throws {
        let image = try #require(render(makeThreads()))
        let png = try #require(
            NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("conversations-rows.png")
        try png.write(to: url)
        print("VIMARSHA_SNAPSHOT \(url.path)")
        #expect(image.width > 0)
    }

    @Test("the empty state renders its guidance line")
    func emptyState() throws {
        let image = try #require(render([]))
        #expect(image.width > 0)
    }

    @Test("the speaker control changes the assistant bubble raster")
    func speakerControlRenders() throws {
        let messages: [ChatMessageDTO] = [.user("Q"), .assistant("The grounded answer.")]
        let without = DiscussTranscriptView(messages: messages)
            .frame(width: 393).padding(24).background(Palette.canvas)
            .environment(\.colorScheme, .dark)
        let with = DiscussTranscriptView(messages: messages, onSpeak: { _, _ in })
            .frame(width: 393).padding(24).background(Palette.canvas)
            .environment(\.colorScheme, .dark)
        let withoutRenderer = ImageRenderer(content: without)
        let withRenderer = ImageRenderer(content: with)
        withoutRenderer.scale = 2
        withRenderer.scale = 2
        let plainImage = try #require(withoutRenderer.cgImage)
        let speakerImage = try #require(withRenderer.cgImage)
        let plain = try #require(
            NSBitmapImageRep(cgImage: plainImage).representation(using: .png, properties: [:])
        )
        let speaker = try #require(
            NSBitmapImageRep(cgImage: speakerImage).representation(using: .png, properties: [:])
        )
        #expect(plain != speaker)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("discuss-speaker-bubble.png")
        try speaker.write(to: url)
        print("VIMARSHA_SNAPSHOT \(url.path)")
    }
}
#endif
