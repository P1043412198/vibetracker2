import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Donut chart visualizing income vs expense for a month.
/// The ring fills proportional to (expense / income), green up to plan,
/// red beyond it. Centered label shows what's left.
class BudgetDonut extends StatelessWidget {
  final double income;
  final double expense;
  final double diameter;
  final Widget center;

  const BudgetDonut({
    super.key,
    required this.income,
    required this.expense,
    required this.center,
    this.diameter = 170,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = income <= 0 ? 0.0 : (expense / income).clamp(0.0, 1.0);
    final overSpent = income > 0 && expense > income;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(diameter),
            painter: _DonutPainter(
              progress: ratio,
              overSpent: overSpent,
              ringWidth: 14,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: center,
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double progress; // 0..1
  final bool overSpent;
  final double ringWidth;

  _DonutPainter({
    required this.progress,
    required this.overSpent,
    required this.ringWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - ringWidth) / 2;

    final track = Paint()
      ..color = const Color(0xFFEFF3F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round
      ..color = overSpent ? AppColors.danger : AppColors.primary;

    final start = -math.pi / 2;
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress || old.overSpent != overSpent;
}
