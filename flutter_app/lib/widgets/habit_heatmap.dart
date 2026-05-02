import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/enums.dart';

/// GitHub-style 12+ week heatmap. Port of
/// `src/components/charts/HabitYearHeatmap.tsx`. Presentation-only: the
/// caller supplies `statusFor(date)`.
class HabitHeatmap extends StatelessWidget {
  const HabitHeatmap({
    super.key,
    required this.statusFor,
    this.weeks = 16,
    this.endDate,
    this.cellSize = 14,
    this.cellGap = 3,
  });

  /// Status of a given date (`null` = not logged).
  final HabitLogStatus? Function(String iso) statusFor;
  final int weeks;
  final DateTime? endDate;
  final double cellSize;
  final double cellGap;

  static const _months = [
    'Янв',
    'Фев',
    'Мар',
    'Апр',
    'Май',
    'Июн',
    'Июл',
    'Авг',
    'Сен',
    'Окт',
    'Ноя',
    'Дек',
  ];

  Color _cellColor(BuildContext context, HabitLogStatus? s) {
    final scheme = Theme.of(context).colorScheme;
    switch (s) {
      case HabitLogStatus.done:
        return const Color(0xFF22C55E);
      case HabitLogStatus.skipped:
        return const Color(0xFFF59E0B);
      case HabitLogStatus.failed:
        return const Color(0xFFEF4444);
      case null:
        return scheme.surfaceContainerHighest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final end = endDate ?? DateTime.now();
    // Normalize end to start of its week (Monday-first locale).
    final endNoTime = DateTime(end.year, end.month, end.day);
    // Days since Monday (Mon=0..Sun=6)
    final endDow = (endNoTime.weekday + 6) % 7;
    final lastWeekStart = endNoTime.subtract(Duration(days: endDow));
    final firstWeekStart = lastWeekStart.subtract(Duration(days: (weeks - 1) * 7));

    final columns = <List<DateTime>>[];
    for (var w = 0; w < weeks; w++) {
      final weekStart = firstWeekStart.add(Duration(days: w * 7));
      columns.add(
        List.generate(7, (i) => weekStart.add(Duration(days: i))),
      );
    }

    int prevMonth = -1;
    final monthLabels = <int, String>{};
    for (var i = 0; i < columns.length; i++) {
      final d = columns[i][0];
      if (d.month - 1 != prevMonth) {
        monthLabels[i] = _months[d.month - 1];
        prevMonth = d.month - 1;
      }
    }

    final cellSizeWithGap = cellSize + cellGap;
    final scheme = Theme.of(context).colorScheme;
    final fmt = DateFormat('yyyy-MM-dd');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month labels row.
          SizedBox(
            height: 14,
            child: Row(
              children: [
                SizedBox(width: cellSize),
                for (var i = 0; i < columns.length; i++)
                  SizedBox(
                    width: cellSizeWithGap,
                    child: Text(
                      monthLabels[i] ?? '',
                      style: TextStyle(
                        fontSize: 9,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Grid 7 rows × N columns.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day-of-week labels column (every other row).
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var d = 0; d < 7; d++)
                    SizedBox(
                      height: cellSizeWithGap,
                      width: cellSize,
                      child: Text(
                        d == 1
                            ? 'Вт'
                            : d == 3
                                ? 'Чт'
                                : d == 5
                                    ? 'Сб'
                                    : '',
                        style: TextStyle(
                          fontSize: 9,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              for (final col in columns)
                Padding(
                  padding: EdgeInsets.only(right: cellGap),
                  child: Column(
                    children: [
                      for (final d in col)
                        Padding(
                          padding: EdgeInsets.only(bottom: cellGap),
                          child: _Cell(
                            date: d,
                            today: end,
                            color: _cellColor(
                                context, statusFor(fmt.format(d))),
                            size: cellSize,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Меньше',
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  )),
              const SizedBox(width: 6),
              for (final c in [
                scheme.surfaceContainerHighest,
                const Color(0xFF86EFAC),
                const Color(0xFF22C55E),
                const Color(0xFF15803D),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Container(
                    width: cellSize,
                    height: cellSize,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              Text('Больше',
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.date,
    required this.today,
    required this.color,
    required this.size,
  });

  final DateTime date;
  final DateTime today;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isFuture = date.isAfter(today);
    return Tooltip(
      message: DateFormat.yMd('ru').format(date),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isFuture ? color.withValues(alpha: 0.4) : color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
