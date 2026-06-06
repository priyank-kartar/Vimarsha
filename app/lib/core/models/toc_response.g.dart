// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toc_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TocResponse _$TocResponseFromJson(Map<String, dynamic> json) => _TocResponse(
  book: BookMeta.fromJson(json['book'] as Map<String, dynamic>),
  chapters: (json['chapters'] as List<dynamic>)
      .map((e) => ChapterSummary.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$TocResponseToJson(_TocResponse instance) =>
    <String, dynamic>{
      'book': instance.book.toJson(),
      'chapters': instance.chapters.map((e) => e.toJson()).toList(),
    };
