import 'package:flutter/material.dart';

import 'heat_color.dart';

/// A GitHub-style calendar heatmap: one square per day, columns are weeks
/// (Mon→Sun top to bottom), intensity encodes a daily value (training volume,
/// spend, habit completion). One glance shows consistency, gaps and best weeks.
class HeatCalendar extends StatelessWidget {
  const HeatCalendar({
    super.key,
    required this.values,
    this.weeks = 27,
    this.endDate,
    this.cell = 13,
    this.gap = 3,
    this.color,
  });

  /// Value per calendar day. Keys are normalised to midnight internally.
  final Map<DateTime, double> values;

  /// How many week-columns to render (default ~half a year fits on a phone).
  final int weeks;

  /// Last day shown (defaults to today).
  final DateTime? endDate;

  final double cell;
  final double gap;

  /// Optional accent used only for the tooltip dot; cells use the heat ramp.
  final Color? color;

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final end = _dayKey(endDate ?? DateTime.now());
    // Anchor the last column on the Sunday of the current week.
    final endWeekSunday = end.add(Duration(days: 7 - end.weekday));
    final firstDay =
        endWeekSunday.subtract(Duration(days: weeks * 7 - 1));

    final normalised = <DateTime, double>{
      for (final e in values.entries) _dayKey(e.key): e.value,
    };
    final maxV = normalised.values.fold<double>(0, (m, v) => v > m ? v : m);

    final columns = <Widget>[];
    for (var w = 0; w < weeks; w++) {
      final cells = <Widget>[];
      for (var d = 0; d < 7; d++) {
        final day = firstDay.add(Duration(days: w * 7 + d));
        final future = day.isAfter(end);
        final v = normalised[day] ?? 0;
        final t = maxV <= 0 ? 0.0 : v / maxV;
        cells.add(Padding(
          padding: EdgeInsets.all(gap / 2),
          child: Tooltip(
            message:
                '${day.day}.${day.month.toString().padLeft(2, '0')} · ${v == v.roundToDouble() ? v.toInt() : v.toStringAsFixed(1)}',
            waitDuration: const Duration(milliseconds: 300),
            child: Container(
              width: cell,
              height: cell,
              decoration: BoxDecoration(
                color: future
                    ? Colors.transparent
                    : heatColor(t, base),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ));
      }
      columns.add(Column(mainAxisSize: MainAxisSize.min, children: cells));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: columns),
    );
  }
}
