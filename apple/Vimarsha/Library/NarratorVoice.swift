import Foundation

/// One selectable narrator voice. Display name (`id`) is the global name the reader sees;
/// `kokoroVoice` is the backend voice token sent as `?voice=`; `engine` is hidden from the UI
/// (all Kokoro for v1). `previewResource` is the bundled preview clip's base name.
nonisolated struct NarratorVoice: Identifiable, Equatable, Sendable {
    let id: String          // e.g. "Aria"
    let kokoroVoice: String // e.g. "af_heart"
    let engine: String      // "kokoro"

    /// `Resources/VoicePreviews/<kokoroVoice>.mp3` — keyed on the stable backend token so a
    /// rename of the display name never orphans a clip.
    var previewResource: String { kokoroVoice }
}

/// The curated, client-owned catalog (the single source of truth for names + default).
nonisolated enum VoiceCatalog {
    static let all: [NarratorVoice] = [
        NarratorVoice(id: "Aria",   kokoroVoice: "af_heart",   engine: "kokoro"),
        NarratorVoice(id: "Stella", kokoroVoice: "af_bella",   engine: "kokoro"),
        NarratorVoice(id: "Milo",   kokoroVoice: "am_michael", engine: "kokoro"),
        NarratorVoice(id: "Imogen", kokoroVoice: "bf_emma",    engine: "kokoro"),
        NarratorVoice(id: "Edmund", kokoroVoice: "bm_george",  engine: "kokoro"),
    ]
    static let defaultId = "Aria"
    static func voice(id: String) -> NarratorVoice {
        all.first { $0.id == id } ?? all.first { $0.id == defaultId } ?? all[0]
    }
}
