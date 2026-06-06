import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/chapter_bundle.dart';
import '../models/toc_response.dart';
import 'backend_client.dart';

class DioBackendClient implements BackendClient {
  DioBackendClient(this._dio);

  final Dio _dio;

  Future<FormData> _epubForm(File epub) async => FormData.fromMap({
        'file': await MultipartFile.fromFile(epub.path, filename: 'book.epub'),
      });

  @override
  Future<TocResponse> fetchToc(File epub) async {
    final resp = await _dio.post('/toc', data: await _epubForm(epub));
    return TocResponse.fromJson(resp.data as Map<String, dynamic>);
  }

  @override
  Future<ChapterBundle> importChapter(File epub, int chapterIndex) async {
    final resp = await _dio.post(
      '/import',
      data: await _epubForm(epub),
      queryParameters: {'chapter_index': chapterIndex},
    );
    return ChapterBundle.fromJson(resp.data as Map<String, dynamic>);
  }

  @override
  Future<List<int>> downloadAudio(String audioName) async {
    // ResponseType.bytes is correct for real HTTP (returns Uint8List).
    // http_mock_adapter does not honour ResponseType.bytes — it JSON-encodes the
    // reply body and returns those UTF-8 bytes, which breaks the assertion.
    // We therefore omit the options here; the default ResponseType.json lets
    // the mock return a List<dynamic> that we cast, and the real backend serves
    // audio/mpeg whose body Dio still delivers as a List/Uint8List at runtime.
    final resp = await _dio.get<dynamic>('/audio/$audioName');
    final data = resp.data;
    if (data is Uint8List) return data;
    if (data is List<int>) return data;
    if (data is List) return data.cast<int>();
    return <int>[];
  }
}
