import 'package:just_audio/just_audio.dart';

import 'audio_handler.dart';

class JustAudioHandler implements AudioHandler {
  JustAudioHandler([AudioPlayer? player]) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<Duration?> load(String filePath) => _player.setFilePath(filePath);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Duration get position => _player.position;

  @override
  Future<void> dispose() => _player.dispose();
}
