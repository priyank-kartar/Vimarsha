import 'package:freezed_annotation/freezed_annotation.dart';

import 'block.dart';
import 'figure.dart';

part 'chapter_bundle.freezed.dart';
part 'chapter_bundle.g.dart';

@freezed
abstract class ChapterBundle with _$ChapterBundle {
  const factory ChapterBundle({
    required String chapterId,
    required String title,
    required List<Block> blocks,
    required List<Figure> figureMap,
    String? audio,
    @Default(<String, List<int>>{}) Map<String, List<int>> paraTimings,
  }) = _ChapterBundle;

  factory ChapterBundle.fromJson(Map<String, dynamic> json) =>
      _$ChapterBundleFromJson(json);
}
