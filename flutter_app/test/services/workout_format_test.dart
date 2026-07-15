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

  group('brzyckiOneRepMax / averagedOneRepMax', () {
    test('single rep returns the weight itself', () {
      expect(brzyckiOneRepMax(100, 1), 100);
    });

    test('Brzycki: 100 / (1.0278 - 0.0278·5)', () {
      // 100 / (1.0278 - 0.139) = 100 / 0.8888 = 112.51…
      expect(brzyckiOneRepMax(100, 5), closeTo(112.512, 1e-2));
    });

    test('Brzycki guards impossible rep counts', () {
      expect(brzyckiOneRepMax(100, 40), 0);
    });

    test('averaged is the mean of Epley and Brzycki', () {
      final e = estimatedOneRepMax(100, 5);
      final b = brzyckiOneRepMax(100, 5);
      expect(averagedOneRepMax(100, 5), closeTo((e + b) / 2, 1e-6));
    });

    test('averaged falls back to Epley when Brzycki is undefined', () {
      expect(averagedOneRepMax(100, 40), estimatedOneRepMax(100, 40));
    });
  });

  group('totalVolume', () {
    test('sums weight × reps', () {
      expect(totalVolume([log(100, 5), log(80, 3)]), 100 * 5 + 80 * 3);
    });

    test('skips sets missing weight or reps', () {
      final weightOnly = ExerciseLog(
        id: 'w',
        exerciseId: 'ex',
        date: '2026-06-26',
        metrics: {WorkoutMetric.weight: 90},
      );
      expect(totalVolume([log(100, 5), weightOnly]), 100 * 5);
    });
  });

  group('inferMuscleGroup', () {
    test('maps common exercise names to groups', () {
      expect(inferMuscleGroup('Приседания со штангой'), MuscleGroup.legs);
      expect(inferMuscleGroup('Bench press'), MuscleGroup.chest);
      expect(inferMuscleGroup('Тяга в наклоне'), MuscleGroup.back);
    });

    test('uses fallback when nothing matches', () {
      expect(inferMuscleGroup('zzz', fallback: MuscleGroup.core),
          MuscleGroup.core);
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
