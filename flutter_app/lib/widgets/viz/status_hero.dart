import 'package:flutter/material.dart';

import 'sparkline.dart';
import 'trend_delta.dart';

/// The one big status number that sits at the top of a tab: a large coloured
/// figure with a caption, an optional trend badge and sparkline. Everything
/// else on the screen is drill-down. Embodies the "one status per screen" rule.
class StatusHero extends StatelessWidget {
  const StatusHero({
    super.key,
    required this.value,
    required this.caption,
    this.color,
    this.icon,
    this.delta,
    this.deltaSuffix = '',
    this.higherIsBetter = true,
    this.spark = const [],
    this.onTap,
  });

  final String value;
  final String caption;
  final Color? color;
  final IconData? icon;

  /// Optional signed change vs the previous period.
  final double? delta;
  final String deltaSuffix;
  final bool higherIsBetter;

  /// Optional recent trend to show beside the number.
  final List<double> spark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: c, size: 26),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: c,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (delta != null) ...[
                      const SizedBox(height: 6),
                      TrendDelta(
                        delta: delta!,
                        suffix: deltaSuffix,
                        higherIsBetter: higherIsBetter,
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
              if (spark.length >= 2)
                Sparkline(values: spark, color: c, width: 72, height: 34),
            ],
          ),
        ),
      ),
    );
  }
}
