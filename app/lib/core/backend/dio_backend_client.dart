import 'dart:io';

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
    // ResponseType.bytes is required for binary audio — the default JSON/string
    // handling corrupts the MP3. The download unit test uses a real local HTTP
    // server (http_mock_adapter mishandles bytes) to verify this path.
    final resp = await _dio.get<List<int>>(
      '/audio/$audioName',
      options: Options(responseType: ResponseType.bytes),
    );
    return resp.data ?? <int>[];
  }

  @override
  Future<List<int>> downloadImage(String imageName) async {
    final resp = await _dio.get<List<int>>(
      '/image/$imageName',
      options: Options(responseType: ResponseType.bytes),
    );
    return resp.data ?? <int>[];
  }
}
