import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/audio/audio_handler.dart';
import '../book/chapter_repository.dart';

/// Drives playback of one cached chapter: loads audio, restores the saved
/// position, mirrors the handler's position/playing into listenable state, and
/// persists reading progress (throttled, and on pause/dispose).
class PlayerController extends ChangeNotifier {
  PlayerController({
    required AudioHandler audio,
    required ChapterRepository chapters,
    required this.bookId,
    required this.index,
  })  : _audio = audio,
        _chapters = chapters;

  final AudioHandler _audio;
  final ChapterRepository _chapters;
  final String bookId;
  final int index;

  static const _saveInterval = Duration(seconds: 5);

  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool playing = false;
  double speed = 1.0;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playSub;
  Duration _lastSaved = Duration.zero;

  Future<void> load(String audioPath) async {
    final dur = await _audio.load(audioPath);
    if (dur != null) duration = dur;

    final row = await _chapters.getChapter(bookId, index);
    final resume = Duration(milliseconds: row?.positionMs ?? 0);
    position = resume;
    _lastSaved = Duration.zero;
    if (resume > Duration.zero) {
      await _audio.seek(resume);
    }

    _posSub = _audio.positionStream.listen(_onPosition);
    _playSub = _audio.playingStream.listen((p) {
      playing = p;
      notifyListeners();
    });
    notifyListeners();
  }

  void _onPosition(Duration p) {
    position = p;
    if ((p - _lastSaved).abs() >= _saveInterval) {
      _lastSaved = p;
      unawaited(_chapters.saveProgress(bookId, index, p.inMilliseconds));
    }
    notifyListeners();
  }

  Future<void> play() => _audio.play();

  Future<void> pause() async {
    await _audio.pause();
    await _persist();
  }

  Future<void> seek(Duration to) async {
    await _audio.seek(to);
    position = to;
    notifyListeners();
  }

  Future<void> setSpeed(double s) async {
    await _audio.setSpeed(s);
    speed = s;
    notifyListeners();
  }

  Future<void> _persist() async {
    _lastSaved = position;
    await _chapters.saveProgress(bookId, index, position.inMilliseconds);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _playSub?.cancel();
    // best-effort final save
    unawaited(_chapters.saveProgress(bookId, index, position.inMilliseconds));
    unawaited(_audio.dispose());
    super.dispose();
  }
}
