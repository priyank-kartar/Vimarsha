import 'package:freezed_annotation/freezed_annotation.dart';

part 'book_meta.freezed.dart';
part 'book_meta.g.dart';

@freezed
abstract class BookMeta with _$BookMeta {
  const factory BookMeta({
    required String title,
    @Default('') String author,
  }) = _BookMeta;

  factory BookMeta.fromJson(Map<String, dynamic> json) =>
      _$BookMetaFromJson(json);
}
