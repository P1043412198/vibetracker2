import 'package:flutter/material.dart';

import '../../../models/financial_plan.dart';

/// Waterfall chart that turns [IncomeBreakdown.steps] into a column chart
/// with floating bars; positive deltas are added to the running balance,
/// negative ones subtract from it.
class IncomeWaterfall extends StatelessWidget {
  const IncomeWaterfall({
    super.key,
    required this.income,
    this.height = 240,
  });

  final IncomeBreakdown income;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _WaterfallPainter(
              steps: income.steps,
              labelStyle: Theme.of(context).textTheme.bodySmall!,
              gridColor: Theme.of(context).dividerColor,
            ),
          );
        },
      ),
    );
  }
}

class _WaterfallPainter extends CustomPainter {
  _WaterfallPainter({
    required this.steps,
    required this.labelStyle,
    required this.gridColor,
  });

  final List<WaterfallStep> steps;
  final TextStyle labelStyle;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (steps.isEmpty) return;
    const margin = EdgeInsets.fromLTRB(40, 16, 8, 56);
    final plotW = size.width - margin.left - margin.right;
    final plotH = size.height - margin.top - margin.bottom;
    final maxValue = steps.map((s) => s.value).fold<double>(0, (a, b) => a > b ? a : b);
    final maxDelta = steps
        .map((s) => s.value.abs() + s.delta.abs())
        .fold<double>(0, (a, b) => a > b ? a : b);
    final scaleMax = maxValue > maxDelta ? maxValue : maxDelta;
    if (scaleMax <= 0) return;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = margin.top + plotH * i / 4;
      canvas.drawLine(Offset(margin.left, y), Offset(size.width - margin.right, y), gridPaint);
      _drawText(canvas, ((scaleMax * (4 - i) / 4)).round().toString(),
          Offset(margin.left - 6, y), TextAlign.right);
    }

    final barW = plotW / steps.length * 0.6;
    final stepX = plotW / steps.length;

    double prev = 0;
    for (int i = 0; i < steps.length; i++) {
      final s = steps[i];
      final cx = margin.left + stepX * (i + 0.5);
      double top, bottom;
      if (s.kind == WaterfallKind.gross ||
          s.kind == WaterfallKind.net ||
          s.kind == WaterfallKind.remainder) {
        top = margin.top + plotH * (1 - s.value / scaleMax);
        bottom = margin.top + plotH;
        prev = s.value;
      } else if (s.delta < 0) {
        // Falls from prev to (prev + delta).
        top = margin.top + plotH * (1 - prev / scaleMax);
        bottom = margin.top + plotH * (1 - (prev + s.delta) / scaleMax);
        prev += s.delta;
      } else {
        // Rises from prev to (prev + delta).
        top = margin.top + plotH * (1 - (prev + s.delta) / scaleMax);
        bottom = margin.top + plotH * (1 - prev / scaleMax);
        prev += s.delta;
      }
      final rect = Rect.fromLTRB(cx - barW / 2, top, cx + barW / 2, bottom);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = s.colorValue,
      );

      // Connector dotted line to the next bar.
      if (i < steps.length - 1) {
        final nextS = steps[i + 1];
        if (nextS.kind != WaterfallKind.gross &&
            nextS.kind != WaterfallKind.net &&
            nextS.kind != WaterfallKind.remainder) {
          final dashY = top;
          final dashX1 = rect.right;
          final dashX2 = margin.left + stepX * (i + 1) - barW / 2;
          _drawDashed(canvas, Offset(dashX1, dashY), Offset(dashX2, dashY),
              Paint()..color = gridColor..strokeWidth = 1);
        }
      }

      // Value label above bar.
      _drawText(canvas, s.delta == 0 ? s.value.round().toString() :
          (s.delta > 0 ? '+${s.delta.round()}' : s.delta.round().toString()),
          Offset(cx, top - 4), TextAlign.center);
      // X-axis label below.
      _drawText(canvas, s.label, Offset(cx, size.height - margin.bottom + 4),
          TextAlign.center, multi: true, maxWidth: stepX);
    }
  }

  void _drawDashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0, gap = 3.0;
    final dx = b.dx - a.dx;
    final length = dx.abs();
    if (length <= 0) return;
    final dirX = dx / length;
    double t = 0;
    while (t < length) {
      final s = Offset(a.dx + dirX * t, a.dy);
      final e = Offset(a.dx + dirX * (t + dash).clamp(0, length).toDouble(), a.dy);
      canvas.drawLine(s, e, paint);
      t += dash + gap;
    }
  }

  void _drawText(Canvas canvas, String text, Offset anchor, TextAlign align,
      {bool multi = false, double? maxWidth}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: multi ? 2 : 1,
      ellipsis: '…',
    );
    tp.layout(maxWidth: maxWidth ?? 200);
    final dx = align == TextAlign.center
        ? anchor.dx - tp.width / 2
        : align == TextAlign.right
            ? anchor.dx - tp.width
            : anchor.dx;
    tp.paint(canvas, Offset(dx, anchor.dy));
  }

  @override
  bool shouldRepaint(covariant _WaterfallPainter oldDelegate) =>
      oldDelegate.steps != steps;
}
