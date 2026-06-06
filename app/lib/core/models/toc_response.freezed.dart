// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'toc_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TocResponse {

 BookMeta get book; List<ChapterSummary> get chapters;
/// Create a copy of TocResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TocResponseCopyWith<TocResponse> get copyWith => _$TocResponseCopyWithImpl<TocResponse>(this as TocResponse, _$identity);

  /// Serializes this TocResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TocResponse&&(identical(other.book, book) || other.book == book)&&const DeepCollectionEquality().equals(other.chapters, chapters));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,book,const DeepCollectionEquality().hash(chapters));

@override
String toString() {
  return 'TocResponse(book: $book, chapters: $chapters)';
}


}

/// @nodoc
abstract mixin class $TocResponseCopyWith<$Res>  {
  factory $TocResponseCopyWith(TocResponse value, $Res Function(TocResponse) _then) = _$TocResponseCopyWithImpl;
@useResult
$Res call({
 BookMeta book, List<ChapterSummary> chapters
});


$BookMetaCopyWith<$Res> get book;

}
/// @nodoc
class _$TocResponseCopyWithImpl<$Res>
    implements $TocResponseCopyWith<$Res> {
  _$TocResponseCopyWithImpl(this._self, this._then);

  final TocResponse _self;
  final $Res Function(TocResponse) _then;

/// Create a copy of TocResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? book = null,Object? chapters = null,}) {
  return _then(_self.copyWith(
book: null == book ? _self.book : book // ignore: cast_nullable_to_non_nullable
as BookMeta,chapters: null == chapters ? _self.chapters : chapters // ignore: cast_nullable_to_non_nullable
as List<ChapterSummary>,
  ));
}
/// Create a copy of TocResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookMetaCopyWith<$Res> get book {
  
  return $BookMetaCopyWith<$Res>(_self.book, (value) {
    return _then(_self.copyWith(book: value));
  });
}
}


/// Adds pattern-matching-related methods to [TocResponse].
extension TocResponsePatterns on TocResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TocResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TocResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TocResponse value)  $default,){
final _that = this;
switch (_that) {
case _TocResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TocResponse value)?  $default,){
final _that = this;
switch (_that) {
case _TocResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( BookMeta book,  List<ChapterSummary> chapters)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TocResponse() when $default != null:
return $default(_that.book,_that.chapters);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( BookMeta book,  List<ChapterSummary> chapters)  $default,) {final _that = this;
switch (_that) {
case _TocResponse():
return $default(_that.book,_that.chapters);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( BookMeta book,  List<ChapterSummary> chapters)?  $default,) {final _that = this;
switch (_that) {
case _TocResponse() when $default != null:
return $default(_that.book,_that.chapters);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TocResponse implements TocResponse {
  const _TocResponse({required this.book, required final  List<ChapterSummary> chapters}): _chapters = chapters;
  factory _TocResponse.fromJson(Map<String, dynamic> json) => _$TocResponseFromJson(json);

@override final  BookMeta book;
 final  List<ChapterSummary> _chapters;
@override List<ChapterSummary> get chapters {
  if (_chapters is EqualUnmodifiableListView) return _chapters;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_chapters);
}


/// Create a copy of TocResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TocResponseCopyWith<_TocResponse> get copyWith => __$TocResponseCopyWithImpl<_TocResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TocResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TocResponse&&(identical(other.book, book) || other.book == book)&&const DeepCollectionEquality().equals(other._chapters, _chapters));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,book,const DeepCollectionEquality().hash(_chapters));

@override
String toString() {
  return 'TocResponse(book: $book, chapters: $chapters)';
}


}

/// @nodoc
abstract mixin class _$TocResponseCopyWith<$Res> implements $TocResponseCopyWith<$Res> {
  factory _$TocResponseCopyWith(_TocResponse value, $Res Function(_TocResponse) _then) = __$TocResponseCopyWithImpl;
@override @useResult
$Res call({
 BookMeta book, List<ChapterSummary> chapters
});


@override $BookMetaCopyWith<$Res> get book;

}
/// @nodoc
class __$TocResponseCopyWithImpl<$Res>
    implements _$TocResponseCopyWith<$Res> {
  __$TocResponseCopyWithImpl(this._self, this._then);

  final _TocResponse _self;
  final $Res Function(_TocResponse) _then;

/// Create a copy of TocResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? book = null,Object? chapters = null,}) {
  return _then(_TocResponse(
book: null == book ? _self.book : book // ignore: cast_nullable_to_non_nullable
as BookMeta,chapters: null == chapters ? _self._chapters : chapters // ignore: cast_nullable_to_non_nullable
as List<ChapterSummary>,
  ));
}

/// Create a copy of TocResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookMetaCopyWith<$Res> get book {
  
  return $BookMetaCopyWith<$Res>(_self.book, (value) {
    return _then(_self.copyWith(book: value));
  });
}
}

// dart format on
