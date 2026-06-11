import SwiftData
import SwiftUI

@main
struct VimarshaApp: App {
    /// The persisted library (V12). A store-opening failure (corrupt/locked database)
    /// degrades to the seed shelf with no import affordance rather than crashing —
    /// honest states on the one surface.
    @State private var store: LibraryStore?
    /// The ONE app-lifetime audio device owner (V16; apple/CLAUDE.md §Seams).
    /// Player controllers borrow it and pause it — nothing else may create one.
    @State private var audioEngine = AVFoundationAudioEngine()

    init() {
        if let container = try? ModelContainer(for: Book.self, Chapter.self) {
            _store = State(initialValue: LibraryStore(context: container.mainContext))
        }
    }

    var body: some Scene {
        WindowGroup {
            LibraryStackView(store: store, audioEngine: audioEngine)
        }
        #if os(macOS)
        .defaultSize(width: 480, height: 920)
        #endif
    }
}
