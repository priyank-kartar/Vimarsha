import Foundation

/// One selectable narrator voice. Display name (`id`) is the global name the reader sees;
/// `voiceToken` is the backend voice value sent as `?voice=`; `engine` selects the tier/route
/// (`kokoro` = local/free, `chatterbox` = premium on RunPod). `isPremium` flags the premium tier.
nonisolated struct NarratorVoice: Identifiable, Equatable, Sendable {
    let id: String          // e.g. "Aria"
    let voiceToken: String  // backend ?voice= value, e.g. "af_heart" / "cb_storyteller"
    let engine: String      // "kokoro" | "chatterbox"
    var isPremium: Bool = false

    /// `Resources/VoicePreviews/<voiceToken>.mp3` — keyed on the stable backend token so a
    /// rename of the display name never orphans a clip. (Premium voices have no bundled clip
    /// in this slice — the picker hides their preview button.)
    var previewResource: String { voiceToken }
}

/// The curated, client-owned catalog (the single source of truth for names + default).
nonisolated enum VoiceCatalog {
    static let all: [NarratorVoice] = [
        NarratorVoice(id: "Aria",   voiceToken: "af_heart",   engine: "kokoro"),
        NarratorVoice(id: "Stella", voiceToken: "af_bella",   engine: "kokoro"),
        NarratorVoice(id: "Milo",   voiceToken: "am_michael", engine: "kokoro"),
        NarratorVoice(id: "Imogen", voiceToken: "bf_emma",    engine: "kokoro"),
        NarratorVoice(id: "Edmund", voiceToken: "bm_george",  engine: "kokoro"),
        NarratorVoice(id: "Storyteller", voiceToken: "cb_storyteller", engine: "chatterbox", isPremium: true),
        NarratorVoice(id: "Steady",      voiceToken: "cb_steady",      engine: "chatterbox", isPremium: true),
        NarratorVoice(id: "Intimate",    voiceToken: "cb_intimate",    engine: "chatterbox", isPremium: true),
    ]
    static let defaultId = "Aria"
    static func voice(id: String) -> NarratorVoice {
        all.first { $0.id == id } ?? all.first { $0.id == defaultId } ?? all[0]
    }
}
