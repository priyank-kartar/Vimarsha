import SwiftUI

@main
struct VimarshaApp: App {
    var body: some Scene {
        WindowGroup {
            LibraryStackView()
        }
        #if os(macOS)
        .defaultSize(width: 480, height: 920)
        #endif
    }
}
