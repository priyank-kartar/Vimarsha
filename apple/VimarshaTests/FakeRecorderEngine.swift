import Foundation
@testable import Vimarsha

/// The mic half of the audio seam's test double (apple/CLAUDE.md §Seams — the audio/mic
/// seam is one of exactly two sanctioned doubles). Permanent test-only code: records to a
/// real temp file (so move-into-container paths exercise real IO) and lets tests script
/// permission, duration and level.
@MainActor
final class FakeRecorderEngine: RecorderEngine {
    /// What `requestPermission` resolves to when no gate is installed.
    var stubbedPermission = true
    /// Optional async gate: when set, `requestPermission` awaits it (lets tests release
    /// the hold WHILE the permission prompt is up — the begin/end race).
    var permissionGate: (() async -> Bool)?
    /// What `stop()` reports as the recorded duration.
    var stubbedRecordedMs = 2_000
    var startError: Error?
    /// Scripted live input level.
    var stubbedLevel: CGFloat = 0

    private(set) var permissionRequests = 0
    private(set) var startedURL: URL?
    private(set) var stopCount = 0
    private(set) var isRecording = false

    var level: CGFloat { stubbedLevel }

    func requestPermission() async -> Bool {
        permissionRequests += 1
        if let permissionGate { return await permissionGate() }
        return stubbedPermission
    }

    func start(to url: URL) throws {
        if let startError { throw startError }
        // A real file, so MemoCapture's move-into-container is real IO.
        try Data("fake-aac".utf8).write(to: url)
        startedURL = url
        isRecording = true
    }

    @discardableResult
    func stop() -> Int {
        stopCount += 1
        guard isRecording else { return 0 }
        isRecording = false
        return stubbedRecordedMs
    }
}
