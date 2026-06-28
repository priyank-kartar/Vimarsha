import AVFoundation
import SwiftUI

/// The app-lifetime router for the single-live-surface model (spec 2026-06-28). Owns which ONE
/// surface is live (`activeSurface`), the book-lifetime `session`, and the frozen `backdrop`
/// shown behind an incoming plane. Closing is a derived transition (`Surface.returnTarget`);
/// the `session` is released only when the surface returns to the library.
@Observable
@MainActor
final class SurfaceCoordinator {
    private(set) var activeSurface: Surface = .library
    private(set) var session: BookSession?
    /// The outgoing surface, frozen to a static image and shown beneath the incoming one so
    /// nothing live observes behind a plane (set/cleared by `SurfaceHost`, chunk 2).
    var backdrop: Image?

    // MARK: Reading-level surfaces (need a live session)

    /// Open a ready chapter into the reading surface, building the book session. Returns
    /// `false` (and stays put) when the chapter won't load. The ephemeral memo/speech engines
    /// default to real `AVFoundationAudioEngine`s; tests inject the audio-seam double.
    @discardableResult
    func openReading(
        book: Book,
        chapter: Chapter,
        store: LibraryStore,
        audioEngine: any AudioEngine,
        recorder: (any RecorderEngine)?,
        memoEngine: any AudioEngine = AVFoundationAudioEngine(),
        speechEngine: any AudioEngine = AVFoundationAudioEngine()
    ) -> Bool {
        guard let session = BookSession.open(
            store: store, audioEngine: audioEngine, recorder: recorder,
            book: book, chapter: chapter, memoEngine: memoEngine, speechEngine: speechEngine
        ) else { return false }
        self.session = session
        activeSurface = .reading
        return true
    }

    func openDiscuss() { guard session != nil else { return }; activeSurface = .discuss }
    func openFigures() { guard session != nil else { return }; activeSurface = .figures }
    func openNotes() { guard session != nil else { return }; activeSurface = .notes }

    // MARK: Library-level planes (open from a focused book; no session)

    func openChapterList(_ book: Book) { activeSurface = .chapterList(book) }
    func openBookMemos(_ book: Book) { activeSurface = .bookMemos(book) }
    func openBookConversations(_ book: Book) { activeSurface = .bookConversations(book) }
    func openVoicePicker(_ book: Book) { activeSurface = .voicePicker(book) }

    // MARK: Close

    /// Recede to the current surface's return target. Landing back on the library ends the
    /// book session (pause player, stop ephemeral playback, release).
    func close() {
        let target = activeSurface.returnTarget
        if target == .library {
            session?.close()
            session = nil
        }
        activeSurface = target
    }
}
