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
}
