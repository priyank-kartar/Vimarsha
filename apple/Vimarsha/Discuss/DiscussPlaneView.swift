import SwiftUI

/// The in-canvas Discuss plane (single-live-surface, spec 2026-06-28; apple/CLAUDE.md §UI map
/// state 6). Replaces the old `.sheet`: a FROZEN snapshot of the reading surface sits behind
/// (zero observation — the fix for the device hang), the real `DiscussPanelView` floats over it.
///
/// Rendered at the app root as a sibling of the keyboard-ignoring library, so SwiftUI's NATIVE
/// keyboard avoidance lifts the panel (manual keyboard padding fed an iOS notification feedback
/// loop). It is the only live surface, so the keyboard can move nothing else.
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

    var body: some View {
        ZStack {
            backdropLayer
            DiscussPanelView(
                chat: chat, voice: voice, speaker: speaker, archive: archive,
                reduceTransparency: reduceTransparency, onClose: onClose
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, topSafeInset)
        }
        .onDisappear {
            // Any dismissal ends the conversation's live audio cleanly (the old sheet onDisappear).
            voice?.cancelHold()
            speaker?.stop()
        }
    }

    /// The static context behind the panel: the frozen reading surface, dimmed so the panel
    /// reads as the foreground; flat canvas when there is no snapshot. Ignores all safe areas
    /// (incl. the keyboard) so only the panel itself is lifted.
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
}
