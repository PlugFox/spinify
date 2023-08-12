import 'package:spinifyapp/src/feature/authentication/data/authentication_repository.dart';
import 'package:spinifyapp/src/feature/chat/data/chat_repository.dart';
import 'package:spinifyapp/src/feature/dependencies/model/app_metadata.dart';

abstract interface class Dependencies {
  /// App metadata
  abstract final AppMetadata appMetadata;

  /// Authentication repository
  abstract final IAuthenticationRepository authenticationRepository;

  /// Chat repository
  abstract final IChatRepository chatRepository;
}
