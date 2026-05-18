import 'package:intl/intl.dart';

import '../models/enums.dart';
import '../models/habit.dart';

/// Pure helpers for habit streak / completion analytics.
///
/// Mirrors the React inline computations in `src/pages/Habits.tsx` and the
/// `StreakChains` chart so the same numbers show up in both apps once we
/// reach feature parity.
class StreakStats {
  StreakStats({
    required this.current,
    required this.best,
    required this.totalDone,
    required this.completionRate,
    required this.lastStatusByDate,
  });

  final int current;
  final int best;
  final int totalDone;

  /// Ratio in `[0, 1]` of days with status==done over the last 30 days
  /// (inclusive of today).
  final double completionRate;

  /// Map keyed by ISO yyyy-MM-dd → most recent log status for that date.
  final Map<String, HabitLogStatus> lastStatusByDate;
}

String _isoDay(DateTime date) =>
    DateFormat('yyyy-MM-dd').format(DateTime(date.year, date.month, date.day));

StreakStats computeStreakStats({
  required Habit habit,
  required Iterable<HabitLog> logs,
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final byDate = <String, HabitLogStatus>{};
  int totalDone = 0;
  for (final l in logs) {
    if (l.habitId != habit.id) continue;
    final iso = l.date.length >= 10 ? l.date.substring(0, 10) : l.date;
    byDate[iso] = l.status;
    if (l.status == HabitLogStatus.done) totalDone += 1;
  }

  // Current streak: count back from today while status == done.
  int current = 0;
  var cursor = DateTime(now.year, now.month, now.day);
  while (true) {
    final iso = _isoDay(cursor);
    final s = byDate[iso];
    if (s == HabitLogStatus.done) {
      current += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    } else {
      break;
    }
  }

  // Best streak: longest run of consecutive 'done' days across all logged
  // days. We walk every day from min(date) to today.
  int best = 0;
  if (byDate.isNotEmpty) {
    final dates = byDate.keys.toList()..sort();
    final firstParts = dates.first.split('-').map(int.parse).toList();
    var walker = DateTime(firstParts[0], firstParts[1], firstParts[2]);
    final endWalker = DateTime(now.year, now.month, now.day);
    int run = 0;
    while (!walker.isAfter(endWalker)) {
      if (byDate[_isoDay(walker)] == HabitLogStatus.done) {
        run += 1;
        if (run > best) best = run;
      } else {
        run = 0;
      }
      walker = walker.add(const Duration(days: 1));
    }
  }

  // Completion rate over last 30 days.
  int doneInWindow = 0;
  for (var i = 0; i < 30; i++) {
    final day = now.subtract(Duration(days: i));
    if (byDate[_isoDay(day)] == HabitLogStatus.done) doneInWindow += 1;
  }
  final rate = doneInWindow / 30.0;

  return StreakStats(
    current: current,
    best: best,
    totalDone: totalDone,
    completionRate: rate,
    lastStatusByDate: byDate,
  );
}

/// Returns the [HabitLogStatus] for [date] (yyyy-MM-dd) — or null if there
/// is no log for that date.
HabitLogStatus? statusFor(
  Iterable<HabitLog> logs,
  String habitId,
  String isoDate,
) {
  for (final l in logs) {
    if (l.habitId != habitId) continue;
    final d = l.date.length >= 10 ? l.date.substring(0, 10) : l.date;
    if (d == isoDate) return l.status;
  }
  return null;
}
