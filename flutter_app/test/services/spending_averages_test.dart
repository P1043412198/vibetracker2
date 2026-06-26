import 'package:flutter_test/flutter_test.dart';

import 'package:vibesight_tracker/models/budget_planner.dart';
import 'package:vibesight_tracker/models/enums.dart';
import 'package:vibesight_tracker/models/finance.dart';
import 'package:vibesight_tracker/services/budget_planner_calc.dart';

/// Dart mirror of `src/lib/finance/__tests__/spendingAverages.test.ts`.
void main() {
  Account account({
    required String id,
    double initialBalance = 0,
    String currency = 'BYN',
  }) {
    return Account(
      id: id,
      name: id,
      type: AccountType.card,
      currency: currency,
      initialBalance: initialBalance,
      color: '#000',
      createdAt: '2025-01-01',
    );
  }

  Transaction tx({
    required TransactionType type,
    required num amount,
    required String date,
    String accountId = 'card',
    String? toAccountId,
  }) {
    return Transaction(
      id: '$type-$date-$amount',
      type: type,
      amount: amount,
      category: 'misc',
      date: date,
      accountId: accountId,
      toAccountId: toAccountId,
    );
  }

  IncomeSource income({
    required IncomeSourceType type,
    required double amount,
    String? name,
    int? dayOfMonth,
  }) {
    return IncomeSource(
      id: '$type-1',
      name: name ?? type.name,
      type: type,
      amount: amount,
      currency: 'BYN',
      dayOfMonth: dayOfMonth,
      adjustForHolidays: false,
      isActive: true,
      createdAt: '2025-01-01',
    );
  }

  final today = DateTime(2026, 6, 26);
  final accounts = [account(id: 'card')];

  group('computeSpendingAverages', () {
    test('returns empty when there are no income/expense transactions', () {
      final a = computeSpendingAverages(
        accounts: accounts,
        transactions: const [],
        today: today,
      );
      expect(a.monthsCounted, 0);
      expect(a.avgDailyExpense, 0);
      expect(a.months, isEmpty);
    });

    test('averages each month over its days; current over elapsed days', () {
      final txs = [
        tx(type: TransactionType.expense, amount: 310, date: '2026-05-10'),
        tx(type: TransactionType.expense, amount: 130, date: '2026-06-05'),
        tx(type: TransactionType.expense, amount: 130, date: '2026-06-20'),
        tx(type: TransactionType.income, amount: 1300, date: '2026-06-01'),
      ];
      final a = computeSpendingAverages(
        accounts: accounts,
        transactions: txs,
        today: today,
      );
      expect(a.monthsCounted, 2);
      final may = a.months.firstWhere((m) => m.monthKey == '2026-05');
      final jun = a.months.firstWhere((m) => m.monthKey == '2026-06');
      expect(may.days, 31);
      expect(may.avgDailyExpense, closeTo(10, 1e-6));
      expect(jun.days, 26);
      expect(jun.avgDailyExpense, closeTo(10, 1e-6));
      expect(a.avgDailyExpense, closeTo(10, 1e-6));
      expect(a.avgDailyIncome, closeTo(1300 / 57, 1e-6));
      expect(a.avgMonthlyExpense, closeTo(285, 1e-6));
    });

    test('respects the account filter and ignores transfers', () {
      final twoAccounts = [account(id: 'card'), account(id: 'cash')];
      final txs = [
        tx(type: TransactionType.expense, amount: 100, date: '2026-06-10', accountId: 'card'),
        tx(type: TransactionType.expense, amount: 999, date: '2026-06-10', accountId: 'cash'),
        tx(type: TransactionType.transfer, amount: 50, date: '2026-06-11', accountId: 'card', toAccountId: 'cash'),
      ];
      final a = computeSpendingAverages(
        accounts: twoAccounts,
        transactions: txs,
        today: today,
        accountIds: const ['card'],
      );
      final jun = a.months.firstWhere((m) => m.monthKey == '2026-06');
      expect(jun.totalExpense, closeTo(100, 1e-6));
    });
  });

  group('computeScenarioProjection', () {
    final sources = [
      income(type: IncomeSourceType.advance, name: 'Аванс', amount: 500, dayOfMonth: 30),
      income(type: IncomeSourceType.salary, name: 'Зарплата', amount: 1200, dayOfMonth: 15),
    ];
    final balance360 = [account(id: 'card', initialBalance: 360)];
    final forecast = computeCashflowForecast(
      accounts: balance360,
      transactions: const [],
      incomeSources: sources,
      plannedExpenses: const [],
      reserve: 0,
      today: today,
      rangeMode: CashflowRangeMode.next,
    );

    test('planToZero mirrors the smoothed safe daily spend', () {
      final p = computeScenarioProjection(
        scenario: SafeToSpendScenario.planToZero,
        forecast: forecast,
      )!;
      expect(p.dailySpend, closeTo(90, 1e-6));
      expect(p.endBalance, closeTo(0, 1e-6));
      expect(p.shortfall, isFalse);
    });

    test('customDaily projects the ending balance and flags a deficit', () {
      final p = computeScenarioProjection(
        scenario: SafeToSpendScenario.customDaily,
        forecast: forecast,
        customDaily: 120,
      )!;
      expect(p.endBalance, closeTo(-120, 1e-6));
      expect(p.surplusOverReserve, closeTo(-120, 1e-6));
      expect(p.shortfall, isTrue);
    });

    test('avgExpense uses history and does NOT subtract obligations twice', () {
      final averages = SpendingAverages(
        months: const [],
        avgDailyExpense: 50,
        avgDailyIncome: 0,
        avgMonthlyExpense: 1500,
        avgMonthlyIncome: 0,
        monthsCounted: 2,
      );
      final p = computeScenarioProjection(
        scenario: SafeToSpendScenario.avgExpense,
        forecast: forecast,
        averages: averages,
      )!;
      expect(p.dailySpend, closeTo(50, 1e-6));
      expect(p.obligations, 0);
      expect(p.endBalance, closeTo(360 - 50 * 4, 1e-6));
      expect(p.insufficientHistory, isFalse);
    });

    test('flags insufficient history for average scenarios with no data', () {
      final p = computeScenarioProjection(
        scenario: SafeToSpendScenario.avgExpenseIncome,
        forecast: forecast,
      )!;
      expect(p.insufficientHistory, isTrue);
    });
  });
}
