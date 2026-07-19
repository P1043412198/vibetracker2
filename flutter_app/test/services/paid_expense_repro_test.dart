import 'package:flutter_test/flutter_test.dart';

import 'package:vibesight_tracker/models/budget_planner.dart';
import 'package:vibesight_tracker/models/enums.dart';
import 'package:vibesight_tracker/models/finance.dart';
import 'package:vibesight_tracker/services/budget_planner_calc.dart';

void main() {
  final today = DateTime(2026, 6, 28);
  final sources = [
    IncomeSource(
      id: 'adv',
      name: 'Аванс',
      type: IncomeSourceType.advance,
      amount: 500,
      currency: 'BYN',
      dayOfMonth: 30,
      adjustForHolidays: false,
      isActive: true,
      createdAt: '2025-01-01',
    ),
  ];
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

  PlannedExpense kvartira({required bool isPaid}) => PlannedExpense(
        id: 'kvartira',
        name: 'Квартира',
        amount: 1000,
        currency: 'BYN',
        dayFrom: 20,
        dayTo: 29,
        isPaid: isPaid,
        isActive: true,
        createdAt: '2025-01-01',
      );

  test('UNPAID rent due 20-29 counts as obligation in current cycle', () {
    final f = computeCashflowForecast(
      accounts: accounts,
      transactions: const [],
      incomeSources: sources,
      plannedExpenses: [kvartira(isPaid: false)],
      reserve: 0,
      today: today,
      rangeMode: CashflowRangeMode.next,
    );
    expect(f.range?.totalObligations, closeTo(1000, 1e-6));
  });

  test('PAID rent must NOT count as obligation', () {
    final f = computeCashflowForecast(
      accounts: accounts,
      transactions: const [],
      incomeSources: sources,
      plannedExpenses: [kvartira(isPaid: true)],
      reserve: 0,
      today: today,
      rangeMode: CashflowRangeMode.next,
    );
    expect(f.range?.totalObligations, closeTo(0, 1e-6));
  });

  test('matching transaction auto-clears the current-month obligation', () {
    final tx = Transaction(
      id: 't1',
      type: TransactionType.expense,
      amount: 1000,
      category: 'Жильё',
      date: '2026-06-22',
      accountId: 'card',
    );
    final f = computeCashflowForecast(
      accounts: accounts,
      transactions: [tx],
      incomeSources: sources,
      plannedExpenses: [
        PlannedExpense(
          id: 'kvartira',
          name: 'Квартира',
          amount: 1000,
          currency: 'BYN',
          dayFrom: 20,
          dayTo: 29,
          category: 'Жильё',
          isPaid: false,
          isActive: true,
          createdAt: '2025-01-01',
        ),
      ],
      reserve: 0,
      today: today,
      rangeMode: CashflowRangeMode.next,
    );
    expect(f.range?.totalObligations, closeTo(0, 1e-6));
  });

  test('one-time July expense does NOT count in a 28 Jun–1 Jul window', () {
    // Rent is a one-time July payment; viewing it today (28 June) must not
    // create a June obligation.
    final julyRent = PlannedExpense(
      id: 'kvartira',
      name: 'Квартира',
      amount: 1000,
      currency: 'BYN',
      dayFrom: 20,
      dayTo: 29,
      recurrence: ExpenseRecurrence.once,
      startMonth: '2026-07',
      isPaid: false,
      isActive: true,
      createdAt: '2025-01-01',
    );
    final f = computeCashflowForecast(
      accounts: accounts,
      transactions: const [],
      incomeSources: sources,
      plannedExpenses: [julyRent],
      reserve: 0,
      today: today,
      rangeMode: CashflowRangeMode.custom,
      customStart: DateTime(2026, 6, 28),
      customEnd: DateTime(2026, 7, 1),
    );
    expect(f.range?.totalObligations, closeTo(0, 1e-6));
  });

  test('monthly expense with startMonth July is suppressed in June', () {
    final fromJuly = PlannedExpense(
      id: 'kvartira',
      name: 'Квартира',
      amount: 1000,
      currency: 'BYN',
      dayFrom: 20,
      dayTo: 29,
      startMonth: '2026-07',
      isPaid: false,
      isActive: true,
      createdAt: '2025-01-01',
    );
    final june = computeCashflowForecast(
      accounts: accounts,
      transactions: const [],
      incomeSources: sources,
      plannedExpenses: [fromJuly],
      reserve: 0,
      today: today,
      rangeMode: CashflowRangeMode.custom,
      customStart: DateTime(2026, 6, 28),
      customEnd: DateTime(2026, 7, 1),
    );
    expect(june.range?.totalObligations, closeTo(0, 1e-6));

    final plannedExpenseAppliesJuly =
        plannedExpenseAppliesToMonth(fromJuly, '2026-07', '2026-06');
    final plannedExpenseAppliesJune =
        plannedExpenseAppliesToMonth(fromJuly, '2026-06', '2026-06');
    expect(plannedExpenseAppliesJuly, isTrue);
    expect(plannedExpenseAppliesJune, isFalse);
  });
}
