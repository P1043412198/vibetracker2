import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../services/finance_calc.dart';
import '../../state/currency_state.dart';
import '../../state/providers.dart';
import '../../state/settings_state.dart';

/// "Графики" — phase-1 cut of the React `FinanceVisualsTab` / charts pack.
/// Shows a pie of monthly expenses by category and a 6-month income/expense
/// bar chart. Sankey/Treemap and the rest are tracked in MIGRATION_PLAN.md.
class ChartsTab extends ConsumerWidget {
  const ChartsTab({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    final accounts = ref.watch(accountsProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final rates = ref.watch(currencyRatesProvider);

    num convert(num amount, String from, String to) =>
        convertCurrency(amount: amount, from: from, to: to, rates: rates);

    final now = DateTime.now();
    final facts = computeMonthFacts(
      month: now,
      transactions: transactions,
      accounts: accounts,
      baseCurrency: baseCurrency,
      convert: convert,
    );

    final byCategory = facts.expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total =
        byCategory.fold<num>(0, (sum, e) => sum + e.value);

    final months = List.generate(6, (i) => DateTime(now.year, now.month - 5 + i, 1));
    final monthFacts = months
        .map((m) => computeMonthFacts(
              month: m,
              transactions: transactions,
              accounts: accounts,
              baseCurrency: baseCurrency,
              convert: convert,
            ))
        .toList();

    num maxBarValue = 0;
    for (final f in monthFacts) {
      if (f.income > maxBarValue) maxBarValue = f.income;
      if (f.expense > maxBarValue) maxBarValue = f.expense;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text('Расходы за ${DateFormat.MMMM('ru').format(now)}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: byCategory.isEmpty
                ? const _ChartEmpty(
                    icon: '📊',
                    text: 'Расходов в этом месяце пока нет.',
                  )
                : Column(
                    children: [
                      SizedBox(
                        height: 220,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 48,
                            sections: [
                              for (var i = 0; i < byCategory.length; i++)
                                PieChartSectionData(
                                  value: byCategory[i].value.toDouble(),
                                  color: _palette[i % _palette.length],
                                  title:
                                      '${(byCategory[i].value / total * 100).toStringAsFixed(0)}%',
                                  radius: 60,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._buildLegend(byCategory, baseCurrency),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Доход / расход за 6 мес.',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 240,
              child: maxBarValue == 0
                  ? const _ChartEmpty(
                      icon: '📈',
                      text: 'Недостаточно данных для графика.',
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxBarValue.toDouble() * 1.2,
                        barTouchData: BarTouchData(enabled: true),
                        gridData: const FlGridData(show: true),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= months.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    DateFormat.MMM('ru').format(months[i]),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 44,
                              getTitlesWidget: (value, meta) {
                                if (value == meta.max) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  NumberFormat.compact().format(value),
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          for (var i = 0; i < months.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: monthFacts[i].income.toDouble(),
                                  color: const Color(0xFF22C55E),
                                  width: 12,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                BarChartRodData(
                                  toY: monthFacts[i].expense.toDouble(),
                                  color: const Color(0xFFEF4444),
                                  width: 12,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: Color(0xFF22C55E), label: 'Доход'),
            SizedBox(width: 24),
            _LegendDot(color: Color(0xFFEF4444), label: 'Расход'),
          ],
        ),
        const SizedBox(height: 16),
        Text('Накопительный остаток за 30 дней',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _CashflowLineChart(
          transactions: transactions,
          baseCurrency: baseCurrency,
          convert: convert,
        ),
        const SizedBox(height: 16),
        Text('Расходы по дням недели',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _WeekdaySpendChart(
          transactions: transactions,
          baseCurrency: baseCurrency,
          convert: convert,
        ),
        const SizedBox(height: 16),
        Text('Топ категории за 30 дней',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _TopCategoriesChart(
          transactions: transactions,
          baseCurrency: baseCurrency,
          convert: convert,
          palette: _palette,
        ),
        const SizedBox(height: 16),
        Text('План vs факт по категориям',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _PlanVsFactChart(
          baseCurrency: baseCurrency,
          convert: convert,
        ),
      ],
    );
  }

  List<Widget> _buildLegend(
      List<MapEntry<String, num>> byCategory, String currency) {
    final fmt =
        NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 2);
    return [
      for (var i = 0; i < byCategory.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _palette[i % _palette.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  byCategory[i].key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${fmt.format(byCategory[i].value)} $currency',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
    ];
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.icon, required this.text});
  final String icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _CashflowLineChart extends ConsumerWidget {
  const _CashflowLineChart({
    required this.transactions,
    required this.baseCurrency,
    required this.convert,
  });
  final List transactions;
  final String baseCurrency;
  final num Function(num, String, String) convert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final accountCurrency = <String, String>{
      for (final a in accounts) a.id: a.currency,
    };
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 29));
    final byDay = List<num>.filled(30, 0);
    for (final t in transactions) {
      final dt = DateTime.tryParse(t.date as String);
      if (dt == null) continue;
      final idx = dt.difference(start).inDays;
      if (idx < 0 || idx >= 30) continue;
      final cur = accountCurrency[t.accountId] ?? baseCurrency;
      final amt =
          convert(t.amount as num, cur, baseCurrency).toDouble();
      if (t.type == TransactionType.income) {
        byDay[idx] += amt;
      } else if (t.type == TransactionType.expense) {
        byDay[idx] -= amt;
      }
    }
    num running = 0;
    final spots = <FlSpot>[];
    for (var i = 0; i < 30; i++) {
      running += byDay[i];
      spots.add(FlSpot(i.toDouble(), running.toDouble()));
    }
    final minV = spots.fold<double>(0, (a, s) => math.min(a, s.y));
    final maxV = spots.fold<double>(0, (a, s) => math.max(a, s.y));
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 29,
              minY: minV - 50,
              maxY: maxV + 50,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, _) => Text(
                        NumberFormat.compact().format(v),
                        style: const TextStyle(fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 5,
                    reservedSize: 22,
                    getTitlesWidget: (v, _) {
                      final d = start.add(Duration(days: v.toInt()));
                      return Text(DateFormat('dd.MM').format(d),
                          style: const TextStyle(fontSize: 9));
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  barWidth: 2.2,
                  color: const Color(0xFF6D5CFF),
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF6D5CFF).withValues(alpha: 0.18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekdaySpendChart extends StatelessWidget {
  const _WeekdaySpendChart({
    required this.transactions,
    required this.baseCurrency,
    required this.convert,
  });
  final List transactions;
  final String baseCurrency;
  final num Function(num, String, String) convert;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 30));
    final byDow = List<num>.filled(7, 0);
    for (final t in transactions) {
      if (t.type != TransactionType.expense) continue;
      final dt = DateTime.tryParse(t.date as String);
      if (dt == null || dt.isBefore(start)) continue;
      byDow[dt.weekday - 1] +=
          convert(t.amount as num, baseCurrency, baseCurrency);
    }
    final maxV = byDow.fold<num>(0, (a, b) => b > a ? b : a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxV.toDouble() * 1.2 + 1,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (v, _) => Text(
                        NumberFormat.compact().format(v),
                        style: const TextStyle(fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, _) {
                      const names = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
                      final i = v.toInt();
                      if (i < 0 || i >= 7) return const SizedBox.shrink();
                      return Text(names[i],
                          style: const TextStyle(fontSize: 11));
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              barGroups: [
                for (var i = 0; i < 7; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: byDow[i].toDouble(),
                      color: const Color(0xFFEF4444),
                      width: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopCategoriesChart extends StatelessWidget {
  const _TopCategoriesChart({
    required this.transactions,
    required this.baseCurrency,
    required this.convert,
    required this.palette,
  });
  final List transactions;
  final String baseCurrency;
  final num Function(num, String, String) convert;
  final List<Color> palette;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 30));
    final by = <String, num>{};
    for (final t in transactions) {
      if (t.type != TransactionType.expense) continue;
      final dt = DateTime.tryParse(t.date as String);
      if (dt == null || dt.isBefore(start)) continue;
      final cat = (t.category as String?) ?? '—';
      by[cat] = (by[cat] ?? 0) +
          convert(t.amount as num, baseCurrency, baseCurrency);
    }
    final entries = by.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();
    final total = top.fold<num>(0, (a, e) => a + e.value);
    final fmt = NumberFormat.currency(
        locale: 'ru_RU', symbol: '', decimalDigits: 0);
    if (top.isEmpty) {
      return const Card(
          child: Padding(
              padding: EdgeInsets.all(16),
              child: _ChartEmpty(
                icon: '🏷️',
                text: 'Расходы по категориям появятся здесь.',
              )));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            for (var i = 0; i < top.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: palette[i % palette.length],
                              borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(top[i].key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                          '${fmt.format(top[i].value)} $baseCurrency',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : (top[i].value / total).toDouble(),
                        minHeight: 6,
                        color: palette[i % palette.length],
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanVsFactChart extends ConsumerWidget {
  const _PlanVsFactChart({
    required this.baseCurrency,
    required this.convert,
  });
  final String baseCurrency;
  final num Function(num, String, String) convert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(monthlyBudgetPlansProvider);
    final transactions = ref.watch(transactionsProvider);
    final accounts = ref.watch(accountsProvider);
    final now = DateTime.now();
    final monthKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    final plan = plans.cast().firstWhere(
        (p) => (p as dynamic).monthKey == monthKey,
        orElse: () => null);
    if (plan == null) {
      return const Card(
          child: Padding(
              padding: EdgeInsets.all(16),
              child: _ChartEmpty(
                icon: '🎯',
                text: 'План на месяц ещё не создан.',
              )));
    }
    final facts = computeMonthFacts(
      month: now,
      transactions: transactions,
      accounts: accounts,
      baseCurrency: baseCurrency,
      convert: convert,
    );
    final cps = (plan as dynamic).categoryPlans as List;
    if (cps.isEmpty) {
      return const Card(
          child: Padding(
              padding: EdgeInsets.all(16),
              child: _ChartEmpty(
                icon: '🎯',
                text: 'В плане ещё нет категорий.',
              )));
    }
    final maxV = cps.fold<num>(0, (a, c) {
      final cat = (c as dynamic).category as String;
      final fact = facts.expenseByCategory[cat] ?? 0;
      final p = (c as dynamic).planned as num;
      return [a, p, fact].reduce((x, y) => x > y ? x : y);
    });
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: SizedBox(
          height: 12.0 + cps.length * 32.0,
          child: ListView.builder(
            itemCount: cps.length,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, i) {
              final c = cps[i] as dynamic;
              final cat = c.category as String;
              final planned = c.planned as num;
              final fact = facts.expenseByCategory[cat] ?? 0;
              final overshoot = fact > planned && planned > 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(cat,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                      Text(
                          '${NumberFormat.compact().format(fact)} / '
                          '${NumberFormat.compact().format(planned)}',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: overshoot
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF22C55E))),
                    ]),
                    const SizedBox(height: 2),
                    Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value:
                              maxV == 0 ? 0 : (planned / maxV).toDouble(),
                          minHeight: 6,
                          color: const Color(0xFF3B82F6),
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: maxV == 0 ? 0 : (fact / maxV).toDouble(),
                          minHeight: 6,
                          color: overshoot
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF22C55E)
                                  .withValues(alpha: 0.85),
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ]),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
