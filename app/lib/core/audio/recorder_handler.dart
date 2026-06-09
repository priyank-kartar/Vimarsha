/// The microphone seam. Real impl: [RecordRecorderHandler]; tests use a fake.
abstract class RecorderHandler {
  /// Begin recording to [filePath]. Throws [RecorderPermissionDenied] if the
  /// mic permission is not granted.
  Future<void> start(String filePath);

  /// Stop recording; returns the recorded file path (or null if nothing).
  Future<String?> stop();

  bool get isRecording;

  Future<void> dispose();
}

class RecorderPermissionDenied implements Exception {
  const RecorderPermissionDenied();
  @override
  String toString() => 'Microphone permission denied';
}
