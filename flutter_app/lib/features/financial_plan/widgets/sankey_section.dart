import 'package:flutter/material.dart';

import '../../../models/financial_plan.dart';

/// Sankey-style chart with one income column on the left flowing into the
/// expense bars on the right. Self-contained CustomPainter so we don't need
/// to drag in the (heavier) `flutter_sankey` package.
class SankeySection extends StatelessWidget {
  const SankeySection({
    super.key,
    required this.data,
    this.height = 320,
  });

  final SankeyData data;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _SankeyPainter(
              data: data,
              labelStyle: Theme.of(context).textTheme.bodySmall!,
              incomeColor: Theme.of(context).colorScheme.primary,
            ),
          );
        },
      ),
    );
  }
}

class _SankeyPainter extends CustomPainter {
  _SankeyPainter({
    required this.data,
    required this.labelStyle,
    required this.incomeColor,
  });

  final SankeyData data;
  final TextStyle labelStyle;
  final Color incomeColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.outflows.isEmpty || data.income <= 0) return;
    const labelGap = 8.0;
    const colW = 20.0;
    const sideMargin = 110.0;
    final usableHeight = size.height - 16;
    final leftX = sideMargin;
    final rightX = size.width - sideMargin - colW;

    final totalOut = data.outflows.fold<double>(0, (a, b) => a + b.amount);
    if (totalOut <= 0) return;
    final flowTotal = data.income < totalOut ? data.income : totalOut;

    // Income bar (single block).
    final incomeRect = Rect.fromLTWH(leftX, 8, colW, usableHeight);
    canvas.drawRRect(
      RRect.fromRectAndRadius(incomeRect, const Radius.circular(6)),
      Paint()..color = incomeColor,
    );

    // Outflow bars stacked on the right.
    final outRects = <Rect>[];
    {
      double y = 8;
      for (final out in data.outflows) {
        final h = usableHeight * (out.amount / totalOut);
        outRects.add(Rect.fromLTWH(rightX, y, colW, h));
        y += h;
      }
      for (int i = 0; i < outRects.length; i++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(outRects[i], const Radius.circular(6)),
          Paint()..color = data.outflows[i].colorValue,
        );
      }
    }

    // Ribbons.
    double srcOffset = 0;
    for (int i = 0; i < data.outflows.length; i++) {
      final out = data.outflows[i];
      final share = out.amount / totalOut;
      final flowH = usableHeight * share * (flowTotal / totalOut);
      final srcTop = incomeRect.top + srcOffset;
      final tgtTop = outRects[i].top;
      srcOffset += flowH;

      final path = Path()
        ..moveTo(incomeRect.right, srcTop)
        ..cubicTo(
          (incomeRect.right + outRects[i].left) / 2,
          srcTop,
          (incomeRect.right + outRects[i].left) / 2,
          tgtTop,
          outRects[i].left,
          tgtTop,
        )
        ..lineTo(outRects[i].left, tgtTop + outRects[i].height)
        ..cubicTo(
          (incomeRect.right + outRects[i].left) / 2,
          tgtTop + outRects[i].height,
          (incomeRect.right + outRects[i].left) / 2,
          srcTop + flowH,
          incomeRect.right,
          srcTop + flowH,
        )
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [
              incomeColor.withValues(alpha: 0.55),
              out.colorValue.withValues(alpha: 0.55),
            ],
          ).createShader(Rect.fromLTRB(
              incomeRect.right, 0, outRects[i].left, 1)),
      );
    }

    // Labels: income on the left.
    _drawText(canvas, 'Доход', Offset(incomeRect.left - labelGap, incomeRect.center.dy),
        alignRight: true);
    _drawText(canvas, '${data.income.round()} BYN',
        Offset(incomeRect.left - labelGap, incomeRect.center.dy + 14),
        alignRight: true, secondary: true);

    for (int i = 0; i < outRects.length; i++) {
      final out = data.outflows[i];
      _drawText(
          canvas,
          '${out.label} · ${out.amount.round()}',
          Offset(outRects[i].right + labelGap, outRects[i].center.dy));
    }
  }

  void _drawText(Canvas canvas, String text, Offset anchor,
      {bool alignRight = false, bool secondary = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: labelStyle.copyWith(
            fontSize: secondary ? 11 : 13,
            fontWeight: secondary ? FontWeight.normal : FontWeight.w600,
          )),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    );
    tp.layout(maxWidth: 130);
    final dx = alignRight ? anchor.dx - tp.width : anchor.dx;
    tp.paint(canvas, Offset(dx, anchor.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _SankeyPainter oldDelegate) =>
      oldDelegate.data != data;
}
