// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chapter_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChapterSummary {

 int get index; String get chapterId; String get title;
/// Create a copy of ChapterSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChapterSummaryCopyWith<ChapterSummary> get copyWith => _$ChapterSummaryCopyWithImpl<ChapterSummary>(this as ChapterSummary, _$identity);

  /// Serializes this ChapterSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChapterSummary&&(identical(other.index, index) || other.index == index)&&(identical(other.chapterId, chapterId) || other.chapterId == chapterId)&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,chapterId,title);

@override
String toString() {
  return 'ChapterSummary(index: $index, chapterId: $chapterId, title: $title)';
}


}

/// @nodoc
abstract mixin class $ChapterSummaryCopyWith<$Res>  {
  factory $ChapterSummaryCopyWith(ChapterSummary value, $Res Function(ChapterSummary) _then) = _$ChapterSummaryCopyWithImpl;
@useResult
$Res call({
 int index, String chapterId, String title
});




}
/// @nodoc
class _$ChapterSummaryCopyWithImpl<$Res>
    implements $ChapterSummaryCopyWith<$Res> {
  _$ChapterSummaryCopyWithImpl(this._self, this._then);

  final ChapterSummary _self;
  final $Res Function(ChapterSummary) _then;

/// Create a copy of ChapterSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? chapterId = null,Object? title = null,}) {
  return _then(_self.copyWith(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,chapterId: null == chapterId ? _self.chapterId : chapterId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ChapterSummary].
extension ChapterSummaryPatterns on ChapterSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChapterSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChapterSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChapterSummary value)  $default,){
final _that = this;
switch (_that) {
case _ChapterSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChapterSummary value)?  $default,){
final _that = this;
switch (_that) {
case _ChapterSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  String chapterId,  String title)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChapterSummary() when $default != null:
return $default(_that.index,_that.chapterId,_that.title);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  String chapterId,  String title)  $default,) {final _that = this;
switch (_that) {
case _ChapterSummary():
return $default(_that.index,_that.chapterId,_that.title);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  String chapterId,  String title)?  $default,) {final _that = this;
switch (_that) {
case _ChapterSummary() when $default != null:
return $default(_that.index,_that.chapterId,_that.title);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChapterSummary implements ChapterSummary {
  const _ChapterSummary({required this.index, required this.chapterId, required this.title});
  factory _ChapterSummary.fromJson(Map<String, dynamic> json) => _$ChapterSummaryFromJson(json);

@override final  int index;
@override final  String chapterId;
@override final  String title;

/// Create a copy of ChapterSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChapterSummaryCopyWith<_ChapterSummary> get copyWith => __$ChapterSummaryCopyWithImpl<_ChapterSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChapterSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChapterSummary&&(identical(other.index, index) || other.index == index)&&(identical(other.chapterId, chapterId) || other.chapterId == chapterId)&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,chapterId,title);

@override
String toString() {
  return 'ChapterSummary(index: $index, chapterId: $chapterId, title: $title)';
}


}

/// @nodoc
abstract mixin class _$ChapterSummaryCopyWith<$Res> implements $ChapterSummaryCopyWith<$Res> {
  factory _$ChapterSummaryCopyWith(_ChapterSummary value, $Res Function(_ChapterSummary) _then) = __$ChapterSummaryCopyWithImpl;
@override @useResult
$Res call({
 int index, String chapterId, String title
});




}
/// @nodoc
class __$ChapterSummaryCopyWithImpl<$Res>
    implements _$ChapterSummaryCopyWith<$Res> {
  __$ChapterSummaryCopyWithImpl(this._self, this._then);

  final _ChapterSummary _self;
  final $Res Function(_ChapterSummary) _then;

/// Create a copy of ChapterSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? chapterId = null,Object? title = null,}) {
  return _then(_ChapterSummary(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,chapterId: null == chapterId ? _self.chapterId : chapterId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
