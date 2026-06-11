import SwiftData
import SwiftUI

@main
struct VimarshaApp: App {
    /// The persisted library (V12). A store-opening failure (corrupt/locked database)
    /// degrades to the seed shelf with no import affordance rather than crashing —
    /// honest states on the one surface.
    @State private var store: LibraryStore?

    init() {
        if let container = try? ModelContainer(for: Book.self, Chapter.self) {
            _store = State(initialValue: LibraryStore(context: container.mainContext))
        }
    }

    var body: some Scene {
        WindowGroup {
            LibraryStackView(store: store)
        }
        #if os(macOS)
        .defaultSize(width: 480, height: 920)
        #endif
    }
}
