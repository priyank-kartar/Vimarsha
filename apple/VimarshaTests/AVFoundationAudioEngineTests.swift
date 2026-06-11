import Foundation
import Testing
@testable import Vimarsha

/// V16 — the REAL `AVAudioPlayer`-backed engine against a real generated WAV file
/// (house rule: the double exists for *consumers* of the seam; the impl itself tests real).
@MainActor
struct AVFoundationAudioEngineTests {
    /// A spec-minimal mono 16-bit PCM WAV of silence at 8kHz.
    private func makeWav(seconds: Double) throws -> URL {
        let sampleRate = 8000
        let sampleCount = Int(Double(sampleRate) * seconds)
        let dataSize = sampleCount * 2
        var bytes = Data()
        func append(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) } }
        bytes.append(contentsOf: "RIFF".utf8)
        append(UInt32(36 + dataSize))
        bytes.append(contentsOf: "WAVEfmt ".utf8)
        append(16)                       // fmt chunk size
        append16(1)                      // PCM
        append16(1)                      // mono
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))   // byte rate
        append16(2)                      // block align
        append16(16)                     // bits per sample
        bytes.append(contentsOf: "data".utf8)
        append(UInt32(dataSize))
        bytes.append(Data(count: dataSize))
        let url = FileManager.default.temporaryDirectory
            .appending(path: "engine-\(UUID().uuidString).wav")
        try bytes.write(to: url)
        return url
    }

    @Test func loadReportsDurationAndStartsPausedAtZero() throws {
        let engine = AVFoundationAudioEngine()
        let duration = try engine.load(url: makeWav(seconds: 0.5))
        #expect(abs(duration - 500) < 50)
        #expect(engine.durationMs == duration)
        #expect(engine.positionMs == 0)
        #expect(!engine.isPlaying)
    }

    @Test func loadOfMissingFileThrows() {
        let engine = AVFoundationAudioEngine()
        let missing = FileManager.default.temporaryDirectory.appending(path: "nope.mp3")
        #expect(throws: (any Error).self) { try engine.load(url: missing) }
    }

    @Test func seekMovesPosition() throws {
        let engine = AVFoundationAudioEngine()
        try engine.load(url: makeWav(seconds: 0.5))
        engine.seek(toMs: 200)
        #expect(abs(engine.positionMs - 200) < 50)
    }

    @Test func playAndPauseDriveIsPlaying() throws {
        let engine = AVFoundationAudioEngine()
        try engine.load(url: makeWav(seconds: 0.5))
        engine.play()
        #expect(engine.isPlaying)
        engine.pause()
        #expect(!engine.isPlaying)
    }
}
