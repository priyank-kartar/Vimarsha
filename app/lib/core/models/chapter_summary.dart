import 'package:freezed_annotation/freezed_annotation.dart';

part 'chapter_summary.freezed.dart';
part 'chapter_summary.g.dart';

@freezed
abstract class ChapterSummary with _$ChapterSummary {
  const factory ChapterSummary({
    required int index,
    required String chapterId,
    required String title,
  }) = _ChapterSummary;

  factory ChapterSummary.fromJson(Map<String, dynamic> json) =>
      _$ChapterSummaryFromJson(json);
}
