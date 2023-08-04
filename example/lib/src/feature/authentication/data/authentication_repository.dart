import 'dart:async';

import 'package:spinifyapp/src/feature/authentication/model/user.dart';

abstract interface class IAuthenticationRepository {
  Stream<User> userChanges();
  FutureOr<User> getUser();
  Future<void> signInAnonymously();

  /* Future<void> sendSignInWithEmailLink(String email);
  Future<void> signInWithEmailLink(String email, String emailLink);
  Future<void> signInWithEmailAndPassword(String email, String password);
  Future<void> signInWithFacebook();
  Future<void> signInWithApple();
  Future<void> signInWithTwitter();
  Future<void> signInWithGithub();
  Future<void> signInWithPhoneNumber(String phoneNumber);
  Future<void> sendPasswordResetEmail(String email);
  Future<void> confirmPasswordReset(String code, String newPassword);
  Future<void> signUpWithEmailAndPassword(String email, String password);
  Future<void> deleteUser();
  Future<bool> isSignedIn();
  Future<void> signInWithGoogle();
  Future<void> signOut(); */
}

class AuthenticationRepositoryFake implements IAuthenticationRepository {
  final StreamController<User> _userController =
      StreamController<User>.broadcast();
  User _user = const User.unauthenticated();

  @override
  FutureOr<User> getUser() => _user;

  @override
  Stream<User> userChanges() => _userController.stream;

  @override
  Future<void> signInAnonymously() => Future<void>.sync(() => _userController
      .add(_user = const User.authenticated(id: 'anonymous-user-id')));
}
