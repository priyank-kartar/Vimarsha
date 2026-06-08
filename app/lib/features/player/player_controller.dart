import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/audio/audio_handler.dart';
import '../../core/models/chapter_bundle.dart';
import '../../core/models/figure.dart';
import '../../core/storage/file_store.dart';
import '../book/chapter_repository.dart';

/// Drives playback of one cached chapter: loads audio + bundle, restores the
/// saved position, mirrors position/playing into listenable state, derives the
/// narrated paragraph and active figures, and persists progress.
class PlayerController extends ChangeNotifier {
  PlayerController({
    required AudioHandler audio,
    required ChapterRepository chapters,
    required FileStore files,
    required this.bookId,
    required this.index,
  })  : _audio = audio,
        _chapters = chapters,
        _files = files;

  final AudioHandler _audio;
  final ChapterRepository _chapters;
  final FileStore _files;
  final String bookId;
  final int index;

  static const _saveInterval = Duration(seconds: 5);

  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool playing = false;
  double speed = 1.0;

  ChapterBundle? bundle;
  String? currentBlockId;
  List<Figure> currentFigures = const [];

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playSub;
  Duration _lastSaved = Duration.zero;
  bool _disposed = false;

  Future<void> load(String audioPath) async {
    if (_posSub != null) return;
    final dur = await _audio.load(audioPath);
    if (dur != null) duration = dur;

    bundle = await _chapters.loadBundle(bookId, index);

    final row = await _chapters.getChapter(bookId, index);
    final resume = Duration(milliseconds: row?.positionMs ?? 0);
    position = resume;
    _lastSaved = Duration.zero;
    if (resume > Duration.zero) await _audio.seek(resume);
    _recompute();

    _posSub = _audio.positionStream.listen(_onPosition);
    _playSub = _audio.playingStream.listen((p) {
      if (_disposed) return;
      playing = p;
      notifyListeners();
    });
    notifyListeners();
  }

  void _onPosition(Duration p) {
    if (_disposed) return;
    position = p;
    if ((p - _lastSaved).abs() >= _saveInterval) {
      _lastSaved = p;
      unawaited(_chapters.saveProgress(bookId, index, p.inMilliseconds));
    }
    _recompute();
    notifyListeners();
  }

  /// Recompute the narrated paragraph + active figures from `position`.
  void _recompute() {
    final b = bundle;
    if (b == null) return;
    final ms = position.inMilliseconds;

    String? blockId;
    var bestStart = -1;
    b.paraTimings.forEach((id, range) {
      final start = range.isNotEmpty ? range[0] : 0;
      if (start <= ms && start > bestStart) {
        bestStart = start;
        blockId = id;
      }
    });
    currentBlockId = blockId;

    currentFigures = b.figureMap
        .where((f) =>
            f.startMs != null &&
            f.endMs != null &&
            ms >= f.startMs! &&
            ms <= f.endMs!)
        .toList();
  }

  /// Resolve a figure's cached image to a local file path (null if no image).
  String? imagePathFor(Figure figure) {
    final name = figure.image;
    if (name == null) return null;
    return _files.imageFile(bookId, index, name).path;
  }

  Future<void> play() => _audio.play();

  Future<void> pause() async {
    await _audio.pause();
    await _persist();
  }

  Future<void> seek(Duration to) async {
    await _audio.seek(to);
    position = to;
    _recompute();
    notifyListeners();
  }

  /// Seek to the start of a block (by id), using its paragraph timing.
  Future<void> seekToBlock(String blockId) async {
    final range = bundle?.paraTimings[blockId];
    if (range == null || range.isEmpty) return;
    await seek(Duration(milliseconds: range[0]));
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
    _disposed = true;
    _posSub?.cancel();
    _playSub?.cancel();
    unawaited(_audio.pause());
    unawaited(_chapters.saveProgress(bookId, index, position.inMilliseconds));
    super.dispose();
  }
}
