import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../models/finance.dart';
import '../../services/finance_calc.dart';
import '../../state/currency_state.dart';
import '../../state/providers.dart';
import '../../state/settings_state.dart';

/// "Sankey" — port of `src/components/charts/SankeyFlow.tsx`.
///
/// We don't have an `@nivo/sankey` equivalent for Flutter, so we render a
/// simple two-column flow ourselves: income sources on the left, expense
/// categories on the right, ribbons proportional to the amount.
class SankeyTab extends ConsumerStatefulWidget {
  const SankeyTab({super.key});

  @override
  ConsumerState<SankeyTab> createState() => _SankeyTabState();
}

class _SankeyTabState extends ConsumerState<SankeyTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  void _shift(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final accounts = ref.watch(accountsProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final rates = ref.watch(currencyRatesProvider);

    num convert(num amount, String from, String to) =>
        convertCurrency(amount: amount, from: from, to: to, rates: rates);

    final monthKey = monthKeyOf(_month);
    final monthTx = transactions
        .where((t) => t.date.startsWith(monthKey))
        .toList();

    final incomeSources = <String, num>{};
    final expenseCats = <String, num>{};
    num totalIncome = 0;
    num totalExpense = 0;

    for (final t in monthTx) {
      final acc = accounts.cast<Account?>().firstWhere(
            (a) => a?.id == t.accountId,
            orElse: () => null,
          );
      final cur = acc?.currency ?? baseCurrency;
      final v = convert(t.amount, cur, baseCurrency);
      if (t.type == TransactionType.income) {
        final src = (t.category.isEmpty) ? 'Доход' : t.category;
        incomeSources[src] = (incomeSources[src] ?? 0) + v;
        totalIncome += v;
      } else if (t.type == TransactionType.expense) {
        final cat = (t.category.isEmpty) ? 'Прочее' : t.category;
        expenseCats[cat] = (expenseCats[cat] ?? 0) + v;
        totalExpense += v;
      }
    }

    final sourcesList = incomeSources.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final catsList = expenseCats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final money = NumberFormat.simpleCurrency(
      locale: 'ru',
      name: baseCurrency,
      decimalDigits: 0,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                    onPressed: () => _shift(-1),
                    icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Text(
                    DateFormat('LLLL y', 'ru').format(_month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                    onPressed: () => _shift(1),
                    icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _stat(context, 'Доход', money.format(totalIncome),
                        const Color(0xFF22C55E)),
                    _stat(context, 'Расход', money.format(totalExpense),
                        const Color(0xFFEF4444)),
                    _stat(
                        context,
                        'Сальдо',
                        money.format(totalIncome - totalExpense),
                        totalIncome - totalExpense >= 0
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444)),
                  ],
                ),
                const SizedBox(height: 16),
                if (sourcesList.isEmpty || catsList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Нет данных для потока «Доходы → Расходы».\n'
                        'Добавь хотя бы одну операцию каждого типа.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 360,
                    child: CustomPaint(
                      painter: _SankeyPainter(
                        sources: sourcesList,
                        targets: catsList,
                        textStyle: Theme.of(context).textTheme.bodySmall!,
                        labelColor:
                            Theme.of(context).colorScheme.onSurface,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat(BuildContext ctx, String label, String value, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(ctx).textTheme.labelSmall),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Sankey painter: two columns of stacked bars connected by
/// proportional ribbons. Income on the left, expenses on the right.
class _SankeyPainter extends CustomPainter {
  _SankeyPainter({
    required this.sources,
    required this.targets,
    required this.textStyle,
    required this.labelColor,
  });
  final List<MapEntry<String, num>> sources;
  final List<MapEntry<String, num>> targets;
  final TextStyle textStyle;
  final Color labelColor;

  static const _palette = <Color>[
    Color(0xFF6D5CFF),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFF8B5CF6),
    Color(0xFFF97316),
    Color(0xFF06B6D4),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (sources.isEmpty || targets.isEmpty) return;
    final totalSrc = sources.fold<num>(0, (s, e) => s + e.value);
    final totalTgt = targets.fold<num>(0, (s, e) => s + e.value);
    final flowTotal =
        totalSrc < totalTgt ? totalSrc.toDouble() : totalTgt.toDouble();
    if (flowTotal <= 0) return;

    const labelGap = 8.0;
    const colW = 14.0;
    const sideMargin = 110.0;
    final usableHeight = size.height - 16;
    final leftX = sideMargin;
    final rightX = size.width - sideMargin - colW;

    // Stack source bars proportionally to flowTotal so totals balance.
    final srcRects = <Rect>[];
    final srcColors = <Color>[];
    {
      double y = 8;
      for (var i = 0; i < sources.length; i++) {
        final h = usableHeight * (sources[i].value.toDouble() / totalSrc);
        srcRects.add(Rect.fromLTWH(leftX, y, colW, h));
        srcColors.add(_palette[i % _palette.length]);
        y += h;
      }
    }
    final tgtRects = <Rect>[];
    final tgtColors = <Color>[];
    {
      double y = 8;
      for (var i = 0; i < targets.length; i++) {
        final h = usableHeight * (targets[i].value.toDouble() / totalTgt);
        tgtRects.add(Rect.fromLTWH(rightX, y, colW, h));
        tgtColors.add(_palette[(i + 5) % _palette.length]);
        y += h;
      }
    }

    // Draw bars.
    for (var i = 0; i < srcRects.length; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(srcRects[i], const Radius.circular(3)),
        Paint()..color = srcColors[i],
      );
    }
    for (var i = 0; i < tgtRects.length; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(tgtRects[i], const Radius.circular(3)),
        Paint()..color = tgtColors[i],
      );
    }

    // Compute and draw flows: each source sends slices to each target
    // proportionally, so the matrix is sourceShare × targetShare × flowTotal.
    final srcOffsets = List<double>.filled(sources.length, 0);
    final tgtOffsets = List<double>.filled(targets.length, 0);
    for (var i = 0; i < sources.length; i++) {
      final srcShare = sources[i].value.toDouble() / totalSrc;
      for (var j = 0; j < targets.length; j++) {
        final tgtShare = targets[j].value.toDouble() / totalTgt;
        final v = flowTotal * srcShare * tgtShare;
        if (v <= 0) continue;
        final srcH = usableHeight * (sources[i].value.toDouble() / totalSrc);
        final tgtH = usableHeight * (targets[j].value.toDouble() / totalTgt);
        final flowSrcH = srcH * tgtShare;
        final flowTgtH = tgtH * srcShare;
        final srcTop = srcRects[i].top + srcOffsets[i];
        final tgtTop = tgtRects[j].top + tgtOffsets[j];
        srcOffsets[i] += flowSrcH;
        tgtOffsets[j] += flowTgtH;

        final path = Path()
          ..moveTo(srcRects[i].right, srcTop)
          ..cubicTo(
            (srcRects[i].right + tgtRects[j].left) / 2,
            srcTop,
            (srcRects[i].right + tgtRects[j].left) / 2,
            tgtTop,
            tgtRects[j].left,
            tgtTop,
          )
          ..lineTo(tgtRects[j].left, tgtTop + flowTgtH)
          ..cubicTo(
            (srcRects[i].right + tgtRects[j].left) / 2,
            tgtTop + flowTgtH,
            (srcRects[i].right + tgtRects[j].left) / 2,
            srcTop + flowSrcH,
            srcRects[i].right,
            srcTop + flowSrcH,
          )
          ..close();

        canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              colors: [
                srcColors[i].withValues(alpha: 0.55),
                tgtColors[j].withValues(alpha: 0.55),
              ],
            ).createShader(Rect.fromLTRB(
                srcRects[i].right, 0, tgtRects[j].left, 1)),
        );
      }
    }

    // Labels.
    for (var i = 0; i < srcRects.length; i++) {
      _drawText(canvas, sources[i].key,
          Offset(srcRects[i].left - labelGap, srcRects[i].center.dy),
          alignRight: true);
    }
    for (var i = 0; i < tgtRects.length; i++) {
      _drawText(canvas, targets[i].key,
          Offset(tgtRects[i].right + labelGap, tgtRects[i].center.dy),
          alignRight: false);
    }
  }

  void _drawText(Canvas canvas, String text, Offset anchor,
      {required bool alignRight}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: textStyle.copyWith(color: labelColor)),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 100);
    final dx = alignRight ? anchor.dx - tp.width : anchor.dx;
    final dy = anchor.dy - tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _SankeyPainter old) =>
      old.sources != sources ||
      old.targets != targets ||
      old.labelColor != labelColor;
}
