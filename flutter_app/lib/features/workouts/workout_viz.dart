import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../models/misc.dart';
import '../../widgets/viz/split_bar.dart';
import 'workout_format.dart';

/// A stable accent colour per muscle group, used across the journal and the
/// analytics charts so the same group always reads the same colour.
Color muscleColor(MuscleGroup? g) => switch (g) {
      MuscleGroup.chest => const Color(0xFF6366F1), // indigo
      MuscleGroup.back => const Color(0xFF0EA5E9), // sky
      MuscleGroup.legs => const Color(0xFFF97316), // orange
      MuscleGroup.shoulders => const Color(0xFFA855F7), // purple
      MuscleGroup.arms => const Color(0xFFEC4899), // pink
      MuscleGroup.core => const Color(0xFFF59E0B), // amber
      MuscleGroup.cardio => const Color(0xFF10B981), // emerald
      null => const Color(0xFF94A3B8), // slate
    };

/// Best-effort mapping of an exercise name to a [MuscleGroup] using Russian
/// and English keyword matching. Returns [fallback] when nothing matches.
/// Used to give each AI-generated exercise its own group instead of lumping
/// every exercise under the first requested target.
MuscleGroup? inferMuscleGroup(String name, {MuscleGroup? fallback}) {
  final n = name.toLowerCase();
  bool has(List<String> kws) => kws.any(n.contains);

  if (has(['присед', 'выпад', 'жим ног', 'разгибан ног', 'сгибан ног', 'икр',
      'голен', 'ягод', 'становая', 'squat', 'lunge', 'leg', 'calf',
      'glute', 'deadlift', 'hamstring', 'quad'])) {
    return MuscleGroup.legs;
  }
  if (has(['жим лёж', 'жим лежа', 'отжим', 'разводк', 'бабочк', 'сведен',
      'груд', 'bench', 'chest', 'push-up', 'pushup', 'fly', 'dip'])) {
    return MuscleGroup.chest;
  }
  if (has(['тяга', 'подтягив', 'спин', 'широчайш', 'row', 'pull-up',
      'pullup', 'pulldown', 'lat', 'back'])) {
    return MuscleGroup.back;
  }
  if (has(['плеч', 'дельт', 'жим стоя', 'жим сид', 'махи', 'shoulder',
      'overhead', 'press', 'lateral', 'delt', 'shrug', 'трапец'])) {
    return MuscleGroup.shoulders;
  }
  if (has(['бицепс', 'трицепс', 'сгибан рук', 'разгибан рук', 'предплеч',
      'молот', 'curl', 'bicep', 'tricep', 'arm', 'forearm'])) {
    return MuscleGroup.arms;
  }
  if (has(['пресс', 'планк', 'скручиван', 'кор', 'корпус', 'abs', 'core',
      'plank', 'crunch', 'oblique'])) {
    return MuscleGroup.core;
  }
  if (has(['бег', 'кардио', 'велотрен', 'дорожк', 'эллипс', 'гребл', 'run',
      'cardio', 'bike', 'cycl', 'treadmill', 'row machine', 'jump'])) {
    return MuscleGroup.cardio;
  }
  return fallback;
}

/// Short muscle-group label for compact chips.
String muscleShortLabel(MuscleGroup g) => switch (g) {
      MuscleGroup.chest => 'Грудь',
      MuscleGroup.back => 'Спина',
      MuscleGroup.legs => 'Ноги',
      MuscleGroup.shoulders => 'Плечи',
      MuscleGroup.arms => 'Руки',
      MuscleGroup.core => 'Кор',
      MuscleGroup.cardio => 'Кардио',
    };

/// Estimated one-rep max via the Epley formula. Returns 0 when there is not
/// enough data (no weight or reps).
num estimatedOneRepMax(num weight, num reps) {
  if (weight <= 0 || reps <= 0) return 0;
  if (reps == 1) return weight;
  return weight * (1 + reps / 30);
}

/// Estimated one-rep max via the Brzycki formula. Undefined at 37+ reps (the
/// denominator hits zero), so it is only meaningful in the low/moderate rep
/// range where it tends to be more conservative than Epley.
num brzyckiOneRepMax(num weight, num reps) {
  if (weight <= 0 || reps <= 0) return 0;
  if (reps == 1) return weight;
  final denom = 1.0278 - 0.0278 * reps;
  if (denom <= 0) return 0;
  return weight / denom;
}

/// Average of the Epley and Brzycki estimates — a bit more robust than either
/// alone. Falls back to Epley when Brzycki is undefined (high reps).
num averagedOneRepMax(num weight, num reps) {
  final e = estimatedOneRepMax(weight, reps);
  final b = brzyckiOneRepMax(weight, reps);
  if (b <= 0) return e;
  return (e + b) / 2;
}

/// Best estimated 1RM across [logs].
num best1RM(Iterable<ExerciseLog> logs) {
  num best = 0;
  for (final l in logs) {
    final rm = estimatedOneRepMax(
      l.metrics[WorkoutMetric.weight] ?? 0,
      l.metrics[WorkoutMetric.reps] ?? 1,
    );
    if (rm > best) best = rm;
  }
  return best;
}

/// A small pill showing an icon + text — used for session meta (duration,
/// sets, volume) and muscle tags.
class WorkoutStatChip extends StatelessWidget {
  const WorkoutStatChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
  });

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

/// A proportional horizontal bar splitting training volume by muscle group,
/// with a compact legend. Animates its segments on build.
class MuscleSplitBar extends StatelessWidget {
  const MuscleSplitBar({super.key, required this.byMuscle});

  /// Volume (or set count) per muscle group. Zero/empty entries are ignored.
  final Map<MuscleGroup, num> byMuscle;

  @override
  Widget build(BuildContext context) {
    return SplitBar(
      segments: [
        for (final e in byMuscle.entries)
          SplitSegment(
            label: muscleShortLabel(e.key),
            value: e.value,
            color: muscleColor(e.key),
          ),
      ],
    );
  }
}

/// A labelled, animated bar chart used for weekly training volume. Each bar
/// grows from the baseline on first build.
class VolumeBars extends StatelessWidget {
  const VolumeBars({
    super.key,
    required this.values,
    required this.labels,
    this.color,
    this.height = 120,
  });

  final List<double> values;
  final List<String> labels;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    final maxV = values.isEmpty
        ? 1.0
        : values.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);
    // Guard against tiny [height] making the clamp bounds invert.
    final maxBarH = (height - 40).clamp(2.0, double.infinity);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      values[i] <= 0 ? '' : fmtNum(values[i]),
                      style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                    const SizedBox(height: 2),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 500 + i * 60),
                      curve: Curves.easeOutBack,
                      builder: (context, t, _) => Container(
                        // Zero-volume weeks collapse to nothing so they read as
                        // "no training" rather than a tiny 2px stub.
                        height: values[i] <= 0
                            ? 0.0
                            : (maxBarH * (values[i] / maxV) * t)
                                .clamp(2.0, maxBarH),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [c, c.withValues(alpha: 0.55)],
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      i < labels.length ? labels[i] : '',
                      style: const TextStyle(fontSize: 8.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
