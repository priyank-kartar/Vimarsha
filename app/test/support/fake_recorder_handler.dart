import 'dart:io';

import 'package:vimarsha/core/audio/recorder_handler.dart';

/// In-test recorder: writes a small fake clip to the requested path on start so
/// the repository has a real file to copy.
class FakeRecorderHandler implements RecorderHandler {
  bool permissionDenied = false;
  bool _recording = false;
  String? startedPath;

  @override
  bool get isRecording => _recording;

  @override
  Future<void> start(String filePath) async {
    if (permissionDenied) throw const RecorderPermissionDenied();
    await File(filePath).writeAsBytes(const [1, 2, 3, 4]);
    startedPath = filePath;
    _recording = true;
  }

  @override
  Future<String?> stop() async {
    _recording = false;
    return startedPath;
  }

  @override
  Future<void> dispose() async {}
}
