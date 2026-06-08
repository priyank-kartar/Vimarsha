// app/test/core/backend/dio_backend_client_test.dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:vimarsha/core/backend/dio_backend_client.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late DioBackendClient client;
  late File epub;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = DioAdapter(dio: dio);
    client = DioBackendClient(dio);
    epub = File('${Directory.systemTemp.createTempSync('be').path}/book.epub')
      ..writeAsBytesSync([1, 2, 3]);
  });

  test('fetchToc posts to /toc and parses the response', () async {
    adapter.onPost(
      '/toc',
      (server) => server.reply(200, {
        'book': {'title': 'B', 'author': 'A'},
        'chapters': [
          {'index': 0, 'chapterId': 'chap1', 'title': 'One'}
        ],
      }),
      data: Matchers.any,
    );
    final toc = await client.fetchToc(epub);
    expect(toc.book.title, 'B');
    expect(toc.chapters.single.chapterId, 'chap1');
  });

  test('importChapter posts to /import with chapter_index and parses bundle',
      () async {
    adapter.onPost(
      '/import',
      (server) => server.reply(200, {
        'chapterId': 'chap1',
        'title': 'One',
        'blocks': [
          {'id': 'b0', 'index': 0, 'kind': 'paragraph', 'text': 'hi'}
        ],
        'figureMap': [],
        'audio': 'chap1.mp3',
        'paraTimings': {
          'b0': [0, 1000]
        },
      }),
      data: Matchers.any,
      queryParameters: {'chapter_index': 0},
    );
    final bundle = await client.importChapter(epub, 0);
    expect(bundle.chapterId, 'chap1');
    expect(bundle.audio, 'chap1.mp3');
    expect(bundle.paraTimings['b0'], [0, 1000]);
  });

  test('downloadAudio gets /audio/<name> as raw bytes', () async {
    // http_mock_adapter mishandles ResponseType.bytes, so use a real local
    // server to verify binary bytes survive intact (production uses bytes mode).
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final payload = [0, 255, 10, 200, 30]; // includes non-UTF8 byte values
    server.listen((req) {
      req.response
        ..headers.contentType = ContentType('audio', 'mpeg')
        ..add(payload);
      req.response.close();
    });

    final realDio = Dio(BaseOptions(baseUrl: 'http://${server.address.host}:${server.port}'));
    final realClient = DioBackendClient(realDio);
    final bytes = await realClient.downloadAudio('chap1.mp3');
    expect(bytes, payload);
  });

  test('downloadImage gets /image/<name> as raw bytes', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final payload = [137, 80, 78, 71, 13, 10];
    server.listen((req) {
      req.response
        ..headers.contentType = ContentType('image', 'png')
        ..add(payload);
      req.response.close();
    });
    final realDio = Dio(BaseOptions(baseUrl: 'http://${server.address.host}:${server.port}'));
    final bytes = await DioBackendClient(realDio).downloadImage('chap1_b2.png');
    expect(bytes, payload);
  });
}
