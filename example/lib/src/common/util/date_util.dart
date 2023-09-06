import 'package:intl/intl.dart' as intl;

sealed class DateUtil {
  /// Format date
  static String format(
    DateTime? date, {
    intl.DateFormat? format,
    String fallback = '-',
  }) {
    if (date == null) return fallback;
    if (format != null) return format.format(date);
    final now = DateTime.now();
    final today = now.copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    if (date.isAfter(today)) return intl.DateFormat.Hms().format(date);
    if (date.isAfter(today.subtract(const Duration(days: 7)))) {
      return intl.DateFormat(intl.DateFormat.WEEKDAY).format(date);
    }
    return intl.DateFormat.yMd().format(date);
  }
}

extension DateUtilX on DateTime {
  /// Format date
  String format({intl.DateFormat? format}) =>
      DateUtil.format(this, format: format);
}
