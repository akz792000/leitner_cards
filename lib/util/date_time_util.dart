import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart' as intl;

class DateTimeUtil {
  static tz.TZDateTime now() => tz.TZDateTime.now(tz.local);

  static format(String pattern, tz.TZDateTime dateTime) => intl.DateFormat(pattern).format(dateTime);

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

  static int daysToNowWithoutTime(tz.TZDateTime from) {
    var now = tz.TZDateTime.now(tz.local);
    var utcFrom = tz.TZDateTime.utc(from.year, from.month, from.day);
    var utcNow = tz.TZDateTime.utc(now.year, now.month, now.day);
    return utcNow.difference(utcFrom).inDays;
  }
}
