import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
