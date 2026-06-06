// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chapter_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChapterSummary _$ChapterSummaryFromJson(Map<String, dynamic> json) =>
    _ChapterSummary(
      index: (json['index'] as num).toInt(),
      chapterId: json['chapterId'] as String,
      title: json['title'] as String,
    );

Map<String, dynamic> _$ChapterSummaryToJson(_ChapterSummary instance) =>
    <String, dynamic>{
      'index': instance.index,
      'chapterId': instance.chapterId,
      'title': instance.title,
    };
