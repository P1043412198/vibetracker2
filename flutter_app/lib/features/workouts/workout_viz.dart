import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../models/misc.dart';
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

/// Best estimated 1RM across [logs].
num best1RM(Iterable<ExerciseLog> logs) {
  num best = 0;
  for (final l in logs) {
    final rm = estimatedOneRepMax(
      l.metrics[WorkoutMetric.weight] ?? 0,
      l.metrics[WorkoutMetric.reps] ?? 0,
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
    final entries = byMuscle.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<num>(0, (s, e) => s + e.value);
    if (total <= 0) {
      return Text('Нет данных',
          style: Theme.of(context).textTheme.bodySmall);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => SizedBox(
              height: 14,
              child: Row(
                children: [
                  for (final e in entries)
                    Expanded(
                      flex: ((e.value / total) * 1000 * t)
                          .round()
                          .clamp(1, 1000000),
                      child: Container(color: muscleColor(e.key)),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final e in entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: muscleColor(e.key),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${muscleShortLabel(e.key)} · ${(e.value / total * 100).round()}%',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
          ],
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
                        height:
                            ((height - 40) * (values[i] / maxV) * t)
                                .clamp(2.0, height - 40),
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
