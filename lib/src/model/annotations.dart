import 'package:meta/meta.dart';

/// Method used manually by the user.
@internal
const SpinifyAnnotation interactive = SpinifyAnnotation('interactive');

/// Method used by the side effect.
@internal
const SpinifyAnnotation sideEffect = SpinifyAnnotation('sideEffect');

/// Method that shouldn't throw an any exception.
@internal
const SpinifyAnnotation safe = SpinifyAnnotation('safe');

/// Method that can throw an exception.
@internal
const SpinifyAnnotation unsafe = SpinifyAnnotation('unsafe');

/// Annotation for Spinify library.
@internal
@immutable
class SpinifyAnnotation {
  @literal
  const SpinifyAnnotation(
    this.name, {
    this.meta = const <String, Object?>{},
  });

  /// Annotation name.
  final String name;

  /// Annotation metadata.
  final Map<String, Object?> meta;
}

/// Annotation for Spinify library that mark methods as possible to throw
/// exceptions of specified types.
@internal
@immutable
class Throws extends SpinifyAnnotation {
  @literal
  const Throws(this.exceptions) : super('throws');

  /// List of exceptions that can be thrown.
  final List<Type> exceptions;
}
