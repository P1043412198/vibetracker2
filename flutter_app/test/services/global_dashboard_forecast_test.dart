import 'package:flutter_test/flutter_test.dart';

import 'package:vibesight_tracker/models/budget_planner.dart';
import 'package:vibesight_tracker/models/enums.dart';
import 'package:vibesight_tracker/models/finance.dart';
import 'package:vibesight_tracker/services/budget_planner_calc.dart';

/// Today is 28 June 2026. The dashboard must be *global* (month-agnostic): a
/// one-time July rent configured in the July tab must never appear in the
/// 28 Jun–1 Jul window, regardless of which month tab is selected.
void main() {
  final today = DateTime(2026, 6, 28);

  IncomeSource advance() => IncomeSource(
        id: 'adv',
        name: 'Аванс',
        type: IncomeSourceType.advance,
        amount: 500,
        currency: 'BYN',
        dayOfMonth: 30,
        adjustForHolidays: false,
        isActive: true,
        createdAt: '2025-01-01',
      );

  final accounts = [
    Account(
      id: 'card',
      name: 'card',
      type: AccountType.card,
      currency: 'BYN',
      initialBalance: 360,
      color: '#000',
      createdAt: '2025-01-01',
    ),
  ];

  PlannedExpense rent({
    ExpenseRecurrence recurrence = ExpenseRecurrence.monthly,
    String? startMonth,
  }) =>
      PlannedExpense(
        id: 'kvartira',
        name: 'Квартира',
        amount: 1000,
        currency: 'BYN',
        dayFrom: 20,
        dayTo: 29,
        recurrence: recurrence,
        startMonth: startMonth,
        isPaid: false,
        isActive: true,
        createdAt: '2025-01-01',
      );

  // June (current real month) has income but no rent; July has a one-time rent.
  BudgetPlanConfig june() => BudgetPlanConfig(
        monthKey: '2026-06',
        incomeSources: [advance()],
        plannedExpenses: const [],
        actualExpenses: const [],
      );
  BudgetPlanConfig july() => BudgetPlanConfig(
        monthKey: '2026-07',
        incomeSources: [advance()],
        plannedExpenses: [
          rent(recurrence: ExpenseRecurrence.once, startMonth: '2026-07'),
        ],
        actualExpenses: const [],
      );

  test('one-time July rent is NOT an obligation in the 28 Jun–1 Jul window',
      () {
    final f = computeGlobalCashflowForecast(
      months: [june(), july()],
      accounts: accounts,
      transactions: const [],
      today: today,
      rangeMode: CashflowRangeMode.custom,
      customStart: DateTime(2026, 6, 28),
      customEnd: DateTime(2026, 7, 1),
    );
    expect(f.range?.totalObligations, closeTo(0, 1e-6));
  });

  test('global forecast ignores which month tab is selected', () {
    // The store carries a selectedMonthKey, but the global forecast takes only
    // `months`, so selecting July changes nothing.
    final a = computeGlobalCashflowForecast(
      months: BudgetPlanStore(months: [june(), july()], selectedMonthKey: '2026-06').months,
      accounts: accounts,
      transactions: const [],
      today: today,
      rangeMode: CashflowRangeMode.custom,
      customStart: DateTime(2026, 6, 28),
      customEnd: DateTime(2026, 7, 1),
    );
    final b = computeGlobalCashflowForecast(
      months: BudgetPlanStore(months: [june(), july()], selectedMonthKey: '2026-07').months,
      accounts: accounts,
      transactions: const [],
      today: today,
      rangeMode: CashflowRangeMode.custom,
      customStart: DateTime(2026, 6, 28),
      customEnd: DateTime(2026, 7, 1),
    );
    expect(a.range?.totalObligations, closeTo(b.range?.totalObligations ?? -1, 1e-6));
    expect(a.range?.totalObligations, closeTo(0, 1e-6));
  });

  test('one-time July rent IS an obligation when the window reaches July', () {
    final f = computeGlobalCashflowForecast(
      months: [june(), july()],
      accounts: accounts,
      transactions: const [],
      today: today,
      rangeMode: CashflowRangeMode.custom,
      customStart: DateTime(2026, 6, 28),
      customEnd: DateTime(2026, 7, 31),
    );
    expect(f.range?.totalObligations, closeTo(1000, 1e-6));
  });

  test('monthly template item carries forward into an unconfigured month', () {
    // Only June is configured, with a monthly rent. August (unconfigured) must
    // still see the rent via the current-month template.
    final juneMonthly = BudgetPlanConfig(
      monthKey: '2026-06',
      incomeSources: [advance()],
      plannedExpenses: [rent()],
      actualExpenses: const [],
    );
    final f = computeGlobalCashflowForecast(
      months: [juneMonthly],
      accounts: accounts,
      transactions: const [],
      today: today,
      rangeMode: CashflowRangeMode.custom,
      customStart: DateTime(2026, 8, 1),
      customEnd: DateTime(2026, 8, 31),
    );
    expect(f.range?.totalObligations, closeTo(1000, 1e-6));
  });

  test('global budget cycles span months and exclude future once expenses', () {
    final cycles = computeGlobalBudgetCycles(
      months: [june(), july()],
      transactions: const [],
      accounts: accounts,
      today: today,
    );
    expect(cycles, isNotEmpty);
    // "До ближайшего дохода" (today → 30 Jun) must not include the July rent.
    final next = cycles.first;
    expect(next.totalPlannedExpenses, closeTo(0, 1e-6));
  });
}
