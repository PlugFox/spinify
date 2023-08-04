import 'dart:async';

import 'package:l/l.dart';
import 'package:meta/meta.dart';
import 'package:platform_info/platform_info.dart';
import 'package:spinifyapp/src/common/constant/config.dart';
import 'package:spinifyapp/src/common/constant/pubspec.yaml.g.dart';
import 'package:spinifyapp/src/common/controller/controller.dart';
import 'package:spinifyapp/src/common/controller/controller_observer.dart';
import 'package:spinifyapp/src/common/util/screen_util.dart';
import 'package:spinifyapp/src/feature/authentication/data/authentication_repository.dart';
import 'package:spinifyapp/src/feature/dependencies/initialization/platform/initialization_vm.dart'
    // ignore: uri_does_not_exist
    if (dart.library.html) 'package:spinifyapp/src/feature/dependencies/initialization/platform/initialization_js.dart';
import 'package:spinifyapp/src/feature/dependencies/model/app_metadata.dart';
import 'package:spinifyapp/src/feature/dependencies/model/dependencies.dart';

typedef _InitializationStep = FutureOr<void> Function(
    _MutableDependencies dependencies);

class _MutableDependencies implements Dependencies {
  @override
  late AppMetadata appMetadata;

  @override
  late IAuthenticationRepository authenticationRepository;
}

@internal
mixin InitializeDependencies {
  /// Initializes the app and returns a [Dependencies] object
  @protected
  Future<Dependencies> $initializeDependencies({
    void Function(int progress, String message)? onProgress,
  }) async {
    final steps = _initializationSteps;
    final dependencies = _MutableDependencies();
    final totalSteps = steps.length;
    for (var currentStep = 0; currentStep < totalSteps; currentStep++) {
      final step = steps[currentStep];
      final percent = (currentStep * 100 ~/ totalSteps).clamp(0, 100);
      onProgress?.call(percent, step.$1);
      l.v6(
          'Initialization | $currentStep/$totalSteps ($percent%) | "${step.$1}"');
      await step.$2(dependencies);
    }
    return dependencies;
  }

  List<(String, _InitializationStep)> get _initializationSteps =>
      <(String, _InitializationStep)>[
        (
          'Platform pre-initialization',
          (_) => $platformInitialization(),
        ),
        (
          'Creating app metadata',
          (dependencies) => dependencies.appMetadata = AppMetadata(
                environment: Config.environment.value,
                isWeb: platform.isWeb,
                isRelease: platform.buildMode.isRelease,
                appName: Pubspec.name,
                appVersion: Pubspec.version.canonical,
                appVersionMajor: Pubspec.version.major,
                appVersionMinor: Pubspec.version.minor,
                appVersionPatch: Pubspec.version.patch,
                appBuildTimestamp: Pubspec.version.build.isNotEmpty
                    ? (int.tryParse(
                            Pubspec.version.build.firstOrNull ?? '-1') ??
                        -1)
                    : -1,
                operatingSystem: platform.operatingSystem.name,
                processorsCount: platform.numberOfProcessors,
                appLaunchedTimestamp: DateTime.now(),
                locale: platform.locale,
                deviceVersion: platform.version,
                deviceScreenSize: ScreenUtil.screenSize().representation,
              ),
        ),
        (
          'Observer state managment',
          (_) => Controller.observer = ControllerObserver(),
        ),
        (
          'Initializing analytics',
          (_) {},
        ),
        (
          'Log app open',
          (_) {},
        ),
        (
          'Get remote config',
          (_) {},
        ),
        (
          'Authentication repository',
          (dependencies) => dependencies.authenticationRepository =
              AuthenticationRepositoryFake(),
        ),
        (
          'Fake delay 1',
          (_) => Future<void>.delayed(const Duration(seconds: 1)),
        ),
        (
          'Fake delay 2',
          (_) => Future<void>.delayed(const Duration(seconds: 1)),
        ),
        (
          'Fake delay 3',
          (_) => Future<void>.delayed(const Duration(seconds: 1)),
        ),
      ];
}
