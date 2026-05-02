import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../services/finance_calc.dart';
import '../../state/currency_state.dart';
import '../../state/providers.dart';
import '../../state/settings_state.dart';

/// "FIRE" — port of `src/components/FIRECalculatorTab.tsx`.
///
/// Standard FIRE projection: target capital = annual income / safe withdrawal
/// rate (4% rule by default). Forward-simulates compounding monthly with a
/// fixed contribution; charts capital over years until the target is reached
/// (or 50 years cap).
class FireTab extends ConsumerStatefulWidget {
  const FireTab({super.key});

  @override
  ConsumerState<FireTab> createState() => _FireTabState();
}

class _FireTabState extends ConsumerState<FireTab> {
  final _capCtl = TextEditingController();
  final _contribCtl = TextEditingController(text: '500');
  final _retCtl = TextEditingController(text: '8');
  final _swrCtl = TextEditingController(text: '4');
  final _targetIncomeCtl = TextEditingController(text: '2000');

  bool _seeded = false;

  @override
  void dispose() {
    _capCtl.dispose();
    _contribCtl.dispose();
    _retCtl.dispose();
    _swrCtl.dispose();
    _targetIncomeCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final transactions = ref.watch(transactionsProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final rates = ref.watch(currencyRatesProvider);

    num convert(num amount, String from, String to) =>
        convertCurrency(amount: amount, from: from, to: to, rates: rates);

    // Compute current net worth from accounts and seed _capCtl once.
    num netWorth = 0;
    for (final a in accounts) {
      final bal = accountBalance(
        account: a,
        transactions: transactions,
        accounts: accounts,
        convert: convert,
      );
      netWorth += convert(bal, a.currency, baseCurrency);
    }
    if (!_seeded) {
      _seeded = true;
      _capCtl.text = netWorth < 0 ? '0' : netWorth.toStringAsFixed(0);
    }

    final result = _project(
      capital: double.tryParse(_capCtl.text) ?? 0,
      monthlyContribution: double.tryParse(_contribCtl.text) ?? 0,
      annualReturnPct: double.tryParse(_retCtl.text) ?? 0,
      swrPct: double.tryParse(_swrCtl.text) ?? 0,
      targetMonthlyIncome:
          double.tryParse(_targetIncomeCtl.text) ?? 0,
    );

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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                        color: Color(0xFFF97316)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Калькулятор FIRE',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Financial Independence, Retire Early',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                _row([
                  _input(_capCtl, 'Текущий капитал ($baseCurrency)'),
                  _input(_contribCtl, 'Взнос / месяц ($baseCurrency)'),
                ]),
                const SizedBox(height: 8),
                _row([
                  _input(_retCtl, 'Годовая доходность, %'),
                  _input(_swrCtl, 'SWR, %'),
                ]),
                const SizedBox(height: 8),
                _input(_targetIncomeCtl,
                    'Цель: пассивный доход / мес. ($baseCurrency)'),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Пересчитать'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kpi('Целевой капитал',
                    money.format(result.targetCapital), const Color(0xFF6D5CFF)),
                _kpi(
                  'Лет до FIRE',
                  result.achievable
                      ? '${result.years.toStringAsFixed(1)} лет'
                      : '> 50 лет',
                  result.achievable
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444),
                  bold: true,
                ),
                _kpi(
                    'Капитал к концу симуляции',
                    money.format(result.endCapital),
                    const Color(0xFFF59E0B)),
                if (!result.achievable)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'При текущих параметрах цель не достижима за 50 лет. '
                      'Увеличь взнос или ставку доходности.',
                      style: TextStyle(
                        color: const Color(0xFFEF4444),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Прогноз накоплений',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: result.projection.length < 2
                      ? const Center(child: Text('Недостаточно данных'))
                      : LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              rightTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 22,
                                  getTitlesWidget: (v, _) => Text(
                                    '${v.toInt()} г.',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                              ),
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: true, reservedSize: 48),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: [
                                  for (final p in result.projection)
                                    FlSpot(
                                        p.year.toDouble(), p.capital.toDouble())
                                ],
                                isCurved: true,
                                color: const Color(0xFFF97316),
                                barWidth: 2.5,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: const Color(0xFFF97316)
                                      .withValues(alpha: 0.18),
                                ),
                              ),
                              LineChartBarData(
                                spots: [
                                  FlSpot(0, result.targetCapital.toDouble()),
                                  FlSpot(
                                      result.projection.last.year.toDouble(),
                                      result.targetCapital.toDouble()),
                                ],
                                isCurved: false,
                                color: const Color(0xFF22C55E),
                                barWidth: 1.5,
                                dashArray: [5, 4],
                                dotData: const FlDotData(show: false),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(List<Widget> children) => Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            Expanded(child: children[i]),
            if (i < children.length - 1) const SizedBox(width: 8),
          ]
        ],
      );

  Widget _input(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (_) => setState(() {}),
    );
  }

  Widget _kpi(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value,
              style: TextStyle(
                color: color,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                fontSize: bold ? 16 : 14,
              )),
        ],
      ),
    );
  }
}

class _FirePoint {
  _FirePoint({required this.year, required this.capital});
  final int year;
  final num capital;
}

class _FireResult {
  _FireResult({
    required this.targetCapital,
    required this.years,
    required this.projection,
    required this.achievable,
    required this.endCapital,
  });
  final num targetCapital;
  final double years;
  final List<_FirePoint> projection;
  final bool achievable;
  final num endCapital;
}

_FireResult _project({
  required double capital,
  required double monthlyContribution,
  required double annualReturnPct,
  required double swrPct,
  required double targetMonthlyIncome,
}) {
  final swr = swrPct / 100;
  final returnRate = annualReturnPct / 100;
  final monthlyReturn = returnRate / 12;
  final targetCapital = swr <= 0 ? double.infinity : (targetMonthlyIncome * 12) / swr;
  final maxMonths = 50 * 12;
  double cur = capital;
  final out = <_FirePoint>[_FirePoint(year: 0, capital: cur.round())];
  int months = 0;
  while (cur < targetCapital && months < maxMonths) {
    cur = cur * (1 + monthlyReturn) + monthlyContribution;
    months++;
    if (months % 12 == 0) {
      out.add(_FirePoint(year: months ~/ 12, capital: cur.round()));
    }
  }
  if (months % 12 != 0) {
    out.add(_FirePoint(year: months ~/ 12, capital: cur.round()));
  }
  return _FireResult(
    targetCapital: targetCapital.isFinite ? targetCapital : 0,
    years: months / 12,
    projection: out,
    achievable: cur >= targetCapital,
    endCapital: cur,
  );
}
