import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/finance.dart';
import '../../services/finance_calc.dart';
import '../../state/currency_state.dart';
import '../../state/providers.dart';
import '../../state/settings_state.dart';
import 'finance_shared.dart';

/// "План месяца" — counterpart of `MonthlyBudgetPlanTab.tsx`.
///
/// Lets you set planned income and a per-category planned expense; shows
/// a fact bar for each category and computes free funds + suggested daily
/// allowance using the same rules as `src/lib/monthlyBudget.ts`.
class MonthlyPlanTab extends ConsumerStatefulWidget {
  const MonthlyPlanTab({super.key});

  @override
  ConsumerState<MonthlyPlanTab> createState() => _MonthlyPlanTabState();
}

class _MonthlyPlanTabState extends ConsumerState<MonthlyPlanTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(monthlyBudgetPlansProvider);
    final transactions = ref.watch(transactionsProvider);
    final accounts = ref.watch(accountsProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final rates = ref.watch(currencyRatesProvider);

    num convert(num amount, String from, String to) =>
        convertCurrency(amount: amount, from: from, to: to, rates: rates);

    final monthKey = monthKeyOf(_month);
    final plan = plans
        .cast<MonthlyBudgetPlan?>()
        .firstWhere((p) => p?.monthKey == monthKey, orElse: () => null);
    final prevPlan = plans.cast<MonthlyBudgetPlan?>().firstWhere(
        (p) => p?.monthKey == previousMonthKey(monthKey),
        orElse: () => null);
    final facts = computeMonthFacts(
      month: _month,
      transactions: transactions,
      accounts: accounts,
      baseCurrency: baseCurrency,
      convert: convert,
    );
    final prevFacts = computeMonthFacts(
      month: DateTime(_month.year, _month.month - 1, 1),
      transactions: transactions,
      accounts: accounts,
      baseCurrency: baseCurrency,
      convert: convert,
    );

    final totalPlannedExpense = (plan?.categoryPlans ?? const [])
        .fold<num>(0, (s, c) => s + c.planned);
    final freeFunds = computeFreeFunds(
      plannedIncome: plan?.plannedIncome ?? 0,
      actualIncome: facts.income,
      actualExpense: facts.expense,
    );
    final daysLeft = daysLeftInMonth(_month);
    final allowance = dailyAllowance(freeFunds.free, daysLeft);
    final fmt =
        NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 2);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _MonthSwitcher(
          month: _month,
          onPrevious: () => setState(() {
            _month = DateTime(_month.year, _month.month - 1, 1);
          }),
          onNext: () => setState(() {
            _month = DateTime(_month.year, _month.month + 1, 1);
          }),
        ),
        const SizedBox(height: 12),
        _PlanSummaryCard(
          plannedIncome: plan?.plannedIncome ?? 0,
          plannedExpense: totalPlannedExpense,
          actualIncome: facts.income,
          actualExpense: facts.expense,
          freeFunds: freeFunds.free,
          dailyAllowance: allowance,
          daysLeft: daysLeft,
          currency: baseCurrency,
          fmt: fmt,
          rollover: plan?.rollover ?? false,
          onEditIncome: () => _editIncome(plan, monthKey),
          onToggleRollover: () => _toggleRollover(plan, monthKey),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text('Лимиты по категориям',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Категория'),
              onPressed: () => _addCategory(plan, monthKey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if ((plan?.categoryPlans.isEmpty ?? true))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Категории пока не настроены',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  const Text(
                      'Добавь первую категорию или выбери из подсказок ниже.'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final c in kExpenseCategories.take(8))
                        ActionChip(
                          label: Text(c),
                          onPressed: () =>
                              _addOrEditCategoryEntry(plan, monthKey, c, 0),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          ...plan!.categoryPlans.map((cp) {
            final actual = facts.expenseByCategory[cp.category] ?? 0;
            final effective = effectiveLimit(
              category: cp.category,
              monthPlan: plan,
              previousPlan: prevPlan,
              previousActuals: prevFacts.expenseByCategory,
            );
            return _CategoryRow(
              plan: cp,
              actual: actual,
              effectiveLimit: effective,
              currency: baseCurrency,
              fmt: fmt,
              onTap: () =>
                  _addOrEditCategoryEntry(plan, monthKey, cp.category, cp.planned),
              onDelete: () => _removeCategory(plan, cp.category),
            );
          }),
      ],
    );
  }

  Future<void> _editIncome(MonthlyBudgetPlan? plan, String monthKey) async {
    final controller = TextEditingController(
        text: (plan?.plannedIncome ?? 0).toString());
    final next = await showDialog<num?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Планируемый доход'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Сумма'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(double.tryParse(controller.text.trim()) ?? 0),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (next == null) return;
    await _upsertPlan(plan, monthKey, plannedIncome: next);
  }

  Future<void> _toggleRollover(MonthlyBudgetPlan? plan, String monthKey) async {
    await _upsertPlan(plan, monthKey, toggleRollover: true);
  }

  Future<void> _addCategory(MonthlyBudgetPlan? plan, String monthKey) async {
    final result = await showModalBottomSheet<_CatResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => const _CategoryFormSheet(),
    );
    if (result == null) return;
    await _addOrEditCategoryEntry(
        plan, monthKey, result.category, result.amount);
  }

  Future<void> _addOrEditCategoryEntry(
    MonthlyBudgetPlan? plan,
    String monthKey,
    String category,
    num planned,
  ) async {
    final controller = TextEditingController(text: planned.toString());
    final result = await showDialog<num?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(category),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Лимит'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(double.tryParse(controller.text.trim()) ?? 0),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final cps = [...?plan?.categoryPlans];
    final i = cps.indexWhere((c) => c.category == category);
    if (i == -1) {
      cps.add(CategoryPlan(category: category, planned: result));
    } else {
      cps[i] = CategoryPlan(category: category, planned: result);
    }
    await _upsertPlan(plan, monthKey, categoryPlans: cps);
  }

  Future<void> _removeCategory(
      MonthlyBudgetPlan? plan, String category) async {
    if (plan == null) return;
    final cps =
        plan.categoryPlans.where((c) => c.category != category).toList();
    await _upsertPlan(plan, plan.monthKey, categoryPlans: cps);
  }

  Future<void> _upsertPlan(
    MonthlyBudgetPlan? plan,
    String monthKey, {
    num? plannedIncome,
    List<CategoryPlan>? categoryPlans,
    bool toggleRollover = false,
  }) async {
    final now = DateTime.now().toIso8601String();
    final next = MonthlyBudgetPlan(
      id: plan?.id ?? const Uuid().v4(),
      monthKey: monthKey,
      plannedIncome: plannedIncome ?? plan?.plannedIncome ?? 0,
      currency: plan?.currency,
      categoryPlans: categoryPlans ?? plan?.categoryPlans ?? const [],
      freeFundsTarget: plan?.freeFundsTarget,
      rollover:
          toggleRollover ? !(plan?.rollover ?? false) : plan?.rollover,
      notes: plan?.notes,
      createdAt: plan?.createdAt ?? now,
      updatedAt: now,
    );
    await ref.read(monthlyBudgetPlansProvider.notifier).upsert(next);
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: onPrevious,
            ),
            Expanded(
              child: Center(
                child: Text(
                  DateFormat.yMMMM('ru').format(month),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({
    required this.plannedIncome,
    required this.plannedExpense,
    required this.actualIncome,
    required this.actualExpense,
    required this.freeFunds,
    required this.dailyAllowance,
    required this.daysLeft,
    required this.currency,
    required this.fmt,
    required this.rollover,
    required this.onEditIncome,
    required this.onToggleRollover,
  });

  final num plannedIncome;
  final num plannedExpense;
  final num actualIncome;
  final num actualExpense;
  final num freeFunds;
  final num dailyAllowance;
  final int daysLeft;
  final String currency;
  final NumberFormat fmt;
  final bool rollover;
  final VoidCallback onEditIncome;
  final VoidCallback onToggleRollover;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PlanRow(
              label: 'Планируемый доход',
              valueText: '${fmt.format(plannedIncome)} $currency',
              actionLabel: 'Изменить',
              onAction: onEditIncome,
            ),
            const SizedBox(height: 4),
            _PlanRow(
              label: 'Фактический доход',
              valueText: '${fmt.format(actualIncome)} $currency',
            ),
            const Divider(height: 24),
            _PlanRow(
              label: 'Запланированные расходы',
              valueText: '${fmt.format(plannedExpense)} $currency',
            ),
            const SizedBox(height: 4),
            _PlanRow(
              label: 'Фактические расходы',
              valueText: '${fmt.format(actualExpense)} $currency',
            ),
            const Divider(height: 24),
            _PlanRow(
              label: 'Свободные средства',
              valueText: '${fmt.format(freeFunds)} $currency',
              valueColor: freeFunds >= 0
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFEF4444),
            ),
            const SizedBox(height: 4),
            _PlanRow(
              label: 'В день (осталось $daysLeft дн.)',
              valueText: '${fmt.format(dailyAllowance)} $currency',
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Перенос остатка'),
              subtitle: const Text(
                  'Неизрасходованный лимит прошлого месяца прибавляется к лимиту этого'),
              value: rollover,
              onChanged: (_) => onToggleRollover(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.label,
    required this.valueText,
    this.valueColor,
    this.actionLabel,
    this.onAction,
  });

  final String label;
  final String valueText;
  final Color? valueColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          valueText,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.plan,
    required this.actual,
    required this.effectiveLimit,
    required this.currency,
    required this.fmt,
    required this.onTap,
    required this.onDelete,
  });

  final CategoryPlan plan;
  final num actual;
  final num effectiveLimit;
  final String currency;
  final NumberFormat fmt;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final progress =
        effectiveLimit > 0 ? (actual / effectiveLimit).clamp(0.0, 1.5) : 0.0;
    final over = actual > effectiveLimit && effectiveLimit > 0;
    final color = over
        ? const Color(0xFFEF4444)
        : Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.category,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${fmt.format(actual)} / ${fmt.format(effectiveLimit)} $currency',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.toDouble().clamp(0.0, 1.0),
                  minHeight: 8,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatResult {
  _CatResult(this.category, this.amount);
  final String category;
  final num amount;
}

class _CategoryFormSheet extends StatefulWidget {
  const _CategoryFormSheet();
  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Новая категория',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _categoryController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Название'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final c in kExpenseCategories)
                ActionChip(
                  label: Text(c),
                  onPressed: () => _categoryController.text = c,
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Лимит'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final name = _categoryController.text.trim();
              if (name.isEmpty) return;
              Navigator.of(context).pop(_CatResult(
                name,
                double.tryParse(_amountController.text.trim()) ?? 0,
              ));
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }
}
