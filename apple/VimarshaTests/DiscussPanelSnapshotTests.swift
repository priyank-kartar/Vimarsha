#if os(macOS)
import Testing
import SwiftUI
@testable import Vimarsha

/// Renders the V33 Discuss transcript so the panel's states can be seen, not just
/// asserted: user/assistant bubbles, the thinking row, the error row with Retry, and
/// the empty-state guidance. macOS-only (`ImageRenderer` runs headless there); bubbles
/// are matte paper so no glass caveat applies.
@Suite("Discuss panel — transcript snapshots")
@MainActor
struct DiscussPanelSnapshotTests {
    private let conversation: [ChatMessageDTO] = [
        .user("What does the passage claim about good design?"),
        .assistant("That good design is nearly invisible — it fits our needs so well it serves without drawing attention to itself."),
        .user("And poor design?"),
    ]

    private func render(
        _ messages: [ChatMessageDTO], sending: Bool = false, error: Bool = false
    ) -> CGImage? {
        let view = DiscussTranscriptView(messages: messages, sending: sending, error: error)
            .frame(width: 393)
            .padding(24)
            .background(Palette.canvas)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    private func pngData(_ image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    @Test("user and assistant turns render, and the error row changes the raster")
    func turnsAndErrorRow() throws {
        let plainImage = try #require(render(conversation))
        let failedImage = try #require(render(conversation, error: true))
        let plain = try #require(pngData(plainImage))
        let failed = try #require(pngData(failedImage))
        #expect(plain != failed)

        let base = FileManager.default.temporaryDirectory
        let plainURL = base.appendingPathComponent("discuss-transcript.png")
        let failedURL = base.appendingPathComponent("discuss-transcript-error.png")
        try plain.write(to: plainURL)
        try failed.write(to: failedURL)
        print("VIMARSHA_SNAPSHOT \(plainURL.path)")
        print("VIMARSHA_SNAPSHOT \(failedURL.path)")
    }

    @Test("the thinking row renders while sending")
    func thinkingRow() throws {
        let idleImage = try #require(render(conversation))
        let sendingImage = try #require(render(conversation, sending: true))
        let idle = try #require(pngData(idleImage))
        let sending = try #require(pngData(sendingImage))
        #expect(idle != sending)
    }

    @Test("the empty state renders its guidance line")
    func emptyState() throws {
        let image = try #require(render([]))
        #expect(image.width > 0)
    }
}
#endif
