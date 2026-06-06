// Opt-in. Requires a running backend with real Chatterbox.
// Run: VIMARSHA_BACKEND_URL=http://localhost:8000 \
//        flutter test test_integration/real_backend_test.dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/backend/dio_backend_client.dart';

void main() {
  final baseUrl =
      Platform.environment['VIMARSHA_BACKEND_URL'] ?? 'http://localhost:8000';

  late DioBackendClient client;
  late File epub;

  setUpAll(() {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 5), // narration can be slow
    ));
    client = DioBackendClient(dio);
    epub = File('../shared/fixtures/sample.epub');
    expect(epub.existsSync(), isTrue,
        reason: 'run Plan 3b Task 9 to generate the fixture');
  });

  test('real backend: /toc returns book metadata + chapters', () async {
    final toc = await client.fetchToc(epub);
    expect(toc.book.title, 'Test Book');
    expect(toc.book.author, 'Ada Lovelace');
    expect(toc.chapters, isNotEmpty);
    expect(toc.chapters.first.title, 'The Engine');
  });

  test('real backend: import produces a narrated bundle with figure timings',
      () async {
    final bundle = await client.importChapter(epub, 0);
    expect(bundle.chapterId, 'chap1');
    expect(bundle.audio, isNotNull);
    expect(bundle.paraTimings, isNotEmpty);
    // Figure 1 (block b2) should have real ms span filled by narration.
    final fig = bundle.figureMap.firstWhere((f) => f.figureId == 'b2');
    expect(fig.startMs, isNotNull);
    expect(fig.endMs, greaterThan(fig.startMs!));

    // Download the audio and confirm it is a real, non-trivial MP3.
    final bytes = await client.downloadAudio(bundle.audio!);
    expect(bytes.length, greaterThan(5000),
        reason: 'real narration should be more than a few KB');

    final tmp = File('${Directory.systemTemp.createTempSync('itaudio').path}/a.mp3')
      ..writeAsBytesSync(bytes);
    final probe = await Process.run('ffprobe', [
      '-v', 'error', '-show_entries', 'format=duration',
      '-of', 'default=nw=1:nk=1', tmp.path,
    ]);
    expect(probe.exitCode, 0, reason: 'ffprobe must read the MP3');
    final duration = double.parse((probe.stdout as String).trim());
    expect(duration, greaterThan(1.0),
        reason: 'a narrated chapter should be over a second of audio');
  }, timeout: const Timeout(Duration(minutes: 10))); // first import downloads the model
}
