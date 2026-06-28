import SwiftUI
#if os(iOS)
import UIKit
#endif

/// A frozen still of the on-screen surface, used as the backdrop behind an in-canvas plane so
/// nothing LIVE renders/observes behind it (single-live-surface; spec 2026-06-28). Captured
/// from the rendered window layer — unlike `ImageRenderer`, this faithfully includes
/// `ScrollView` content (the V14 gotcha). `nil` on macOS / when unavailable → the host falls
/// back to the flat canvas.
enum SurfaceSnapshot {
    @MainActor
    static func captureKeyWindow() -> Image? {
        #if os(iOS)
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
            window.bounds.width > 0, window.bounds.height > 0
        else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let uiImage = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        return Image(uiImage: uiImage)
        #else
        return nil
        #endif
    }
}
