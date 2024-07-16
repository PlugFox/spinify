import 'package:meta/meta.dart';

/// Method used manually by the user.
@internal
const SpinifyAnnotation interactive = SpinifyAnnotation('interactive');

/// Method used by the side effect.
@internal
const SpinifyAnnotation sideEffect = SpinifyAnnotation('sideEffect');

// TODO(plugfox): add more annotations

/// Annotation for Spinify library.
@internal
@immutable
final class SpinifyAnnotation {
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
