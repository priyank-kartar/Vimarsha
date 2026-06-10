// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_context.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatContext {

 String get passage; String? get figureCaption; String get bookTitle; String get chapterTitle;
/// Create a copy of ChatContext
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatContextCopyWith<ChatContext> get copyWith => _$ChatContextCopyWithImpl<ChatContext>(this as ChatContext, _$identity);

  /// Serializes this ChatContext to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatContext&&(identical(other.passage, passage) || other.passage == passage)&&(identical(other.figureCaption, figureCaption) || other.figureCaption == figureCaption)&&(identical(other.bookTitle, bookTitle) || other.bookTitle == bookTitle)&&(identical(other.chapterTitle, chapterTitle) || other.chapterTitle == chapterTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,passage,figureCaption,bookTitle,chapterTitle);

@override
String toString() {
  return 'ChatContext(passage: $passage, figureCaption: $figureCaption, bookTitle: $bookTitle, chapterTitle: $chapterTitle)';
}


}

/// @nodoc
abstract mixin class $ChatContextCopyWith<$Res>  {
  factory $ChatContextCopyWith(ChatContext value, $Res Function(ChatContext) _then) = _$ChatContextCopyWithImpl;
@useResult
$Res call({
 String passage, String? figureCaption, String bookTitle, String chapterTitle
});




}
/// @nodoc
class _$ChatContextCopyWithImpl<$Res>
    implements $ChatContextCopyWith<$Res> {
  _$ChatContextCopyWithImpl(this._self, this._then);

  final ChatContext _self;
  final $Res Function(ChatContext) _then;

/// Create a copy of ChatContext
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? passage = null,Object? figureCaption = freezed,Object? bookTitle = null,Object? chapterTitle = null,}) {
  return _then(_self.copyWith(
passage: null == passage ? _self.passage : passage // ignore: cast_nullable_to_non_nullable
as String,figureCaption: freezed == figureCaption ? _self.figureCaption : figureCaption // ignore: cast_nullable_to_non_nullable
as String?,bookTitle: null == bookTitle ? _self.bookTitle : bookTitle // ignore: cast_nullable_to_non_nullable
as String,chapterTitle: null == chapterTitle ? _self.chapterTitle : chapterTitle // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatContext].
extension ChatContextPatterns on ChatContext {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatContext value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatContext() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatContext value)  $default,){
final _that = this;
switch (_that) {
case _ChatContext():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatContext value)?  $default,){
final _that = this;
switch (_that) {
case _ChatContext() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String passage,  String? figureCaption,  String bookTitle,  String chapterTitle)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatContext() when $default != null:
return $default(_that.passage,_that.figureCaption,_that.bookTitle,_that.chapterTitle);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String passage,  String? figureCaption,  String bookTitle,  String chapterTitle)  $default,) {final _that = this;
switch (_that) {
case _ChatContext():
return $default(_that.passage,_that.figureCaption,_that.bookTitle,_that.chapterTitle);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String passage,  String? figureCaption,  String bookTitle,  String chapterTitle)?  $default,) {final _that = this;
switch (_that) {
case _ChatContext() when $default != null:
return $default(_that.passage,_that.figureCaption,_that.bookTitle,_that.chapterTitle);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChatContext implements ChatContext {
  const _ChatContext({required this.passage, this.figureCaption, required this.bookTitle, required this.chapterTitle});
  factory _ChatContext.fromJson(Map<String, dynamic> json) => _$ChatContextFromJson(json);

@override final  String passage;
@override final  String? figureCaption;
@override final  String bookTitle;
@override final  String chapterTitle;

/// Create a copy of ChatContext
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatContextCopyWith<_ChatContext> get copyWith => __$ChatContextCopyWithImpl<_ChatContext>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatContextToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatContext&&(identical(other.passage, passage) || other.passage == passage)&&(identical(other.figureCaption, figureCaption) || other.figureCaption == figureCaption)&&(identical(other.bookTitle, bookTitle) || other.bookTitle == bookTitle)&&(identical(other.chapterTitle, chapterTitle) || other.chapterTitle == chapterTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,passage,figureCaption,bookTitle,chapterTitle);

@override
String toString() {
  return 'ChatContext(passage: $passage, figureCaption: $figureCaption, bookTitle: $bookTitle, chapterTitle: $chapterTitle)';
}


}

/// @nodoc
abstract mixin class _$ChatContextCopyWith<$Res> implements $ChatContextCopyWith<$Res> {
  factory _$ChatContextCopyWith(_ChatContext value, $Res Function(_ChatContext) _then) = __$ChatContextCopyWithImpl;
@override @useResult
$Res call({
 String passage, String? figureCaption, String bookTitle, String chapterTitle
});




}
/// @nodoc
class __$ChatContextCopyWithImpl<$Res>
    implements _$ChatContextCopyWith<$Res> {
  __$ChatContextCopyWithImpl(this._self, this._then);

  final _ChatContext _self;
  final $Res Function(_ChatContext) _then;

/// Create a copy of ChatContext
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? passage = null,Object? figureCaption = freezed,Object? bookTitle = null,Object? chapterTitle = null,}) {
  return _then(_ChatContext(
passage: null == passage ? _self.passage : passage // ignore: cast_nullable_to_non_nullable
as String,figureCaption: freezed == figureCaption ? _self.figureCaption : figureCaption // ignore: cast_nullable_to_non_nullable
as String?,bookTitle: null == bookTitle ? _self.bookTitle : bookTitle // ignore: cast_nullable_to_non_nullable
as String,chapterTitle: null == chapterTitle ? _self.chapterTitle : chapterTitle // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
