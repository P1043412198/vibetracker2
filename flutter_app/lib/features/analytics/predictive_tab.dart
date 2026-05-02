import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../models/finance.dart';
import '../../services/ai_service.dart';
import '../../services/finance_calc.dart';
import '../../state/currency_state.dart';
import '../../state/providers.dart';
import '../../state/settings_state.dart';

/// "Прогноз" — port of `src/components/PredictiveBudgetTab.tsx`.
///
/// Plots cumulative spend so far in the current month plus an extrapolation
/// to month-end based on the average daily spend, against the planned monthly
/// budget. Optionally summarises the situation via Gemini (uses the same
/// `geminiApiKey` that the AI workout generator uses).
class PredictiveTab extends ConsumerStatefulWidget {
  const PredictiveTab({super.key});

  @override
  ConsumerState<PredictiveTab> createState() => _PredictiveTabState();
}

class _PredictiveTabState extends ConsumerState<PredictiveTab> {
  String? _aiInsight;
  bool _aiLoading = false;
  String? _aiError;

  Future<void> _runAi(_PredictData d, String currency) async {
    setState(() {
      _aiLoading = true;
      _aiError = null;
    });
    try {
      final prompt =
          'Проанализируй текущие расходы пользователя за этот месяц.\n'
          'Сегодня ${d.currentDay} день из ${d.daysInMonth}.\n'
          'Бюджет на месяц: ${d.budget.toStringAsFixed(0)} $currency.\n'
          'Уже потрачено: ${d.spent.toStringAsFixed(0)} $currency.\n'
          'Средний расход в день: ${d.avgPerDay.toStringAsFixed(0)} $currency.\n'
          'Прогноз трат к концу месяца: ${d.predicted.toStringAsFixed(0)} $currency.\n\n'
          'Напиши короткий, мотивирующий и полезный инсайт (максимум 3-4 предложения). '
          'Предупреди о кассовом разрыве, если прогноз превышает бюджет. '
          'Посоветуй, на сколько нужно сократить дневные траты, чтобы уложиться в бюджет.';
      final out = await AiService.generateContent(prompt);
      if (!mounted) return;
      setState(() {
        _aiInsight = out;
        _aiLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = e.toString();
        _aiLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final accounts = ref.watch(accountsProvider);
    final budgetPlans = ref.watch(monthlyBudgetPlansProvider);
    final budgetLimits = ref.watch(budgetLimitsProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final rates = ref.watch(currencyRatesProvider);
    num convert(num amount, String from, String to) =>
        convertCurrency(amount: amount, from: from, to: to, rates: rates);

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final currentDay = now.day;
    final monthKey = monthKeyOf(now);

    // Total month budget — prefer explicit month plan, fall back to limits.
    num budget = 0;
    final monthPlan = budgetPlans
        .cast<MonthlyBudgetPlan?>()
        .firstWhere((p) => p?.monthKey == monthKey, orElse: () => null);
    if (monthPlan != null) {
      for (final cp in monthPlan.categoryPlans) {
        budget += cp.planned;
      }
    } else {
      for (final l in budgetLimits) {
        final cur = (l.currency == null || l.currency!.isEmpty)
            ? baseCurrency
            : l.currency!;
        budget += convert(l.amount, cur, baseCurrency);
      }
    }

    // Cumulative actual spend per day so far.
    final dailySpend = List<double>.filled(daysInMonth + 1, 0);
    final monthExpenses = transactions
        .where((t) =>
            t.type == TransactionType.expense && t.date.startsWith(monthKey))
        .toList();
    for (final t in monthExpenses) {
      final acc = accounts.cast<Account?>().firstWhere(
            (a) => a?.id == t.accountId,
            orElse: () => null,
          );
      final cur = acc?.currency ?? baseCurrency;
      final v = convert(t.amount, cur, baseCurrency).toDouble();
      final day = int.tryParse(t.date.split('-').last) ?? 0;
      if (day >= 1 && day <= daysInMonth) dailySpend[day] += v;
    }
    double cum = 0;
    final actualSpots = <FlSpot>[];
    for (var d = 1; d <= currentDay && d <= daysInMonth; d++) {
      cum += dailySpend[d];
      actualSpots.add(FlSpot(d.toDouble(), cum));
    }
    final spent = cum;
    final avgPerDay = currentDay > 0 ? spent / currentDay : 0;
    final predictedEnd = spent + avgPerDay * (daysInMonth - currentDay);

    final predictSpots = <FlSpot>[];
    if (currentDay <= daysInMonth) {
      predictSpots.add(FlSpot(currentDay.toDouble(), spent));
      for (var d = currentDay + 1; d <= daysInMonth; d++) {
        predictSpots
            .add(FlSpot(d.toDouble(), spent + avgPerDay * (d - currentDay)));
      }
    }
    final budgetSpots = <FlSpot>[];
    if (budget > 0) {
      for (var d = 1; d <= daysInMonth; d++) {
        budgetSpots.add(FlSpot(d.toDouble(), budget * d / daysInMonth));
      }
    }

    final money = NumberFormat.simpleCurrency(
      locale: 'ru',
      name: baseCurrency,
      decimalDigits: 0,
    );
    final overBudget = budget > 0 && predictedEnd > budget;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Прогноз на ${DateFormat('LLLL', 'ru').format(now)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _statRow('Бюджет', money.format(budget),
                    Theme.of(context).colorScheme.primary),
                _statRow('Уже потрачено', money.format(spent),
                    const Color(0xFFEF4444)),
                _statRow('Средний расход / день',
                    money.format(avgPerDay), const Color(0xFFF59E0B)),
                _statRow(
                  'Прогноз к концу месяца',
                  money.format(predictedEnd),
                  overBudget
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF22C55E),
                  bold: true,
                ),
                if (budget > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      overBudget
                          ? 'Перерасход на ${money.format(predictedEnd - budget)}.'
                              ' Чтобы уложиться, держи дневной чек на '
                              '${money.format((budget - spent) / (daysInMonth - currentDay).clamp(1, daysInMonth))}.'
                          : 'Запас на месяц: ${money.format(budget - predictedEnd)}.',
                      style: TextStyle(
                        color: overBudget
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF22C55E),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 240,
              child: actualSpots.isEmpty
                  ? Center(
                      child: Text(
                        'Нет расходов в этом месяце.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        minX: 1,
                        maxX: daysInMonth.toDouble(),
                        minY: 0,
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              interval:
                                  (daysInMonth / 5).clamp(1, 31).toDouble(),
                              getTitlesWidget: (v, _) => Text(
                                v.toInt().toString(),
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true, reservedSize: 40)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          if (budgetSpots.isNotEmpty)
                            LineChartBarData(
                              spots: budgetSpots,
                              isCurved: false,
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                              barWidth: 1.5,
                              dashArray: [5, 4],
                              dotData: const FlDotData(show: false),
                            ),
                          LineChartBarData(
                            spots: actualSpots,
                            isCurved: true,
                            color: const Color(0xFF22C55E),
                            barWidth: 2.5,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(0xFF22C55E).withValues(alpha: 0.18),
                            ),
                          ),
                          if (predictSpots.length > 1)
                            LineChartBarData(
                              spots: predictSpots,
                              isCurved: false,
                              color: overBudget
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFF59E0B),
                              barWidth: 2,
                              dashArray: [4, 3],
                              dotData: const FlDotData(show: false),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _aiCard(
          context,
          _PredictData(
            currentDay: currentDay,
            daysInMonth: daysInMonth,
            budget: budget,
            spent: spent,
            avgPerDay: avgPerDay,
            predicted: predictedEnd,
          ),
          baseCurrency,
        ),
      ],
    );
  }

  Widget _statRow(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.7),
                fontSize: 13,
              )),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiCard(BuildContext context, _PredictData d, String currency) {
    final hasKey = AiService.apiKey != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI-инсайт',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_aiLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    onPressed: hasKey ? () => _runAi(d, currency) : null,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Спросить'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (!hasKey)
              Text(
                'Чтобы получить AI-комментарий, добавь ключ Gemini в '
                'Настройки → AI (Gemini).',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else if (_aiError != null)
              Text(_aiError!,
                  style: const TextStyle(color: Color(0xFFEF4444)))
            else if (_aiInsight != null)
              Text(_aiInsight!,
                  style: Theme.of(context).textTheme.bodyMedium)
            else
              Text(
                'Нажми «Спросить», чтобы Gemini проанализировал текущий '
                'темп расходов и подсказал, как уложиться в бюджет.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _PredictData {
  _PredictData({
    required this.currentDay,
    required this.daysInMonth,
    required this.budget,
    required this.spent,
    required this.avgPerDay,
    required this.predicted,
  });
  final int currentDay;
  final int daysInMonth;
  final num budget;
  final num spent;
  final num avgPerDay;
  final num predicted;
}
