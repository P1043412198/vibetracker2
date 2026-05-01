import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/budget_plan.dart';
import '../models/category.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../utils/month_key.dart';
import '../widgets/section_card.dart';

class PlanEditorScreen extends StatefulWidget {
  final AppState state;
  final DateTime month;

  const PlanEditorScreen({
    super.key,
    required this.state,
    required this.month,
  });

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  late TextEditingController _incomeCtrl;
  late Map<String, TextEditingController> _catCtrls;

  @override
  void initState() {
    super.initState();
    final plan = widget.state.planFor(widget.month);
    _incomeCtrl = TextEditingController(
      text: plan.incomePlan == 0 ? '' : plan.incomePlan.toStringAsFixed(0),
    );
    _catCtrls = {
      for (final cat in DefaultCategories.expenses)
        cat.id: TextEditingController(
          text: (plan.categoryPlans[cat.id] ?? 0) == 0
              ? ''
              : plan.categoryPlans[cat.id]!.toStringAsFixed(0),
        ),
    };
  }

  @override
  void dispose() {
    _incomeCtrl.dispose();
    for (final c in _catCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _parse(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
  }

  double get _expensePlanTotal {
    var sum = 0.0;
    for (final c in _catCtrls.values) {
      sum += _parse(c.text);
    }
    return sum;
  }

  double get _incomePlan => _parse(_incomeCtrl.text);

  double get _free => _incomePlan - _expensePlanTotal;

  Future<void> _save() async {
    final categoryPlans = <String, double>{};
    _catCtrls.forEach((id, c) {
      final v = _parse(c.text);
      if (v > 0) categoryPlans[id] = v;
    });

    final plan = BudgetPlan(
      monthKey: monthKeyFor(widget.month),
      incomePlan: _incomePlan,
      categoryPlans: categoryPlans,
    );
    await widget.state.savePlan(plan);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _apply502030() async {
    final income = _incomePlan;
    if (income <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Сначала укажи планируемый доход')),
      );
      return;
    }
    // 50% — нужды (food, home, transport, health)
    // 30% — желания (cafes, shopping, entertainment)
    // 20% — свободно (не распределяем)
    final needs = income * 0.5;
    final wants = income * 0.3;

    void put(String id, double v) =>
        _catCtrls[id]?.text = v.toStringAsFixed(0);

    put('food', needs * 0.45);
    put('home', needs * 0.25);
    put('transport', needs * 0.18);
    put('health', needs * 0.12);
    put('cafes', wants * 0.35);
    put('shopping', wants * 0.4);
    put('entertainment', wants * 0.25);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('План на ${formatMonthLong(widget.month)}'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Сохранить'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Планируемый доход',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                _MoneyField(
                  controller: _incomeCtrl,
                  hint: '0',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _free < 0
                        ? const Color(0xFFFFE5E5)
                        : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _free < 0
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_rounded,
                        color: _free < 0
                            ? AppColors.danger
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _free < 0
                              ? 'Расходы по плану превышают доход на ${formatMoney(_free.abs())}'
                              : 'Свободно по плану: ${formatMoney(_free)}',
                          style: TextStyle(
                            color: _free < 0
                                ? AppColors.danger
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionHeader(
            title: 'Расходы по категориям',
            trailing: TextButton.icon(
              onPressed: _apply502030,
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('50/30/20'),
            ),
          ),
          SectionCard(
            child: Column(
              children: [
                for (var i = 0; i < DefaultCategories.expenses.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _CategoryPlanRow(
                    category: DefaultCategories.expenses[i],
                    controller:
                        _catCtrls[DefaultCategories.expenses[i].id]!,
                    onChanged: () => setState(() {}),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F4F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Всего расходов по плану',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        formatMoney(_expensePlanTotal),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _save,
            child: const Text('Сохранить план'),
          ),
        ],
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onChanged;

  const _MoneyField({
    required this.controller,
    this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        suffixText: '₽',
      ),
    );
  }
}

class _CategoryPlanRow extends StatelessWidget {
  final TxCategory category;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _CategoryPlanRow({
    required this.category,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(category.icon, color: category.color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            category.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          width: 130,
          child: _MoneyField(
            controller: controller,
            hint: '0',
            onChanged: (_) => onChanged(),
          ),
        ),
      ],
    );
  }
}
