import Testing
import Foundation
@testable import Vimarsha

@Suite("Bundled voice previews")
struct VoicePreviewResourceTests {
    @Test func everyVoiceHasABundledPreviewClip() {
        for voice in VoiceCatalog.all {
            let url = Bundle.main.url(
                forResource: voice.previewResource, withExtension: "mp3", subdirectory: "VoicePreviews"
            ) ?? Bundle.main.url(forResource: voice.previewResource, withExtension: "mp3")
            #expect(url != nil, "missing preview clip for \(voice.id) (\(voice.previewResource).mp3)")
        }
    }
}
