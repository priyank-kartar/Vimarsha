import 'package:freezed_annotation/freezed_annotation.dart';

import 'book_meta.dart';
import 'chapter_summary.dart';

part 'toc_response.freezed.dart';
part 'toc_response.g.dart';

@freezed
abstract class TocResponse with _$TocResponse {
  const factory TocResponse({
    required BookMeta book,
    required List<ChapterSummary> chapters,
  }) = _TocResponse;

  factory TocResponse.fromJson(Map<String, dynamic> json) =>
      _$TocResponseFromJson(json);
}
