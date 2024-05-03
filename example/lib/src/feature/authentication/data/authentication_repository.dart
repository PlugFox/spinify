import 'dart:async';
import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:spinify/spinify.old.dart';
import 'package:spinifyapp/src/feature/authentication/model/sign_in_data.dart';
import 'package:spinifyapp/src/feature/authentication/model/user.dart';

abstract interface class IAuthenticationRepository {
  Stream<User> userChanges();
  FutureOr<User> getUser();
  FutureOr<String> getToken();
  Future<void> signIn(SignInData data);
  Future<void> signOut();
}

class AuthenticationRepositoryImpl implements IAuthenticationRepository {
  AuthenticationRepositoryImpl();

  final StreamController<User> _userController =
      StreamController<User>.broadcast();
  User _user = const User.unauthenticated();

  @override
  FutureOr<User> getUser() => _user;

  @override
  Future<String> getToken() async {
    switch (_user) {
      case AuthenticatedUser user:
        final AuthenticatedUser(
          :String username,
          :String token,
          :String channel
        ) = user;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        SpinifyJWT jwt = SpinifyJWT(
          sub: username,
          exp: now + (24 * 60 * 60),
          iat: now,
          info: <String, Object?>{
            'username': username,
          },
          channels: <String>[channel],
        );
        return jwt.encode(token);
      case UnauthenticatedUser _:
        throw Exception('User is not authenticated');
    }
  }

  @override
  Stream<User> userChanges() => _userController.stream;

  @override
  Future<void> signIn(SignInData data) {
    String buildChannelName(String channel, [String? secret]) =>
        switch (secret) {
          null || '' => channel,
          String secret => '$channel'
              '#'
              '${hex.encode(utf8.encoder.fuse(sha256).convert(secret).bytes)}',
        };
    return Future<void>.sync(
      () => _userController.add(
        _user = User.authenticated(
            username: data.username,
            endpoint: data.endpoint,
            token: data.token,
            channel: buildChannelName(data.channel, data.secret),
            secret: switch (data.secret) {
              null || '' => null,
              String secret => secret,
            }),
      ),
    );
  }

  @override
  Future<void> signOut() => Future<void>.sync(
        () => _userController.add(
          _user = const User.unauthenticated(),
        ),
      );
}
