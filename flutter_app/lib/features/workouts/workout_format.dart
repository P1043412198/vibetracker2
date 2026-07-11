import '../../models/enums.dart';
import '../../models/misc.dart';

/// Short unit label for a workout metric ("кг", "повт.", ...).
String workoutMetricUnit(WorkoutMetric m) => switch (m) {
      WorkoutMetric.weight => 'кг',
      WorkoutMetric.reps => 'повт.',
      WorkoutMetric.distance => 'км',
      WorkoutMetric.time => 'мин',
      WorkoutMetric.speed => 'км/ч',
      WorkoutMetric.calories => 'ккал',
    };

/// Full human label for a workout metric ("Вес", "Повторы", ...).
String workoutMetricLabel(WorkoutMetric m) => switch (m) {
      WorkoutMetric.weight => 'Вес',
      WorkoutMetric.reps => 'Повторы',
      WorkoutMetric.distance => 'Дистанция',
      WorkoutMetric.time => 'Время',
      WorkoutMetric.speed => 'Скорость',
      WorkoutMetric.calories => 'Калории',
    };

/// Compact one-line summary of a single set's metrics, e.g. `60 кг × 10`.
/// Falls back to listing each metric with its unit.
String setSummary(ExerciseLog log) {
  final m = log.metrics;
  final parts = <String>[];
  if (m.containsKey(WorkoutMetric.weight) && m.containsKey(WorkoutMetric.reps)) {
    parts.add('${_fmt(m[WorkoutMetric.weight]!)} кг × ${_fmt(m[WorkoutMetric.reps]!)}');
  } else {
    m.forEach((k, v) => parts.add('${_fmt(v)} ${workoutMetricUnit(k)}'));
  }
  if (parts.isEmpty) parts.add('—');
  if (log.restTime != null && log.restTime! > 0) {
    parts.add('отдых ${log.restTime}с');
  }
  return parts.join('  ·  ');
}

/// Total training volume (Σ weight × reps) across [logs].
num totalVolume(Iterable<ExerciseLog> logs) {
  num v = 0;
  for (final l in logs) {
    final w = l.metrics[WorkoutMetric.weight] ?? 0;
    final r = l.metrics[WorkoutMetric.reps] ?? 1;
    v += w * r;
  }
  return v;
}

/// Best (max) single value of [metric] across [logs], or 0 when absent.
num bestMetric(Iterable<ExerciseLog> logs, WorkoutMetric metric) {
  num best = 0;
  for (final l in logs) {
    final v = l.metrics[metric];
    if (v != null && v > best) best = v;
  }
  return best;
}

/// Public compact number formatter ("60", "62.5").
String fmtNum(num v) => _fmt(v);

/// Best (max) weight recorded for [exerciseId] across [logs].
num bestWeightFor(Iterable<ExerciseLog> logs, String exerciseId) {
  num best = 0;
  for (final l in logs) {
    if (l.exerciseId != exerciseId) continue;
    final w = l.metrics[WorkoutMetric.weight];
    if (w != null && w > best) best = w;
  }
  return best;
}

/// Estimated one-rep max via the Epley formula: `w · (1 + reps/30)`.
/// Returns [weight] unchanged for a single rep and 0 when weight is 0.
double estimatedOneRepMax(num weight, num reps) {
  if (weight <= 0 || reps <= 0) return 0;
  if (reps == 1) return weight.toDouble();
  return weight * (1 + reps / 30);
}

/// Best estimated 1RM across [logs] (max Epley over every weight×reps set).
double bestE1RM(Iterable<ExerciseLog> logs) {
  double best = 0;
  for (final l in logs) {
    final w = l.metrics[WorkoutMetric.weight];
    final r = l.metrics[WorkoutMetric.reps];
    if (w == null) continue;
    final e = estimatedOneRepMax(w, r ?? 1);
    if (e > best) best = e;
  }
  return best;
}

/// "1ч 05м" / "45м 10с" / "30с" style duration from seconds.
String formatWorkoutDuration(int? sec) {
  if (sec == null || sec <= 0) return '—';
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final s = sec % 60;
  if (h > 0) return '$hч ${m.toString().padLeft(2, '0')}м';
  if (m > 0) return '$mм ${s.toString().padLeft(2, '0')}с';
  return '$sс';
}

String _fmt(num v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}
