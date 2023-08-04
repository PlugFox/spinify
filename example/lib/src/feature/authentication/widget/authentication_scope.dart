import 'package:flutter/widgets.dart';
import 'package:spinifyapp/src/feature/authentication/controller/authentication_controller.dart';
import 'package:spinifyapp/src/feature/authentication/model/user.dart';
import 'package:spinifyapp/src/feature/dependencies/widget/dependencies_scope.dart';

/// {@template authentication_scope}
/// AuthenticationScope widget.
/// {@endtemplate}
class AuthenticationScope extends StatefulWidget {
  /// {@macro authentication_scope}
  const AuthenticationScope({
    required this.signInScreen,
    required this.child,
    super.key,
  });

  /// Sign In screen for unauthenticated users.
  final Widget signInScreen;

  /// The widget below this widget in the tree.
  final Widget child;

  /// User of the authentication scope.
  static User userOf(BuildContext context, {bool listen = true}) =>
      _InheritedAuthenticationScope.of(context, listen: listen).user;

  /// Authentication controller of the authentication scope.
  static AuthenticationController controllerOf(BuildContext context) =>
      _InheritedAuthenticationScope.of(context, listen: false).controller;

  @override
  State<AuthenticationScope> createState() => _AuthenticationScopeState();
}

/// State for widget AuthenticationScope.
class _AuthenticationScopeState extends State<AuthenticationScope> {
  late final AuthenticationController _authenticationController;
  User _user = const User.unauthenticated();

  @override
  void initState() {
    super.initState();
    _authenticationController = AuthenticationController(
      repository: DependenciesScope.of(context).authenticationRepository,
    )..addListener(_onAuthenticationControllerChanged);
  }

  @override
  void dispose() {
    _authenticationController
      ..removeListener(_onAuthenticationControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _onAuthenticationControllerChanged() {
    final user = _authenticationController.state.user;
    if (!identical(_user, user)) setState(() => _user = user);
  }

  @override
  Widget build(BuildContext context) => _InheritedAuthenticationScope(
        controller: _authenticationController,
        user: _user,
        child: switch (_user) {
          UnauthenticatedUser _ => widget.signInScreen,
          AuthenticatedUser _ => widget.child,
        },
      );
}

/// Inherited widget for quick access in the element tree.
class _InheritedAuthenticationScope extends InheritedWidget {
  const _InheritedAuthenticationScope({
    required this.controller,
    required this.user,
    required super.child,
  });

  final AuthenticationController controller;
  final User user;

  /// The state from the closest instance of this class
  /// that encloses the given context, if any.
  /// For example: `AuthenticationScope.maybeOf(context)`.
  static _InheritedAuthenticationScope? maybeOf(BuildContext context,
          {bool listen = true}) =>
      listen
          ? context.dependOnInheritedWidgetOfExactType<
              _InheritedAuthenticationScope>()
          : context
              .getInheritedWidgetOfExactType<_InheritedAuthenticationScope>();

  static Never _notFoundInheritedWidgetOfExactType() => throw ArgumentError(
        'Out of scope, not found inherited widget '
            'a _InheritedAuthenticationScope of the exact type',
        'out_of_scope',
      );

  /// The state from the closest instance of this class
  /// that encloses the given context.
  /// For example: `AuthenticationScope.of(context)`.
  static _InheritedAuthenticationScope of(BuildContext context,
          {bool listen = true}) =>
      maybeOf(context, listen: listen) ?? _notFoundInheritedWidgetOfExactType();

  @override
  bool updateShouldNotify(covariant _InheritedAuthenticationScope oldWidget) =>
      !identical(user, oldWidget.user);
}
