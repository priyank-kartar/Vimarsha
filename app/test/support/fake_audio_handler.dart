import 'dart:async';

import 'package:vimarsha/core/audio/audio_handler.dart';

/// Controllable AudioHandler for tests: you push position/playing events and
/// inspect the calls made to it.
class FakeAudioHandler implements AudioHandler {
  final _position = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();

  Duration _pos = Duration.zero;
  Duration? loadedDuration = const Duration(seconds: 60);

  String? loadedPath;
  bool playCalled = false;
  bool pauseCalled = false;
  double speed = 1.0;
  final List<Duration> seeks = [];
  bool disposed = false;

  /// Test helper: emit a position event (also updates `position`).
  void emitPosition(Duration d) {
    _pos = d;
    _position.add(d);
  }

  /// Test helper: emit a playing-state event.
  void emitPlaying(bool v) => _playing.add(v);

  @override
  Future<Duration?> load(String filePath) async {
    loadedPath = filePath;
    return loadedDuration;
  }

  @override
  Future<void> play() async {
    playCalled = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    pauseCalled = true;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    _pos = position;
  }

  @override
  Future<void> setSpeed(double s) async => speed = s;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Duration get position => _pos;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _position.close();
    await _playing.close();
  }
}
