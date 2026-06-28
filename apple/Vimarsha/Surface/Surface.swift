import Foundation

/// The single source of truth for which ONE surface is live (apple/CLAUDE.md Prime Directive;
/// spec `docs/superpowers/specs/2026-06-28-vimarsha-single-live-surface-design.md`).
///
/// Exactly one surface is mounted/observing at a time — the fix for the device-only Discuss
/// 100% CPU hang, which was an emergent loop of simultaneously-alive observing surfaces.
/// Library-level planes carry the `Book` they were opened for.
enum Surface: Equatable {
    case library
    case chapterList(Book)
    case bookMemos(Book)
    case bookConversations(Book)
    case voicePicker(Book)
    case reading
    case figures
    case notes
    case discuss

    /// Where "close" lands: reading-level planes recede to the reading surface; everything
    /// opened from the library (and reading itself) recedes to the library tower. Makes
    /// closing a derived transition instead of a tangle of nil-assignments.
    var returnTarget: Surface {
        switch self {
        case .discuss, .figures, .notes:
            return .reading
        case .library, .reading, .chapterList, .bookMemos, .bookConversations, .voicePicker:
            return .library
        }
    }
}
