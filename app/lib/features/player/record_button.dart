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
  bool _wasPlaying = false;

  Future<void> _start() async {
    if (_recording) return;
    _wasPlaying = widget.controller.playing;
    await widget.controller.pause(); // also freezes the reading view (position stops)
    final file = await ref.read(fileStoreProvider).newRecordingFile();
    try {
      await ref.read(recorderHandlerProvider).start(file.path);
      setState(() => _recording = true);
    } on RecorderPermissionDenied {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
    }
  }

  Future<void> _stop() async {
    if (!_recording) return;
    setState(() => _recording = false);
    final path = await ref.read(recorderHandlerProvider).stop();
    final messenger = mounted ? ScaffoldMessenger.of(context) : null;
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
        messenger?.showSnackBar(
          const SnackBar(content: Text('Memo saved · transcribing…')),
        );
      }
    }
    if (_wasPlaying) await widget.controller.play();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _start(),
      onTapUp: (_) => _stop(),
      onTapCancel: _stop,
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
