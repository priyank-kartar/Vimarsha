#if os(macOS)
import Testing
import SwiftUI
@testable import Vimarsha

/// Renders the V30 Notes rows so the morphed list state can be seen, not just asserted:
/// ready/pending/error transcripts with their actions, and the aqua playing accent.
/// macOS-only (`ImageRenderer` runs headless there); rows are matte paper so no glass
/// caveat applies.
@Suite("Memo notes — row snapshots")
@MainActor
struct MemoNotesSnapshotTests {
    private func makeMemos() -> [Memo] {
        let ready = Memo(paragraphIndex: 3, positionMs: 43_000, audioPath: "m1.m4a")
        ready.status = .ready
        ready.transcript = "This connects to the earlier argument about accident."
        let pending = Memo(paragraphIndex: 7, positionMs: 121_000, audioPath: "m2.m4a")
        let failed = Memo(paragraphIndex: 9, positionMs: 180_000, audioPath: "m3.m4a")
        failed.status = .error
        return [ready, pending, failed]
    }

    private func render(_ memos: [Memo], playing: UUID? = nil) -> CGImage? {
        let view = MemoListView(memos: memos, playingMemoId: playing, reduceTransparency: true)
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

    @Test("the three transcript states render, and the playing accent shows")
    func statesAndPlayingAccent() throws {
        let memos = makeMemos()
        let idleImage = try #require(render(memos))
        let playingImage = try #require(render(memos, playing: memos[0].id))
        let idle = try #require(pngData(idleImage))
        let playing = try #require(pngData(playingImage))
        #expect(idle != playing)

        let base = FileManager.default.temporaryDirectory
        let idleURL = base.appendingPathComponent("memo-notes-rows.png")
        let playingURL = base.appendingPathComponent("memo-notes-playing.png")
        try idle.write(to: idleURL)
        try playing.write(to: playingURL)
        print("VIMARSHA_SNAPSHOT \(idleURL.path)")
        print("VIMARSHA_SNAPSHOT \(playingURL.path)")
    }

    @Test("the empty state renders its guidance line")
    func emptyState() throws {
        let image = try #require(render([]))
        #expect(image.width > 0)
    }
}
#endif
