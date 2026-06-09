import 'package:record/record.dart';

import 'recorder_handler.dart';

class RecordRecorderHandler implements RecorderHandler {
  RecordRecorderHandler([AudioRecorder? recorder])
      : _rec = recorder ?? AudioRecorder();

  final AudioRecorder _rec;
  bool _recording = false;

  @override
  bool get isRecording => _recording;

  @override
  Future<void> start(String filePath) async {
    if (!await _rec.hasPermission()) {
      throw const RecorderPermissionDenied();
    }
    await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: filePath);
    _recording = true;
  }

  @override
  Future<String?> stop() async {
    final path = await _rec.stop();
    _recording = false;
    return path;
  }

  @override
  Future<void> dispose() => _rec.dispose();
}
