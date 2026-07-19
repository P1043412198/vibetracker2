import 'package:flutter/material.dart';

import 'heat_color.dart';

/// Actual-vs-plan bar: a thin track with the target marked, a fill for the
/// actual value, coloured by how close it is to (or over) the limit. This is
/// the pixel form of the plan/fact philosophy used across the app.
class BulletBar extends StatelessWidget {
  const BulletBar({
    super.key,
    required this.actual,
    required this.target,
    this.height = 12,
    this.higherIsBetter = false,
  });

  final double actual;
  final double target;
  final double height;

  /// When false (default, e.g. budgets), exceeding target is bad. When true
  /// (e.g. savings goal), exceeding target is good.
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safeTarget = target <= 0 ? 1.0 : target;
    final ratio = (actual / safeTarget);
    final fillFraction = ratio.clamp(0.0, 1.0);
    final over = ratio > 1;
    final color = higherIsBetter
        ? (ratio >= 1 ? vizGood : vizWarn)
        : vizStatusColor(ratio);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fillFraction,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              ),
              // Target tick (only meaningful when not already full width).
              if (!over)
                Positioned(
                  left: (w - 2).clamp(0.0, w),
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: scheme.outline),
                ),
            ],
          ),
        );
      },
    );
  }
}
