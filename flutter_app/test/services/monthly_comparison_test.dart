import 'package:flutter_test/flutter_test.dart';

import 'package:vibesight_tracker/models/enums.dart';
import 'package:vibesight_tracker/models/finance.dart';
import 'package:vibesight_tracker/services/budget_planner_calc.dart';

/// Dart mirror of `src/lib/finance/__tests__/monthlyComparison.test.ts`.
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
    String category = 'misc',
    String accountId = 'card',
  }) {
    return Transaction(
      id: '$type-$date-$amount-$category',
      type: type,
      amount: amount,
      category: category,
      date: date,
      accountId: accountId,
    );
  }

  final accounts = [account(id: 'card')];

  num conv(num amount, String from, String to) {
    if (from == to) return amount;
    const rates = {'USD': 3.0, 'BYN': 1.0};
    final fromRate = rates[from];
    final toRate = rates[to];
    if (fromRate == null || toRate == null) return amount;
    return amount * fromRate / toRate;
  }

  group('computeMonthlyComparison', () {
    test('returns zeroed sides when there are no transactions', () {
      final c = computeMonthlyComparison(
        accounts: accounts,
        transactions: const [],
        monthKeyA: '2026-05',
        monthKeyB: '2026-06',
      );
      expect(c.a.totalExpense, 0);
      expect(c.b.totalExpense, 0);
      expect(c.expenseDelta, 0);
      expect(c.categories, isEmpty);
      expect(c.a.month, 5); // May = 5 (1-based)
      expect(c.b.month, 6);
    });

    test('sums income/expense per month and computes b − a deltas', () {
      final txs = [
        tx(type: TransactionType.expense, amount: 100, date: '2026-05-10', category: 'food'),
        tx(type: TransactionType.expense, amount: 50, date: '2026-05-15', category: 'fun'),
        tx(type: TransactionType.income, amount: 1000, date: '2026-05-01'),
        tx(type: TransactionType.expense, amount: 180, date: '2026-06-10', category: 'food'),
        tx(type: TransactionType.income, amount: 1200, date: '2026-06-01'),
        // outside both months → ignored
        tx(type: TransactionType.expense, amount: 999, date: '2026-04-10', category: 'food'),
      ];
      final c = computeMonthlyComparison(
        accounts: accounts,
        transactions: txs,
        monthKeyA: '2026-05',
        monthKeyB: '2026-06',
      );
      expect(c.a.totalExpense, 150);
      expect(c.a.totalIncome, 1000);
      expect(c.a.net, 850);
      expect(c.b.totalExpense, 180);
      expect(c.b.totalIncome, 1200);
      expect(c.b.net, 1020);

      expect(c.expenseDelta, 30);
      expect(c.incomeDelta, 200);
      expect(c.netDelta, 170);

      expect(c.categories[0].category, 'food');
      expect(c.categories[0].delta, 80);
      expect(c.categories[1].category, 'fun');
      expect(c.categories[1].delta, -50);
    });

    test('ignores transfers and respects the accountIds filter', () {
      final accts = [
        account(id: 'card'),
        account(id: 'cash'),
      ];
      final txs = [
        tx(type: TransactionType.transfer, amount: 500, date: '2026-06-10', accountId: 'card'),
        tx(type: TransactionType.expense, amount: 70, date: '2026-06-10', category: 'food', accountId: 'card'),
        tx(type: TransactionType.expense, amount: 90, date: '2026-06-11', category: 'food', accountId: 'cash'),
      ];
      final c = computeMonthlyComparison(
        accounts: accts,
        transactions: txs,
        monthKeyA: '2026-05',
        monthKeyB: '2026-06',
        accountIds: const ['card'],
      );
      expect(c.b.totalExpense, 70);
      expect(c.b.byCategory['food'], 70);
    });

    test('converts foreign-currency amounts into the base currency', () {
      final accts = [account(id: 'usd', currency: 'USD')];
      final txs = [
        tx(type: TransactionType.expense, amount: 100, date: '2026-06-10', category: 'food', accountId: 'usd'),
      ];
      final c = computeMonthlyComparison(
        accounts: accts,
        transactions: txs,
        convert: conv,
        baseCurrency: 'BYN',
        monthKeyA: '2026-05',
        monthKeyB: '2026-06',
      );
      expect(c.b.totalExpense, 300);
    });
  });
}
