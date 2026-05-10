import 'package:flutter/material.dart';

import '../../../models/financial_plan.dart';

/// Three side-by-side bar groups: Накопления, Бюджет еды/быта, Комфорт.
class ScenarioCompareTriple extends StatelessWidget {
  const ScenarioCompareTriple({super.key, required this.items});

  final List<ScenarioComparison> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Group(
                  title: 'Накопления за 12 мес',
                  items: items,
                  valueOf: (s) => s.savingsUsdYear,
                  valueLabel: (s) => '\$${s.savingsUsdYear.round()}',
                  unit: 'USD',
                ),
              ),
              Expanded(
                child: _Group(
                  title: 'Бюджет еды/быта в день',
                  items: items,
                  valueOf: (s) => s.foodPerDay,
                  valueLabel: (s) => '${s.foodPerDay.round()} BYN',
                  unit: 'BYN/день',
                  thresholdLine: 15,
                  thresholdLabel: 'минимум для комфорта',
                ),
              ),
              Expanded(
                child: _Group(
                  title: 'Комфорт жизни (1–10)',
                  items: items,
                  valueOf: (s) => s.comfort.toDouble(),
                  valueLabel: (s) => '${s.comfort}/10',
                  unit: '',
                ),
              ),
            ],
          ),
        ],
      );
    });
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.items,
    required this.valueOf,
    required this.valueLabel,
    required this.unit,
    this.thresholdLine,
    this.thresholdLabel,
  });

  final String title;
  final List<ScenarioComparison> items;
  final double Function(ScenarioComparison) valueOf;
  final String Function(ScenarioComparison) valueLabel;
  final String unit;
  final double? thresholdLine;
  final String? thresholdLabel;

  @override
  Widget build(BuildContext context) {
    final maxV = items
        .map(valueOf)
        .fold<double>(0, (a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: items.map((s) {
                final v = valueOf(s);
                final h = 130 * (v / maxV);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(valueLabel(s),
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Container(
                          height: h.toDouble().clamp(2.0, 130.0),
                          decoration: BoxDecoration(
                            color: s.colorValue,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(s.scenarioId,
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full scenario table — every parameter row by row.
class ScenarioTable extends StatelessWidget {
  const ScenarioTable({super.key, required this.items});

  final List<ScenarioComparison> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final rows = <_TableRow>[
      _TableRow('USD за следующий месяц',
          items.map((s) => '\$${(s.savingsUsdYear / 12).round()}').toList()),
      _TableRow('Накопления за год',
          items.map((s) => '\$${s.savingsUsdYear.round()}').toList()),
      _TableRow('Накопления за 16 мес',
          items.map((s) => '\$${s.savings16mUsd.round()}').toList()),
      _TableRow('До цели',
          items.map((s) => '${s.monthsToGoal} мес').toList()),
      _TableRow('Еда/быт в день',
          items.map((s) => '${s.foodPerDay.round()} BYN').toList()),
      _TableRow('Еда/быт в неделю',
          items.map((s) => '${s.foodPerWeek.round()} BYN').toList()),
      _TableRow('Походы в зал', items.map((s) => s.gym).toList()),
      _TableRow('Линзы', items.map((s) => s.lenses).toList()),
      _TableRow('Кэшбэк (Halva)', items.map((s) => s.cashback).toList()),
      _TableRow('Резерв на форс-мажор', items.map((s) => s.reserve).toList()),
      _TableRow('Стресс / риск срыва', items.map((s) => s.stress).toList()),
      _TableRow(
          'Комфорт жизни (1–10)', items.map((s) => '${s.comfort}/10').toList()),
      _TableRow('Подходит, если…', items.map((s) => s.suitability).toList()),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor:
            WidgetStateProperty.all(const Color(0xFF1E3A8A)),
        headingTextStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
        columns: [
          const DataColumn(label: Text('Параметр')),
          ...items.map((s) => DataColumn(
                label: Text(
                  '${s.scenarioId} (${s.subtitle})',
                  style: TextStyle(color: s.colorValue),
                ),
              )),
        ],
        rows: rows
            .map((r) => DataRow(
                  cells: [
                    DataCell(Text(r.label,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600))),
                    ...List.generate(items.length,
                        (i) => DataCell(Text(r.values[i],
                            style: TextStyle(color: items[i].colorValue)))),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

class _TableRow {
  _TableRow(this.label, this.values);
  final String label;
  final List<String> values;
}

/// Three two-segment progress bars (6 mes / 12 mes / target) with goal flag.
class ProgressBarsToGoal extends StatelessWidget {
  const ProgressBarsToGoal({super.key, required this.items, this.boosters});

  final List<ScenarioProgress> items;
  final List<String>? boosters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in items) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    p.scenarioId,
                    style: TextStyle(
                      color: p.colorValue,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(p.name,
                          style: TextStyle(
                              color: p.colorValue,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _stacked(p),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: Text('всего ${p.totalMonths} мес',
                      style: const TextStyle(fontSize: 11),
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
        ],
        if (boosters != null && boosters!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF22C55E))),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Бустеры скорости',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF065F46))),
                const SizedBox(height: 6),
                for (final b in boosters!) Text('• $b'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _stacked(ScenarioProgress p) {
    final pct6 = p.pct6m.clamp(0.0, 1.0);
    final pct12 = p.pct12m.clamp(0.0, 1.0);
    return SizedBox(
      height: 26,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: 1,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFE5E7EB)),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct12,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(p.colorValue.withValues(alpha: 0.5)),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct6,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(p.colorValue),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('6 мес: \$${p.savedUsd6m.round()}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                Text('12 мес: \$${p.savedUsd12m.round()}',
                    style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical list of action steps with colored stripe and date label.
class ActionStepsList extends StatelessWidget {
  const ActionStepsList({super.key, required this.steps});

  final List<ActionStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                  border: Border.all(color: steps[i].colorValue),
                  borderRadius: BorderRadius.circular(8),
                  color: steps[i].colorValue.withValues(alpha: 0.06)),
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 36,
                    color: steps[i].colorValue,
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: Text(
                      steps[i].dateLabel,
                      style: TextStyle(
                          color: steps[i].colorValue,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${i + 1}. ${steps[i].text}',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
