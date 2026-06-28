import Combine
import SwiftUI

/// The in-canvas Discuss plane (single-live-surface, spec 2026-06-28; apple/CLAUDE.md §UI map
/// state 6). Replaces the old `.sheet`: a FROZEN snapshot of the reading surface sits behind
/// (zero observation — the fix for the device hang), the real `DiscussPanelView` floats over it.
///
/// Keyboard avoidance is LOCAL to this plane: the app root ignores the keyboard, so the only
/// live view the keyboard can move is this one — there is no cross-surface layout to feed the
/// AttributeGraph loop that the old sheet-over-live-reading composition did.
struct DiscussPlaneView: View {
    /// Frozen still of the reading surface beneath; `nil` → flat canvas (macOS / capture miss).
    let backdrop: Image?
    let chat: ChatStore
    var voice: VoiceInput?
    var speaker: ReplySpeaker?
    var archive: DiscussArchive?
    var reduceTransparency: Bool = false
    var onClose: () -> Void = {}

    @Environment(\.topSafeInset) private var topSafeInset
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        ZStack {
            backdropLayer
            DiscussPanelView(
                chat: chat, voice: voice, speaker: speaker, archive: archive,
                reduceTransparency: reduceTransparency, onClose: onClose
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, topSafeInset)
            // The plane shrinks from the bottom to sit above the keyboard (the root ignores it).
            .padding(.bottom, keyboardHeight)
        }
        .onReceive(keyboardHeightPublisher) { keyboardHeight = $0 }
        .onDisappear {
            // Any dismissal ends the conversation's live audio cleanly (the sheet's old onDisappear).
            voice?.cancelHold()
            speaker?.stop()
        }
    }

    /// The static context behind the panel: the frozen reading surface, dimmed so the panel
    /// reads as the foreground; flat canvas when there is no snapshot.
    @ViewBuilder
    private var backdropLayer: some View {
        Group {
            if let backdrop {
                backdrop.resizable().scaledToFill()
            } else {
                Palette.canvas
            }
        }
        .overlay(Palette.ink0.opacity(0.35))
        .ignoresSafeArea()
    }

    /// Keyboard height (iOS) so the plane can lift its input row above the keyboard. macOS has
    /// no software keyboard avoidance to do, so this stays 0.
    private var keyboardHeightPublisher: AnyPublisher<CGFloat, Never> {
        #if os(iOS)
        let willShow = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height }
        let willHide = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }
        return willShow.merge(with: willHide).eraseToAnyPublisher()
        #else
        return Empty().eraseToAnyPublisher()
        #endif
    }
}
