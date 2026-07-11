import 'package:flutter_test/flutter_test.dart';

import 'package:vibesight_tracker/models/enums.dart';
import 'package:vibesight_tracker/models/misc.dart';
import 'package:vibesight_tracker/features/workouts/workout_format.dart';
import 'package:vibesight_tracker/features/workouts/workout_viz.dart';

ExerciseLog log(num weight, num reps) => ExerciseLog(
      id: '$weight-$reps',
      exerciseId: 'ex',
      date: '2026-06-26',
      metrics: {
        WorkoutMetric.weight: weight,
        WorkoutMetric.reps: reps,
      },
    );

void main() {
  group('estimatedOneRepMax (Epley)', () {
    test('single rep returns the weight itself', () {
      expect(estimatedOneRepMax(100, 1), 100);
    });

    test('multi-rep applies the Epley formula w·(1+reps/30)', () {
      // 100 × (1 + 5/30) = 116.666…
      expect(estimatedOneRepMax(100, 5), closeTo(116.6667, 1e-3));
    });

    test('zero weight or reps yields 0', () {
      expect(estimatedOneRepMax(0, 5), 0);
      expect(estimatedOneRepMax(100, 0), 0);
    });
  });

  group('best1RM', () {
    test('takes the max estimated 1RM across sets', () {
      // 80×8 → 101.33; 100×3 → 110; 95×5 → 110.83 (winner)
      final logs = [log(80, 8), log(100, 3), log(95, 5)];
      expect(best1RM(logs), closeTo(110.833, 1e-2));
    });

    test('reps default to 1 when the set only logs weight', () {
      final l = ExerciseLog(
        id: 'w-only',
        exerciseId: 'ex',
        date: '2026-06-26',
        metrics: {WorkoutMetric.weight: 90},
      );
      expect(best1RM([l]), 90);
    });

    test('empty logs → 0', () {
      expect(best1RM(const []), 0);
    });
  });

  group('RPE', () {
    test('setSummary appends RPE when present', () {
      final l = ExerciseLog(
        id: 'r',
        exerciseId: 'ex',
        date: '2026-06-26',
        metrics: {WorkoutMetric.weight: 80, WorkoutMetric.reps: 5},
        rpe: 8,
      );
      expect(setSummary(l), contains('RPE 8'));
    });

    test('setSummary omits RPE when absent', () {
      expect(setSummary(log(80, 5)), isNot(contains('RPE')));
    });

    test('rpe survives a JSON round-trip', () {
      final l = ExerciseLog(
        id: 'r',
        exerciseId: 'ex',
        date: '2026-06-26',
        metrics: {WorkoutMetric.weight: 80, WorkoutMetric.reps: 5},
        rpe: 7.5,
      );
      final back = ExerciseLog.fromJson(l.toJson());
      expect(back.rpe, 7.5);
    });
  });
}
