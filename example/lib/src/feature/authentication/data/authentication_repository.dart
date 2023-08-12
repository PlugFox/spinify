import 'dart:async';

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
        return user.token;
      case UnauthenticatedUser _:
        throw Exception('User is not authenticated');
    }
  }

  @override
  Stream<User> userChanges() => _userController.stream;

  @override
  Future<void> signIn(SignInData data) => Future<void>.sync(
        () => _userController.add(
          _user = User.authenticated(
            username: data.username,
            endpoint: data.endpoint,
            token: data.token,
            channel: data.channel,
            secret: data.secret,
          ),
        ),
      );

  @override
  Future<void> signOut() => Future<void>.sync(
        () => _userController.add(
          _user = const User.unauthenticated(),
        ),
      );
}
