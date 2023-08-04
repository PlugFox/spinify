import 'dart:async';

import 'package:spinifyapp/src/common/controller/droppable_controller_concurrency.dart';
import 'package:spinifyapp/src/common/controller/state_controller.dart';
import 'package:spinifyapp/src/common/util/error_util.dart';
import 'package:spinifyapp/src/feature/authentication/controller/authentication_state.dart';
import 'package:spinifyapp/src/feature/authentication/data/authentication_repository.dart';
import 'package:spinifyapp/src/feature/authentication/model/user.dart';

final class AuthenticationController
    extends StateController<AuthenticationState>
    with DroppableControllerConcurrency {
  AuthenticationController(
      {required IAuthenticationRepository repository,
      super.initialState =
          const AuthenticationState.idle(user: User.unauthenticated())})
      : _repository = repository {
    _userSubscription = repository
        .userChanges()
        .map<AuthenticationState>((u) => AuthenticationState.idle(user: u))
        .where((newState) =>
            state.isProcessing || !identical(newState.user, state.user))
        .listen(setState);
  }

  final IAuthenticationRepository _repository;
  StreamSubscription<AuthenticationState>? _userSubscription;

  void signInAnonymously() => handle(
        () async {
          setState(AuthenticationState.processing(
              user: state.user, message: 'Logging in...'));
          await _repository.signInAnonymously();
        },
        (error, _) => setState(AuthenticationState.idle(
            user: state.user, error: ErrorUtil.formatMessage(error))),
        () => setState(AuthenticationState.idle(user: state.user)),
      );

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
