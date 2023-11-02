import 'package:l/l.dart';

sealed class LoggerUtil {
  /// Formats the log message.
  static Object messageFormatting(
          Object message, LogLevel logLevel, DateTime now) =>
      '${timeFormat(now)} | $message';

  /// Formats the time.
  static String timeFormat(DateTime time) =>
      '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
}
