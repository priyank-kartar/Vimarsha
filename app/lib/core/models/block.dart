import 'package:freezed_annotation/freezed_annotation.dart';

part 'block.freezed.dart';
part 'block.g.dart';

@freezed
abstract class Block with _$Block {
  const factory Block({
    required String id,
    required int index,
    required String kind,
    String? text,
    int? level,
    String? src,
    String? alt,
    String? caption,
    String? html,
  }) = _Block;

  factory Block.fromJson(Map<String, dynamic> json) => _$BlockFromJson(json);
}
