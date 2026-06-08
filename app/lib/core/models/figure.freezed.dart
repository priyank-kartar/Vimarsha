// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'figure.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Figure {

 String get figureId; String get kind; String? get asset; String? get caption; String? get label; String get startPara; String get endPara; int? get startMs; int? get endMs; String? get image;
/// Create a copy of Figure
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FigureCopyWith<Figure> get copyWith => _$FigureCopyWithImpl<Figure>(this as Figure, _$identity);

  /// Serializes this Figure to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Figure&&(identical(other.figureId, figureId) || other.figureId == figureId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.asset, asset) || other.asset == asset)&&(identical(other.caption, caption) || other.caption == caption)&&(identical(other.label, label) || other.label == label)&&(identical(other.startPara, startPara) || other.startPara == startPara)&&(identical(other.endPara, endPara) || other.endPara == endPara)&&(identical(other.startMs, startMs) || other.startMs == startMs)&&(identical(other.endMs, endMs) || other.endMs == endMs)&&(identical(other.image, image) || other.image == image));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,figureId,kind,asset,caption,label,startPara,endPara,startMs,endMs,image);

@override
String toString() {
  return 'Figure(figureId: $figureId, kind: $kind, asset: $asset, caption: $caption, label: $label, startPara: $startPara, endPara: $endPara, startMs: $startMs, endMs: $endMs, image: $image)';
}


}

/// @nodoc
abstract mixin class $FigureCopyWith<$Res>  {
  factory $FigureCopyWith(Figure value, $Res Function(Figure) _then) = _$FigureCopyWithImpl;
@useResult
$Res call({
 String figureId, String kind, String? asset, String? caption, String? label, String startPara, String endPara, int? startMs, int? endMs, String? image
});




}
/// @nodoc
class _$FigureCopyWithImpl<$Res>
    implements $FigureCopyWith<$Res> {
  _$FigureCopyWithImpl(this._self, this._then);

  final Figure _self;
  final $Res Function(Figure) _then;

/// Create a copy of Figure
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? figureId = null,Object? kind = null,Object? asset = freezed,Object? caption = freezed,Object? label = freezed,Object? startPara = null,Object? endPara = null,Object? startMs = freezed,Object? endMs = freezed,Object? image = freezed,}) {
  return _then(_self.copyWith(
figureId: null == figureId ? _self.figureId : figureId // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,asset: freezed == asset ? _self.asset : asset // ignore: cast_nullable_to_non_nullable
as String?,caption: freezed == caption ? _self.caption : caption // ignore: cast_nullable_to_non_nullable
as String?,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,startPara: null == startPara ? _self.startPara : startPara // ignore: cast_nullable_to_non_nullable
as String,endPara: null == endPara ? _self.endPara : endPara // ignore: cast_nullable_to_non_nullable
as String,startMs: freezed == startMs ? _self.startMs : startMs // ignore: cast_nullable_to_non_nullable
as int?,endMs: freezed == endMs ? _self.endMs : endMs // ignore: cast_nullable_to_non_nullable
as int?,image: freezed == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Figure].
extension FigurePatterns on Figure {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Figure value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Figure() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Figure value)  $default,){
final _that = this;
switch (_that) {
case _Figure():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Figure value)?  $default,){
final _that = this;
switch (_that) {
case _Figure() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String figureId,  String kind,  String? asset,  String? caption,  String? label,  String startPara,  String endPara,  int? startMs,  int? endMs,  String? image)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Figure() when $default != null:
return $default(_that.figureId,_that.kind,_that.asset,_that.caption,_that.label,_that.startPara,_that.endPara,_that.startMs,_that.endMs,_that.image);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String figureId,  String kind,  String? asset,  String? caption,  String? label,  String startPara,  String endPara,  int? startMs,  int? endMs,  String? image)  $default,) {final _that = this;
switch (_that) {
case _Figure():
return $default(_that.figureId,_that.kind,_that.asset,_that.caption,_that.label,_that.startPara,_that.endPara,_that.startMs,_that.endMs,_that.image);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String figureId,  String kind,  String? asset,  String? caption,  String? label,  String startPara,  String endPara,  int? startMs,  int? endMs,  String? image)?  $default,) {final _that = this;
switch (_that) {
case _Figure() when $default != null:
return $default(_that.figureId,_that.kind,_that.asset,_that.caption,_that.label,_that.startPara,_that.endPara,_that.startMs,_that.endMs,_that.image);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Figure implements Figure {
  const _Figure({required this.figureId, required this.kind, this.asset, this.caption, this.label, required this.startPara, required this.endPara, this.startMs, this.endMs, this.image});
  factory _Figure.fromJson(Map<String, dynamic> json) => _$FigureFromJson(json);

@override final  String figureId;
@override final  String kind;
@override final  String? asset;
@override final  String? caption;
@override final  String? label;
@override final  String startPara;
@override final  String endPara;
@override final  int? startMs;
@override final  int? endMs;
@override final  String? image;

/// Create a copy of Figure
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FigureCopyWith<_Figure> get copyWith => __$FigureCopyWithImpl<_Figure>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FigureToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Figure&&(identical(other.figureId, figureId) || other.figureId == figureId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.asset, asset) || other.asset == asset)&&(identical(other.caption, caption) || other.caption == caption)&&(identical(other.label, label) || other.label == label)&&(identical(other.startPara, startPara) || other.startPara == startPara)&&(identical(other.endPara, endPara) || other.endPara == endPara)&&(identical(other.startMs, startMs) || other.startMs == startMs)&&(identical(other.endMs, endMs) || other.endMs == endMs)&&(identical(other.image, image) || other.image == image));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,figureId,kind,asset,caption,label,startPara,endPara,startMs,endMs,image);

@override
String toString() {
  return 'Figure(figureId: $figureId, kind: $kind, asset: $asset, caption: $caption, label: $label, startPara: $startPara, endPara: $endPara, startMs: $startMs, endMs: $endMs, image: $image)';
}


}

/// @nodoc
abstract mixin class _$FigureCopyWith<$Res> implements $FigureCopyWith<$Res> {
  factory _$FigureCopyWith(_Figure value, $Res Function(_Figure) _then) = __$FigureCopyWithImpl;
@override @useResult
$Res call({
 String figureId, String kind, String? asset, String? caption, String? label, String startPara, String endPara, int? startMs, int? endMs, String? image
});




}
/// @nodoc
class __$FigureCopyWithImpl<$Res>
    implements _$FigureCopyWith<$Res> {
  __$FigureCopyWithImpl(this._self, this._then);

  final _Figure _self;
  final $Res Function(_Figure) _then;

/// Create a copy of Figure
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? figureId = null,Object? kind = null,Object? asset = freezed,Object? caption = freezed,Object? label = freezed,Object? startPara = null,Object? endPara = null,Object? startMs = freezed,Object? endMs = freezed,Object? image = freezed,}) {
  return _then(_Figure(
figureId: null == figureId ? _self.figureId : figureId // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,asset: freezed == asset ? _self.asset : asset // ignore: cast_nullable_to_non_nullable
as String?,caption: freezed == caption ? _self.caption : caption // ignore: cast_nullable_to_non_nullable
as String?,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,startPara: null == startPara ? _self.startPara : startPara // ignore: cast_nullable_to_non_nullable
as String,endPara: null == endPara ? _self.endPara : endPara // ignore: cast_nullable_to_non_nullable
as String,startMs: freezed == startMs ? _self.startMs : startMs // ignore: cast_nullable_to_non_nullable
as int?,endMs: freezed == endMs ? _self.endMs : endMs // ignore: cast_nullable_to_non_nullable
as int?,image: freezed == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
