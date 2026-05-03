import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/finance.dart';
import '../../models/savings_goal.dart';
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
            carryIn: carryIn,
          );
    final breakdown = cashflow == null
        ? null
        : buildFreeFundsBreakdown(
            cashflow: cashflow,
            month: _month,
            today: DateTime.now(),
          );

    // Phase 19: derived data for new cards.
    final history = computeHistoricalMonths(
      endMonth: _month,
      count: 6,
      transactions: transactions,
      accounts: accounts,
      baseCurrency: baseCurrency,
      convert: convert,
      excludedAccountIds: excluded,
    );
    num totalLiquid = 0;
    for (final a in accounts) {
      if (excluded.contains(a.id)) continue;
      totalLiquid += convert(
          accountBalance(
            account: a,
            transactions: transactions,
            accounts: accounts,
            convert: convert,
          ),
          a.currency,
          planCurrency);
    }
    final emergency = computeEmergencyFund(
      totalLiquid: totalLiquid,
      history: history,
    );
    final health = computeHealthCheck(
      plannedIncomeRef: (plan?.plannedIncome ?? 0) > scheduledIncomeTotal
          ? (plan?.plannedIncome ?? 0)
          : scheduledIncomeTotal,
      categoryPlans: plan?.categoryPlans ?? const [],
      scheduledExpenses:
          plan?.scheduledExpenses ?? const <ScheduledExpense>[],
      loansMonthlyPayments: loansMonthlyPayments,
      committedTotal: committed.total,
      freeFunds: freeFunds.free,
    );
    final subscriptions = computeSubscriptions(
        plan?.scheduledExpenses ?? const <ScheduledExpense>[]);
    final dailyAllowanceList =
        cashflow == null ? const <num>[] : perDayAllowance(cashflow);
    final savingsGoals = ref.watch(savingsGoalsProvider);
    final hasPrevPlan = prevPlan != null &&
        ((prevPlan.categoryPlans.isNotEmpty) ||
            ((prevPlan.incomes ?? const []).isNotEmpty) ||
            ((prevPlan.scheduledExpenses ?? const []).isNotEmpty));
    final isCurrentMonthEmpty = plan == null ||
        (plan.categoryPlans.isEmpty &&
            (plan.incomes ?? const []).isEmpty &&
            (plan.scheduledExpenses ?? const []).isEmpty &&
            plan.plannedIncome == 0);

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
        if (hasPrevPlan) ...[
          const SizedBox(height: 8),
          _CopyPrevMonthBanner(
            previousMonthLabel:
                _previousMonthLabel(_month),
            isCurrentMonthEmpty: isCurrentMonthEmpty,
            onCopy: () => _copyPrevMonth(plan, monthKey, prevPlan),
            onAddRecurring: () =>
                _carryRecurring(plan, monthKey, prevPlan),
          ),
        ],
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
        _HealthCheckCard(
          health: health,
          currency: planCurrency,
          fmt: fmt,
        ),
        if (history.any((m) => m.expense > 0)) ...[
          const SizedBox(height: 12),
          _EmergencyFundCard(
            emergency: emergency,
            currency: planCurrency,
            fmt: fmt,
          ),
        ],
        const SizedBox(height: 12),
        _IncomeScheduleCard(
          incomes: plan?.incomes ?? const [],
          currency: planCurrency,
          fmt: fmt,
          onAdd: () => _addIncomeEntry(plan, monthKey),
          onEdit: (e) => _editIncomeEntry(plan, monthKey, e),
          onDelete: (id) => _removeIncomeEntry(plan, monthKey, id),
        ),
        if ((plan?.incomes ?? const <IncomeEntry>[]).isNotEmpty) ...[
          const SizedBox(height: 12),
          _IncomeBreakdownCard(
            incomes: plan!.incomes!,
            history: history,
            currency: planCurrency,
            fmt: fmt,
          ),
        ],
        const SizedBox(height: 12),
        _ScheduledExpenseCard(
          items: plan?.scheduledExpenses ?? const [],
          currency: planCurrency,
          fmt: fmt,
          onAdd: () => _addScheduledExpense(plan, monthKey),
          onEdit: (e) => _editScheduledExpense(plan, monthKey, e),
          onDelete: (id) => _removeScheduledExpense(plan, monthKey, id),
        ),
        if (subscriptions.items.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SubscriptionsCard(
            summary: subscriptions,
            currency: planCurrency,
            fmt: fmt,
            onEdit: (e) => _editScheduledExpense(plan, monthKey, e),
          ),
        ],
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
        if (cashflow != null && dailyAllowanceList.isNotEmpty) ...[
          const SizedBox(height: 12),
          _PerDayAllowanceCard(
            allowances: dailyAllowanceList,
            cashflow: cashflow,
            month: _month,
            today: DateTime.now(),
            currency: planCurrency,
            fmt: fmt,
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
        const SizedBox(height: 12),
        _SavingsGoalsCard(
          goals: savingsGoals,
          currency: planCurrency,
          fmt: fmt,
          weeklyAllowance: weekly,
          freeFunds: freeFunds.free,
          onAdd: () => _addSavingsGoal(planCurrency),
          onEdit: (g) => _editSavingsGoal(g),
          onDelete: (id) => ref
              .read(savingsGoalsProvider.notifier)
              .remove(id),
          onTopUp: (g) => _topUpSavingsGoal(g),
        ),
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

  // ---------------------------------------------------------------
  // Phase 19: copy from previous month + savings goals helpers.
  // ---------------------------------------------------------------

  String _previousMonthLabel(DateTime current) {
    final prev = DateTime(current.year, current.month - 1, 1);
    return DateFormat.yMMMM('ru_RU').format(prev);
  }

  /// Replace the current month's plan with a clone of [prev]. New IDs are
  /// generated for incomes/expenses so editing one doesn't ripple back.
  Future<void> _copyPrevMonth(
    MonthlyBudgetPlan? current,
    String monthKey,
    MonthlyBudgetPlan? prev,
  ) async {
    if (prev == null) return;
    if (current != null && (current.categoryPlans.isNotEmpty ||
        (current.incomes ?? const []).isNotEmpty ||
        (current.scheduledExpenses ?? const []).isNotEmpty)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Перезаписать план?'),
          content: const Text(
              'В текущем месяце уже есть план. Скопировать с прошлого месяца, заменив всё?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Перезаписать'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    final uuid = const Uuid();
    final newIncomes = (prev.incomes ?? const <IncomeEntry>[])
        .map((e) => IncomeEntry(
              id: uuid.v4(),
              name: e.name,
              amount: e.amount,
              day: e.day,
              recurEvery: e.recurEvery,
            ))
        .toList();
    final newExpenses = (prev.scheduledExpenses ?? const <ScheduledExpense>[])
        .map((e) => ScheduledExpense(
              id: uuid.v4(),
              name: e.name,
              amount: e.amount,
              day: e.day,
              category: e.category,
              recurEvery: e.recurEvery,
              isSubscription: e.isSubscription,
            ))
        .toList();
    final newCategories = prev.categoryPlans
        .map((c) => CategoryPlan(
              category: c.category,
              planned: c.planned,
              dueDay: c.dueDay,
            ))
        .toList();
    final now = DateTime.now().toIso8601String();
    final next = MonthlyBudgetPlan(
      id: current?.id ?? const Uuid().v4(),
      monthKey: monthKey,
      plannedIncome: prev.plannedIncome,
      currency: prev.currency ?? current?.currency,
      categoryPlans: newCategories,
      freeFundsTarget: prev.freeFundsTarget,
      rollover: current?.rollover ?? prev.rollover,
      freeFundsCarryover:
          current?.freeFundsCarryover ?? prev.freeFundsCarryover,
      notes: current?.notes,
      excludedAccountIds:
          current?.excludedAccountIds ?? prev.excludedAccountIds,
      incomes: newIncomes,
      scheduledExpenses: newExpenses,
      createdAt: current?.createdAt ?? now,
      updatedAt: now,
    );
    await ref.read(monthlyBudgetPlansProvider.notifier).upsert(next);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('План скопирован с прошлого месяца')));
    }
  }

  /// Add only the recurring entries (recurEvery>0) from [prev] that don't
  /// already exist in the current plan (matched by name+day).
  Future<void> _carryRecurring(
    MonthlyBudgetPlan? current,
    String monthKey,
    MonthlyBudgetPlan? prev,
  ) async {
    if (prev == null) return;
    final uuid = const Uuid();
    final curIncomes = [...(current?.incomes ?? const <IncomeEntry>[])];
    final curExpenses =
        [...(current?.scheduledExpenses ?? const <ScheduledExpense>[])];
    var added = 0;
    for (final e in (prev.incomes ?? const <IncomeEntry>[])) {
      if ((e.recurEvery ?? 0) <= 0) continue;
      final dup = curIncomes.any((c) =>
          c.name.toLowerCase() == e.name.toLowerCase() && c.day == e.day);
      if (dup) continue;
      curIncomes.add(IncomeEntry(
        id: uuid.v4(),
        name: e.name,
        amount: e.amount,
        day: e.day,
        recurEvery: e.recurEvery,
      ));
      added++;
    }
    for (final e in (prev.scheduledExpenses ?? const <ScheduledExpense>[])) {
      if ((e.recurEvery ?? 0) <= 0) continue;
      final dup = curExpenses.any((c) =>
          c.name.toLowerCase() == e.name.toLowerCase() && c.day == e.day);
      if (dup) continue;
      curExpenses.add(ScheduledExpense(
        id: uuid.v4(),
        name: e.name,
        amount: e.amount,
        day: e.day,
        category: e.category,
        recurEvery: e.recurEvery,
        isSubscription: e.isSubscription,
      ));
      added++;
    }
    if (added == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Все повторяющиеся записи уже есть в этом месяце.')));
      }
      return;
    }
    await _upsertPlan(current, monthKey,
        incomes: curIncomes, scheduledExpenses: curExpenses);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Добавлено повторяющихся: $added')));
    }
  }

  Future<void> _addSavingsGoal(String currency) async {
    final result = await showModalBottomSheet<SavingsGoal?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _SavingsGoalSheet(currency: currency),
    );
    if (result == null) return;
    await ref.read(savingsGoalsProvider.notifier).add(result);
  }

  Future<void> _editSavingsGoal(SavingsGoal goal) async {
    final result = await showModalBottomSheet<SavingsGoal?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _SavingsGoalSheet(currency: goal.currency, initial: goal),
    );
    if (result == null) return;
    await ref.read(savingsGoalsProvider.notifier).upsert(result);
  }

  Future<void> _topUpSavingsGoal(SavingsGoal goal) async {
    final ctl = TextEditingController();
    final next = await showDialog<num?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Пополнить «${goal.title}»'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              const InputDecoration(hintText: 'Сумма пополнения'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              final v =
                  double.tryParse(ctl.text.trim().replaceAll(',', '.')) ?? 0;
              Navigator.of(ctx).pop(v);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    if (next == null || next <= 0) return;
    await ref.read(savingsGoalsProvider.notifier).upsert(
          goal.copyWith(currentAmount: goal.currentAmount + next),
        );
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
                      title: Row(children: [
                        Flexible(child: Text(e.name)),
                        if ((e.recurEvery ?? 0) > 0) ...[
                          const SizedBox(width: 6),
                          _RecurChip(every: e.recurEvery!),
                        ],
                      ]),
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

/// Tiny chip showing a recurrence period (e.g. "1м", "Кв", "Год") next to
/// scheduled income/expense rows.
class _RecurChip extends StatelessWidget {
  const _RecurChip({required this.every});
  final int every;

  static String labelFor(int every) {
    switch (every) {
      case 1:
        return '1 мес';
      case 2:
        return '2 мес';
      case 3:
        return 'Квартал';
      case 6:
        return 'Полгода';
      case 12:
        return 'Год';
      default:
        return '$every мес';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.repeat, size: 11, color: scheme.primary),
        const SizedBox(width: 3),
        Text(labelFor(every),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: scheme.primary)),
      ]),
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
  late int _recur = widget.initial?.recurEvery ?? 1;

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
      recurEvery: _recur > 0 ? _recur : null,
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
            const SizedBox(height: 12),
            _RecurrenceSelector(
              value: _recur,
              onChanged: (v) => setState(() => _recur = v),
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

/// Phase 19: shared "Повторять" picker used by income & expense sheets.
/// `value=0` means one-off; >0 means "every N months".
class _RecurrenceSelector extends StatelessWidget {
  const _RecurrenceSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final options = <(int, String)>[
      (0, 'Один раз'),
      (1, 'Каждый месяц'),
      (2, 'Раз в 2 мес'),
      (3, 'Квартал'),
      (6, 'Полугодие'),
      (12, 'Год'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(children: [
            Icon(Icons.repeat, size: 16, color: scheme.primary),
            const SizedBox(width: 6),
            Text('Повторять',
                style: Theme.of(context).textTheme.labelMedium),
          ]),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final (v, label) in options)
              ChoiceChip(
                label: Text(label),
                selected: value == v,
                onSelected: (_) => onChanged(v),
              ),
          ],
        ),
      ],
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
                      title: Row(children: [
                        Flexible(child: Text(e.name)),
                        if ((e.recurEvery ?? 0) > 0) ...[
                          const SizedBox(width: 6),
                          _RecurChip(every: e.recurEvery!),
                        ],
                        if (e.isSubscription == true) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.subscriptions_outlined,
                                      size: 11, color: Color(0xFFEF4444)),
                                  SizedBox(width: 3),
                                  Text('Подписка',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFEF4444))),
                                ]),
                          ),
                        ],
                      ]),
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
  late int _recur = widget.initial?.recurEvery ?? 1;
  late bool? _isSubscription = widget.initial?.isSubscription;

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
      recurEvery: _recur > 0 ? _recur : null,
      isSubscription: _isSubscription,
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
            const SizedBox(height: 12),
            _RecurrenceSelector(
              value: _recur,
              onChanged: (v) => setState(() => _recur = v),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Это подписка'),
              subtitle: const Text(
                  'Помечу в карточке «Подписки», где видно общую сумму в месяц/год'),
              value: _isSubscription == true,
              onChanged: (v) =>
                  setState(() => _isSubscription = v ? true : null),
            ),
            const SizedBox(height: 12),
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
        0, (a, w) => math.max(a, w.weeklyFree.abs().toDouble()));
    final ySpan = (maxAbs == 0 ? 100 : maxAbs * 1.25).toDouble();
    final yInterval = _niceInterval(ySpan, 4);
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
            const SizedBox(height: 4),
            Text(
              'Бар = свободно в эту неделю (из остатка до следующей зарплаты)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  minY: 0,
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
                        reservedSize: 44,
                        interval: yInterval,
                        getTitlesWidget: (v, _) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(v.toInt().toString(),
                              style: const TextStyle(fontSize: 10)),
                        ),
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
                            toY: math.max(0, weeks[i].weeklyFree.toDouble()),
                            color: scheme.primary,
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
                      width: 90,
                      child: Text(
                        'Нед. ${w.index} (${DateFormat('d').format(w.startDate)}–${DateFormat('d').format(w.endDate)})',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${w.daysInclusive} дн. · ${fmt.format(w.dailyAllowance)} $currency/день · остаток ${fmt.format(w.endBalance)} $currency',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    Text(
                      '${fmt.format(w.weeklyFree)} $currency',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: w.weeklyFree > 0
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF6B7280)),
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
    final yInterval = _niceInterval(yMax, 4);
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
                        reservedSize: 44,
                        interval: yInterval,
                        getTitlesWidget: (v, _) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(v.toInt().toString(),
                              style: const TextStyle(fontSize: 10)),
                        ),
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
            const SizedBox(height: 4),
            Text(
              'Бар = сколько можно тратить в этот день (остаток равномерно до следующей зп)',
              style: Theme.of(context).textTheme.bodySmall,
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
                        () {
                          final parts = <String>[];
                          if (days[i].income > 0) {
                            parts.add('+${fmt.format(days[i].income)}');
                          }
                          if (days[i].expense > 0) {
                            parts.add('-${fmt.format(days[i].expense)}');
                          }
                          parts.add(
                              'остаток ${fmt.format(days[i].endBalance)}');
                          return parts.join(' · ');
                        }(),
                        style: const TextStyle(fontSize: 11),
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

/// Pick a "nice" Y-axis interval so labels don't overlap. Targets ~[divisions]
/// gridlines. Rounds to powers of 10 with 1/2/5 mantissa.
double _niceInterval(double range, int divisions) {
  if (range <= 0) return 1.0;
  final raw = range / math.max(1, divisions);
  final pow10 = math.pow(10, raw.abs().toStringAsFixed(0).length - 1);
  for (final mult in const <double>[1, 2, 5, 10]) {
    final candidate = mult * pow10;
    if (candidate >= raw) return candidate;
  }
  return raw;
}

// =====================================================================
// Phase 19 widgets
// =====================================================================

/// Copy-from-previous-month banner. Shown only when the previous month has a
/// plan. Two actions:
/// * Скопировать всё — replace this month with last month (with confirm).
/// * Только повторяющиеся — append entries with recurEvery>0.
class _CopyPrevMonthBanner extends StatelessWidget {
  const _CopyPrevMonthBanner({
    required this.previousMonthLabel,
    required this.isCurrentMonthEmpty,
    required this.onCopy,
    required this.onAddRecurring,
  });

  final String previousMonthLabel;
  final bool isCurrentMonthEmpty;
  final VoidCallback onCopy;
  final VoidCallback onAddRecurring;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.content_copy_outlined,
                  size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isCurrentMonthEmpty
                      ? 'План пуст. Перенести из «$previousMonthLabel»?'
                      : 'Из «$previousMonthLabel» можно перенести записи.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.copy_all_outlined, size: 16),
                  label: const Text('Скопировать всё'),
                  onPressed: onCopy,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.repeat, size: 16),
                  label: const Text('Только повторяющиеся'),
                  onPressed: onAddRecurring,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Health-check (50/30/20 + expense/income ratio + traffic light).
class _HealthCheckCard extends StatelessWidget {
  const _HealthCheckCard({
    required this.health,
    required this.currency,
    required this.fmt,
  });

  final HealthCheck health;
  final String currency;
  final NumberFormat fmt;

  Color _color(int sev) {
    switch (sev) {
      case 0:
        return const Color(0xFFEF4444);
      case 1:
        return const Color(0xFFF59E0B);
      case 2:
      default:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = _color(health.severity);
    final pct = (health.expenseToIncome * 100).clamp(0, 200).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.health_and_safety_outlined, color: c),
              const SizedBox(width: 8),
              Text('Здоровье плана',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  health.severity == 2
                      ? 'OK'
                      : health.severity == 1
                          ? 'Можно лучше'
                          : 'Внимание',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: c, fontSize: 12),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0, 1).toDouble(),
                minHeight: 10,
                backgroundColor: scheme.surfaceContainerHighest,
                color: c,
              ),
            ),
            const SizedBox(height: 6),
            Text(health.message,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text('Структура 50/30/20',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            _StackedShareBar(
              segments: [
                _StackSegment(
                  label: 'Обязательное',
                  share: health.needsShare,
                  color: const Color(0xFFEF4444),
                ),
                _StackSegment(
                  label: 'Хотелки',
                  share: health.wantsShare,
                  color: const Color(0xFFF59E0B),
                ),
                _StackSegment(
                  label: 'Накопления',
                  share: health.savingsShare,
                  color: const Color(0xFF10B981),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 4, children: [
              _ShareLegend(
                color: const Color(0xFFEF4444),
                label: 'Обязательное',
                value: health.needsShare,
              ),
              _ShareLegend(
                color: const Color(0xFFF59E0B),
                label: 'Хотелки',
                value: health.wantsShare,
              ),
              _ShareLegend(
                color: const Color(0xFF10B981),
                label: 'Накопления',
                value: health.savingsShare,
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              'Расходы: ${fmt.format(health.expenseToIncome * 100)}% от дохода. '
              'Накопления: ${fmt.format(health.savingsRate * 100)}%.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StackSegment {
  _StackSegment(
      {required this.label, required this.share, required this.color});
  final String label;
  final double share;
  final Color color;
}

class _StackedShareBar extends StatelessWidget {
  const _StackedShareBar({required this.segments});
  final List<_StackSegment> segments;

  @override
  Widget build(BuildContext context) {
    final shown = segments.where((s) => s.share > 0).toList();
    if (shown.isEmpty) {
      return Container(
        height: 12,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }
    final total = shown.fold<double>(0, (s, x) => s + x.share);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            for (final s in shown)
              Expanded(
                flex: ((s.share / total) * 1000).round(),
                child: Container(color: s.color),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShareLegend extends StatelessWidget {
  const _ShareLegend(
      {required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text('$label · ${(value * 100).toStringAsFixed(0)}%',
          style: const TextStyle(fontSize: 12)),
    ]);
  }
}

/// Emergency-fund indicator: «у тебя X месяцев расходов отложено».
class _EmergencyFundCard extends StatelessWidget {
  const _EmergencyFundCard({
    required this.emergency,
    required this.currency,
    required this.fmt,
  });

  final EmergencyFund emergency;
  final String currency;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final c = switch (emergency.severity) {
      0 => const Color(0xFFEF4444),
      1 => const Color(0xFFF59E0B),
      2 => const Color(0xFF6366F1),
      _ => const Color(0xFF10B981),
    };
    final months = emergency.months.toDouble();
    final ratio = (months / 6).clamp(0, 1).toDouble();
    final label = emergency.severity == 0
        ? 'Подушки нет'
        : emergency.severity == 1
            ? 'Маловато'
            : emergency.severity == 2
                ? 'Норм'
                : 'Отлично';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.savings_outlined, color: c),
              const SizedBox(width: 8),
              Text('Подушка безопасности',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: c,
                        fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                emergency.months <= 0
                    ? '0 мес'
                    : '${emergency.months.toStringAsFixed(1)} мес',
                style: const TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '/ цель 6 мес',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                color: c,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Доступно: ${fmt.format(emergency.totalLiquid)} $currency · '
              'средний расход: ${fmt.format(emergency.avgMonthlyExpense)} $currency / мес',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Income-sources pie chart + 6-month income/expense trend line.
class _IncomeBreakdownCard extends StatelessWidget {
  const _IncomeBreakdownCard({
    required this.incomes,
    required this.history,
    required this.currency,
    required this.fmt,
  });

  final List<IncomeEntry> incomes;
  final List<HistoricalMonth> history;
  final String currency;
  final NumberFormat fmt;

  static const _palette = <Color>[
    Color(0xFF22C55E),
    Color(0xFF6366F1),
    Color(0xFFF59E0B),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFFF97316),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = incomes.fold<num>(0, (s, e) => s + e.amount);
    final hasHistory =
        history.any((m) => m.income > 0 || m.expense > 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.donut_large_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              Text('Доходы — структура и тренд',
                  style: Theme.of(context).textTheme.titleSmall),
            ]),
            const SizedBox(height: 8),
            if (incomes.isEmpty || total <= 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                    'Добавь доход в «Доходы по датам», чтобы увидеть круговую диаграмму.',
                    style: Theme.of(context).textTheme.bodySmall),
              )
            else ...[
              SizedBox(
                height: 160,
                child: Row(children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 32,
                        sections: [
                          for (var i = 0; i < incomes.length; i++)
                            PieChartSectionData(
                              value: incomes[i].amount.toDouble(),
                              color: _palette[i % _palette.length],
                              title:
                                  '${((incomes[i].amount / total) * 100).round()}%',
                              radius: 44,
                              titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < incomes.length; i++)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 2),
                            child: Row(children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _palette[i % _palette.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${incomes[i].name}: ${fmt.format(incomes[i].amount)} $currency',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                          ),
                        const SizedBox(height: 4),
                        Text('Итого: ${fmt.format(total)} $currency',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
            if (hasHistory) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text('Доход / расход — 6 мес',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              SizedBox(
                height: 140,
                child: _HistoryLineChart(history: history, fmt: fmt),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryLineChart extends StatelessWidget {
  const _HistoryLineChart({required this.history, required this.fmt});
  final List<HistoricalMonth> history;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final maxY = history.fold<double>(
        0,
        (a, m) => math.max(
            a,
            math.max(m.income.toDouble(),
                m.expense.toDouble())));
    final niceMaxY = maxY <= 0 ? 100.0 : maxY * 1.15;
    final interval = _niceInterval(niceMaxY, 4);
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (history.length - 1).toDouble(),
        minY: 0,
        maxY: niceMaxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
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
              interval: interval,
              getTitlesWidget: (v, _) => Text(
                v >= 1000
                    ? '${(v / 1000).toStringAsFixed(0)}к'
                    : v.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 22,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= history.length) {
                  return const SizedBox.shrink();
                }
                final m = history[idx].month;
                return Text(
                    DateFormat('LLL', 'ru_RU').format(m).replaceAll('.', ''),
                    style: const TextStyle(fontSize: 10));
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
            isCurved: true,
            color: const Color(0xFF22C55E),
            barWidth: 2,
            dotData: const FlDotData(show: true),
            spots: [
              for (var i = 0; i < history.length; i++)
                FlSpot(i.toDouble(), history[i].income.toDouble()),
            ],
          ),
          LineChartBarData(
            isCurved: true,
            color: const Color(0xFFEF4444),
            barWidth: 2,
            dotData: const FlDotData(show: true),
            spots: [
              for (var i = 0; i < history.length; i++)
                FlSpot(i.toDouble(), history[i].expense.toDouble()),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card listing the auto-detected subscriptions plus monthly/annual totals.
class _SubscriptionsCard extends StatelessWidget {
  const _SubscriptionsCard({
    required this.summary,
    required this.currency,
    required this.fmt,
    required this.onEdit,
  });

  final SubscriptionsSummary summary;
  final String currency;
  final NumberFormat fmt;
  final ValueChanged<ScheduledExpense> onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.subscriptions_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              Text('Подписки',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text('${summary.items.length} шт',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            Text(
                'В месяц: ${fmt.format(summary.monthlyTotal)} $currency · '
                'в год: ${fmt.format(summary.annualTotal)} $currency',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final s in summary.items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.repeat,
                    color: Color(0xFFEF4444), size: 20),
                title: Text(s.name),
                subtitle: Text(
                  '−${fmt.format(s.amount)} $currency · ${_RecurChip.labelFor(s.recurEvery ?? 1)}'
                  '${s.day == 0 ? '' : ' · ${s.day}-го'}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => onEdit(s),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Per-day allowance bars across the whole month — на каждый день видно,
/// сколько можно безопасно тратить, не залезая в обязательные платежи.
class _PerDayAllowanceCard extends StatelessWidget {
  const _PerDayAllowanceCard({
    required this.allowances,
    required this.cashflow,
    required this.month,
    required this.today,
    required this.currency,
    required this.fmt,
  });

  final List<num> allowances;
  final CashflowResult cashflow;
  final DateTime month;
  final DateTime today;
  final String currency;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCurrentMonth =
        today.year == month.year && today.month == month.month;
    final maxA = allowances.fold<double>(
        0, (a, x) => math.max(a, x.toDouble()));
    final niceMax = maxA <= 0 ? 1.0 : maxA * 1.2;
    final daysInMonth = allowances.length;
    final periods = cashflow.periods;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.bar_chart_rounded, color: scheme.primary),
              const SizedBox(width: 8),
              Text('Можно тратить — каждый день',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              if (isCurrentMonth && today.day - 1 < allowances.length)
                Text(
                    'Сегодня ${fmt.format(allowances[today.day - 1])} $currency',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            Text(
              'Безопасный дневной расход: считаем остаток до следующего дохода или конца месяца, '
              'вычитаем будущие обязательные платежи и делим на оставшиеся дни.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceBetween,
                  maxY: niceMax,
                  minY: 0,
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
                        interval: _niceInterval(niceMax, 4),
                        getTitlesWidget: (v, _) => Text(
                          v >= 1000
                              ? '${(v / 1000).toStringAsFixed(0)}к'
                              : v.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        reservedSize: 22,
                        getTitlesWidget: (v, _) {
                          final d = v.toInt() + 1;
                          if (d < 1 || d > daysInMonth) {
                            return const SizedBox.shrink();
                          }
                          if (d == 1 || d % 5 == 0 || d == daysInMonth) {
                            return Text('$d',
                                style: const TextStyle(fontSize: 10));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, gIdx, rod, rIdx) {
                        final d = group.x + 1;
                        return BarTooltipItem(
                          'День $d\n${fmt.format(rod.toY)} $currency',
                          const TextStyle(
                              color: Colors.white, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var i = 0; i < daysInMonth; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: allowances[i].toDouble(),
                            width: 7,
                            color: _allowanceColor(
                                allowances[i].toDouble(), maxA, scheme),
                            borderRadius:
                                BorderRadius.circular(2),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (periods.isNotEmpty) ...[
              Text('По периодам',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              for (final p in periods)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(p.label,
                          style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${fmt.format(p.dailyAllowance)} $currency / день · '
                        '${p.daysInclusive} ${_dayWord(p.daysInclusive)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ]),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Color _allowanceColor(double v, double max, ColorScheme scheme) {
    if (max <= 0) return scheme.primary;
    if (v <= 0) return const Color(0xFFEF4444);
    final r = v / max;
    if (r < 0.33) return const Color(0xFFF59E0B);
    if (r < 0.66) return const Color(0xFF6366F1);
    return const Color(0xFF10B981);
  }

  static String _dayWord(int n) {
    final lastTwo = n % 100;
    if (lastTwo >= 11 && lastTwo <= 14) return 'дней';
    final last = n % 10;
    if (last == 1) return 'день';
    if (last >= 2 && last <= 4) return 'дня';
    return 'дней';
  }
}

/// Savings goals card — list of goals with progress + ETA forecast based on
/// current weekly allowance.
class _SavingsGoalsCard extends StatelessWidget {
  const _SavingsGoalsCard({
    required this.goals,
    required this.currency,
    required this.fmt,
    required this.weeklyAllowance,
    required this.freeFunds,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onTopUp,
  });

  final List<SavingsGoal> goals;
  final String currency;
  final NumberFormat fmt;
  final num weeklyAllowance;
  final num freeFunds;
  final VoidCallback onAdd;
  final ValueChanged<SavingsGoal> onEdit;
  final ValueChanged<String> onDelete;
  final ValueChanged<SavingsGoal> onTopUp;

  String? _eta(SavingsGoal g) {
    if (g.isCompleted) return 'Цель достигнута';
    if (weeklyAllowance <= 0) return null;
    final weeks = (g.remaining / weeklyAllowance).ceil();
    if (weeks <= 0) return null;
    final eta = DateTime.now().add(Duration(days: weeks * 7));
    final monthFmt = DateFormat.yMMMM('ru_RU');
    return 'При откладывании ${fmt.format(weeklyAllowance)} $currency / нед — '
        '$weeks нед, к ${monthFmt.format(eta)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.flag_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              Text('Цели и накопления',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              IconButton(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                tooltip: 'Добавить цель',
              ),
            ]),
            if (goals.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                child: Text(
                  'Поставь цель: например «Отпуск 2000 BYN к августу» — '
                  'я подскажу, сколько откладывать в неделю.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              for (final g in goals)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _SavingsGoalRow(
                    goal: g,
                    currency: currency,
                    fmt: fmt,
                    eta: _eta(g),
                    onEdit: () => onEdit(g),
                    onDelete: () => onDelete(g.id),
                    onTopUp: () => onTopUp(g),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SavingsGoalRow extends StatelessWidget {
  const _SavingsGoalRow({
    required this.goal,
    required this.currency,
    required this.fmt,
    required this.eta,
    required this.onEdit,
    required this.onDelete,
    required this.onTopUp,
  });

  final SavingsGoal goal;
  final String currency;
  final NumberFormat fmt;
  final String? eta;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = goal.isCompleted
        ? const Color(0xFF10B981)
        : scheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(goal.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              tooltip: 'Пополнить',
              onPressed: onTopUp,
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
            ),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 8,
              color: color,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${fmt.format(goal.currentAmount)} / ${fmt.format(goal.targetAmount)} ${goal.currency} · '
            '${(goal.progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 12),
          ),
          if (goal.deadline != null)
            Text(
                'Дедлайн: ${DateFormat.yMMMd('ru_RU').format(DateTime.parse(goal.deadline!))}',
                style: Theme.of(context).textTheme.bodySmall),
          if (eta != null) ...[
            const SizedBox(height: 2),
            Text(eta!,
                style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.9))),
          ],
        ],
      ),
    );
  }
}

class _SavingsGoalSheet extends StatefulWidget {
  const _SavingsGoalSheet({required this.currency, this.initial});
  final String currency;
  final SavingsGoal? initial;

  @override
  State<_SavingsGoalSheet> createState() => _SavingsGoalSheetState();
}

class _SavingsGoalSheetState extends State<_SavingsGoalSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.initial?.title ?? '');
  late final TextEditingController _target = TextEditingController(
      text: widget.initial == null
          ? ''
          : widget.initial!.targetAmount.toString());
  late final TextEditingController _current = TextEditingController(
      text: widget.initial == null
          ? '0'
          : widget.initial!.currentAmount.toString());
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    final raw = widget.initial?.deadline;
    if (raw != null && raw.isNotEmpty) {
      _deadline = DateTime.tryParse(raw);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    _current.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    final target =
        double.tryParse(_target.text.trim().replaceAll(',', '.')) ?? 0;
    final current =
        double.tryParse(_current.text.trim().replaceAll(',', '.')) ?? 0;
    if (title.isEmpty || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Заполни название и сумму цели')));
      return;
    }
    final now = DateTime.now().toIso8601String();
    Navigator.of(context).pop(
      widget.initial == null
          ? SavingsGoal(
              id: const Uuid().v4(),
              title: title,
              targetAmount: target,
              currentAmount: current,
              currency: widget.currency,
              createdAt: now,
              deadline: _deadline?.toIso8601String().substring(0, 10),
            )
          : widget.initial!.copyWith(
              title: title,
              targetAmount: target,
              currentAmount: current,
              deadline: _deadline?.toIso8601String().substring(0, 10),
            ),
    );
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
            Text(widget.initial == null ? 'Новая цель' : 'Изменить цель',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: 'Название (Отпуск, Машина, …)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _target,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  InputDecoration(labelText: 'Сумма цели (${widget.currency})'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _current,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: 'Уже отложено (${widget.currency})'),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.event_outlined),
              title: Text(_deadline == null
                  ? 'Дедлайн (опционально)'
                  : 'К ${DateFormat.yMMMd('ru_RU').format(_deadline!)}'),
              trailing: _deadline == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _deadline = null),
                    ),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _deadline ?? now,
                  firstDate: now,
                  lastDate: DateTime(now.year + 10),
                );
                if (picked != null) setState(() => _deadline = picked);
              },
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
