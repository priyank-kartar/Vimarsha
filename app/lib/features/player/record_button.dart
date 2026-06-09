import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/recorder_handler.dart';
import '../../core/providers.dart';
import 'player_controller.dart';

/// Hold-to-record: press to pause playback + start recording, release to stop,
/// save the memo, and auto-resume playback (if it was playing).
class RecordButton extends ConsumerStatefulWidget {
  const RecordButton({
    super.key,
    required this.controller,
    required this.bookId,
    required this.index,
  });

  final PlayerController controller;
  final String bookId;
  final int index;

  @override
  ConsumerState<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends ConsumerState<RecordButton> {
  bool _recording = false;
  bool _starting = false;
  bool _pressed = false; // set synchronously by the gesture handlers
  bool _wasPlaying = false;

  Future<void> _start() async {
    if (_recording || _starting) return;
    _starting = true;
    _wasPlaying = widget.controller.playing;
    await widget.controller.pause(); // also freezes the reading view (position stops)
    final file = await ref.read(fileStoreProvider).newRecordingFile();
    try {
      await ref.read(recorderHandlerProvider).start(file.path);
    } on RecorderPermissionDenied {
      _starting = false;
      if (_wasPlaying) await widget.controller.play(); // don't leave it stuck paused
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }
    _starting = false;
    _recording = true;
    if (mounted) setState(() {});
    // The user may have released while start() was still awaiting — stop now so
    // we never strand an in-flight recording or leave playback paused.
    if (!_pressed) await _stop();
  }

  Future<void> _stop() async {
    if (!_recording) return;
    _recording = false;
    if (mounted) setState(() {});
    final path = await ref.read(recorderHandlerProvider).stop();
    final messenger = mounted ? ScaffoldMessenger.of(context) : null;
    var saved = false;
    if (path != null) {
      final f = File(path);
      if (f.existsSync() && f.lengthSync() > 0) {
        await ref.read(memoRepositoryProvider).saveMemo(
              bookId: widget.bookId,
              chapterIndex: widget.index,
              blockId: widget.controller.currentBlockId,
              positionMs: widget.controller.position.inMilliseconds,
              recordedFile: f,
            );
        saved = true;
        messenger?.showSnackBar(
          const SnackBar(content: Text('Memo saved · transcribing…')),
        );
      }
      if (!saved) {
        // Discard a too-short/empty clip rather than leaking it in rec/.
        try {
          if (f.existsSync()) f.deleteSync();
        } catch (_) {/* best-effort */}
      }
    }
    if (_wasPlaying) await widget.controller.play();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _pressed = true;
        _start();
      },
      onTapUp: (_) {
        _pressed = false;
        _stop();
      },
      onTapCancel: () {
        _pressed = false;
        _stop();
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _recording ? Colors.red : Colors.red.shade400,
          boxShadow: _recording
              ? [BoxShadow(color: Colors.red.withValues(alpha: 0.5), blurRadius: 16, spreadRadius: 4)]
              : null,
        ),
        child: Icon(_recording ? Icons.stop : Icons.mic, color: Colors.white),
      ),
    );
  }
}
