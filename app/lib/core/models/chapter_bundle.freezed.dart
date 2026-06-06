// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chapter_bundle.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChapterBundle {

 String get chapterId; String get title; List<Block> get blocks; List<Figure> get figureMap; String? get audio; Map<String, List<int>> get paraTimings;
/// Create a copy of ChapterBundle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChapterBundleCopyWith<ChapterBundle> get copyWith => _$ChapterBundleCopyWithImpl<ChapterBundle>(this as ChapterBundle, _$identity);

  /// Serializes this ChapterBundle to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChapterBundle&&(identical(other.chapterId, chapterId) || other.chapterId == chapterId)&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other.blocks, blocks)&&const DeepCollectionEquality().equals(other.figureMap, figureMap)&&(identical(other.audio, audio) || other.audio == audio)&&const DeepCollectionEquality().equals(other.paraTimings, paraTimings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chapterId,title,const DeepCollectionEquality().hash(blocks),const DeepCollectionEquality().hash(figureMap),audio,const DeepCollectionEquality().hash(paraTimings));

@override
String toString() {
  return 'ChapterBundle(chapterId: $chapterId, title: $title, blocks: $blocks, figureMap: $figureMap, audio: $audio, paraTimings: $paraTimings)';
}


}

/// @nodoc
abstract mixin class $ChapterBundleCopyWith<$Res>  {
  factory $ChapterBundleCopyWith(ChapterBundle value, $Res Function(ChapterBundle) _then) = _$ChapterBundleCopyWithImpl;
@useResult
$Res call({
 String chapterId, String title, List<Block> blocks, List<Figure> figureMap, String? audio, Map<String, List<int>> paraTimings
});




}
/// @nodoc
class _$ChapterBundleCopyWithImpl<$Res>
    implements $ChapterBundleCopyWith<$Res> {
  _$ChapterBundleCopyWithImpl(this._self, this._then);

  final ChapterBundle _self;
  final $Res Function(ChapterBundle) _then;

/// Create a copy of ChapterBundle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chapterId = null,Object? title = null,Object? blocks = null,Object? figureMap = null,Object? audio = freezed,Object? paraTimings = null,}) {
  return _then(_self.copyWith(
chapterId: null == chapterId ? _self.chapterId : chapterId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,blocks: null == blocks ? _self.blocks : blocks // ignore: cast_nullable_to_non_nullable
as List<Block>,figureMap: null == figureMap ? _self.figureMap : figureMap // ignore: cast_nullable_to_non_nullable
as List<Figure>,audio: freezed == audio ? _self.audio : audio // ignore: cast_nullable_to_non_nullable
as String?,paraTimings: null == paraTimings ? _self.paraTimings : paraTimings // ignore: cast_nullable_to_non_nullable
as Map<String, List<int>>,
  ));
}

}


/// Adds pattern-matching-related methods to [ChapterBundle].
extension ChapterBundlePatterns on ChapterBundle {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChapterBundle value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChapterBundle() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChapterBundle value)  $default,){
final _that = this;
switch (_that) {
case _ChapterBundle():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChapterBundle value)?  $default,){
final _that = this;
switch (_that) {
case _ChapterBundle() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String chapterId,  String title,  List<Block> blocks,  List<Figure> figureMap,  String? audio,  Map<String, List<int>> paraTimings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChapterBundle() when $default != null:
return $default(_that.chapterId,_that.title,_that.blocks,_that.figureMap,_that.audio,_that.paraTimings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String chapterId,  String title,  List<Block> blocks,  List<Figure> figureMap,  String? audio,  Map<String, List<int>> paraTimings)  $default,) {final _that = this;
switch (_that) {
case _ChapterBundle():
return $default(_that.chapterId,_that.title,_that.blocks,_that.figureMap,_that.audio,_that.paraTimings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String chapterId,  String title,  List<Block> blocks,  List<Figure> figureMap,  String? audio,  Map<String, List<int>> paraTimings)?  $default,) {final _that = this;
switch (_that) {
case _ChapterBundle() when $default != null:
return $default(_that.chapterId,_that.title,_that.blocks,_that.figureMap,_that.audio,_that.paraTimings);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChapterBundle implements ChapterBundle {
  const _ChapterBundle({required this.chapterId, required this.title, required final  List<Block> blocks, required final  List<Figure> figureMap, this.audio, final  Map<String, List<int>> paraTimings = const <String, List<int>>{}}): _blocks = blocks,_figureMap = figureMap,_paraTimings = paraTimings;
  factory _ChapterBundle.fromJson(Map<String, dynamic> json) => _$ChapterBundleFromJson(json);

@override final  String chapterId;
@override final  String title;
 final  List<Block> _blocks;
@override List<Block> get blocks {
  if (_blocks is EqualUnmodifiableListView) return _blocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_blocks);
}

 final  List<Figure> _figureMap;
@override List<Figure> get figureMap {
  if (_figureMap is EqualUnmodifiableListView) return _figureMap;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_figureMap);
}

@override final  String? audio;
 final  Map<String, List<int>> _paraTimings;
@override@JsonKey() Map<String, List<int>> get paraTimings {
  if (_paraTimings is EqualUnmodifiableMapView) return _paraTimings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_paraTimings);
}


/// Create a copy of ChapterBundle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChapterBundleCopyWith<_ChapterBundle> get copyWith => __$ChapterBundleCopyWithImpl<_ChapterBundle>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChapterBundleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChapterBundle&&(identical(other.chapterId, chapterId) || other.chapterId == chapterId)&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other._blocks, _blocks)&&const DeepCollectionEquality().equals(other._figureMap, _figureMap)&&(identical(other.audio, audio) || other.audio == audio)&&const DeepCollectionEquality().equals(other._paraTimings, _paraTimings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chapterId,title,const DeepCollectionEquality().hash(_blocks),const DeepCollectionEquality().hash(_figureMap),audio,const DeepCollectionEquality().hash(_paraTimings));

@override
String toString() {
  return 'ChapterBundle(chapterId: $chapterId, title: $title, blocks: $blocks, figureMap: $figureMap, audio: $audio, paraTimings: $paraTimings)';
}


}

/// @nodoc
abstract mixin class _$ChapterBundleCopyWith<$Res> implements $ChapterBundleCopyWith<$Res> {
  factory _$ChapterBundleCopyWith(_ChapterBundle value, $Res Function(_ChapterBundle) _then) = __$ChapterBundleCopyWithImpl;
@override @useResult
$Res call({
 String chapterId, String title, List<Block> blocks, List<Figure> figureMap, String? audio, Map<String, List<int>> paraTimings
});




}
/// @nodoc
class __$ChapterBundleCopyWithImpl<$Res>
    implements _$ChapterBundleCopyWith<$Res> {
  __$ChapterBundleCopyWithImpl(this._self, this._then);

  final _ChapterBundle _self;
  final $Res Function(_ChapterBundle) _then;

/// Create a copy of ChapterBundle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chapterId = null,Object? title = null,Object? blocks = null,Object? figureMap = null,Object? audio = freezed,Object? paraTimings = null,}) {
  return _then(_ChapterBundle(
chapterId: null == chapterId ? _self.chapterId : chapterId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,blocks: null == blocks ? _self._blocks : blocks // ignore: cast_nullable_to_non_nullable
as List<Block>,figureMap: null == figureMap ? _self._figureMap : figureMap // ignore: cast_nullable_to_non_nullable
as List<Figure>,audio: freezed == audio ? _self.audio : audio // ignore: cast_nullable_to_non_nullable
as String?,paraTimings: null == paraTimings ? _self._paraTimings : paraTimings // ignore: cast_nullable_to_non_nullable
as Map<String, List<int>>,
  ));
}


}

// dart format on
