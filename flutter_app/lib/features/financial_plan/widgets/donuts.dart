import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/financial_plan.dart';

/// Donut chart with side-by-side legend; values are slices of [items].
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.items,
    this.innerRadiusRatio = 0.55,
    this.size = 220,
    this.showLabels = true,
  });

  final List<ExpenseItem> items;
  final double innerRadiusRatio;
  final double size;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(
          items: items,
          innerRadiusRatio: innerRadiusRatio,
          labelStyle: Theme.of(context).textTheme.bodySmall!,
          showLabels: showLabels,
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.items,
    required this.innerRadiusRatio,
    required this.labelStyle,
    required this.showLabels,
  });

  final List<ExpenseItem> items;
  final double innerRadiusRatio;
  final TextStyle labelStyle;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;
    final total = items.fold<double>(0, (a, b) => a + b.amount);
    if (total <= 0) return;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    final inner = radius * innerRadiusRatio;

    double angle = -math.pi / 2;
    for (final it in items) {
      final sweep = (it.amount / total) * math.pi * 2;
      final paint = Paint()..color = it.colorValue;
      final path = Path()
        ..moveTo(
            center.dx + math.cos(angle) * inner,
            center.dy + math.sin(angle) * inner)
        ..lineTo(
            center.dx + math.cos(angle) * radius,
            center.dy + math.sin(angle) * radius)
        ..arcTo(
            Rect.fromCircle(center: center, radius: radius),
            angle,
            sweep,
            false)
        ..lineTo(
            center.dx + math.cos(angle + sweep) * inner,
            center.dy + math.sin(angle + sweep) * inner)
        ..arcTo(
            Rect.fromCircle(center: center, radius: inner),
            angle + sweep,
            -sweep,
            false)
        ..close();
      canvas.drawPath(path, paint);
      if (showLabels && sweep > 0.18) {
        final mid = angle + sweep / 2;
        final label = '${(it.amount / total * 100).round()}%';
        final pos = Offset(
            center.dx + math.cos(mid) * (inner + radius) / 2,
            center.dy + math.sin(mid) * (inner + radius) / 2);
        _drawText(canvas, label, pos, Colors.white);
      }
      angle += sweep;
    }
  }

  void _drawText(Canvas canvas, String text, Offset center, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: labelStyle.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.items != items;
}

/// Horizontal bar list, used as the right-hand companion to the donut.
class HorizontalBars extends StatelessWidget {
  const HorizontalBars({super.key, required this.items, this.maxBars = 10});

  final List<ExpenseItem> items;
  final int maxBars;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final shown = items.take(maxBars).toList();
    final maxAmount = shown.fold<double>(0, (a, b) => a > b.amount ? a : b.amount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: shown.map((it) {
        final ratio = maxAmount > 0 ? it.amount / maxAmount : 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  it.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio.toDouble(),
                    minHeight: 14,
                    valueColor: AlwaysStoppedAnimation(it.colorValue),
                    backgroundColor: it.colorValue.withValues(alpha: 0.15),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 64,
                child: Text(
                  '${it.amount.round()}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Donut paired with a list of horizontal bars (legend with values).
class DonutWithBars extends StatelessWidget {
  const DonutWithBars({super.key, required this.items, this.donutLabel});

  final List<ExpenseItem> items;
  final String? donutLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 560;
      final donut = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonutChart(items: items),
          if (donutLabel != null) ...[
            const SizedBox(height: 6),
            Text(donutLabel!,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ],
      );
      final bars = HorizontalBars(items: items);
      if (!wide) {
        return Column(
          children: [
            donut,
            const SizedBox(height: 16),
            bars,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          donut,
          const SizedBox(width: 24),
          Expanded(child: bars),
        ],
      );
    });
  }
}
