import 'package:flutter/material.dart';

import 'heat_color.dart';

/// A compact "change vs previous period" badge: an arrow + signed delta.
///
/// [higherIsBetter] flips the colour semantics: rising expenses are bad (red),
/// rising income/volume is good (green).
class TrendDelta extends StatelessWidget {
  const TrendDelta({
    super.key,
    required this.delta,
    this.suffix = '',
    this.higherIsBetter = true,
    this.compact = false,
  });

  /// Signed change. Percentage or absolute — the caller formats [suffix].
  final double delta;
  final String suffix;
  final bool higherIsBetter;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final flat = delta.abs() < 1e-9;
    final rising = delta > 0;
    final good = flat ? null : (rising == higherIsBetter);
    final color = good == null
        ? Theme.of(context).colorScheme.outline
        : (good ? vizGood : vizBad);
    final icon = flat
        ? Icons.trending_flat
        : (rising ? Icons.arrow_upward : Icons.arrow_downward);
    final text =
        '${rising ? '+' : ''}${_fmt(delta)}$suffix';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 13 : 16, color: color),
        const SizedBox(width: 2),
        Text(
          text,
          style: (compact
                  ? Theme.of(context).textTheme.labelSmall
                  : Theme.of(context).textTheme.labelMedium)
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  String _fmt(double v) {
    final a = v.abs();
    if (a >= 100) return v.round().toString();
    if (a == a.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}
