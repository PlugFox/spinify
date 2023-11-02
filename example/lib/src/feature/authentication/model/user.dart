import 'package:meta/meta.dart';

/// User username type.
typedef Username = String;

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
    required Username username,
    required String endpoint,
    required String token,
    required String channel,
    String? secret,
  }) = AuthenticatedUser;

  /// The user's username.
  abstract final Username? username;
}

/// {@macro user}
///
/// Unauthenticated user.
class UnauthenticatedUser extends User {
  /// {@macro user}
  const UnauthenticatedUser() : super._();

  @override
  Username? get username => null;

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
  bool operator ==(Object other) =>
      identical(this, other) || other is UnauthenticatedUser;

  @override
  String toString() => 'UnauthenticatedUser()';
}

final class AuthenticatedUser extends User {
  const AuthenticatedUser({
    required this.username,
    required this.endpoint,
    required this.token,
    required this.channel,
    this.secret,
  }) : super._();

  factory AuthenticatedUser.fromJson(Map<String, Object> json) {
    if (json.isEmpty) throw FormatException('Json is empty', json);
    if (json
        case <String, Object?>{
          'username': Username username,
          'endpoint': String endpoint,
          'token': String token,
          'channel': String channel,
          'secret': String? secret,
        })
      return AuthenticatedUser(
        username: username,
        endpoint: endpoint,
        token: token,
        channel: channel,
        secret: secret,
      );
    throw FormatException('Invalid json format', json);
  }

  @override
  @nonVirtual
  final Username username;

  /// Centrifuge endpoint
  final String endpoint;

  /// Centrifuge HMAC token for JWT authentication.
  /// **BEWARE**: You should not store the token in the real app!
  final String token;

  /// Centrifuge channel.
  final String channel;

  /// Centrifuge secret (optional)
  final String? secret;

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
        'username': username,
      };

  @override
  int get hashCode => username.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthenticatedUser &&
          username == other.username &&
          endpoint == other.endpoint &&
          token == other.token &&
          channel == other.channel &&
          secret == other.secret;

  @override
  String toString() => 'AuthenticatedUser(username: $username)';
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
