// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'figure.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Figure _$FigureFromJson(Map<String, dynamic> json) => _Figure(
  figureId: json['figureId'] as String,
  kind: json['kind'] as String,
  asset: json['asset'] as String?,
  caption: json['caption'] as String?,
  label: json['label'] as String?,
  startPara: json['startPara'] as String,
  endPara: json['endPara'] as String,
  startMs: (json['startMs'] as num?)?.toInt(),
  endMs: (json['endMs'] as num?)?.toInt(),
  image: json['image'] as String?,
);

Map<String, dynamic> _$FigureToJson(_Figure instance) => <String, dynamic>{
  'figureId': instance.figureId,
  'kind': instance.kind,
  'asset': instance.asset,
  'caption': instance.caption,
  'label': instance.label,
  'startPara': instance.startPara,
  'endPara': instance.endPara,
  'startMs': instance.startMs,
  'endMs': instance.endMs,
  'image': instance.image,
};
