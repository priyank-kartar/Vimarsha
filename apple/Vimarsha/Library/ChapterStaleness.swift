import Foundation

/// Whether a cached chapter's audio no longer matches the book's selected voice. Pure so it's
/// unit-testable and usable from both the chapter list (hint + hold-to-re-render) and the
/// open/play path (lazy re-render).
nonisolated enum ChapterStaleness {
    static func isStale(status: ChapterStatus, narratedVoiceId: String?, bookVoiceId: String) -> Bool {
        guard status == .ready, let narrated = narratedVoiceId else { return false }
        return narrated != bookVoiceId
    }
}

extension Chapter {
    /// Convenience over the pure predicate using the owning book's selected voice.
    var isStaleForBookVoice: Bool {
        guard let book else { return false }
        return ChapterStaleness.isStale(
            status: status, narratedVoiceId: narratedVoiceId, bookVoiceId: book.voiceId
        )
    }
}

/// What tapping a chapter row should do, given its status and staleness — keeps the decision
/// pure and testable, off the view.
nonisolated enum ChapterOpenRouting {
    enum Action: Equatable { case open, rerender, download }

    static func action(status: ChapterStatus, isStale: Bool) -> Action {
        switch status {
        case .ready: return isStale ? .rerender : .open
        case .none, .error: return .download
        case .pending: return .open   // unreachable (pending rows aren't buttons); harmless default
        }
    }
}
