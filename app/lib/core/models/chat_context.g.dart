// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_context.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChatContext _$ChatContextFromJson(Map<String, dynamic> json) => _ChatContext(
  passage: json['passage'] as String,
  figureCaption: json['figureCaption'] as String?,
  bookTitle: json['bookTitle'] as String,
  chapterTitle: json['chapterTitle'] as String,
);

Map<String, dynamic> _$ChatContextToJson(_ChatContext instance) =>
    <String, dynamic>{
      'passage': instance.passage,
      'figureCaption': instance.figureCaption,
      'bookTitle': instance.bookTitle,
      'chapterTitle': instance.chapterTitle,
    };
