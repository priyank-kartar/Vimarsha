// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'block.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Block _$BlockFromJson(Map<String, dynamic> json) => _Block(
  id: json['id'] as String,
  index: (json['index'] as num).toInt(),
  kind: json['kind'] as String,
  text: json['text'] as String?,
  level: (json['level'] as num?)?.toInt(),
  src: json['src'] as String?,
  alt: json['alt'] as String?,
  caption: json['caption'] as String?,
  html: json['html'] as String?,
);

Map<String, dynamic> _$BlockToJson(_Block instance) => <String, dynamic>{
  'id': instance.id,
  'index': instance.index,
  'kind': instance.kind,
  'text': instance.text,
  'level': instance.level,
  'src': instance.src,
  'alt': instance.alt,
  'caption': instance.caption,
  'html': instance.html,
};
