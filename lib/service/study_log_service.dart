import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:timezone/timezone.dart' as tz;

import '../util/date_time_util.dart';

/// Stores per-session study records in Hive so study time can be queried by
/// period (today / week / month / year).
///
/// Each entry is a plain Map: `{'gc': 'FA_EN', 'd': '2026-06-20', 's': 120}`.
/// No Hive adapter is needed — the box stores dynamic values.
/// The box is opened by [setup()] in main.dart before this service initialises.
class StudyLogService extends GetxService {
  static const String boxId = 'studyLog';

  late final Box _box;

  @override
  void onInit() {
    super.onInit();
    _box = Hive.box(boxId);
  }

  /// Records a completed study session lasting [durationSecs].
  /// [date] defaults to today — pass the session's *start* date so that
  /// sessions crossing midnight are attributed to the day they began.
  /// Sessions shorter than 1 second are ignored.
  void logSessionByCode(String code, int durationSecs, {String? date}) {
    if (durationSecs < 1) return;
    final now = DateTimeUtil.now();
    _box.add(<String, dynamic>{
      'gc': code,
      'd': date ?? dateKey(now),
      's': durationSecs,
    });
  }

  /// Seconds studied for a code on a specific [dateKey] string (YYYY-MM-DD).
  int daySecsByCode(String code, String dateKey) {
    return _entries
        .where(
            (e) => e['gc']?.toString() == code && e['d']?.toString() == dateKey)
        .fold(0, (sum, e) => sum + _secs(e));
  }

  /// Seconds studied for a code on today's date.
  int todaySecsByCode(String code) {
    final now = DateTimeUtil.now();
    final today = dateKey(now);
    return _entries
        .where(
            (e) => e['gc']?.toString() == code && e['d']?.toString() == today)
        .fold(0, (sum, e) => sum + _secs(e));
  }

  /// Seconds studied for a code over the last [days] days (inclusive today).
  int periodSecsByCode(String code, {required int days}) {
    final from = DateTimeUtil.now().subtract(Duration(days: days - 1));
    final fromKey = dateKey(from);
    return _entries
        .where((e) =>
            e['gc']?.toString() == code &&
            (e['d']?.toString() ?? '').compareTo(fromKey) >= 0)
        .fold(0, (sum, e) => sum + _secs(e));
  }

  List<Map> get _entries => _box.values.whereType<Map>().toList();

  int _secs(Map e) => (e['s'] as num?)?.toInt() ?? 0;

  /// Formats a [TZDateTime] as YYYY-MM-DD. Public so callers can lock the
  /// study date at session start and pass it back via [logSession].
  String dateKey(tz.TZDateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
