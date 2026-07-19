import 'package:flutter/material.dart';

/// One proportional segment of a [SplitBar].
class SplitSegment {
  const SplitSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final num value;
  final Color color;
}

/// A proportional horizontal bar with a compact legend — a generalisation of
/// the workout MuscleSplitBar, usable for expense categories or muscle groups.
class SplitBar extends StatelessWidget {
  const SplitBar({
    super.key,
    required this.segments,
    this.animate = true,
    this.emptyLabel = 'Нет данных',
    this.height = 14,
  });

  final List<SplitSegment> segments;
  final bool animate;
  final String emptyLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final entries = segments.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<num>(0, (s, e) => s + e.value);
    if (total <= 0) {
      return Text(emptyLabel, style: Theme.of(context).textTheme.bodySmall);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: animate ? 650 : 0),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => SizedBox(
              height: height,
              child: Row(
                children: [
                  for (final e in entries)
                    Expanded(
                      flex: ((e.value / total) * 1000 * t)
                          .round()
                          .clamp(1, 1000000),
                      child: Container(color: e.color),
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
                      color: e.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${e.label} · ${(e.value / total * 100).round()}%',
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
