import 'dart:io';

import 'package:vimarsha/core/backend/backend_client.dart';
import 'package:vimarsha/core/models/chapter_bundle.dart';
import 'package:vimarsha/core/models/toc_response.dart';

/// In-test BackendClient. Returns canned values; can be told to throw.
class FakeBackendClient implements BackendClient {
  FakeBackendClient({this.toc, this.bundle, this.audio = const [1, 2, 3, 4]});

  TocResponse? toc;
  ChapterBundle? bundle;
  List<int> audio;
  Object? throwOnToc;
  Object? throwOnImport;

  int tocCalls = 0;
  int importCalls = 0;

  @override
  Future<TocResponse> fetchToc(File epub) async {
    tocCalls++;
    if (throwOnToc != null) throw throwOnToc!;
    return toc!;
  }

  @override
  Future<ChapterBundle> importChapter(File epub, int chapterIndex) async {
    importCalls++;
    if (throwOnImport != null) throw throwOnImport!;
    return bundle!;
  }

  @override
  Future<List<int>> downloadAudio(String audioName) async => audio;

  /// bytes returned by downloadImage (any name); records requested names.
  List<int> image = const [137, 80, 78, 71]; // "\x89PNG"
  final List<String> imageRequests = [];
  Object? throwOnImage;

  @override
  Future<List<int>> downloadImage(String imageName) async {
    if (throwOnImage != null) throw throwOnImage!;
    imageRequests.add(imageName);
    return image;
  }
}
