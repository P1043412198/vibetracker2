import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
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
    final excluded = (plan?.excludedAccountIds ?? const <String>[]).toSet();
    final facts = computeMonthFacts(
      month: _month,
      transactions: transactions,
      accounts: accounts,
      baseCurrency: baseCurrency,
      convert: convert,
      excludedAccountIds: excluded,
    );
    final prevFacts = computeMonthFacts(
      month: DateTime(_month.year, _month.month - 1, 1),
      transactions: transactions,
      accounts: accounts,
      baseCurrency: baseCurrency,
      convert: convert,
      excludedAccountIds: excluded,
    );

    // Phase 14: schedule-aware cashflow with loans included.
    final planCurrency = plan?.currency ?? baseCurrency;
    // Sum of all active loan monthly payments converted into the plan
    // currency. Active = balance > 0 AND monthlyPayment > 0.
    num loansMonthlyPayments = 0;
    final loansForPayments = ref.read(loansProvider);
    for (final l in loansForPayments) {
      if (l.balance <= 0 || l.monthlyPayment <= 0) continue;
      loansMonthlyPayments +=
          convert(l.monthlyPayment, l.currency, planCurrency);
    }

    final categoryPlanTotal = (plan?.categoryPlans ?? const [])
        .fold<num>(0, (s, c) => s + c.planned);
    final scheduledExpensesTotal =
        (plan?.scheduledExpenses ?? const <ScheduledExpense>[])
            .fold<num>(0, (s, e) => s + e.amount);
    final scheduledIncomeTotal = (plan?.incomes ?? const <IncomeEntry>[])
        .fold<num>(0, (s, e) => s + e.amount);
    final committed = computeCommittedExpense(
      categoryPlans: plan?.categoryPlans ?? const [],
      actualByCategory: facts.expenseByCategory,
      totalActualExpense: facts.expense,
      scheduledExpenses:
          plan?.scheduledExpenses ?? const <ScheduledExpense>[],
      loansMonthlyPayments: loansMonthlyPayments,
    );
    // Static "плановая" сумма (used for the "Запланированные расходы" row).
    final totalPlannedExpense =
        categoryPlanTotal + scheduledExpensesTotal + loansMonthlyPayments;

    // Phase 18: free-funds carry-over from previous month (when enabled).
    final loans = ref.watch(loansProvider);
    final prevLoansMonthlyPayments = loansMonthlyPayments;
    final carryEnabled = plan?.freeFundsCarryover ?? false;
    final carryIn = carryEnabled
        ? computeMonthLeftoverFree(
            plan: prevPlan,
            facts: prevFacts,
            loansMonthlyPayments: prevLoansMonthlyPayments,
          )
        : 0;

    final freeFunds = computeFreeFunds(
      plannedIncome: plan?.plannedIncome ?? 0,
      scheduledIncomeTotal: scheduledIncomeTotal,
      plannedExpense: committed.total,
      actualIncome: facts.income,
      actualExpense: facts.expense,
      carryIn: carryIn,
    );
    final daysLeft = daysLeftInMonth(_month);
    final allowance = dailyAllowance(freeFunds.free, daysLeft);
    final weekly = weeklyAllowance(freeFunds.free, daysLeft);
    final fmt =
        NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 2);

    final cashflow = plan == null
        ? null
        : buildCashflow(
            month: _month,
            plan: plan,
            loans: loans,
            planCurrency: planCurrency,
            convert: convert,
          );
    final breakdown = cashflow == null
        ? null
        : buildFreeFundsBreakdown(
            cashflow: cashflow,
            month: _month,
            today: DateTime.now(),
          );

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
        _AccountSelectorCard(
          accounts: accounts,
          excluded: excluded,
          onToggle: (id) => _toggleExcludedAccount(plan, monthKey, id),
        ),
        const SizedBox(height: 12),
        _PlanSummaryCard(
          plannedIncome: plan?.plannedIncome ?? 0,
          scheduledIncomeTotal: scheduledIncomeTotal,
          plannedExpense: totalPlannedExpense,
          committedExpense: committed.total,
          loansMonthlyPayments: loansMonthlyPayments,
          actualIncome: facts.income,
          actualExpense: facts.expense,
          freeFunds: freeFunds.free,
          carryIn: carryIn,
          dailyAllowance: allowance,
          weeklyAllowance: weekly,
          daysLeft: daysLeft,
          currency: baseCurrency,
          fmt: fmt,
          rollover: plan?.rollover ?? false,
          freeFundsCarryover: plan?.freeFundsCarryover ?? false,
          onEditIncome: () => _editIncome(plan, monthKey),
          onToggleRollover: () => _toggleRollover(plan, monthKey),
          onToggleFreeFundsCarryover: () =>
              _toggleFreeFundsCarryover(plan, monthKey),
        ),
        const SizedBox(height: 12),
        _IncomeScheduleCard(
          incomes: plan?.incomes ?? const [],
          currency: planCurrency,
          fmt: fmt,
          onAdd: () => _addIncomeEntry(plan, monthKey),
          onEdit: (e) => _editIncomeEntry(plan, monthKey, e),
          onDelete: (id) => _removeIncomeEntry(plan, monthKey, id),
        ),
        const SizedBox(height: 12),
        _ScheduledExpenseCard(
          items: plan?.scheduledExpenses ?? const [],
          currency: planCurrency,
          fmt: fmt,
          onAdd: () => _addScheduledExpense(plan, monthKey),
          onEdit: (e) => _editScheduledExpense(plan, monthKey, e),
          onDelete: (id) => _removeScheduledExpense(plan, monthKey, id),
        ),
        if (cashflow != null && cashflow.periods.isNotEmpty) ...[
          const SizedBox(height: 12),
          _CashflowCard(
            cashflow: cashflow,
            currency: planCurrency,
            fmt: fmt,
            today: DateTime.now(),
            month: _month,
          ),
        ],
        if (breakdown != null && breakdown.weeks.isNotEmpty) ...[
          const SizedBox(height: 12),
          _FreeFundsByWeekCard(
            breakdown: breakdown,
            currency: planCurrency,
            fmt: fmt,
            today: DateTime.now(),
          ),
        ],
        if (breakdown != null && breakdown.days.isNotEmpty) ...[
          const SizedBox(height: 12),
          _FreeFundsByWeekdayCard(
            breakdown: breakdown,
            currency: planCurrency,
            fmt: fmt,
            today: DateTime.now(),
          ),
        ],
        if (plan != null && plan.categoryPlans.isNotEmpty) ...[
          const SizedBox(height: 12),
          _PlanVsFactCard(
            categoryPlans: plan.categoryPlans,
            actualByCategory: facts.expenseByCategory,
            currency: baseCurrency,
            fmt: fmt,
          ),
          const SizedBox(height: 12),
          _ExpenseShareCard(
            categoryPlans: plan.categoryPlans,
            scheduledExpenses:
                plan.scheduledExpenses ?? const <ScheduledExpense>[],
            loansMonthlyPayments: loansMonthlyPayments,
            currency: baseCurrency,
            fmt: fmt,
          ),
        ],
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
              onTap: () => _addOrEditCategoryEntry(
                  plan, monthKey, cp.category, cp.planned,
                  initialDueDay: cp.dueDay),
              onPickDay: () =>
                  _editCategoryDueDay(plan, monthKey, cp),
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

  Future<void> _toggleFreeFundsCarryover(
      MonthlyBudgetPlan? plan, String monthKey) async {
    await _upsertPlan(plan, monthKey, toggleFreeFundsCarryover: true);
  }

  Future<void> _toggleExcludedAccount(
      MonthlyBudgetPlan? plan, String monthKey, String accountId) async {
    final current = [...?plan?.excludedAccountIds];
    if (current.contains(accountId)) {
      current.remove(accountId);
    } else {
      current.add(accountId);
    }
    await _upsertPlan(plan, monthKey, excludedAccountIds: current);
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
    num planned, {
    int? initialDueDay,
  }) async {
    final amountCtl = TextEditingController(text: planned.toString());
    final dayCtl = TextEditingController(
        text: initialDueDay == null ? '' : initialDueDay.toString());
    final result = await showDialog<_CategoryEditResult?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(category),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Лимит'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: dayCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'День списания (1–31, опционально)',
                helperText:
                    'Когда обычно списывается этот расход — учитывается в графике',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final amt =
                  double.tryParse(amountCtl.text.trim().replaceAll(',', '.')) ??
                      0;
              final day = int.tryParse(dayCtl.text.trim());
              Navigator.of(dialogContext).pop(_CategoryEditResult(
                amount: amt,
                dueDay: (day != null && day >= 1 && day <= 31) ? day : null,
              ));
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final cps = [...?plan?.categoryPlans];
    final i = cps.indexWhere((c) => c.category == category);
    if (i == -1) {
      cps.add(CategoryPlan(
        category: category,
        planned: result.amount,
        dueDay: result.dueDay,
      ));
    } else {
      cps[i] = CategoryPlan(
        category: category,
        planned: result.amount,
        dueDay: result.dueDay,
      );
    }
    await _upsertPlan(plan, monthKey, categoryPlans: cps);
  }

  Future<void> _editCategoryDueDay(
    MonthlyBudgetPlan? plan,
    String monthKey,
    CategoryPlan cp,
  ) async {
    final dayCtl = TextEditingController(
        text: cp.dueDay == null ? '' : cp.dueDay.toString());
    final picked = await showDialog<_DueDayResult>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${cp.category} — день списания'),
        content: TextField(
          controller: dayCtl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'День месяца (1–31)',
            helperText: 'Оставь пустым, чтобы расход распределить по месяцу',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(const _DueDayResult.clear()),
            child: const Text('Очистить'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(dayCtl.text.trim());
              if (v == null || v < 1 || v > 31) {
                Navigator.of(dialogContext).pop(const _DueDayResult.clear());
              } else {
                Navigator.of(dialogContext).pop(_DueDayResult.set(v));
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (picked == null) return;
    final cps = [...?plan?.categoryPlans];
    final i = cps.indexWhere((c) => c.category == cp.category);
    if (i == -1) return;
    cps[i] = CategoryPlan(
      category: cp.category,
      planned: cp.planned,
      dueDay: picked.day,
    );
    await _upsertPlan(plan, monthKey, categoryPlans: cps);
  }

  Future<void> _addIncomeEntry(
      MonthlyBudgetPlan? plan, String monthKey) async {
    final result = await showModalBottomSheet<IncomeEntry?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => const _IncomeFormSheet(),
    );
    if (result == null) return;
    final list = [...(plan?.incomes ?? const <IncomeEntry>[])];
    list.add(result);
    await _upsertPlan(plan, monthKey, incomes: list);
  }

  Future<void> _editIncomeEntry(MonthlyBudgetPlan? plan, String monthKey,
      IncomeEntry existing) async {
    final result = await showModalBottomSheet<IncomeEntry?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _IncomeFormSheet(initial: existing),
    );
    if (result == null) return;
    final list = [...(plan?.incomes ?? const <IncomeEntry>[])];
    final i = list.indexWhere((e) => e.id == existing.id);
    if (i != -1) list[i] = result;
    await _upsertPlan(plan, monthKey, incomes: list);
  }

  Future<void> _removeIncomeEntry(
      MonthlyBudgetPlan? plan, String monthKey, String id) async {
    final list = [...(plan?.incomes ?? const <IncomeEntry>[])]
      ..removeWhere((e) => e.id == id);
    await _upsertPlan(plan, monthKey, incomes: list);
  }

  Future<void> _addScheduledExpense(
      MonthlyBudgetPlan? plan, String monthKey) async {
    final result = await showModalBottomSheet<ScheduledExpense?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => const _ScheduledExpenseFormSheet(),
    );
    if (result == null) return;
    final list = [...(plan?.scheduledExpenses ?? const <ScheduledExpense>[])];
    list.add(result);
    await _upsertPlan(plan, monthKey, scheduledExpenses: list);
  }

  Future<void> _editScheduledExpense(
      MonthlyBudgetPlan? plan,
      String monthKey,
      ScheduledExpense existing) async {
    final result = await showModalBottomSheet<ScheduledExpense?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) =>
          _ScheduledExpenseFormSheet(initial: existing),
    );
    if (result == null) return;
    final list = [...(plan?.scheduledExpenses ?? const <ScheduledExpense>[])];
    final i = list.indexWhere((e) => e.id == existing.id);
    if (i != -1) list[i] = result;
    await _upsertPlan(plan, monthKey, scheduledExpenses: list);
  }

  Future<void> _removeScheduledExpense(
      MonthlyBudgetPlan? plan, String monthKey, String id) async {
    final list = [...(plan?.scheduledExpenses ?? const <ScheduledExpense>[])]
      ..removeWhere((e) => e.id == id);
    await _upsertPlan(plan, monthKey, scheduledExpenses: list);
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
    bool toggleFreeFundsCarryover = false,
    List<String>? excludedAccountIds,
    List<IncomeEntry>? incomes,
    List<ScheduledExpense>? scheduledExpenses,
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
      freeFundsCarryover: toggleFreeFundsCarryover
          ? !(plan?.freeFundsCarryover ?? false)
          : plan?.freeFundsCarryover,
      notes: plan?.notes,
      excludedAccountIds:
          excludedAccountIds ?? plan?.excludedAccountIds,
      incomes: incomes ?? plan?.incomes,
      scheduledExpenses: scheduledExpenses ?? plan?.scheduledExpenses,
      createdAt: plan?.createdAt ?? now,
      updatedAt: now,
    );
    await ref.read(monthlyBudgetPlansProvider.notifier).upsert(next);
  }
}

class _DueDayResult {
  const _DueDayResult.clear() : day = null;
  const _DueDayResult.set(int v) : day = v;
  final int? day;
}

class _CategoryEditResult {
  _CategoryEditResult({required this.amount, required this.dueDay});
  final num amount;
  final int? dueDay;
}

class _AccountSelectorCard extends StatelessWidget {
  const _AccountSelectorCard({
    required this.accounts,
    required this.excluded,
    required this.onToggle,
  });

  final List<Account> accounts;
  final Set<String> excluded;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text('Какие счета учитывать в плане',
                      style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Отключи подушку безопасности или копилку — операции по ним '
                'не будут влиять на расчёт плана и свободных средств.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final a in accounts)
                  FilterChip(
                    selected: !excluded.contains(a.id),
                    onSelected: (_) => onToggle(a.id),
                    label: Text('${a.name} (${a.currency})'),
                    selectedColor: scheme.primaryContainer,
                    checkmarkColor: scheme.onPrimaryContainer,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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
    required this.scheduledIncomeTotal,
    required this.plannedExpense,
    required this.committedExpense,
    required this.loansMonthlyPayments,
    required this.actualIncome,
    required this.actualExpense,
    required this.freeFunds,
    required this.carryIn,
    required this.dailyAllowance,
    required this.weeklyAllowance,
    required this.daysLeft,
    required this.currency,
    required this.fmt,
    required this.rollover,
    required this.freeFundsCarryover,
    required this.onEditIncome,
    required this.onToggleRollover,
    required this.onToggleFreeFundsCarryover,
  });

  final num plannedIncome;
  final num scheduledIncomeTotal;
  final num plannedExpense;
  final num committedExpense;
  final num loansMonthlyPayments;
  final num actualIncome;
  final num actualExpense;
  final num freeFunds;
  final num carryIn;
  final num dailyAllowance;
  final num weeklyAllowance;
  final int daysLeft;
  final String currency;
  final NumberFormat fmt;
  final bool rollover;
  final bool freeFundsCarryover;
  final VoidCallback onEditIncome;
  final VoidCallback onToggleRollover;
  final VoidCallback onToggleFreeFundsCarryover;

  @override
  Widget build(BuildContext context) {
    final effectivePlannedIncome = plannedIncome > scheduledIncomeTotal
        ? plannedIncome
        : scheduledIncomeTotal;
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
            if (scheduledIncomeTotal > 0) ...[
              const SizedBox(height: 4),
              _PlanRow(
                label: 'Доходы по датам',
                valueText:
                    '${fmt.format(scheduledIncomeTotal)} $currency',
              ),
              if (scheduledIncomeTotal > plannedIncome) ...[
                const SizedBox(height: 4),
                _PlanRow(
                  label: 'Итого план дохода',
                  valueText:
                      '${fmt.format(effectivePlannedIncome)} $currency',
                  valueColor: const Color(0xFF22C55E),
                ),
              ],
            ],
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
            if (loansMonthlyPayments > 0) ...[
              const SizedBox(height: 4),
              _PlanRow(
                label: '  · в т.ч. платежи по кредитам',
                valueText:
                    '${fmt.format(loansMonthlyPayments)} $currency',
              ),
            ],
            const SizedBox(height: 4),
            _PlanRow(
              label: 'Фактические расходы',
              valueText: '${fmt.format(actualExpense)} $currency',
            ),
            if (committedExpense != plannedExpense &&
                committedExpense != actualExpense) ...[
              const SizedBox(height: 4),
              _PlanRow(
                label: 'Учтено к расходам',
                valueText: '${fmt.format(committedExpense)} $currency',
                valueColor: const Color(0xFFEF4444),
              ),
            ],
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
            const SizedBox(height: 4),
            _PlanRow(
              label: 'В неделю',
              valueText: '${fmt.format(weeklyAllowance)} $currency',
            ),
            if (carryIn > 0) ...[
              const SizedBox(height: 4),
              _PlanRow(
                label: '+ Перенос с прошлого месяца',
                valueText: '${fmt.format(carryIn)} $currency',
                valueColor: const Color(0xFF22C55E),
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Перенос лимитов по категориям'),
              subtitle: const Text(
                  'Неизрасходованный лимит прошлого месяца прибавляется к этому'),
              value: rollover,
              onChanged: (_) => onToggleRollover(),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Перенос свободных средств'),
              subtitle: const Text(
                  'Непотраченный остаток прошлого месяца переходит на текущий'),
              value: freeFundsCarryover,
              onChanged: (_) => onToggleFreeFundsCarryover(),
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
    required this.onPickDay,
    required this.onDelete,
  });

  final CategoryPlan plan;
  final num actual;
  final num effectiveLimit;
  final String currency;
  final NumberFormat fmt;
  final VoidCallback onTap;
  final VoidCallback onPickDay;
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
                  if (plan.dueDay != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: color.withValues(alpha: 0.18),
                        child: Text('${plan.dueDay}',
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w800,
                                fontSize: 12)),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.category,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                        if (plan.dueDay != null)
                          Text('списание ${plan.dueDay} числа',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall),
                      ],
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
              Row(children: [
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.event, size: 16),
                  label: Text(plan.dueDay == null
                      ? 'Без даты'
                      : '${plan.dueDay} число'),
                  onPressed: onPickDay,
                ),
              ]),
              const SizedBox(height: 4),
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

/// Card that lists scheduled income lines (salary, bonus, etc).
class _IncomeScheduleCard extends StatelessWidget {
  const _IncomeScheduleCard({
    required this.incomes,
    required this.currency,
    required this.fmt,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<IncomeEntry> incomes;
  final String currency;
  final NumberFormat fmt;
  final VoidCallback onAdd;
  final ValueChanged<IncomeEntry> onEdit;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = incomes.fold<num>(0, (s, e) => s + e.amount);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(children: [
                Icon(Icons.calendar_month_outlined,
                    size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Доходы по датам',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (incomes.isNotEmpty)
                  Text('${fmt.format(total)} $currency',
                      style:
                          const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Добавить доход',
                  onPressed: onAdd,
                ),
              ]),
            ),
            if (incomes.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Text(
                    'Укажи, в какие дни месяца поступают зарплата, премия и др. — '
                    'я разделю месяц на периоды и посчитаю свободные деньги в день.',
                    style: Theme.of(context).textTheme.bodySmall),
              )
            else
              Column(
                children: [
                  for (final e in incomes)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF22C55E),
                        radius: 14,
                        child: Text('${e.day}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ),
                      title: Text(e.name),
                      subtitle:
                          Text('${fmt.format(e.amount)} $currency'),
                      trailing: Wrap(
                        spacing: 0,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 20),
                            onPressed: () => onEdit(e),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 20),
                            onPressed: () => onDelete(e.id),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _IncomeFormSheet extends StatefulWidget {
  const _IncomeFormSheet({this.initial});
  final IncomeEntry? initial;

  @override
  State<_IncomeFormSheet> createState() => _IncomeFormSheetState();
}

class _IncomeFormSheetState extends State<_IncomeFormSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _amount = TextEditingController(
      text: widget.initial == null ? '' : widget.initial!.amount.toString());
  late final TextEditingController _day = TextEditingController(
      text: widget.initial == null ? '5' : widget.initial!.day.toString());

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _day.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final amount =
        double.tryParse(_amount.text.trim().replaceAll(',', '.')) ?? 0;
    final day = int.tryParse(_day.text.trim());
    if (name.isEmpty || amount <= 0 || day == null || day < 1 || day > 31) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Заполни название, сумму и день (1–31)')));
      return;
    }
    Navigator.of(context).pop(IncomeEntry(
      id: widget.initial?.id ?? const Uuid().v4(),
      name: name,
      amount: amount,
      day: day,
    ));
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
          Text(widget.initial == null ? 'Новый доход' : 'Изменить доход',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
                labelText: 'Название (Зарплата, Премия, …)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amount,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Сумма'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _day,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'День месяца (1–31)',
              helperText:
                  'Если число превышает количество дней — будет последний день',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}

/// Card listing one-off planned expenses bound to a specific date
/// (e.g. internet on the 25th, rent on the 1st). Mirrors the income card.
class _ScheduledExpenseCard extends StatelessWidget {
  const _ScheduledExpenseCard({
    required this.items,
    required this.currency,
    required this.fmt,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ScheduledExpense> items;
  final String currency;
  final NumberFormat fmt;
  final VoidCallback onAdd;
  final ValueChanged<ScheduledExpense> onEdit;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]..sort((a, b) => a.day.compareTo(b.day));
    final total = sorted.fold<num>(0, (s, e) => s + e.amount);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(children: [
                const Icon(Icons.event_busy_outlined,
                    size: 18, color: Color(0xFFEF4444)),
                const SizedBox(width: 8),
                Text('Расходы по датам',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (sorted.isNotEmpty)
                  Text('${fmt.format(total)} $currency',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEF4444))),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Добавить расход',
                  onPressed: onAdd,
                ),
              ]),
            ),
            if (sorted.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Text(
                    'Перечисли разовые/периодические расходы с датой '
                    '(квартплата, интернет, подписки) — они уйдут в нужный день и сдвинут «свободно/день».',
                    style: Theme.of(context).textTheme.bodySmall),
              )
            else
              Column(
                children: [
                  for (final e in sorted)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEF4444),
                        radius: 14,
                        child: Text('${e.day}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ),
                      title: Text(e.name),
                      subtitle: Text(
                          '−${fmt.format(e.amount)} $currency${e.category != null ? ' · ${e.category}' : ''}'),
                      trailing: Wrap(
                        spacing: 0,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 20),
                            onPressed: () => onEdit(e),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 20),
                            onPressed: () => onDelete(e.id),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ScheduledExpenseFormSheet extends StatefulWidget {
  const _ScheduledExpenseFormSheet({this.initial});
  final ScheduledExpense? initial;

  @override
  State<_ScheduledExpenseFormSheet> createState() =>
      _ScheduledExpenseFormSheetState();
}

class _ScheduledExpenseFormSheetState
    extends State<_ScheduledExpenseFormSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _amount = TextEditingController(
      text:
          widget.initial == null ? '' : widget.initial!.amount.toString());
  late final TextEditingController _day = TextEditingController(
      text: widget.initial == null ? '1' : widget.initial!.day.toString());
  String? _category;

  @override
  void initState() {
    super.initState();
    _category = widget.initial?.category;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _day.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final amount =
        double.tryParse(_amount.text.trim().replaceAll(',', '.')) ?? 0;
    final day = int.tryParse(_day.text.trim());
    if (name.isEmpty || amount <= 0 || day == null || day < 1 || day > 31) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Заполни название, сумму и день (1–31)')));
      return;
    }
    Navigator.of(context).pop(ScheduledExpense(
      id: widget.initial?.id ?? const Uuid().v4(),
      name: name,
      amount: amount,
      day: day,
      category: _category,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
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
            Text(
                widget.initial == null
                    ? 'Новый плановый расход'
                    : 'Изменить расход',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText:
                      'Название (Интернет, Квартплата, Подписка, …)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Сумма'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _day,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'День месяца (1–31)',
                helperText:
                    'Если число превышает количество дней — будет последний день',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('Без категории'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                for (final c in kExpenseCategories.take(8))
                  ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    onSelected: (v) =>
                        setState(() => _category = v ? c : null),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Visualises the cashflow timeline for the selected month: a line chart of
/// the running balance, day-of-month markers for events, and a "free per
/// day" breakdown by period.
class _CashflowCard extends StatelessWidget {
  const _CashflowCard({
    required this.cashflow,
    required this.currency,
    required this.fmt,
    required this.today,
    required this.month,
  });

  final CashflowResult cashflow;
  final String currency;
  final NumberFormat fmt;
  final DateTime today;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCurrentMonth =
        today.year == month.year && today.month == month.month;
    final highlightDay =
        isCurrentMonth ? today.day : (cashflow.timeline.isEmpty ? 1 : 1);
    final period = cashflow.periods.isEmpty
        ? null
        : cashflow.periods.firstWhere(
            (p) => highlightDay >= p.startDay && highlightDay <= p.endDay,
            orElse: () => cashflow.periods.first,
          );
    final minBal = cashflow.timeline.fold<double>(
        0, (a, d) => math.min(a, d.balance.toDouble()));
    final maxBal = cashflow.timeline.fold<double>(
        0, (a, d) => math.max(a, d.balance.toDouble()));
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.timeline, color: scheme.primary),
              const SizedBox(width: 8),
              Text('Cashflow и периоды',
                  style: Theme.of(context).textTheme.titleSmall),
            ]),
            const SizedBox(height: 4),
            if (period != null)
              Text(
                isCurrentMonth
                    ? 'Текущий период: ${period.label} • '
                        '${fmt.format(period.dailyAllowance)} $currency / день'
                    : 'Первый период: ${period.label} • '
                        '${fmt.format(period.dailyAllowance)} $currency / день',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  minX: 1,
                  maxX: cashflow.timeline.length.toDouble(),
                  minY: minBal - 50,
                  maxY: maxBal + 50,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      strokeWidth: 0.5,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 38,
                        getTitlesWidget: (v, _) => Text(
                          v.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        reservedSize: 22,
                        getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                            style: const TextStyle(fontSize: 10)),
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
                      spots: [
                        for (final d in cashflow.timeline)
                          FlSpot(d.dayOfMonth.toDouble(),
                              d.balance.toDouble()),
                      ],
                      isCurved: true,
                      barWidth: 2,
                      color: scheme.primary,
                      dotData: FlDotData(
                        show: true,
                        checkToShowDot: (spot, _) =>
                            spot.x.toInt() == highlightDay,
                        getDotPainter: (spot, _, __, ___) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: scheme.primary,
                          strokeColor: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: scheme.primary.withValues(alpha: 0.18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final p in cashflow.periods)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    backgroundColor: p == period
                        ? scheme.primaryContainer
                        : null,
                    label: Text(
                      '${p.label}: ${fmt.format(p.dailyAllowance)} $currency / д',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-week breakdown card: how much free funds is left in each Mon-Sun
/// stretch of the month, with a bar chart and a list of weeks.
class _FreeFundsByWeekCard extends StatelessWidget {
  const _FreeFundsByWeekCard({
    required this.breakdown,
    required this.currency,
    required this.fmt,
    required this.today,
  });

  final FreeFundsBreakdown breakdown;
  final String currency;
  final NumberFormat fmt;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final weeks = breakdown.weeks;
    final maxAbs = weeks.fold<double>(
        0,
        (a, w) => math.max(
            a, (w.endBalance - w.startBalance).abs().toDouble()));
    final ySpan = (maxAbs == 0 ? 100 : maxAbs * 1.25).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.view_week_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              Text('Свободные средства по неделям',
                  style: Theme.of(context).textTheme.titleSmall),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  minY: -ySpan,
                  maxY: ySpan,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      strokeWidth: 0.5,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 38,
                        getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                            style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= weeks.length) {
                            return const SizedBox.shrink();
                          }
                          return Text('Н${weeks[i].index}',
                              style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: [
                    for (var i = 0; i < weeks.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: (weeks[i].endBalance - weeks[i].startBalance)
                                .toDouble(),
                            color: (weeks[i].endBalance -
                                            weeks[i].startBalance) >=
                                        0
                                ? scheme.primary
                                : const Color(0xFFEF4444),
                            width: 18,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(4)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final w in weeks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        'Нед. ${w.index}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${DateFormat('d').format(w.startDate)}–${DateFormat('d MMM', 'ru').format(w.endDate)} · '
                        '${w.daysInclusive} дн. · '
                        '${fmt.format(w.dailyAllowance)} $currency/день',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      '${fmt.format(w.endBalance - w.startBalance)} $currency',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: (w.endBalance - w.startBalance) >= 0
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFEF4444)),
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

/// Per-day-of-week card: shows Mon-Sun of the current week with the
/// suggested daily allowance and end-of-day running balance.
class _FreeFundsByWeekdayCard extends StatelessWidget {
  const _FreeFundsByWeekdayCard({
    required this.breakdown,
    required this.currency,
    required this.fmt,
    required this.today,
  });

  final FreeFundsBreakdown breakdown;
  final String currency;
  final NumberFormat fmt;
  final DateTime today;

  static const _names = [
    'Пн',
    'Вт',
    'Ср',
    'Чт',
    'Пт',
    'Сб',
    'Вс',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = breakdown.days;
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    final maxAllowance = days.fold<double>(
        0, (a, d) => math.max(a, d.allowance.abs().toDouble()));
    final yMax = (maxAllowance == 0 ? 50 : maxAllowance * 1.25).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.calendar_view_week_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              Text('Свободные средства по дням недели',
                  style: Theme.of(context).textTheme.titleSmall),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              height: 130,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  minY: 0,
                  maxY: yMax,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      strokeWidth: 0.5,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                            style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= _names.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(_names[i],
                              style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: [
                    for (var i = 0; i < days.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: math.max(0, days[i].allowance.toDouble()),
                            color: DateFormat('yyyy-MM-dd')
                                        .format(days[i].date) ==
                                    todayKey
                                ? scheme.tertiary
                                : scheme.primary,
                            width: 14,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(4)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < days.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        '${_names[i]} ${DateFormat('d.MM').format(days[i].date)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: DateFormat('yyyy-MM-dd')
                                      .format(days[i].date) ==
                                  todayKey
                              ? scheme.tertiary
                              : null,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        days[i].income > 0 || days[i].expense > 0
                            ? 'доход ${fmt.format(days[i].income)} · '
                                'расход ${fmt.format(days[i].expense)}'
                            : 'обычный день',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      '${fmt.format(days[i].allowance)} $currency',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
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

/// Plan vs. Fact stacked-bar chart: for every category with a planned
/// limit, show a "planned" bar and an "actual" bar side-by-side so the
/// user can see at a glance where they're under / over budget.
class _PlanVsFactCard extends StatelessWidget {
  const _PlanVsFactCard({
    required this.categoryPlans,
    required this.actualByCategory,
    required this.currency,
    required this.fmt,
  });

  final List<CategoryPlan> categoryPlans;
  final Map<String, num> actualByCategory;
  final String currency;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cats = [...categoryPlans]..sort((a, b) => b.planned.compareTo(a.planned));
    final maxV = cats.fold<double>(0, (a, c) {
      final p = c.planned.toDouble();
      final f = (actualByCategory[c.category] ?? 0).toDouble();
      return math.max(a, math.max(p, f));
    });
    final yMax = (maxV == 0 ? 100 : maxV * 1.2).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.bar_chart, color: scheme.primary),
              const SizedBox(width: 8),
              Text('План vs Факт по категориям',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              _LegendDot(color: scheme.primary, label: 'План'),
              const SizedBox(width: 8),
              _LegendDot(
                  color: const Color(0xFFEF4444), label: 'Факт'),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              height: math.max(120.0, cats.length * 28.0),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  minY: 0,
                  maxY: yMax,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      strokeWidth: 0.5,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 38,
                        getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                            style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= cats.length) {
                            return const SizedBox.shrink();
                          }
                          final name = cats[i].category;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              name.length > 6
                                  ? '${name.substring(0, 6)}…'
                                  : name,
                              style: const TextStyle(fontSize: 9),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: [
                    for (var i = 0; i < cats.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 2,
                        barRods: [
                          BarChartRodData(
                            toY: cats[i].planned.toDouble(),
                            color: scheme.primary,
                            width: 8,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(2)),
                          ),
                          BarChartRodData(
                            toY: (actualByCategory[cats[i].category] ?? 0)
                                .toDouble(),
                            color: const Color(0xFFEF4444),
                            width: 8,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(2)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            for (final c in cats)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(c.category,
                          style: const TextStyle(fontSize: 12)),
                    ),
                    Text(
                      '${fmt.format(actualByCategory[c.category] ?? 0)} / ${fmt.format(c.planned)} $currency',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (actualByCategory[c.category] ?? 0) > c.planned
                            ? const Color(0xFFEF4444)
                            : null,
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

/// Donut showing the composition of planned expenses for the month
/// (categories + scheduled bills + loan payments). Helps spot over-allocated
/// buckets at a glance.
class _ExpenseShareCard extends StatelessWidget {
  const _ExpenseShareCard({
    required this.categoryPlans,
    required this.scheduledExpenses,
    required this.loansMonthlyPayments,
    required this.currency,
    required this.fmt,
  });

  final List<CategoryPlan> categoryPlans;
  final List<ScheduledExpense> scheduledExpenses;
  final num loansMonthlyPayments;
  final String currency;
  final NumberFormat fmt;

  static const _palette = [
    Color(0xFF6D5CFF),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFFA855F7),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = <_ShareEntry>[];
    for (final cp in categoryPlans) {
      if (cp.planned <= 0) continue;
      entries.add(_ShareEntry(label: cp.category, value: cp.planned));
    }
    if (scheduledExpenses.isNotEmpty) {
      final s =
          scheduledExpenses.fold<num>(0, (a, e) => a + e.amount);
      if (s > 0) {
        entries.add(_ShareEntry(label: 'По датам', value: s));
      }
    }
    if (loansMonthlyPayments > 0) {
      entries.add(_ShareEntry(
          label: 'Кредиты', value: loansMonthlyPayments));
    }
    entries.sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<num>(0, (a, e) => a + e.value);
    if (total <= 0) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.donut_small, color: scheme.primary),
              const SizedBox(width: 8),
              Text('Структура расходов плана',
                  style: Theme.of(context).textTheme.titleSmall),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 38,
                  sectionsSpace: 2,
                  sections: [
                    for (var i = 0; i < entries.length; i++)
                      PieChartSectionData(
                        value: entries[i].value.toDouble(),
                        color: _palette[i % _palette.length],
                        radius: 38,
                        title: total == 0
                            ? ''
                            : '${(entries[i].value * 100 / total).round()}%',
                        titleStyle: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var i = 0; i < entries.length; i++)
                  _LegendDot(
                    color: _palette[i % _palette.length],
                    label:
                        '${entries[i].label} · ${fmt.format(entries[i].value)} $currency',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareEntry {
  _ShareEntry({required this.label, required this.value});
  final String label;
  final num value;
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
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
