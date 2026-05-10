import 'package:flutter/material.dart';

import '../../../models/financial_plan.dart';

/// Renders the «Календарь мая» grid (7 columns × N rows) and a heatmap
/// variant where cells are coloured by absolute spend.
class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.calendar,
    required this.heatmap,
  });

  final MonthCalendar calendar;
  final bool heatmap;

  static const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: _weekdays
              .map((d) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ))
              .toList(),
        ),
        ...calendar.weeks.map((row) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: row
                  .map((cell) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: _Cell(cell: cell, heatmap: heatmap),
                        ),
                      ))
                  .toList(),
            )),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: calendar.legend
              .map((b) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                            color: b.colorValue,
                            borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 4),
                      Text(b.label, style: const TextStyle(fontSize: 11)),
                    ],
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell, required this.heatmap});

  final CalendarCell cell;
  final bool heatmap;

  Color get _bg {
    switch (cell.kind) {
      case CalendarKind.filler:
        return Colors.transparent;
      case CalendarKind.empty:
        return const Color(0xFFFEE2E2);
      case CalendarKind.income:
        return const Color(0xFF22C55E);
      case CalendarKind.rent:
        return const Color(0xFFF59E0B);
      case CalendarKind.bigSpend:
        return const Color(0xFFEF4444);
      case CalendarKind.spend:
        // For heatmap, scale colour by |delta|.
        if (heatmap) {
          final v = cell.delta.abs();
          if (v == 0) return const Color(0xFFFEE2E2);
          if (v < 30) return const Color(0xFFD1FAE5);
          if (v < 100) return const Color(0xFFFEF3C7);
          if (v < 500) return const Color(0xFFFED7AA);
          return const Color(0xFFEF4444);
        }
        return const Color(0xFFD1FAE5);
      case CalendarKind.none:
        return Colors.transparent;
    }
  }

  Color get _fg {
    if (cell.kind == CalendarKind.income ||
        cell.kind == CalendarKind.rent ||
        cell.kind == CalendarKind.bigSpend) {
      return Colors.white;
    }
    return Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    if (cell.kind == CalendarKind.filler) {
      return const SizedBox(height: 64);
    }
    return Container(
      height: 64,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: Colors.black.withValues(alpha: 0.05), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cell.day == 0 ? '' : cell.day.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 10,
              color: _fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Center(
            child: Text(
              cell.label,
              style: TextStyle(fontSize: 10, color: _fg, height: 1.1),
              maxLines: 3,
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
