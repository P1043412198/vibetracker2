import 'package:flutter_test/flutter_test.dart';
import 'package:vibesight_tracker/models/enums.dart';
import 'package:vibesight_tracker/models/finance.dart';
import 'package:vibesight_tracker/services/net_worth.dart';

num identityConvert(num a, String from, String to) => a;

Account account({String id = 'a1', num initial = 0, String currency = 'BYN'}) =>
    Account(
      id: id,
      name: 'Счёт',
      type: AccountType.cash,
      currency: currency,
      initialBalance: initial,
      color: '#fff',
      createdAt: '2026-01-01',
    );

Transaction tx({
  required String id,
  required TransactionType type,
  required num amount,
  required String date,
  String accountId = 'a1',
}) =>
    Transaction(
      id: id,
      type: type,
      amount: amount,
      category: 'x',
      date: date,
      accountId: accountId,
    );

void main() {
  group('computeNetWorthTrend', () {
    test('null for empty', () {
      expect(computeNetWorthTrend([]), isNull);
    });

    test('up trend with averaged rate', () {
      final t = computeNetWorthTrend([100, 200, 400])!;
      expect(t.current, 400);
      expect(t.change, 300);
      expect(t.monthlyRate, 150);
      expect(t.direction, TrendDirection.up);
    });

    test('down trend', () {
      final t = computeNetWorthTrend([500, 100])!;
      expect(t.change, -400);
      expect(t.direction, TrendDirection.down);
    });

    test('flat within epsilon', () {
      final t = computeNetWorthTrend([1000, 1000.2])!;
      expect(t.direction, TrendDirection.flat);
    });
  });

  group('computeNetWorthHistory', () {
    test('reconstructs assets as of each month-end', () {
      final accounts = [account(initial: 0)];
      final txs = [
        tx(id: 't1', type: TransactionType.income, amount: 100, date: '2026-04-15'),
        tx(id: 't2', type: TransactionType.income, amount: 50, date: '2026-06-10'),
        tx(id: 't3', type: TransactionType.expense, amount: 30, date: '2026-06-20'),
      ];
      final history = computeNetWorthHistory(
        accounts: accounts,
        transactions: txs,
        loans: const [],
        loanPayments: const [],
        baseCurrency: 'BYN',
        convert: identityConvert,
        now: DateTime(2026, 6, 26),
        months: 3,
      );
      expect(history.map((p) => p.monthKey).toList(),
          ['2026-04', '2026-05', '2026-06']);
      expect(history[0].assets, 100); // April: only t1
      expect(history[1].assets, 100); // May: unchanged
      expect(history[2].assets, 120); // June: +50 -30
      expect(history[2].netWorth, 120);
    });

    test('subtracts outstanding loan principal as debts', () {
      final loans = [
        Loan(
          id: 'l1',
          title: 'Авто',
          principal: 1000,
          balance: 1000,
          annualRate: 10,
          monthlyPayment: 100,
          startDate: '2026-01-01',
          currency: 'BYN',
        ),
      ];
      final payments = [
        LoanPayment(id: 'p1', loanId: 'l1', date: '2026-05-10', amount: 300),
      ];
      final history = computeNetWorthHistory(
        accounts: const [],
        transactions: const [],
        loans: loans,
        loanPayments: payments,
        baseCurrency: 'BYN',
        convert: identityConvert,
        now: DateTime(2026, 6, 26),
        months: 3,
      );
      expect(history[0].debts, 1000); // April: nothing paid
      expect(history[2].debts, 700); // June: 300 paid
      expect(history[2].netWorth, -700);
    });
  });
}
