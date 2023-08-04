import 'package:meta/meta.dart';

/// User id type.
typedef UserId = String;

/// {@template user}
/// The user entry model.
/// {@endtemplate}
sealed class User with _UserPatternMatching, _UserShortcuts {
  /// {@macro user}
  const User._();

  /// {@macro user}
  @literal
  const factory User.unauthenticated() = UnauthenticatedUser;

  /// {@macro user}
  const factory User.authenticated({
    required UserId id,
  }) = AuthenticatedUser;

  /// The user's id.
  abstract final UserId? id;
}

/// {@macro user}
///
/// Unauthenticated user.
class UnauthenticatedUser extends User {
  /// {@macro user}
  const UnauthenticatedUser() : super._();

  @override
  UserId? get id => null;

  @override
  @nonVirtual
  bool get isAuthenticated => false;

  @override
  T map<T>({
    required T Function(UnauthenticatedUser user) unauthenticated,
    required T Function(AuthenticatedUser user) authenticated,
  }) =>
      unauthenticated(this);

  @override
  int get hashCode => -2;

  @override
  bool operator ==(Object other) => identical(this, other) || other is UnauthenticatedUser && id == other.id;

  @override
  String toString() => 'UnauthenticatedUser()';
}

final class AuthenticatedUser extends User {
  const AuthenticatedUser({
    required this.id,
  }) : super._();

  factory AuthenticatedUser.fromJson(Map<String, Object> json) {
    if (json.isEmpty) throw FormatException('Json is empty', json);
    if (json
        case <String, Object?>{
          'id': UserId id,
        })
      return AuthenticatedUser(
        id: id,
      );
    throw FormatException('Invalid json format', json);
  }

  @override
  @nonVirtual
  final UserId id;

  @override
  @nonVirtual
  bool get isAuthenticated => true;

  @override
  T map<T>({
    required T Function(UnauthenticatedUser user) unauthenticated,
    required T Function(AuthenticatedUser user) authenticated,
  }) =>
      authenticated(this);

  Map<String, Object> toJson() => {
        'id': id,
      };

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AuthenticatedUser && id == other.id;

  @override
  String toString() => 'AuthenticatedUser(id: $id)';
}

mixin _UserPatternMatching {
  /// Pattern matching on [User] subclasses.
  T map<T>({
    required T Function(UnauthenticatedUser user) unauthenticated,
    required T Function(AuthenticatedUser user) authenticated,
  });

  /// Pattern matching on [User] subclasses.
  T maybeMap<T>({
    required T Function() orElse,
    T Function(UnauthenticatedUser user)? unauthenticated,
    T Function(AuthenticatedUser user)? authenticated,
  }) =>
      map<T>(
        unauthenticated: (user) => unauthenticated?.call(user) ?? orElse(),
        authenticated: (user) => authenticated?.call(user) ?? orElse(),
      );

  /// Pattern matching on [User] subclasses.
  T? mapOrNull<T>({
    T Function(UnauthenticatedUser user)? unauthenticated,
    T Function(AuthenticatedUser user)? authenticated,
  }) =>
      map<T?>(
        unauthenticated: (user) => unauthenticated?.call(user),
        authenticated: (user) => authenticated?.call(user),
      );
}

mixin _UserShortcuts on _UserPatternMatching {
  /// User is authenticated.
  bool get isAuthenticated;

  /// User is not authenticated.
  bool get isNotAuthenticated => !isAuthenticated;
}
