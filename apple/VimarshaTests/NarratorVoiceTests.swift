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
        #expect(VoiceCatalog.all.filter { !$0.isPremium }.allSatisfy { $0.engine == "kokoro" })
    }

    @Test func voiceLookupFallsBackToDefault() {
        #expect(VoiceCatalog.voice(id: "Imogen").voiceToken == "bf_emma")
        #expect(VoiceCatalog.voice(id: "nonexistent").id == VoiceCatalog.defaultId)
    }

    @Test func premiumVoicesAreChatterboxAndFlagged() {
        let premium = VoiceCatalog.all.filter(\.isPremium)
        #expect(premium.count == 3)
        #expect(premium.allSatisfy { $0.engine == "chatterbox" })
        #expect(Set(premium.map(\.voiceToken)) == ["cb_storyteller", "cb_steady", "cb_intimate"])
        // free voices stay kokoro + not premium
        #expect(VoiceCatalog.all.filter { !$0.isPremium }.allSatisfy { $0.engine == "kokoro" })
    }
}
