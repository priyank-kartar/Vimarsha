import SwiftUI

/// The device's top safe-area inset (status bar / notch height), measured from the key window
/// at the app root and injected into the environment.
///
/// The whole app draws full-bleed (the paging pages are `containerRelativeFrame` and every
/// surface bleeds its canvas with `ignoresSafeArea`), so SwiftUI propagates a ZERO safe-area
/// inset into the page content — top controls placed with `.overlay(alignment: .top…)` would
/// otherwise render under the status bar and be impossible to tap. Each surface adds this value
/// to its top controls' padding to clear the status bar. macOS has no such inset → 0.
private struct TopSafeInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

/// The device's bottom safe-area inset (home indicator). Same story as the top: the full-bleed
/// surfaces zero the propagated inset, so bottom controls (the reading transport, the Discuss
/// panel) add this to avoid sitting on / under the home indicator. macOS → 0.
private struct BottomSafeInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var topSafeInset: CGFloat {
        get { self[TopSafeInsetKey.self] }
        set { self[TopSafeInsetKey.self] = newValue }
    }

    var bottomSafeInset: CGFloat {
        get { self[BottomSafeInsetKey.self] }
        set { self[BottomSafeInsetKey.self] = newValue }
    }
}
