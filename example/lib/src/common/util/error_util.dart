import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart'
    show BuildContext, Colors, ScaffoldMessenger, SnackBar, Text;
import 'package:l/l.dart';
import 'package:spinifyapp/src/common/localization/localization.dart';
import 'package:spinifyapp/src/common/util/platform/error_util_vm.dart'
    // ignore: uri_does_not_exist
    if (dart.library.html) 'package:spinifyapp/src/common/util/platform/error_util_js.dart';

/// Error util.
sealed class ErrorUtil {
  /// Log the error to the console and to Crashlytics.
  static Future<void> logError(
    Object exception,
    StackTrace stackTrace, {
    String? hint,
    bool fatal = false,
  }) async {
    try {
      if (exception is String) {
        return await logMessage(
          exception,
          stackTrace: stackTrace,
          hint: hint,
          warning: true,
        );
      }
      $captureException(exception, stackTrace, hint, fatal).ignore();
      l.e(exception, stackTrace);
    } on Object catch (error, stackTrace) {
      l.e(
        'Error while logging error "$error" inside ErrorUtil.logError',
        stackTrace,
      );
    }
  }

  /// Logs a message to the console and to Crashlytics.
  static Future<void> logMessage(
    String message, {
    StackTrace? stackTrace,
    String? hint,
    bool warning = false,
  }) async {
    try {
      l.e(message, stackTrace ?? StackTrace.current);
      $captureMessage(message, stackTrace, hint, warning).ignore();
    } on Object catch (error, stackTrace) {
      l.e(
        'Error while logging error "$error" inside ErrorUtil.logMessage',
        stackTrace,
      );
    }
  }

  /// Rethrows the error with the stack trace.
  static Never throwWithStackTrace(Object error, StackTrace stackTrace) =>
      Error.throwWithStackTrace(error, stackTrace);

  @pragma('vm:prefer-inline')
  static String _localizedError(
      String fallback, String Function(Localization l) localize) {
    try {
      return localize(Localization.current);
    } on Object {
      return fallback;
    }
  }

  // Also we can add current localization to this method
  static String formatMessage(
    Object error, [
    String fallback = 'An error has occurred',
  ]) =>
      switch (error) {
        String e => e,
        FormatException _ =>
          _localizedError('Invalid format', (lcl) => lcl.errInvalidFormat),
        TimeoutException _ =>
          _localizedError('Timeout exceeded', (lcl) => lcl.errTimeOutExceeded),
        UnimplementedError _ => _localizedError(
            'Not implemented yet', (lcl) => lcl.errNotImplementedYet),
        UnsupportedError _ => _localizedError(
            'Unsupported operation', (lcl) => lcl.errUnsupportedOperation),
        FileSystemException _ => _localizedError(
            'File system error', (lcl) => lcl.errFileSystemException),
        AssertionError _ =>
          _localizedError('Assertion error', (lcl) => lcl.errAssertionError),
        Error _ => _localizedError(
            'An error has occurred', (lcl) => lcl.errAnErrorHasOccurred),
        Exception _ => _localizedError('An exception has occurred',
            (lcl) => lcl.errAnExceptionHasOccurred),
        _ => fallback,
      };

  /// Shows a error snackbar with the given message.
  static void showSnackBar(BuildContext context, Object message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(formatMessage(message)),
          backgroundColor: Colors.red,
        ),
      );
}
