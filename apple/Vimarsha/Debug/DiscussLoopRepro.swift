#if DEBUG
import SwiftUI
import SwiftData

/// Deterministic reproduction harness for the Discuss-panel 100% CPU hang
/// (docs/superpowers/2026-06-28-discuss-hang-handoff.md). Launch the app with
/// `-VimarshaDiscussLoopRepro 1` and the root becomes this harness instead of the library,
/// so the hang can be reproduced and measured WITHOUT a narrated chapter or a backend.
///
/// Two modes (set `-VimarshaReproMode <mode>`):
///  - `panel` (default): the REAL `.sheet` + `DiscussPanelView` over a plain canvas. Isolates
///    the panel + keyboard. (Result: does NOT loop — the panel alone is fine.)
///  - `surface`: the REAL `ReadingSurfaceView` with a real loaded `PlayerController`
///    underneath, wrapped in the production app-root modifiers, auto-opening Discuss. This is
///    the faithful reproduction of the on-device hang.
enum DiscussLoopRepro {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-VimarshaDiscussLoopRepro")
    }

    static var mode: String {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-VimarshaReproMode"), i + 1 < args.count else { return "panel" }
        return args[i + 1]
    }

    /// Set by the `surface` harness so the real `ReadingSurfaceView` auto-opens Discuss
    /// (its `showDiscuss` is private @State; this is a DEBUG-only seam, not a shipped API).
    static var autoOpenInReadingSurface = false
}

/// A no-op backend so the real `ChatStore` constructs without a server.
private struct ReproBackendClient: BackendClient {
    func fetchToc(epubAt url: URL) async throws -> TocResponse { throw Err.unused }
    func importChapter(epubAt url: URL, chapterIndex: Int, engine: String?, voice: String?) async throws -> ChapterBundleDTO { throw Err.unused }
    func downloadAudio(named name: String) async throws -> Data { throw Err.unused }
    func downloadImage(named name: String) async throws -> Data { throw Err.unused }
    func transcribe(audioAt url: URL) async throws -> String { throw Err.unused }
    func chat(messages: [ChatMessageDTO], context: ChatContextDTO) async throws -> String { "ok" }
    func speak(text: String, engine: String?, voice: String?) async throws -> Data { throw Err.unused }
    enum Err: Error { case unused }
}

/// The audio seam's harness double (mirrors the test target's `FakeAudioEngine`): `load`
/// returns a stub duration without touching a file, so a `PlayerController` can load a
/// fabricated chapter with no real MP3 on disk.
private final class ReproAudioEngine: AudioEngine {
    var durationMs = 0
    var isPlaying = false
    var onFinish: (() -> Void)?
    /// Wall-clock-driven playhead so `PlayerController`'s 250ms ticker sees the position
    /// advance — faithfully reproducing narration playing UNDER the Discuss sheet.
    private var startedAt: Date?
    private var basePositionMs = 0
    var positionMs: Int {
        guard isPlaying, let startedAt else { return basePositionMs }
        return min(basePositionMs + Int(Date().timeIntervalSince(startedAt) * 1000), durationMs)
    }
    @discardableResult
    func load(url: URL) throws -> Int { durationMs = 600_000; basePositionMs = 0; return durationMs }
    func play() { startedAt = Date(); isPlaying = true }
    func pause() { basePositionMs = positionMs; isPlaying = false; startedAt = nil }
    func seek(toMs ms: Int) { basePositionMs = ms; startedAt = isPlaying ? Date() : nil }
    func setRate(_ rate: Double) {}
}

/// The mic seam's harness double — no real recording.
private final class ReproRecorderEngine: RecorderEngine {
    func requestPermission() async -> Bool { true }
    func start(to url: URL) throws {}
    @discardableResult func stop() -> Int { 0 }
    var isRecording = false
    var level: CGFloat = 0
}

/// A loaded `PlayerController` over a fabricated ready chapter (no backend / real MP3).
@MainActor
private func reproLoadedPlayer() -> PlayerController? {
    guard let container = try? ModelContainer(
        for: Book.self, Chapter.self, Memo.self, ChatThread.self, ChatLine.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    ) else { return nil }
    let context = ModelContext(container)
    let root = FileManager.default.temporaryDirectory.appending(path: "DiscussRepro-\(UUID())")
    let book = Book(title: "Repro", author: "A", epubPath: "x/book.epub")
    let chapter = Chapter(index: 0, title: "One")
    chapter.status = .ready
    chapter.audioPath = "chapters/0/chapter.mp3"
    chapter.bundlePath = "chapters/0/bundle.json"
    let bundle = ChapterBundleDTO(
        chapterId: "c0", title: "One",
        blocks: (0..<40).map { i in
            BlockDTO(id: "b\(i)", index: i, kind: "paragraph",
                     text: "Paragraph \(i): the quick brown fox jumps over the lazy dog, again.")
        },
        figureMap: [], audio: "chapter.mp3",
        paraTimings: Dictionary(uniqueKeysWithValues: (0..<40).map { ("b\($0)", [$0 * 1000, $0 * 1000 + 900]) })
    )
    let bundleURL = root.appending(path: chapter.bundlePath!)
    try? FileManager.default.createDirectory(at: bundleURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let data = try? JSONEncoder().encode(bundle) else { return nil }
    try? data.write(to: bundleURL)
    book.chapters = [chapter]
    context.insert(book)
    try? context.save()
    let player = PlayerController(engine: ReproAudioEngine(), context: context, containerRoot: root)
    guard (try? player.load(chapter)) != nil else { return nil }
    player.play()
    return player
}

// MARK: - Root harness view

struct DiscussLoopReproView: View {
    var body: some View {
        switch DiscussLoopRepro.mode {
        case "surface": ReadingSurfaceReproView()
        case "panelWired": PanelWiredReproView()
        default: PanelReproView()
        }
    }
}

// MARK: - panelWired mode (DISAMBIGUATOR: full wiring over a PLAIN canvas)
//
// Same sheet+canvas as `panel`, but DiscussPanelView gets the REAL voice/speaker/archive the
// production app passes (the only difference from the stable `panel` case). If THIS loops on
// device, the wiring/component is the cause; if it stays stable, the live library behind the
// real sheet is the cause.

private struct PanelWiredReproView: View {
    @State private var show = false
    @State private var wired: Wired?

    private struct Wired {
        let chat: ChatStore
        let voice: VoiceInput
        let speaker: ReplySpeaker
        let archive: DiscussArchive
    }

    var body: some View {
        ZStack { Palette.canvas.ignoresSafeArea() }
            .task { if wired == nil { wired = build(); show = wired != nil } }
            .sheet(isPresented: $show) {
                if let wired {
                    DiscussPanelView(
                        chat: wired.chat, voice: wired.voice, speaker: wired.speaker,
                        archive: wired.archive, reduceTransparency: false, onClose: { show = false }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Palette.canvas)
                }
            }
    }

    @MainActor private func build() -> Wired? {
        guard let player = reproLoadedPlayer() else { return nil }
        let backend = ReproBackendClient()
        let chat = ChatStore(
            backend: backend,
            contextSnapshot: { ChatContextDTO(passage: "p", bookTitle: "Repro", chapterTitle: "One") }
        )
        let voice = VoiceInput(recorder: ReproRecorderEngine(), backend: backend, player: player)
        let speaker = ReplySpeaker(backend: backend, speechEngine: ReproAudioEngine(), player: player)
        let archive = DiscussArchive(threads: { [] }, save: { false }, deleteThread: { _ in })
        return Wired(chat: chat, voice: voice, speaker: speaker, archive: archive)
    }
}

// MARK: - panel mode (isolate the panel + keyboard)

private struct PanelReproView: View {
    @State private var showDiscuss = false
    @State private var chat = ChatStore(
        backend: ReproBackendClient(),
        contextSnapshot: { ChatContextDTO(passage: "A sample passage.", bookTitle: "Repro", chapterTitle: "One") }
    )
    var body: some View {
        ZStack { Palette.canvas.ignoresSafeArea() }
            .onAppear { showDiscuss = true }
            .sheet(isPresented: $showDiscuss) {
                DiscussPanelView(chat: chat, voice: nil, speaker: nil, archive: nil,
                                 reduceTransparency: false, onClose: { showDiscuss = false })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Palette.canvas)
            }
    }
}

// MARK: - surface mode (faithful: real reading surface underneath the Discuss sheet)

private struct ReadingSurfaceReproView: View {
    @State private var loaded: Loaded?

    /// Built once: an in-memory store, a fabricated `ready` chapter with a bundle on disk,
    /// a loaded `PlayerController`, and a real `ChatStore`.
    private struct Loaded {
        let player: PlayerController
        let chat: ChatStore
        let book: ShelfBook
    }

    /// `-VimarshaReproRoot paging` wraps the surface in VimarshaApp's horizontal paging
    /// ScrollView (the prime suspect ancestor); anything else mounts it bare.
    private var wrapInPagingRoot: Bool {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-VimarshaReproRoot"), i + 1 < a.count else { return false }
        return a[i + 1] == "paging"
    }

    @ViewBuilder private var surface: some View {
        if let loaded {
            ReadingSurfaceView(
                book: loaded.book, chapterIndex: 0, chapterTitle: "The Shape of Accidents",
                player: loaded.player, chatStore: loaded.chat, reduceTransparency: false, onClose: {}
            )
        } else {
            Palette.canvas.ignoresSafeArea()
        }
    }

    var body: some View {
        Group {
            if wrapInPagingRoot {
                // EXACT VimarshaApp root: a horizontal paging ScrollView of full-bleed pages,
                // the reading surface overlaid on the first page (mirrors `.overlay { readingSurface }`).
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        Palette.canvas.containerRelativeFrame([.horizontal, .vertical])
                            .overlay { surface }
                        Palette.canvas.containerRelativeFrame([.horizontal, .vertical])
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                .scrollDisabled(true)
            } else {
                surface
            }
        }
        // The production app-root modifiers (VimarshaApp.body).
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .environment(\.topSafeInset, 59)
        .environment(\.bottomSafeInset, 34)
        .task { if loaded == nil { loaded = build() } }
        .onAppear { DiscussLoopRepro.autoOpenInReadingSurface = true }
    }

    @MainActor
    private func build() -> Loaded? {
        guard let container = try? ModelContainer(
            for: Book.self, Chapter.self, Memo.self, ChatThread.self, ChatLine.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        ) else { return nil }
        let context = ModelContext(container)
        let root = FileManager.default.temporaryDirectory.appending(path: "DiscussRepro-\(UUID())")
        let book = Book(title: "Repro", author: "A", epubPath: "x/book.epub")
        let chapter = Chapter(index: 0, title: "One")
        chapter.status = .ready
        chapter.audioPath = "chapters/0/chapter.mp3"
        chapter.bundlePath = "chapters/0/bundle.json"
        let bundle = ChapterBundleDTO(
            chapterId: "c0", title: "One",
            blocks: (0..<40).map { i in
                BlockDTO(id: "b\(i)", index: i, kind: "paragraph",
                         text: "Paragraph \(i): the quick brown fox jumps over the lazy dog, again and again.")
            },
            figureMap: [],
            audio: "chapter.mp3",
            paraTimings: Dictionary(uniqueKeysWithValues: (0..<40).map { ("b\($0)", [$0 * 1000, $0 * 1000 + 900]) })
        )
        let bundleURL = root.appending(path: chapter.bundlePath!)
        try? FileManager.default.createDirectory(at: bundleURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(bundle) else { return nil }
        try? data.write(to: bundleURL)
        book.chapters = [chapter]
        context.insert(book)
        try? context.save()
        let player = PlayerController(engine: ReproAudioEngine(), context: context, containerRoot: root)
        guard (try? player.load(chapter)) != nil else { return nil }
        player.play()   // narration plays underneath, exactly like production (Discuss never pauses)
        let chat = ChatStore(
            backend: ReproBackendClient(),
            contextSnapshot: { ChatContextDTO(passage: "p", bookTitle: "Repro", chapterTitle: "One") }
        )
        return Loaded(player: player, chat: chat, book: ShelfBook.seeds[0])
    }
}
#endif
