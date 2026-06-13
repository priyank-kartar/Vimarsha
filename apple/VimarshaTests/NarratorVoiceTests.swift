import Testing
@testable import Vimarsha

@Suite("Narrator voice catalog")
struct NarratorVoiceTests {
    @Test func catalogHasDistinctVoicesAndADefault() {
        let ids = VoiceCatalog.all.map(\.id)
        #expect(ids.count >= 5)
        #expect(Set(ids).count == ids.count)
        #expect(ids.contains(VoiceCatalog.defaultId))
        #expect(VoiceCatalog.defaultId == "Aria")
        #expect(VoiceCatalog.all.allSatisfy { $0.engine == "kokoro" })
    }

    @Test func voiceLookupFallsBackToDefault() {
        #expect(VoiceCatalog.voice(id: "Imogen").kokoroVoice == "bf_emma")
        #expect(VoiceCatalog.voice(id: "nonexistent").id == VoiceCatalog.defaultId)
    }
}
