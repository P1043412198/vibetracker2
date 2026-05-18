import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../models/habit.dart';
import '../../services/streak.dart';
import '../../state/providers.dart';

/// Cross-habit analytics tab. Combines:
///
/// * Pie of "Полезные vs Вредные" by count.
/// * Donut of today's status distribution across all habits.
/// * Top-8 habits by current streak (horizontal bar chart).
/// * 30-day completion bar chart (sum of `done` logs across all habits).
class HabitsAnalyticsTab extends ConsumerWidget {
  const HabitsAnalyticsTab({super.key});

  static const _good = Color(0xFF22C55E);
  static const _bad = Color(0xFFEF4444);
  static const _skip = Color(0xFFF59E0B);
  static const _muted = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final logs = ref.watch(habitLogsProvider);
    if (habits.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Нет привычек. Создай хотя бы одну, чтобы увидеть аналитику.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _OverviewStats(habits: habits, logs: logs),
        const SizedBox(height: 12),
        _TypeDonutCard(habits: habits),
        const SizedBox(height: 12),
        _TodayStatusCard(habits: habits, logs: logs),
        const SizedBox(height: 12),
        _StreakRankingCard(habits: habits, logs: logs),
        const SizedBox(height: 12),
        _Last30DaysCard(habits: habits, logs: logs),
      ],
    );
  }
}

class _OverviewStats extends StatelessWidget {
  const _OverviewStats({required this.habits, required this.logs});
  final List<Habit> habits;
  final List<HabitLog> logs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final doneToday = logs
        .where(
            (l) => l.date == today && l.status == HabitLogStatus.done)
        .map((l) => l.habitId)
        .toSet()
        .length;
    final totalDone =
        logs.where((l) => l.status == HabitLogStatus.done).length;
    int bestStreak = 0;
    for (final h in habits) {
      final s = computeStreakStats(habit: h, logs: logs);
      if (s.best > bestStreak) bestStreak = s.best;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _Pill(
              label: 'Привычек',
              value: '${habits.length}',
              color: scheme.primary,
            ),
            const SizedBox(width: 8),
            _Pill(
              label: 'Сделано сегодня',
              value: '$doneToday',
              color: HabitsAnalyticsTab._good,
            ),
            const SizedBox(width: 8),
            _Pill(
              label: 'Всего отметок',
              value: '$totalDone',
              color: scheme.tertiary,
            ),
            const SizedBox(width: 8),
            _Pill(
              label: 'Рекорд серии',
              value: '$bestStreak',
              color: const Color(0xFFEAB308),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
          ],
        ),
      ),
    );
  }
}

class _TypeDonutCard extends StatelessWidget {
  const _TypeDonutCard({required this.habits});
  final List<Habit> habits;

  @override
  Widget build(BuildContext context) {
    final good = habits.where((h) => h.type == HabitTypeKind.good).length;
    final bad = habits.where((h) => h.type == HabitTypeKind.bad).length;
    final total = good + bad;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Полезные / Вредные',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 48,
                      sections: [
                        if (good > 0)
                          PieChartSectionData(
                            value: good.toDouble(),
                            color: HabitsAnalyticsTab._good,
                            title:
                                '${(good * 100 / total).round()}%',
                            radius: 40,
                            titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12),
                          ),
                        if (bad > 0)
                          PieChartSectionData(
                            value: bad.toDouble(),
                            color: HabitsAnalyticsTab._bad,
                            title: '${(bad * 100 / total).round()}%',
                            radius: 40,
                            titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$total',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800)),
                      Text('всего',
                          style:
                              Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              children: [
                _LegendDot(
                    color: HabitsAnalyticsTab._good,
                    text: 'Полезные • $good'),
                _LegendDot(
                    color: HabitsAnalyticsTab._bad,
                    text: 'Вредные • $bad'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayStatusCard extends StatelessWidget {
  const _TodayStatusCard({required this.habits, required this.logs});
  final List<Habit> habits;
  final List<HabitLog> logs;

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final byStatus = <HabitLogStatus, int>{};
    for (final h in habits) {
      final l = logs.cast<HabitLog?>().firstWhere(
            (e) => e?.habitId == h.id && e?.date == today,
            orElse: () => null,
          );
      if (l != null) {
        byStatus[l.status] = (byStatus[l.status] ?? 0) + 1;
      }
    }
    final notMarked = habits.length -
        byStatus.values.fold<int>(0, (s, v) => s + v);
    final entries = <_Slice>[
      if ((byStatus[HabitLogStatus.done] ?? 0) > 0)
        _Slice(
          label: 'Сделано',
          value: byStatus[HabitLogStatus.done]!,
          color: HabitsAnalyticsTab._good,
        ),
      if ((byStatus[HabitLogStatus.failed] ?? 0) > 0)
        _Slice(
          label: 'Сорвалось',
          value: byStatus[HabitLogStatus.failed]!,
          color: HabitsAnalyticsTab._bad,
        ),
      if ((byStatus[HabitLogStatus.skipped] ?? 0) > 0)
        _Slice(
          label: 'Пропущено',
          value: byStatus[HabitLogStatus.skipped]!,
          color: HabitsAnalyticsTab._skip,
        ),
      if (notMarked > 0)
        _Slice(
          label: 'Не отмечено',
          value: notMarked,
          color: HabitsAnalyticsTab._muted,
        ),
    ];
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Сегодня',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 48,
                      sections: [
                        for (final e in entries)
                          PieChartSectionData(
                            value: e.value.toDouble(),
                            color: e.color,
                            title:
                                '${(e.value * 100 / total).round()}%',
                            radius: 40,
                            titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$total',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800)),
                      Text('привычек',
                          style:
                              Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                for (final e in entries)
                  _LegendDot(
                      color: e.color,
                      text: '${e.label} • ${e.value}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakRankingCard extends StatelessWidget {
  const _StreakRankingCard({required this.habits, required this.logs});
  final List<Habit> habits;
  final List<HabitLog> logs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ranked = habits
        .map((h) => MapEntry(h, computeStreakStats(habit: h, logs: logs)))
        .toList()
      ..sort((a, b) => b.value.current.compareTo(a.value.current));
    final top = ranked.take(8).toList();
    if (top.isEmpty) {
      return const SizedBox.shrink();
    }
    final maxCurrent = top.fold<int>(
        0, (m, e) => e.value.current > m ? e.value.current : m);
    final cap = maxCurrent == 0 ? 1 : maxCurrent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Топ серий (текущие / рекорд)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            for (final entry in top)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        entry.key.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          if (entry.value.best > 0)
                            FractionallySizedBox(
                              widthFactor:
                                  (entry.value.best / cap).clamp(0, 1),
                              child: Container(
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAB308)
                                      .withValues(alpha: 0.45),
                                  borderRadius:
                                      BorderRadius.circular(7),
                                ),
                              ),
                            ),
                          if (entry.value.current > 0)
                            FractionallySizedBox(
                              widthFactor:
                                  (entry.value.current / cap).clamp(0, 1),
                              child: Container(
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF97316),
                                  borderRadius:
                                      BorderRadius.circular(7),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 56,
                      child: Text(
                        '${entry.value.current} / ${entry.value.best}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 16,
              children: const [
                _LegendDot(color: Color(0xFFF97316), text: 'Текущая'),
                _LegendDot(color: Color(0xFFEAB308), text: 'Рекорд'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Last30DaysCard extends StatelessWidget {
  const _Last30DaysCard({required this.habits, required this.logs});
  final List<Habit> habits;
  final List<HabitLog> logs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final byDay = List<int>.filled(30, 0);
    for (final l in logs) {
      if (l.status != HabitLogStatus.done) continue;
      final d = l.date.length >= 10 ? l.date.substring(0, 10) : l.date;
      DateTime parsed;
      try {
        parsed = DateTime.parse(d);
      } catch (_) {
        continue;
      }
      final diff = DateTime(today.year, today.month, today.day)
          .difference(DateTime(parsed.year, parsed.month, parsed.day))
          .inDays;
      if (diff >= 0 && diff < 30) {
        byDay[29 - diff] += 1;
      }
    }
    final maxV = byDay.fold<int>(0, (m, v) => v > m ? v : m);
    final maxY =
        ((maxV == 0 ? habits.length : maxV).toDouble()) * 1.2;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Сделано за день (30 дн.)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY <= 0 ? 1 : maxY,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval:
                            maxY > 4 ? (maxY / 4).ceilToDouble() : 1,
                        getTitlesWidget: (v, _) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text('${v.round()}',
                              style:
                                  const TextStyle(fontSize: 10)),
                        ),
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i > 29) {
                            return const SizedBox.shrink();
                          }
                          if (i % 7 != 0 && i != 29) {
                            return const SizedBox.shrink();
                          }
                          final day = today
                              .subtract(Duration(days: 29 - i));
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                                DateFormat('d/MM').format(day),
                                style:
                                    const TextStyle(fontSize: 8)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < byDay.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: byDay[i].toDouble(),
                            color: scheme.primary,
                            width: 6,
                            borderRadius: const BorderRadius
                                .vertical(top: Radius.circular(2)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Сумма «сделано» по всем привычкам за каждый день',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Slice {
  _Slice({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
