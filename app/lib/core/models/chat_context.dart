import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_context.freezed.dart';
part 'chat_context.g.dart';

@freezed
abstract class ChatContext with _$ChatContext {
  const factory ChatContext({
    required String passage,
    String? figureCaption,
    required String bookTitle,
    required String chapterTitle,
  }) = _ChatContext;

  factory ChatContext.fromJson(Map<String, dynamic> json) =>
      _$ChatContextFromJson(json);
}
