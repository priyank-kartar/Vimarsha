// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chapter_bundle.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChapterBundle _$ChapterBundleFromJson(Map<String, dynamic> json) =>
    _ChapterBundle(
      chapterId: json['chapterId'] as String,
      title: json['title'] as String,
      blocks: (json['blocks'] as List<dynamic>)
          .map((e) => Block.fromJson(e as Map<String, dynamic>))
          .toList(),
      figureMap: (json['figureMap'] as List<dynamic>)
          .map((e) => Figure.fromJson(e as Map<String, dynamic>))
          .toList(),
      audio: json['audio'] as String?,
      paraTimings:
          (json['paraTimings'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(
              k,
              (e as List<dynamic>).map((e) => (e as num).toInt()).toList(),
            ),
          ) ??
          const <String, List<int>>{},
    );

Map<String, dynamic> _$ChapterBundleToJson(_ChapterBundle instance) =>
    <String, dynamic>{
      'chapterId': instance.chapterId,
      'title': instance.title,
      'blocks': instance.blocks.map((e) => e.toJson()).toList(),
      'figureMap': instance.figureMap.map((e) => e.toJson()).toList(),
      'audio': instance.audio,
      'paraTimings': instance.paraTimings,
    };
