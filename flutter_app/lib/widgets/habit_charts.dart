import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/enums.dart';
import '../models/habit.dart';

/// Per-habit charts card.
///
/// Renders three visualisations side by side (or stacked on narrow screens):
///
/// * **Donut**: distribution of log statuses (done / failed / skipped) for
///   *all* recorded entries of this habit.
/// * **Last-12-weeks bar chart**: number of `done` entries per ISO week.
/// * **Last-30-days line / area chart**: rolling 7-day completion ratio.
class HabitChartsCard extends StatelessWidget {
  const HabitChartsCard({
    super.key,
    required this.habit,
    required this.logs,
  });

  final Habit habit;
  final List<HabitLog> logs;

  static const _doneColor = Color(0xFF22C55E);
  static const _failColor = Color(0xFFEF4444);
  static const _skipColor = Color(0xFFF59E0B);

  Map<HabitLogStatus, int> _statusCounts() {
    final result = <HabitLogStatus, int>{
      HabitLogStatus.done: 0,
      HabitLogStatus.failed: 0,
      HabitLogStatus.skipped: 0,
    };
    for (final l in logs) {
      result[l.status] = (result[l.status] ?? 0) + 1;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final counts = _statusCounts();
    final total = counts.values.fold<int>(0, (s, v) => s + v);
    final isGood = habit.type == HabitTypeKind.good;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Графики и диаграммы',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (total == 0)
              const _ChartEmpty(
                  text: 'Отметь хотя бы один день — появятся графики.')
            else ...[
              SizedBox(
                height: 180,
                child: _StatusDonut(counts: counts, isGood: isGood),
              ),
              const SizedBox(height: 8),
              _StatusLegend(counts: counts, total: total, isGood: isGood),
              const SizedBox(height: 24),
              Text('Выполнено за неделю (12 нед.)',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: _WeeklyDoneBarChart(logs: logs),
              ),
              const SizedBox(height: 24),
              Text('Скользящее выполнение (7-дневное окно)',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                child: _RollingRateChart(logs: logs),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusDonut extends StatelessWidget {
  const _StatusDonut({required this.counts, required this.isGood});
  final Map<HabitLogStatus, int> counts;
  final bool isGood;

  @override
  Widget build(BuildContext context) {
    final entries = <_StatusSlice>[
      _StatusSlice(
        status: HabitLogStatus.done,
        value: counts[HabitLogStatus.done] ?? 0,
        color: HabitChartsCard._doneColor,
      ),
      _StatusSlice(
        status: HabitLogStatus.failed,
        value: counts[HabitLogStatus.failed] ?? 0,
        color: HabitChartsCard._failColor,
      ),
      _StatusSlice(
        status: HabitLogStatus.skipped,
        value: counts[HabitLogStatus.skipped] ?? 0,
        color: HabitChartsCard._skipColor,
      ),
    ].where((e) => e.value > 0).toList();
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    return Stack(
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
                  radius: 32,
                  showTitle: false,
                ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$total',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'отметок',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusSlice {
  _StatusSlice({
    required this.status,
    required this.value,
    required this.color,
  });
  final HabitLogStatus status;
  final int value;
  final Color color;
}

class _StatusLegend extends StatelessWidget {
  const _StatusLegend({
    required this.counts,
    required this.total,
    required this.isGood,
  });
  final Map<HabitLogStatus, int> counts;
  final int total;
  final bool isGood;

  String _label(HabitLogStatus s) {
    switch (s) {
      case HabitLogStatus.done:
        return isGood ? 'Сделал' : 'Удержался';
      case HabitLogStatus.failed:
        return isGood ? 'Не сделал' : 'Сорвался';
      case HabitLogStatus.skipped:
        return 'Пропустил';
    }
  }

  Color _color(HabitLogStatus s) {
    switch (s) {
      case HabitLogStatus.done:
        return HabitChartsCard._doneColor;
      case HabitLogStatus.failed:
        return HabitChartsCard._failColor;
      case HabitLogStatus.skipped:
        return HabitChartsCard._skipColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = HabitLogStatus.values
        .map((s) => MapEntry(s, counts[s] ?? 0))
        .where((e) => e.value > 0)
        .toList();
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final e in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _color(e.key),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${_label(e.key)} • ${e.value} '
                '(${total == 0 ? 0 : (e.value * 100 / total).round()}%)',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
      ],
    );
  }
}

class _WeeklyDoneBarChart extends StatelessWidget {
  const _WeeklyDoneBarChart({required this.logs});
  final List<HabitLog> logs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    // 12 weeks ending with current ISO week (Mon-based, like elsewhere in app).
    final weekStarts = <DateTime>[];
    DateTime cursor = DateTime(today.year, today.month, today.day);
    cursor = cursor.subtract(Duration(days: cursor.weekday - 1));
    for (var i = 11; i >= 0; i--) {
      weekStarts.add(cursor.subtract(Duration(days: i * 7)));
    }
    final byWeek = List<int>.filled(weekStarts.length, 0);
    for (final l in logs) {
      if (l.status != HabitLogStatus.done) continue;
      final d = l.date.length >= 10 ? l.date.substring(0, 10) : l.date;
      DateTime? parsed;
      try {
        parsed = DateTime.parse(d);
      } catch (_) {
        continue;
      }
      for (var i = 0; i < weekStarts.length; i++) {
        final start = weekStarts[i];
        final end = start.add(const Duration(days: 7));
        if (!parsed.isBefore(start) && parsed.isBefore(end)) {
          byWeek[i] += 1;
          break;
        }
      }
    }
    final maxValue = byWeek.fold<int>(0, (m, v) => v > m ? v : m);
    final maxY = (maxValue == 0 ? 1 : maxValue).toDouble() * 1.2;
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: maxY > 4 ? (maxY / 4).ceilToDouble() : 1,
              getTitlesWidget: (value, _) {
                final v = value.round();
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text('$v',
                      style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= weekStarts.length) {
                  return const SizedBox.shrink();
                }
                if (i % 2 != 0 && i != weekStarts.length - 1) {
                  return const SizedBox.shrink();
                }
                final ws = weekStarts[i];
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(DateFormat('dd.MM').format(ws),
                      style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < byWeek.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: byWeek[i].toDouble(),
                  color: scheme.primary,
                  width: 12,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RollingRateChart extends StatelessWidget {
  const _RollingRateChart({required this.logs});
  final List<HabitLog> logs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 29));
    // Build a date->done-bool map for the last 30 days (inclusive).
    final byDate = <String, bool>{};
    for (final l in logs) {
      final d = l.date.length >= 10 ? l.date.substring(0, 10) : l.date;
      byDate[d] = l.status == HabitLogStatus.done;
    }
    final iso = DateFormat('yyyy-MM-dd');
    final spots = <FlSpot>[];
    for (var i = 0; i < 30; i++) {
      final day = start.add(Duration(days: i));
      // 7-day rolling window ending on `day`.
      var done = 0;
      for (var w = 0; w < 7; w++) {
        final probe = day.subtract(Duration(days: w));
        if (byDate[iso.format(probe)] == true) done += 1;
      }
      spots.add(FlSpot(i.toDouble(), done / 7.0));
    }
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 29,
        minY: 0,
        maxY: 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 0.25,
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 0.25,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text('${(v * 100).round()}%',
                    style: const TextStyle(fontSize: 10)),
              ),
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 7,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i > 29) return const SizedBox.shrink();
                final date = start.add(Duration(days: i));
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(DateFormat('dd.MM').format(date),
                      style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: scheme.primary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  scheme.primary.withValues(alpha: 0.25),
                  scheme.primary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
