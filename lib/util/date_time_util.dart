import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart' as intl;

/// Timezone-aware date/time helpers used throughout the app.
///
/// All datetime values are stored as [tz.TZDateTime] (local timezone) so that
/// the Leitner day-boundary checks behave correctly regardless of locale.
class DateTimeUtil {
  static tz.TZDateTime now() => tz.TZDateTime.now(tz.local);

  static format(String pattern, tz.TZDateTime dateTime) => intl.DateFormat(pattern).format(dateTime);

  /// Adds the local UTC offset to [dateTime] before formatting.
  ///
  /// Stored datetimes are UTC-based; this corrects the display value for the
  /// device's local timezone without modifying the stored value.
  static String adjustDateTime(tz.TZDateTime dateTime) {
    final timezoneOffset = DateTime.now().timeZoneOffset;
    final timeDiff = Duration(
      hours: timezoneOffset.inHours,
      minutes: timezoneOffset.inMinutes % 60,
    );

    // adjust the time diff
    final adjust = dateTime.add(timeDiff);
    return intl.DateFormat("yyyy-MM-dd HH:mm").format(adjust);
  }

  static int daysToNow(tz.TZDateTime from) {
    final now = tz.TZDateTime.now(tz.local);
    return now.difference(from).inDays;
  }

  /// Compares calendar dates (midnight-to-midnight) rather than raw timestamps.
  ///
  /// Using UTC midnight for both sides ensures a card modified at 11 pm is
  /// treated as "today" and not as spanning two days.
  static int daysToNowWithoutTime(tz.TZDateTime from) {
    var now = tz.TZDateTime.now(tz.local);
    var utcFrom = tz.TZDateTime.utc(from.year, from.month, from.day);
    var utcNow = tz.TZDateTime.utc(now.year, now.month, now.day);
    return utcNow.difference(utcFrom).inDays;
  }
}
