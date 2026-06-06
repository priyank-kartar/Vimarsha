// app/test/core/models/models_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/models/chapter_bundle.dart';
import 'package:vimarsha/core/models/book_meta.dart';

void main() {
  test('parses the shared sample bundle fixture', () {
    final file = File('../shared/fixtures/sample-chapter.bundle.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final bundle = ChapterBundle.fromJson(json);

    expect(bundle.chapterId, 'chap1');
    expect(bundle.title, 'The Engine');
    expect(bundle.blocks, isNotEmpty);
    expect(bundle.audio, 'chap1.mp3');
    // figure ms ranges were filled by narration
    final fig = bundle.figureMap.firstWhere((f) => f.figureId == 'b2');
    expect(fig.kind, 'figure');
    expect(fig.startMs, isNotNull);
    expect(fig.endMs, greaterThan(fig.startMs!));
    // paraTimings is a map of [start,end]
    expect(bundle.paraTimings['b0'], hasLength(2));
  });

  test('round-trips to json and back', () {
    final file = File('../shared/fixtures/sample-chapter.bundle.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final bundle = ChapterBundle.fromJson(json);
    final again = ChapterBundle.fromJson(bundle.toJson());
    expect(again, bundle);
  });

  test('book meta parses title and author', () {
    final meta = BookMeta.fromJson({'title': 'Test Book', 'author': 'Ada Lovelace'});
    expect(meta.title, 'Test Book');
    expect(meta.author, 'Ada Lovelace');
  });
}
