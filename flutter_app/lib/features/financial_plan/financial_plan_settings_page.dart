import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/financial_plan.dart';
import '../../state/financial_plan_state.dart';

/// Editor for the [FinancialPlanConfig]: salary, days, scenarios, portfolio.
class FinancialPlanSettingsPage extends ConsumerStatefulWidget {
  const FinancialPlanSettingsPage({super.key});

  @override
  ConsumerState<FinancialPlanSettingsPage> createState() =>
      _FinancialPlanSettingsPageState();
}

class _FinancialPlanSettingsPageState
    extends ConsumerState<FinancialPlanSettingsPage> {
  late FinancialPlanConfig _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(financialPlanConfigProvider);
  }

  Future<void> _save() async {
    await ref.read(financialPlanConfigProvider.notifier).update(_draft);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки фин. плана'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _draft = FinancialPlanConfig.defaults()),
            child: const Text('Сброс'),
          ),
          IconButton(
            tooltip: 'Сохранить',
            onPressed: _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(title: 'Доход', children: [
            _NumField(
              label: 'Грязная ЗП (BYN)',
              value: _draft.salaryGross,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(salaryGross: v)),
            ),
            _NumField(
              label: 'Аванс (BYN)',
              value: _draft.advanceAmount,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(advanceAmount: v)),
            ),
            _IntField(
              label: 'День аванса (1–31)',
              value: _draft.advanceDay,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(advanceDay: v)),
            ),
            _IntField(
              label: 'День ЗП (1–31)',
              value: _draft.payDay,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(payDay: v)),
            ),
          ]),
          _Section(title: 'Аренда / основные удержания', children: [
            _NumField(
              label: 'Аренда (BYN)',
              value: _draft.rentAmount,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(rentAmount: v)),
            ),
            _IntField(
              label: 'День аренды',
              value: _draft.rentDay,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(rentDay: v)),
            ),
            SwitchListTile(
              title: const Text('1% профсоюз'),
              value: _draft.applyTradeUnion,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(applyTradeUnion: v)),
            ),
          ]),
          _Section(title: 'Цель', children: [
            _NumField(
              label: 'Сумма цели',
              value: _draft.goalAmount,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(goalAmount: v)),
            ),
            DropdownButtonFormField<String>(
              value: _draft.goalCurrency,
              items: const [
                DropdownMenuItem(value: 'BYN', child: Text('BYN')),
                DropdownMenuItem(value: 'USD', child: Text('USD')),
              ],
              onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(goalCurrency: v ?? 'BYN')),
              decoration: const InputDecoration(labelText: 'Валюта цели'),
            ),
            _NumField(
              label: 'Курс USD (BYN за \$1)',
              value: _draft.usdRate,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(usdRate: v)),
            ),
          ]),
          _Section(title: 'Сценарии', children: [
            for (int i = 0; i < _draft.scenarios.length; i++)
              _ScenarioCard(
                scenario: _draft.scenarios[i],
                onChanged: (s) {
                  final list = [..._draft.scenarios];
                  list[i] = s;
                  setState(() => _draft = _draft.copyWith(scenarios: list));
                },
              ),
          ]),
          _Section(title: 'Портфель (% по инструментам)', children: [
            _PortfolioEditor(
              allocations: _draft.portfolio,
              onChanged: (list) =>
                  setState(() => _draft = _draft.copyWith(portfolio: list)),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _NumField extends StatefulWidget {
  const _NumField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: _ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: widget.label),
        onChanged: (v) {
          final parsed = double.tryParse(v.replaceAll(',', '.'));
          if (parsed != null) widget.onChanged(parsed);
        },
      ),
    );
  }
}

class _IntField extends StatefulWidget {
  const _IntField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_IntField> createState() => _IntFieldState();
}

class _IntFieldState extends State<_IntField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: widget.label),
        onChanged: (v) {
          final parsed = int.tryParse(v);
          if (parsed != null) widget.onChanged(parsed);
        },
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.scenario,
    required this.onChanged,
  });

  final SavingsScenario scenario;
  final ValueChanged<SavingsScenario> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: scenario.colorValue),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Сценарий ${scenario.id} — ${scenario.subtitle}',
                style: TextStyle(
                    color: scenario.colorValue, fontWeight: FontWeight.w700)),
            _NumField(
              label: 'USD/мес в копилку',
              value: scenario.savingsUsd,
              onChanged: (v) => onChanged(scenario.copyWith(savingsUsd: v)),
            ),
            _NumField(
              label: 'Еда / быт в день, BYN',
              value: scenario.foodPerDay,
              onChanged: (v) => onChanged(scenario.copyWith(foodPerDay: v)),
            ),
            _NumField(
              label: 'Кэшбэк/мес, BYN',
              value: scenario.cashbackPerMonth,
              onChanged: (v) =>
                  onChanged(scenario.copyWith(cashbackPerMonth: v)),
            ),
            _NumField(
              label: 'Подработка/мес, BYN',
              value: scenario.sideHustlePerMonth,
              onChanged: (v) =>
                  onChanged(scenario.copyWith(sideHustlePerMonth: v)),
            ),
            SwitchListTile(
              title: const Text('Зал (100 BYN)'),
              value: scenario.includeGym,
              onChanged: (v) => onChanged(scenario.copyWith(includeGym: v)),
            ),
            SwitchListTile(
              title: const Text('Линзы / контактные'),
              value: scenario.includeLenses,
              onChanged: (v) => onChanged(scenario.copyWith(includeLenses: v)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text('Комфорт ${scenario.comfort} / 10'),
            ),
            Slider(
              value: scenario.comfort.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '${scenario.comfort}',
              onChanged: (v) => onChanged(scenario.copyWith(comfort: v.round())),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioEditor extends StatelessWidget {
  const _PortfolioEditor({
    required this.allocations,
    required this.onChanged,
  });

  final List<PortfolioAllocation> allocations;
  final ValueChanged<List<PortfolioAllocation>> onChanged;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final a in allocations) a.instrumentId: a.percent};
    final total = byId.values.fold<double>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Сумма: ${total.toStringAsFixed(0)}% (должно быть 100)',
            style: TextStyle(
              color: (total - 100).abs() < 0.5
                  ? const Color(0xFF065F46)
                  : Colors.red,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 4),
        for (final inst in brbInstruments)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                      color: Color(inst.color),
                      borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(inst.shortName,
                      style: const TextStyle(fontSize: 12)),
                ),
                SizedBox(
                  width: 110,
                  child: Slider(
                    value: (byId[inst.id] ?? 0).clamp(0.0, 100.0),
                    max: 100,
                    onChanged: (v) {
                      final next = <PortfolioAllocation>[];
                      bool added = false;
                      for (final a in allocations) {
                        if (a.instrumentId == inst.id) {
                          next.add(PortfolioAllocation(
                              instrumentId: inst.id, percent: v));
                          added = true;
                        } else {
                          next.add(a);
                        }
                      }
                      if (!added) {
                        next.add(PortfolioAllocation(
                            instrumentId: inst.id, percent: v));
                      }
                      onChanged(next);
                    },
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text('${(byId[inst.id] ?? 0).round()}%',
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
