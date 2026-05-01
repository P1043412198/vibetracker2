import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/category.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../utils/month_key.dart';
import '../widgets/period_chip.dart';
import '../widgets/section_card.dart';

class AnalyticsScreen extends StatefulWidget {
  final AppState state;

  const AnalyticsScreen({super.key, required this.state});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  /// 0 — Неделя, 1 — Месяц, 2 — Год, 3 — Период
  int _period = 1;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final month = widget.state.selectedMonth;
        final byCat = widget.state.expenseByCategoryIn(month);
        final total = byCat.values.fold(0.0, (a, b) => a + b);
        final entries = byCat.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return Scaffold(
          appBar: AppBar(title: const Text('Аналитика')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              PeriodChips(
                labels: const ['Неделя', 'Месяц', 'Год', 'Период'],
                selected: _period,
                onSelected: (i) => setState(() => _period = i),
              ),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Структура расходов'),
              SectionCard(
                child: total == 0
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'В этом месяце расходов нет',
                            style:
                                TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 44,
                                    sections: [
                                      for (var i = 0; i < entries.length; i++)
                                        PieChartSectionData(
                                          color: DefaultCategories.byId(
                                                      entries[i].key)
                                                  ?.color ??
                                              AppColors.expenseColors[
                                                  i % AppColors.expenseColors.length],
                                          value: entries[i].value,
                                          radius: 22,
                                          showTitle: false,
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      formatMoney(total),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Text(
                                      'Всего',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final e in entries.take(5))
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4),
                                    child: _LegendRow(
                                      color: DefaultCategories.byId(e.key)
                                              ?.color ??
                                          AppColors.primary,
                                      label:
                                          DefaultCategories.byId(e.key)?.name ??
                                              e.key,
                                      pct: total == 0
                                          ? 0
                                          : (e.value / total * 100),
                                      amount: e.value,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Динамика расходов'),
              SectionCard(
                child: SizedBox(
                  height: 200,
                  child: _DailyExpenseChart(state: widget.state),
                ),
              ),
              const SizedBox(height: 16),
              SectionHeader(
                title: 'За ${formatMonthLong(month)}',
              ),
              SectionCard(
                child: Column(
                  children: [
                    _SummaryRow(
                      label: 'Доходы',
                      value: widget.state.totalIncomeIn(month),
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 6),
                    _SummaryRow(
                      label: 'Расходы',
                      value: widget.state.totalExpenseIn(month),
                      color: AppColors.danger,
                      negative: true,
                    ),
                    const Divider(
                        height: 18, color: AppColors.divider),
                    _SummaryRow(
                      label: 'Сальдо',
                      value: widget.state.totalIncomeIn(month) -
                          widget.state.totalExpenseIn(month),
                      color: widget.state.totalIncomeIn(month) -
                                  widget.state.totalExpenseIn(month) >=
                              0
                          ? AppColors.primary
                          : AppColors.danger,
                      bold: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final double pct;
  final double amount;
  const _LegendRow({
    required this.color,
    required this.label,
    required this.pct,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '${pct.toStringAsFixed(0)}%',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatMoney(amount),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool negative;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
    this.negative = false,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = negative ? -value.abs() : value;
    final text = negative
        ? '−${formatMoney(value.abs())}'
        : formatMoneySigned(displayValue);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              fontSize: bold ? 15 : 14,
            ),
          ),
        ),
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color,
            fontSize: bold ? 16 : 14,
          ),
        ),
      ],
    );
  }
}

class _DailyExpenseChart extends StatelessWidget {
  final AppState state;
  const _DailyExpenseChart({required this.state});

  @override
  Widget build(BuildContext context) {
    final month = state.selectedMonth;
    final byDay = state.dailyExpenseIn(month);
    final dim = daysInMonth(month);
    final spots = <FlSpot>[];
    var maxY = 0.0;
    for (var d = 1; d <= dim; d++) {
      final v = byDay[d] ?? 0;
      if (v > maxY) maxY = v;
      spots.add(FlSpot(d.toDouble(), v));
    }
    final niceMaxY = (maxY * 1.2).clamp(100, double.infinity);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: niceMaxY.toDouble(),
        minX: 1,
        maxX: dim.toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: niceMaxY / 4,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.divider, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: niceMaxY / 4,
              getTitlesWidget: (v, meta) => Text(
                formatNumberCompact(v),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (dim / 5).floorToDouble().clamp(1, 99).toDouble(),
              getTitlesWidget: (v, meta) {
                final day = v.toInt();
                if (day < 1 || day > dim) {
                  return const SizedBox.shrink();
                }
                return Text(
                  '$day',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            curveSmoothness: 0.25,
            spots: spots,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}
