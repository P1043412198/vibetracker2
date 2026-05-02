import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../state/providers.dart';
import '../../state/settings_state.dart';

/// Phase 12: lightweight mini-chart widgets for the dashboard. They reuse
/// existing providers and stay self-contained so the dashboard doesn't grow
/// a new chart dependency.
class ExpenseWeekChartWidget extends ConsumerWidget {
  const ExpenseWeekChartWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = ref.watch(transactionsProvider);
    final currency = ref.watch(defaultCurrencyProvider);
    final today = DateTime.now();
    final days = List.generate(7, (i) {
      final d = DateTime(today.year, today.month, today.day - (6 - i));
      return d;
    });
    final byDay = <String, num>{};
    for (final d in days) {
      byDay[_iso(d)] = 0;
    }
    for (final t in tx) {
      if (t.type != TransactionType.expense) continue;
      if (byDay.containsKey(t.date)) {
        byDay[t.date] = (byDay[t.date] ?? 0) + t.amount;
      }
    }
    final values = days.map((d) => byDay[_iso(d)] ?? 0).toList();
    final maxV = values.fold<num>(0, (a, b) => a > b ? a : b);
    final fmt =
        NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 0);
    final weekTotal = values.fold<num>(0, (a, b) => a + b);
    return Card(
      child: InkWell(
        onTap: () => context.go('/finance'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.show_chart, color: Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Расход за 7 дней',
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  Text('${fmt.format(weekTotal)} $currency',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 64,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < days.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: maxV == 0
                                    ? 2
                                    : 2 + (values[i] / maxV) * 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _weekdayShort(days[i]),
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _weekdayShort(DateTime d) {
    const names = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
    return names[d.weekday - 1];
  }
}

/// 4-week per-day completion grid for habits (GitHub-style heatmap).
class HabitHeatmapWidget extends ConsumerWidget {
  const HabitHeatmapWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final logs = ref.watch(habitLogsProvider);
    final today = DateTime.now();
    const totalDays = 28;
    final days = List.generate(totalDays, (i) {
      final d = DateTime(today.year, today.month, today.day - (totalDays - 1 - i));
      return d;
    });
    // For each day, ratio of completed vs total habits
    final completedByDay = <String, int>{};
    for (final l in logs) {
      if (l.status == HabitLogStatus.done) {
        completedByDay[l.date] = (completedByDay[l.date] ?? 0) + 1;
      }
    }
    final total = habits.length;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: () => context.go('/habits'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.grid_on, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Привычки за 4 недели',
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  if (total > 0)
                    Text('$total активных',
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              if (total == 0)
                const Text('Создай первую привычку, чтобы увидеть прогресс.')
              else
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final cell =
                        ((constraints.maxWidth - (7 - 1) * 4) / 7).clamp(8.0, 24.0);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var w = 0; w < 4; w++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                for (var d = 0; d < 7; d++)
                                  Padding(
                                    padding: EdgeInsets.only(
                                        right: d == 6 ? 0 : 4),
                                    child: _Cell(
                                      size: cell,
                                      ratio: () {
                                        final i = w * 7 + d;
                                        if (i >= days.length) return 0.0;
                                        final iso = _iso(days[i]);
                                        final done =
                                            completedByDay[iso] ?? 0;
                                        return total == 0
                                            ? 0.0
                                            : (done / total).clamp(0, 1).toDouble();
                                      }(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _Cell extends StatelessWidget {
  const _Cell({required this.size, required this.ratio});
  final double size;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final base = const Color(0xFF22C55E);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ratio == 0
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : base.withValues(alpha: (0.25 + ratio * 0.75).clamp(0.25, 1.0)),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// Tasks done vs planned per weekday (last 7 days).
class TaskWeekProgressWidget extends ConsumerWidget {
  const TaskWeekProgressWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final today = DateTime.now();
    final days = List.generate(7, (i) {
      final d = DateTime(today.year, today.month, today.day - (6 - i));
      return d;
    });
    int planned = 0;
    int done = 0;
    final byDay = <String, _DayBucket>{};
    for (final d in days) {
      byDay[_iso(d)] = _DayBucket();
    }
    for (final t in tasks) {
      if (t.period != TaskPeriod.day) continue;
      if (byDay.containsKey(t.date)) {
        final b = byDay[t.date]!;
        b.total += 1;
        planned += 1;
        if (t.completed) {
          b.done += 1;
          done += 1;
        }
      }
    }
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: () => context.go('/tasks'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Задачи за неделю',
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  Text('$done / $planned',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 64,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < days.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SizedBox(
                                height: 50,
                                child: _StackedBar(
                                  bucket: byDay[_iso(days[i])] ?? _DayBucket(),
                                  primary: scheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _weekdayShort(days[i]),
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static String _weekdayShort(DateTime d) {
    const names = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
    return names[d.weekday - 1];
  }
}

class _DayBucket {
  int total = 0;
  int done = 0;
}

class _StackedBar extends StatelessWidget {
  const _StackedBar({required this.bucket, required this.primary});
  final _DayBucket bucket;
  final Color primary;
  @override
  Widget build(BuildContext context) {
    if (bucket.total == 0) {
      return Container(
        height: 4,
        margin: const EdgeInsets.only(top: 46),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }
    final doneFrac = bucket.done / bucket.total;
    final remaining = 1 - doneFrac;
    return LayoutBuilder(
      builder: (ctx, c) {
        return Stack(
          children: [
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: c.maxHeight * remaining,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(3),
                        topRight: Radius.circular(3),
                      ),
                    ),
                  ),
                  Container(
                    height: c.maxHeight * doneFrac,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(remaining == 0 ? 3 : 0),
                        topRight: Radius.circular(remaining == 0 ? 3 : 0),
                        bottomLeft: const Radius.circular(3),
                        bottomRight: const Radius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
