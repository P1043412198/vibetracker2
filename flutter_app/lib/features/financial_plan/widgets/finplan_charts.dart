import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../models/finance.dart';
import '../../../models/financial_plan_month.dart';
import '../../../models/enums.dart';
import '../financial_plan_helpers.dart';

/// Visual analytics block for the financial plan month detail page.
///
/// Renders a stack of modern charts driven by the active scenario:
///   * KPI ring strip — quick metrics with progress halos
///   * Income flow — stacked horizontal bar that shows where every dollar of
///     planned income lands (expense / savings / debt / free)
///   * Expense breakdown donut — share of each expense section
///   * Plan vs Fact bars — grouped bars per section vs real transactions
///   * Daily balance — line chart with the projected balance curve
class FinPlanAnalytics extends StatelessWidget {
  const FinPlanAnalytics({
    super.key,
    required this.plan,
    required this.scenario,
    required this.summary,
    required this.transactions,
    required this.fact,
  });

  final FinancialPlanMonth plan;
  final FinPlanScenario scenario;
  final FinPlanSummary summary;
  final List<Transaction> transactions;
  final MonthFact fact;

  @override
  Widget build(BuildContext context) {
    final hasIncome = summary.income > 0;
    final hasExpense = summary.expense + summary.savings + summary.debt > 0;
    final sections = scenario.sections;

    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KpiRingStrip(summary: summary, fact: fact)
            .animate()
            .fadeIn(duration: 280.ms)
            .slideY(begin: 0.06, end: 0),
        if (hasIncome) ...[
          const SizedBox(height: 12),
          _ChartCard(
            title: 'Куда уходит доход',
            subtitle: 'распределение запланированного дохода по статьям',
            child: _IncomeFlowBar(summary: summary),
          )
              .animate()
              .fadeIn(duration: 320.ms, delay: 60.ms)
              .slideY(begin: 0.06, end: 0),
        ],
        if (hasExpense) ...[
          const SizedBox(height: 12),
          _ChartCard(
            title: 'Структура расходов',
            subtitle: 'доля каждой секции расходов',
            child: _ExpenseDonut(scenario: scenario),
          )
              .animate()
              .fadeIn(duration: 320.ms, delay: 120.ms)
              .slideY(begin: 0.06, end: 0),
        ],
        const SizedBox(height: 12),
        _ChartCard(
          title: 'План vs Факт',
          subtitle: 'факт берётся из транзакций по привязанной категории',
          child: _PlanVsFactBars(
            scenario: scenario,
            transactions: transactions,
            monthKey: plan.monthKey,
          ),
        )
            .animate()
            .fadeIn(duration: 320.ms, delay: 180.ms)
            .slideY(begin: 0.06, end: 0),
        const SizedBox(height: 12),
        _ChartCard(
          title: 'Динамика баланса',
          subtitle: 'нарастающим итогом по дням месяца',
          child: _DailyBalanceLine(
            scenario: scenario,
            transactions: transactions,
            monthKey: plan.monthKey,
          ),
        )
            .animate()
            .fadeIn(duration: 320.ms, delay: 240.ms)
            .slideY(begin: 0.06, end: 0),
      ],
    );
  }
}

/// ────────────────────────────────────────────────────────────────────────
/// Generic card wrapper used by every chart in the analytics block.
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────────────
/// KPI ring strip (3 rings side by side: Доход / Расход план / Сбережения).
class _KpiRingStrip extends StatelessWidget {
  const _KpiRingStrip({required this.summary, required this.fact});
  final FinPlanSummary summary;
  final MonthFact fact;

  @override
  Widget build(BuildContext context) {
    final totalSpend = summary.expense + summary.savings + summary.debt;
    final incomeProgress = summary.income == 0
        ? 0.0
        : (fact.income / summary.income).clamp(0.0, 1.0);
    final expenseProgress = totalSpend == 0
        ? 0.0
        : (fact.expense / totalSpend).clamp(0.0, 1.5);
    final savingsTarget = summary.income == 0
        ? 0.0
        : (summary.savings / summary.income).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: _KpiRing(
                label: 'Доход',
                planned: summary.income,
                actual: fact.income,
                progress: incomeProgress,
                color: const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _KpiRing(
                label: 'Расход',
                planned: totalSpend,
                actual: fact.expense,
                progress: expenseProgress.clamp(0.0, 1.0),
                color: const Color(0xFFEF4444),
                warningWhenOver: true,
                isOver: expenseProgress > 1.0,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _KpiRing(
                label: 'Сбережения',
                planned: summary.savings,
                actual: summary.savings, // saved == planned by definition
                progress: savingsTarget,
                color: const Color(0xFF6366F1),
                progressLabel: '${(savingsTarget * 100).round()}% дохода',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiRing extends StatelessWidget {
  const _KpiRing({
    required this.label,
    required this.planned,
    required this.actual,
    required this.progress,
    required this.color,
    this.warningWhenOver = false,
    this.isOver = false,
    this.progressLabel,
  });

  final String label;
  final double planned;
  final double actual;
  final double progress;
  final Color color;
  final bool warningWhenOver;
  final bool isOver;
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(
      locale: 'ru',
      symbol: '',
      decimalDigits: 0,
    );
    final ringColor =
        warningWhenOver && isOver ? const Color(0xFFEAB308) : color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 8,
                  backgroundColor: ringColor.withValues(alpha: 0.14),
                  valueColor: AlwaysStoppedAnimation(ringColor),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(progress.clamp(0.0, 1.0) * 100).round()}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: ringColor,
                    ),
                  ),
                  if (isOver)
                    const Icon(Icons.warning_amber_rounded,
                        size: 12, color: Color(0xFFEAB308)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            progressLabel ?? '${fmt.format(actual)} / ${fmt.format(planned)}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// ────────────────────────────────────────────────────────────────────────
/// Stacked horizontal bar that shows where the income goes.
class _IncomeFlowBar extends StatelessWidget {
  const _IncomeFlowBar({required this.summary});
  final FinPlanSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final income = summary.income;
    if (income <= 0) {
      return const SizedBox.shrink();
    }
    final free = (summary.balance).clamp(0.0, double.infinity);
    final expense = summary.expense;
    final savings = summary.savings;
    final debt = summary.debt;
    final overspend =
        summary.balance < 0 ? summary.balance.abs() : 0;
    final slices = <_FlowSlice>[
      if (expense > 0)
        _FlowSlice('Расход', expense, const Color(0xFFEF4444)),
      if (savings > 0)
        _FlowSlice('Сбережения', savings, const Color(0xFF6366F1)),
      if (debt > 0)
        _FlowSlice('Долги', debt, const Color(0xFFF59E0B)),
      if (free > 0)
        _FlowSlice('Свободно', free.toDouble(), const Color(0xFF22C55E)),
      if (overspend > 0)
        _FlowSlice('Перерасход', overspend.toDouble(), const Color(0xFFEAB308)),
    ];
    if (slices.isEmpty) {
      return const SizedBox.shrink();
    }
    final total = slices.fold<double>(0, (a, b) => a + b.value);
    final fmt =
        NumberFormat.currency(locale: 'ru', symbol: '', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 18,
            child: Row(
              children: [
                for (final s in slices)
                  Expanded(
                    flex: ((s.value / total) * 1000).round(),
                    child: Tooltip(
                      message: '${s.label}: ${fmt.format(s.value)}',
                      child: Container(color: s.color),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final s in slices)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: s.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${s.label} · ${fmt.format(s.value)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _FlowSlice {
  _FlowSlice(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

/// ────────────────────────────────────────────────────────────────────────
/// Donut chart showing distribution of expense by section.
class _ExpenseDonut extends StatefulWidget {
  const _ExpenseDonut({required this.scenario});
  final FinPlanScenario scenario;
  @override
  State<_ExpenseDonut> createState() => _ExpenseDonutState();
}

class _ExpenseDonutState extends State<_ExpenseDonut> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt =
        NumberFormat.currency(locale: 'ru', symbol: '', decimalDigits: 0);
    final entries = <_DonutEntry>[];
    for (final section in widget.scenario.sections) {
      final isSpend = section.kind == FinPlanSectionKind.expense ||
          section.kind == FinPlanSectionKind.savings ||
          section.kind == FinPlanSectionKind.debt;
      if (!isSpend) continue;
      final total =
          section.items.fold<double>(0, (acc, i) => acc + i.amount);
      if (total <= 0) continue;
      entries.add(_DonutEntry(
        title: section.title,
        value: total,
        color: Color(section.color ?? defaultColorForKind(section.kind)),
      ));
    }
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final total = entries.fold<double>(0, (a, b) => a + b.value);
    return SizedBox(
      height: 220,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 56,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        _touched = -1;
                        return;
                      }
                      _touched =
                          response.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                sections: [
                  for (var i = 0; i < entries.length; i++)
                    PieChartSectionData(
                      value: entries[i].value,
                      color: entries[i].color,
                      radius: i == _touched ? 56 : 48,
                      showTitle: i == _touched,
                      title:
                          '${((entries[i].value / total) * 100).round()}%',
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fmt.format(total),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'всего расходов',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < entries.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: entries[i].color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entries[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  i == _touched ? FontWeight.w900 : FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${((entries[i].value / total) * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutEntry {
  _DonutEntry({required this.title, required this.value, required this.color});
  final String title;
  final double value;
  final Color color;
}

/// ────────────────────────────────────────────────────────────────────────
/// Grouped vertical bars: plan vs fact per section.
class _PlanVsFactBars extends StatelessWidget {
  const _PlanVsFactBars({
    required this.scenario,
    required this.transactions,
    required this.monthKey,
  });
  final FinPlanScenario scenario;
  final List<Transaction> transactions;
  final String monthKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = <_BarEntry>[];
    for (final section in scenario.sections) {
      final plan =
          section.items.fold<double>(0, (acc, i) => acc + i.amount);
      double fact = 0;
      for (final item in section.items) {
        fact += factForItem(item, transactions, monthKey);
      }
      entries.add(_BarEntry(
        title: section.title,
        plan: plan,
        fact: fact,
        color: Color(section.color ?? defaultColorForKind(section.kind)),
      ));
    }
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final maxVal = entries.fold<double>(
        0, (acc, e) => acc > e.plan ? acc : (e.plan > e.fact ? e.plan : e.fact));
    final maxY = maxVal == 0 ? 1.0 : (maxVal * 1.15);
    final fmt =
        NumberFormat.compactCurrency(locale: 'ru', symbol: '', decimalDigits: 0);

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceBetween,
          barGroups: [
            for (var i = 0; i < entries.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 4,
                barRods: [
                  BarChartRodData(
                    toY: entries[i].plan,
                    color: entries[i].color,
                    width: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  BarChartRodData(
                    toY: entries[i].fact,
                    color: entries[i].color.withValues(alpha: 0.45),
                    width: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
              strokeWidth: 1,
              dashArray: const [4, 4],
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: maxY / 4,
                getTitlesWidget: (v, meta) => Text(
                  fmt.format(v),
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, meta) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  final t = entries[idx].title;
                  final short = t.length > 8 ? '${t.substring(0, 7)}…' : t;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      short,
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItem: (group, gIdx, rod, rIdx) {
                final e = entries[group.x];
                final isPlan = rIdx == 0;
                final label = isPlan ? 'План' : 'Факт';
                return BarTooltipItem(
                  '${e.title}\n$label: ${fmt.format(rod.toY)}',
                  TextStyle(
                    color: scheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BarEntry {
  _BarEntry({
    required this.title,
    required this.plan,
    required this.fact,
    required this.color,
  });
  final String title;
  final double plan;
  final double fact;
  final Color color;
}

/// ────────────────────────────────────────────────────────────────────────
/// Cumulative balance line — plan curve (linear distribution of total income
/// minus total expenses) versus actual cumulative balance from transactions.
class _DailyBalanceLine extends StatelessWidget {
  const _DailyBalanceLine({
    required this.scenario,
    required this.transactions,
    required this.monthKey,
  });
  final FinPlanScenario scenario;
  final List<Transaction> transactions;
  final String monthKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final start = parseMonthKey(monthKey);
    if (start == null) return const SizedBox.shrink();
    final daysInMonth = DateTime(start.year, start.month + 1, 0).day;
    final totalIncome = scenario.sections
        .where((s) => s.kind == FinPlanSectionKind.income)
        .expand((s) => s.items)
        .fold<double>(0, (a, b) => a + b.amount);
    final totalSpend = scenario.sections
        .where((s) =>
            s.kind == FinPlanSectionKind.expense ||
            s.kind == FinPlanSectionKind.savings ||
            s.kind == FinPlanSectionKind.debt)
        .expand((s) => s.items)
        .fold<double>(0, (a, b) => a + b.amount);
    // Actual cumulative balance from transactions
    final byDay = List<double>.filled(daysInMonth + 1, 0);
    for (final t in transactions) {
      if (!t.date.startsWith(monthKey)) continue;
      final parts = t.date.split('-');
      if (parts.length < 3) continue;
      final day = int.tryParse(parts[2].substring(0, 2));
      if (day == null || day < 1 || day > daysInMonth) continue;
      final delta = t.type == TransactionType.income
          ? t.amount.toDouble()
          : -t.amount.toDouble();
      byDay[day] += delta;
    }
    final factSpots = <FlSpot>[];
    double cum = 0;
    factSpots.add(const FlSpot(0, 0));
    for (var d = 1; d <= daysInMonth; d++) {
      cum += byDay[d];
      factSpots.add(FlSpot(d.toDouble(), cum));
    }
    final planSpots = <FlSpot>[
      const FlSpot(0, 0),
      FlSpot(daysInMonth.toDouble(), totalIncome - totalSpend),
    ];

    final today = DateTime.now();
    final isCurrentMonth =
        today.year == start.year && today.month == start.month;
    final highlightDay = isCurrentMonth ? today.day : null;

    final allVals = [
      ...planSpots.map((s) => s.y),
      ...factSpots.map((s) => s.y),
      0.0,
    ];
    final minV = allVals.reduce((a, b) => a < b ? a : b);
    final maxV = allVals.reduce((a, b) => a > b ? a : b);
    final pad = ((maxV - minV).abs() * 0.15).clamp(50, double.infinity);
    final fmt =
        NumberFormat.compactCurrency(locale: 'ru', symbol: '', decimalDigits: 0);

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: daysInMonth.toDouble(),
          minY: minV - pad,
          maxY: maxV + pad,
          extraLinesData: highlightDay == null
              ? const ExtraLinesData()
              : ExtraLinesData(verticalLines: [
                  VerticalLine(
                    x: highlightDay.toDouble(),
                    color: scheme.primary.withValues(alpha: 0.5),
                    strokeWidth: 1.5,
                    dashArray: const [4, 4],
                    label: VerticalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                      labelResolver: (_) => 'сейчас · день $highlightDay',
                    ),
                  ),
                ]),
          lineBarsData: [
            LineChartBarData(
              spots: planSpots,
              isCurved: false,
              color: scheme.primary,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              dashArray: const [6, 4],
            ),
            LineChartBarData(
              spots: factSpots,
              isCurved: true,
              curveSmoothness: 0.18,
              color: scheme.primary,
              barWidth: 3,
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.primary.withValues(alpha: 0.25),
                    scheme.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, bar) {
                  if (highlightDay == null) return false;
                  return spot.x.toInt() == highlightDay;
                },
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: scheme.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
              strokeWidth: 1,
              dashArray: const [4, 4],
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (daysInMonth / 6).clamp(1, daysInMonth).toDouble(),
                reservedSize: 22,
                getTitlesWidget: (v, meta) => Text(
                  v.toInt().toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (v, meta) => Text(
                  fmt.format(v),
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItems: (touched) => touched
                  .map(
                    (t) => LineTooltipItem(
                      'день ${t.x.toInt()}: ${fmt.format(t.y)}',
                      TextStyle(
                        color: scheme.onInverseSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────────────
/// Year overview — 12-month bar chart of income/expense for the financial
/// plan list page header. Aggregates real transactions per month, regardless
/// of whether a plan exists. The bar height represents totals, the
/// difference (income - expense) is overlaid as a thin line/sparkline.
class YearOverviewCard extends StatefulWidget {
  const YearOverviewCard({
    super.key,
    required this.transactions,
    required this.plans,
    required this.year,
    required this.onYearChanged,
  });

  final List<Transaction> transactions;
  final List<FinancialPlanMonth> plans;
  final int year;
  final ValueChanged<int> onYearChanged;

  @override
  State<YearOverviewCard> createState() => _YearOverviewCardState();
}

class _YearOverviewCardState extends State<YearOverviewCard> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt =
        NumberFormat.compactCurrency(locale: 'ru', symbol: '', decimalDigits: 0);
    final byMonthIncome = List<double>.filled(12, 0);
    final byMonthExpense = List<double>.filled(12, 0);
    for (final t in widget.transactions) {
      final parts = t.date.split('-');
      if (parts.length < 2) continue;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (y != widget.year || m == null || m < 1 || m > 12) continue;
      if (t.type == TransactionType.income) {
        byMonthIncome[m - 1] += t.amount.toDouble();
      } else if (t.type == TransactionType.expense) {
        byMonthExpense[m - 1] += t.amount.toDouble();
      }
    }
    final totalIncome = byMonthIncome.fold<double>(0, (a, b) => a + b);
    final totalExpense = byMonthExpense.fold<double>(0, (a, b) => a + b);
    final maxVal = [
      ...byMonthIncome,
      ...byMonthExpense,
      1.0,
    ].reduce((a, b) => a > b ? a : b);
    final maxY = maxVal * 1.15;

    final monthNames = [
      'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Год ${widget.year}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Прошлый год',
                  onPressed: () => widget.onYearChanged(widget.year - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Следующий год',
                  onPressed: () => widget.onYearChanged(widget.year + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _YearKpi(
                  label: 'Доход',
                  value: totalIncome,
                  color: const Color(0xFF22C55E),
                ),
                const SizedBox(width: 12),
                _YearKpi(
                  label: 'Расход',
                  value: totalExpense,
                  color: const Color(0xFFEF4444),
                ),
                const SizedBox(width: 12),
                _YearKpi(
                  label: 'Сальдо',
                  value: totalIncome - totalExpense,
                  color: totalIncome - totalExpense >= 0
                      ? const Color(0xFF6366F1)
                      : const Color(0xFFEAB308),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barGroups: [
                    for (var i = 0; i < 12; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 2,
                        barRods: [
                          BarChartRodData(
                            toY: byMonthIncome[i],
                            color: const Color(0xFF22C55E),
                            width: 6,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          BarChartRodData(
                            toY: byMonthExpense[i],
                            color: const Color(0xFFEF4444),
                            width: 6,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ],
                      ),
                  ],
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      strokeWidth: 1,
                      dashArray: const [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: maxY / 4,
                        getTitlesWidget: (v, meta) => Text(
                          fmt.format(v),
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (v, meta) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            monthNames[v.toInt().clamp(0, 11)],
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => scheme.inverseSurface,
                      getTooltipItem: (group, gIdx, rod, rIdx) {
                        final isIncome = rIdx == 0;
                        final label = isIncome ? 'Доход' : 'Расход';
                        return BarTooltipItem(
                          '${monthNames[group.x]} · $label\n${fmt.format(rod.toY)}',
                          TextStyle(
                            color: scheme.onInverseSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YearKpi extends StatelessWidget {
  const _YearKpi({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fmt =
        NumberFormat.currency(locale: 'ru', symbol: '', decimalDigits: 0);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.20),
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                fmt.format(value),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────────────
/// Bar chart comparing all scenarios of the same month (balance / income /
/// expense per scenario). Used on the compare page and as an inline card.
class ScenarioComparisonChart extends StatelessWidget {
  const ScenarioComparisonChart({super.key, required this.plan});
  final FinancialPlanMonth plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scenarios = plan.scenarios;
    if (scenarios.length < 2) return const SizedBox.shrink();
    final summaries = [
      for (final s in scenarios)
        _ScenarioStat(
          scenario: s,
          income: s.sections
              .where((sec) => sec.kind == FinPlanSectionKind.income)
              .expand((sec) => sec.items)
              .fold<double>(0, (a, b) => a + b.amount),
          expense: s.sections
              .where((sec) =>
                  sec.kind == FinPlanSectionKind.expense ||
                  sec.kind == FinPlanSectionKind.savings ||
                  sec.kind == FinPlanSectionKind.debt)
              .expand((sec) => sec.items)
              .fold<double>(0, (a, b) => a + b.amount),
        ),
    ];
    final maxV = summaries
        .expand((s) => [s.income, s.expense])
        .fold<double>(1, (a, b) => a > b ? a : b);
    final fmt =
        NumberFormat.compactCurrency(locale: 'ru', symbol: '', decimalDigits: 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Сравнение сценариев',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'доход (план) vs расход (план) для каждого сценария',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maxV * 1.2,
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: [
                    for (var i = 0; i < summaries.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: summaries[i].income,
                            color: const Color(0xFF22C55E),
                            width: 14,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          BarChartRodData(
                            toY: summaries[i].expense,
                            color: const Color(0xFFEF4444),
                            width: 14,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      strokeWidth: 1,
                      dashArray: const [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: maxV / 4,
                        getTitlesWidget: (v, meta) => Text(
                          fmt.format(v),
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (v, meta) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= summaries.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              summaries[idx].scenario.name,
                              style: TextStyle(
                                fontSize: 10,
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioStat {
  _ScenarioStat({
    required this.scenario,
    required this.income,
    required this.expense,
  });
  final FinPlanScenario scenario;
  final double income;
  final double expense;
}
