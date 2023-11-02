import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:spinifyapp/src/feature/dependencies/model/dependencies.dart';

/// {@template dependencies_scope}
/// DependenciesScope widget.
/// {@endtemplate}
class DependenciesScope extends StatelessWidget {
  /// {@macro dependencies_scope}
  const DependenciesScope({
    required this.initialization,
    required this.splashScreen,
    required this.child,
    this.errorBuilder,
    super.key,
  });

  /// The state from the closest instance of this class
  /// that encloses the given context, if any.
  /// e.g. `DependenciesScope.maybeOf(context)`.
  static Dependencies? maybeOf(BuildContext context) => switch (context
          .getElementForInheritedWidgetOfExactType<_InheritedDependencies>()
          ?.widget) {
        _InheritedDependencies inheritedDependencies =>
          inheritedDependencies.dependencies,
        _ => null,
      };

  static Never _notFoundInheritedWidgetOfExactType() => throw ArgumentError(
        'Out of scope, not found inherited widget '
            'a DependenciesScope of the exact type',
        'out_of_scope',
      );

  /// The state from the closest instance of this class
  /// that encloses the given context.
  /// e.g. `DependenciesScope.of(context)`
  static Dependencies of(BuildContext context) =>
      maybeOf(context) ?? _notFoundInheritedWidgetOfExactType();

  /// Initialization of the dependencies.
  final Future<Dependencies> initialization;

  /// Splash screen widget.
  final Widget splashScreen;

  /// Error widget.
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;

  /// The widget below this widget in the tree.
  final Widget child;

  @override
  Widget build(BuildContext context) => FutureBuilder<Dependencies>(
        future: initialization,
        builder: (context, snapshot) =>
            switch ((snapshot.data, snapshot.error, snapshot.stackTrace)) {
          (Dependencies dependencies, null, null) => _InheritedDependencies(
              dependencies: dependencies,
              child: child,
            ),
          (_, Object error, StackTrace? stackTrace) =>
            errorBuilder?.call(error, stackTrace) ?? ErrorWidget(error),
          _ => splashScreen,
        },
      );
}

/// {@template inherited_dependencies}
/// InheritedDependencies widget.
/// {@endtemplate}
class _InheritedDependencies extends InheritedWidget {
  /// {@macro inherited_dependencies}
  const _InheritedDependencies({
    required this.dependencies,
    required super.child,
  });

  final Dependencies dependencies;

  @override
  bool updateShouldNotify(covariant _InheritedDependencies oldWidget) => false;
}
