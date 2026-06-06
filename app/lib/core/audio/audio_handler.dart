/// The seam over the audio device. Real impl: [JustAudioHandler]; the player
/// controller is tested against a fake implementation.
abstract class AudioHandler {
  /// Load a local audio file; returns its total duration if known.
  Future<Duration?> load(String filePath);

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);

  /// Current playback position (updates as audio plays).
  Stream<Duration> get positionStream;

  /// Whether audio is currently playing.
  Stream<bool> get playingStream;

  Duration get position;

  Future<void> dispose();
}
