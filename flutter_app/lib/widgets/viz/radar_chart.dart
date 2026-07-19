import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One axis of a [RadarChart].
class RadarAxis {
  const RadarAxis({required this.label, required this.value});

  final String label;

  /// Normalised 0..1 (the caller normalises against the peak axis).
  final double value;
}

/// A spider/radar chart for balance across dimensions (muscle groups,
/// push/pull, category mix). A skew shows instantly where a bar chart wouldn't.
class RadarChart extends StatelessWidget {
  const RadarChart({
    super.key,
    required this.axes,
    this.color,
    this.size = 220,
  });

  final List<RadarAxis> axes;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RadarPainter(
          axes: axes,
          color: color ?? scheme.primary,
          grid: scheme.outlineVariant,
          labelColor: scheme.onSurfaceVariant,
          textDirection: Directionality.of(context),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.axes,
    required this.color,
    required this.grid,
    required this.labelColor,
    required this.textDirection,
  });

  final List<RadarAxis> axes;
  final Color color;
  final Color grid;
  final Color labelColor;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final n = axes.length;
    if (n < 3) return;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 24;
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = grid;

    // Concentric rings.
    for (var ring = 1; ring <= 4; ring++) {
      final r = radius * ring / 4;
      final path = Path();
      for (var i = 0; i < n; i++) {
        final a = -math.pi / 2 + 2 * math.pi * i / n;
        final p = center + Offset(math.cos(a), math.sin(a)) * r;
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Spokes + labels.
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / n;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(center, center + dir * radius, gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: axes[i].label,
          style: TextStyle(color: labelColor, fontSize: 10),
        ),
        textDirection: textDirection,
      )..layout();
      final labelPos = center + dir * (radius + 12);
      tp.paint(
        canvas,
        labelPos - Offset(tp.width / 2, tp.height / 2),
      );
    }

    // Data polygon.
    final dataPath = Path();
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / n;
      final v = axes[i].value.clamp(0.0, 1.0);
      final p = center + Offset(math.cos(a), math.sin(a)) * radius * v;
      if (i == 0) {
        dataPath.moveTo(p.dx, p.dy);
      } else {
        dataPath.lineTo(p.dx, p.dy);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, Paint()..color = color.withValues(alpha: 0.22));
    canvas.drawPath(
      dataPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.color != color ||
      old.grid != grid ||
      !_sameAxes(old.axes, axes);

  bool _sameAxes(List<RadarAxis> a, List<RadarAxis> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].value != b[i].value || a[i].label != b[i].label) return false;
    }
    return true;
  }
}
