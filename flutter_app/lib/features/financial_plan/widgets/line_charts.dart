import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/financial_plan.dart';

/// Multi-line chart used for the daily-balance and trajectory sections.
class MultiLineChart extends StatelessWidget {
  const MultiLineChart({
    super.key,
    required this.tracks,
    required this.xLabels,
    this.markers = const [],
    this.goalY,
    this.height = 260,
  });

  final List<MultiLineTrack> tracks;
  final List<String> xLabels;
  final List<MultiLineMarker> markers;
  final double? goalY;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _MultiLinePainter(
            tracks: tracks,
            xLabels: xLabels,
            markers: markers,
            goalY: goalY,
            labelStyle: Theme.of(context).textTheme.bodySmall!,
            gridColor: Theme.of(context).dividerColor,
          ),
        );
      }),
    );
  }
}

class MultiLineTrack {
  const MultiLineTrack({
    required this.label,
    required this.color,
    required this.points,
  });

  final String label;
  final Color color;
  final List<double> points;
}

class MultiLineMarker {
  const MultiLineMarker({
    required this.x,
    required this.label,
    required this.color,
  });

  final double x;
  final String label;
  final Color color;
}

class _MultiLinePainter extends CustomPainter {
  _MultiLinePainter({
    required this.tracks,
    required this.xLabels,
    required this.markers,
    required this.goalY,
    required this.labelStyle,
    required this.gridColor,
  });

  final List<MultiLineTrack> tracks;
  final List<String> xLabels;
  final List<MultiLineMarker> markers;
  final double? goalY;
  final TextStyle labelStyle;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (tracks.isEmpty) return;
    const margin = EdgeInsets.fromLTRB(48, 90, 16, 32);
    final plotW = size.width - margin.left - margin.right;
    final plotH = size.height - margin.top - margin.bottom;
    if (plotW <= 0 || plotH <= 0) return;

    final maxY = tracks
        .expand((t) => t.points)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final scale = maxY > 0 ? maxY : 1;
    final n = tracks.first.points.length;
    final xStep = n > 1 ? plotW / (n - 1) : 0;

    // Grid + Y labels.
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = margin.top + plotH * i / 4;
      canvas.drawLine(Offset(margin.left, y),
          Offset(size.width - margin.right, y), gridPaint);
      _drawText(canvas, ((scale * (4 - i) / 4)).round().toString(),
          Offset(margin.left - 4, y), TextAlign.right);
    }

    // Markers (vertical lines).
    for (final m in markers) {
      final x = margin.left + xStep * m.x;
      canvas.drawLine(
          Offset(x, margin.top),
          Offset(x, margin.top + plotH),
          Paint()
            ..color = m.color.withValues(alpha: 0.7)
            ..strokeWidth = 1.5);
      _drawText(canvas, m.label, Offset(x + 4, margin.top - 4), TextAlign.left,
          color: m.color, multi: true, maxWidth: 110);
    }

    // Goal horizontal line.
    if (goalY != null && scale > 0) {
      final y = margin.top + plotH * (1 - goalY! / scale);
      _drawDashed(
          canvas,
          Offset(margin.left, y),
          Offset(size.width - margin.right, y),
          Paint()
            ..color = Colors.red
            ..strokeWidth = 2);
      _drawText(canvas, 'Цель: ${goalY!.round()}',
          Offset(margin.left + 4, y - 14), TextAlign.left,
          color: Colors.red);
    }

    // Lines.
    for (final t in tracks) {
      final paint = Paint()
        ..color = t.color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      Path? path;
      for (int i = 0; i < t.points.length; i++) {
        final x = margin.left + xStep * i;
        final y = margin.top + plotH * (1 - t.points[i] / scale);
        if (path == null) {
          path = Path()..moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        canvas.drawCircle(Offset(x, y), 2.4, Paint()..color = t.color);
      }
      if (path != null) canvas.drawPath(path, paint);
    }

    // Legend at top.
    double legendX = margin.left;
    for (final t in tracks) {
      final dotR = 5.0;
      canvas.drawCircle(Offset(legendX + dotR, 16), dotR, Paint()..color = t.color);
      final tp = TextPainter(
        text: TextSpan(
            text: t.label,
            style: labelStyle.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(legendX + dotR * 2 + 4, 10));
      legendX += dotR * 2 + 8 + tp.width + 16;
      if (legendX > size.width - 80) {
        legendX = margin.left;
      }
    }

    // X labels (sparse).
    if (xLabels.isNotEmpty) {
      final stride = math.max(1, (xLabels.length / 6).ceil());
      for (int i = 0; i < xLabels.length; i += stride) {
        final x = margin.left + xStep * i;
        _drawText(canvas, xLabels[i],
            Offset(x, size.height - margin.bottom + 4), TextAlign.center);
      }
    }
  }

  void _drawDashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 6.0, gap = 4.0;
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length <= 0) return;
    final dirX = dx / length;
    final dirY = dy / length;
    double t = 0;
    while (t < length) {
      final s = Offset(a.dx + dirX * t, a.dy + dirY * t);
      final endT = (t + dash).clamp(0, length).toDouble();
      final e = Offset(a.dx + dirX * endT, a.dy + dirY * endT);
      canvas.drawLine(s, e, paint);
      t += dash + gap;
    }
  }

  void _drawText(Canvas canvas, String text, Offset anchor, TextAlign align,
      {Color? color, bool multi = false, double maxWidth = 200}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style:
            labelStyle.copyWith(fontSize: 11, color: color ?? labelStyle.color),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: multi ? 3 : 1,
      ellipsis: '…',
    );
    tp.layout(maxWidth: maxWidth);
    final dx = align == TextAlign.center
        ? anchor.dx - tp.width / 2
        : align == TextAlign.right
            ? anchor.dx - tp.width
            : anchor.dx;
    tp.paint(canvas, Offset(dx, anchor.dy));
  }

  @override
  bool shouldRepaint(covariant _MultiLinePainter oldDelegate) =>
      oldDelegate.tracks != tracks ||
      oldDelegate.markers != markers ||
      oldDelegate.goalY != goalY;
}

/// Grouped vertical bars (income vs expense per week).
class GroupedBars extends StatelessWidget {
  const GroupedBars({
    super.key,
    required this.labels,
    required this.groups,
    this.height = 220,
  });

  final List<String> labels;
  final List<GroupedBarSet> groups;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _GroupedBarsPainter(
            labels: labels,
            groups: groups,
            labelStyle: Theme.of(context).textTheme.bodySmall!,
            gridColor: Theme.of(context).dividerColor,
          ),
        );
      }),
    );
  }
}

class GroupedBarSet {
  const GroupedBarSet({required this.label, required this.color, required this.values});

  final String label;
  final Color color;
  final List<double> values;
}

class _GroupedBarsPainter extends CustomPainter {
  _GroupedBarsPainter({
    required this.labels,
    required this.groups,
    required this.labelStyle,
    required this.gridColor,
  });

  final List<String> labels;
  final List<GroupedBarSet> groups;
  final TextStyle labelStyle;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty || groups.isEmpty) return;
    const margin = EdgeInsets.fromLTRB(40, 24, 8, 28);
    final plotW = size.width - margin.left - margin.right;
    final plotH = size.height - margin.top - margin.bottom;

    final maxV = groups
        .expand((g) => g.values)
        .fold<double>(0, (a, b) => a > b ? a : b);
    if (maxV <= 0) return;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = margin.top + plotH * i / 4;
      canvas.drawLine(Offset(margin.left, y),
          Offset(size.width - margin.right, y), gridPaint);
    }

    final groupCount = labels.length;
    final groupW = plotW / groupCount;
    final barW = groupW / (groups.length + 1);

    for (int gi = 0; gi < groupCount; gi++) {
      final groupX = margin.left + groupW * gi;
      for (int si = 0; si < groups.length; si++) {
        final v = gi < groups[si].values.length ? groups[si].values[gi] : 0;
        final h = plotH * (v / maxV);
        final left = groupX + barW * (si + 0.5);
        final rect = Rect.fromLTWH(left, margin.top + plotH - h, barW, h);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            Paint()..color = groups[si].color);
      }
      _drawText(canvas, labels[gi],
          Offset(groupX + groupW / 2, size.height - margin.bottom + 4),
          TextAlign.center);
    }

    // Legend at top.
    double legendX = margin.left;
    for (final g in groups) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(legendX, 8, 12, 12), const Radius.circular(2)),
          Paint()..color = g.color);
      final tp = TextPainter(
        text: TextSpan(
            text: g.label,
            style: labelStyle.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(legendX + 16, 8));
      legendX += 16 + tp.width + 16;
    }
  }

  void _drawText(Canvas canvas, String text, Offset anchor, TextAlign align) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle.copyWith(fontSize: 11)),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = align == TextAlign.center ? anchor.dx - tp.width / 2 : anchor.dx;
    tp.paint(canvas, Offset(dx, anchor.dy));
  }

  @override
  bool shouldRepaint(covariant _GroupedBarsPainter oldDelegate) =>
      oldDelegate.groups != groups;
}

/// Quarterly bars (single series).
class QuarterlyBars extends StatelessWidget {
  const QuarterlyBars({
    super.key,
    required this.values,
    this.height = 220,
    this.goalY,
  });

  final List<QuarterlyAccrual> values;
  final double height;
  final double? goalY;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _QuarterlyPainter(
            values: values,
            goalY: goalY,
            labelStyle: Theme.of(context).textTheme.bodySmall!,
            gridColor: Theme.of(context).dividerColor,
          ),
        );
      }),
    );
  }
}

class _QuarterlyPainter extends CustomPainter {
  _QuarterlyPainter({
    required this.values,
    required this.goalY,
    required this.labelStyle,
    required this.gridColor,
  });

  final List<QuarterlyAccrual> values;
  final double? goalY;
  final TextStyle labelStyle;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const margin = EdgeInsets.fromLTRB(40, 16, 8, 36);
    final plotW = size.width - margin.left - margin.right;
    final plotH = size.height - margin.top - margin.bottom;

    final maxV = math.max(
        values.fold<double>(0, (a, b) => a > b.amountUsd ? a : b.amountUsd),
        goalY ?? 0);
    if (maxV <= 0) return;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = margin.top + plotH * i / 4;
      canvas.drawLine(Offset(margin.left, y),
          Offset(size.width - margin.right, y), gridPaint);
    }

    if (goalY != null) {
      final y = margin.top + plotH * (1 - goalY! / maxV);
      _drawDashed(
          canvas,
          Offset(margin.left, y),
          Offset(size.width - margin.right, y),
          Paint()
            ..color = Colors.red
            ..strokeWidth = 2);
    }

    final barW = plotW / values.length * 0.6;
    final stepX = plotW / values.length;
    for (int i = 0; i < values.length; i++) {
      final v = values[i];
      final cx = margin.left + stepX * (i + 0.5);
      final h = plotH * (v.amountUsd / maxV);
      final rect =
          Rect.fromLTWH(cx - barW / 2, margin.top + plotH - h, barW, h);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()..color = v.colorValue);
      _drawText(canvas, '\$${v.amountUsd.round()}',
          Offset(cx, margin.top + plotH - h - 16), TextAlign.center,
          bold: true);
      _drawText(canvas, v.label,
          Offset(cx, size.height - margin.bottom + 4), TextAlign.center);
    }
  }

  void _drawDashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 6.0, gap = 4.0;
    final dx = b.dx - a.dx;
    final length = dx.abs();
    final dir = dx / length;
    double t = 0;
    while (t < length) {
      final s = Offset(a.dx + dir * t, a.dy);
      final endT = (t + dash).clamp(0, length).toDouble();
      final e = Offset(a.dx + dir * endT, a.dy);
      canvas.drawLine(s, e, paint);
      t += dash + gap;
    }
  }

  void _drawText(Canvas canvas, String text, Offset anchor, TextAlign align,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: labelStyle.copyWith(
            fontSize: 11,
            fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          )),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = align == TextAlign.center ? anchor.dx - tp.width / 2 : anchor.dx;
    tp.paint(canvas, Offset(dx, anchor.dy));
  }

  @override
  bool shouldRepaint(covariant _QuarterlyPainter oldDelegate) =>
      oldDelegate.values != values;
}

/// Risk vs return scatter with a colored "sweet spot" rectangle and a
/// labelled arrow.
class RiskReturnScatterChart extends StatelessWidget {
  const RiskReturnScatterChart({
    super.key,
    required this.scatter,
    this.height = 320,
  });

  final RiskReturnScatter scatter;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _ScatterPainter(
            scatter: scatter,
            labelStyle: Theme.of(context).textTheme.bodySmall!,
            gridColor: Theme.of(context).dividerColor,
          ),
        );
      }),
    );
  }
}

class _ScatterPainter extends CustomPainter {
  _ScatterPainter({
    required this.scatter,
    required this.labelStyle,
    required this.gridColor,
  });

  final RiskReturnScatter scatter;
  final TextStyle labelStyle;
  final Color gridColor;

  static const _xMax = 10.0;
  static const _yMax = 25.0;

  @override
  void paint(Canvas canvas, Size size) {
    const margin = EdgeInsets.fromLTRB(48, 24, 24, 36);
    final plotW = size.width - margin.left - margin.right;
    final plotH = size.height - margin.top - margin.bottom;

    Offset toScreen(double risk, double yieldPct) {
      final x = margin.left + plotW * (risk / _xMax);
      final y = margin.top + plotH * (1 - yieldPct / _yMax);
      return Offset(x, y);
    }

    // Grid lines.
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    for (int i = 0; i <= 5; i++) {
      final y = margin.top + plotH * i / 5;
      canvas.drawLine(Offset(margin.left, y),
          Offset(size.width - margin.right, y), gridPaint);
      _drawText(canvas, ((_yMax * (5 - i) / 5).round()).toString(),
          Offset(margin.left - 4, y - 6), TextAlign.right);
    }
    for (int i = 0; i <= 5; i++) {
      final x = margin.left + plotW * i / 5;
      canvas.drawLine(Offset(x, margin.top),
          Offset(x, margin.top + plotH), gridPaint);
      _drawText(canvas, '${(_xMax * i / 5).round()}',
          Offset(x, size.height - margin.bottom + 4), TextAlign.center);
    }

    // Sweet spot rectangle.
    final r = scatter.sweetSpot;
    final ssTopLeft = toScreen(r.minRisk, r.maxYield);
    final ssBottomRight = toScreen(r.maxRisk, r.minYield);
    final ssRect = Rect.fromPoints(ssTopLeft, ssBottomRight);
    canvas.drawRRect(
        RRect.fromRectAndRadius(ssRect, const Radius.circular(8)),
        Paint()..color = const Color(0xFF22C55E).withValues(alpha: 0.15));
    canvas.drawRRect(
        RRect.fromRectAndRadius(ssRect, const Radius.circular(8)),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF22C55E)
          ..strokeWidth = 1.5);
    _drawText(canvas, 'Sweet spot:\nнизкий риск +\nдостойный %',
        Offset(ssRect.center.dx, ssRect.top - 36), TextAlign.center,
        color: const Color(0xFF22C55E), bold: true, multi: true);

    // Arrow.
    final from = toScreen(scatter.startArrow.fromRisk, scatter.startArrow.fromYield);
    final to = toScreen(scatter.startArrow.toRisk, scatter.startArrow.toYield);
    final arrowPaint = Paint()
      ..color = const Color(0xFF1E3A8A)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(from, to, arrowPaint);
    _drawText(canvas, scatter.startArrow.label,
        Offset(to.dx + 4, to.dy - 36), TextAlign.left,
        color: const Color(0xFF1E3A8A), bold: true, multi: true);

    // Points.
    for (final p in scatter.points) {
      final pos = toScreen(p.risk, p.yieldPct);
      canvas.drawCircle(pos, 8, Paint()..color = p.colorValue);
      canvas.drawCircle(
          pos,
          8,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      _drawText(canvas, p.label, Offset(pos.dx + 12, pos.dy - 6), TextAlign.left,
          bold: true);
    }

    // Axis titles.
    _drawText(canvas, 'Риск (1 — нет, 10 — высокий)',
        Offset(size.width / 2, size.height - 14), TextAlign.center);
  }

  void _drawText(Canvas canvas, String text, Offset anchor, TextAlign align,
      {Color? color, bool bold = false, bool multi = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: labelStyle.copyWith(
            fontSize: 11,
            fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
            color: color ?? labelStyle.color,
          )),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: multi ? 4 : 1,
      ellipsis: '…',
    )..layout(maxWidth: 180);
    final dx = align == TextAlign.center
        ? anchor.dx - tp.width / 2
        : align == TextAlign.right
            ? anchor.dx - tp.width
            : anchor.dx;
    tp.paint(canvas, Offset(dx, anchor.dy));
  }

  @override
  bool shouldRepaint(covariant _ScatterPainter oldDelegate) =>
      oldDelegate.scatter != scatter;
}
