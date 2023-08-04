import 'dart:async';

import 'package:flutter/material.dart';
import 'package:l/l.dart';
import 'package:spinifyapp/src/common/util/logger_util.dart';
import 'package:spinifyapp/src/common/widget/app.dart';
import 'package:spinifyapp/src/feature/dependencies/initialization/initialization.dart';
import 'package:spinifyapp/src/feature/dependencies/widget/dependencies_scope.dart';
import 'package:spinifyapp/src/feature/dependencies/widget/initialization_splash_screen.dart';

void main() => l.capture<void>(
      () => runZonedGuarded<void>(
        () {
          final initialization = InitializationExecutor();
          runApp(
            DependenciesScope(
              initialization: initialization(),
              splashScreen: InitializationSplashScreen(
                progress: initialization,
              ),
              child: const App(),
            ),
          );
        },
        l.e,
      ),
      const LogOptions(
        handlePrint: true,
        messageFormatting: LoggerUtil.messageFormatting,
        outputInRelease: false,
        printColors: true,
      ),
    );
