import 'package:freezed_annotation/freezed_annotation.dart';

part 'figure.freezed.dart';
part 'figure.g.dart';

@freezed
abstract class Figure with _$Figure {
  const factory Figure({
    required String figureId,
    required String kind,
    String? asset,
    String? caption,
    String? label,
    required String startPara,
    required String endPara,
    int? startMs,
    int? endMs,
    String? image,
  }) = _Figure;

  factory Figure.fromJson(Map<String, dynamic> json) => _$FigureFromJson(json);
}
