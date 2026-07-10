import 'package:flutter_test/flutter_test.dart';

import 'package:vibesight_tracker/models/budget_planner.dart';
import 'package:vibesight_tracker/models/enums.dart';
import 'package:vibesight_tracker/models/finance.dart';
import 'package:vibesight_tracker/services/budget_planner_calc.dart';

/// Dart mirror of `src/lib/finance/__tests__/cashflowForecast.test.ts`.
///
/// User scenario: today 26 June 2026, 360 ₽ on hand, advance +500 on the 30th,
/// salary +1200 on the 15th of July.
void main() {
  IncomeSource income({
    required IncomeSourceType type,
    required double amount,
    String? name,
    String currency = 'BYN',
    int? dayOfMonth,
  }) {
    return IncomeSource(
      id: '$type-1',
      name: name ?? type.name,
      type: type,
      amount: amount,
      currency: currency,
      dayOfMonth: dayOfMonth,
      // Keep dates deterministic (no weekend/holiday shifting).
      adjustForHolidays: false,
      isActive: true,
      createdAt: '2025-01-01',
    );
  }

  Account account({
    required String id,
    required double initialBalance,
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

  PlannedExpense expense({
    required String name,
    required double amount,
    required int dayTo,
    String currency = 'BYN',
  }) {
    return PlannedExpense(
      id: name,
      name: name,
      amount: amount,
      currency: currency,
      dayFrom: dayTo,
      dayTo: dayTo,
      isPaid: false,
      isActive: true,
      createdAt: '2025-01-01',
    );
  }

  final today = DateTime(2026, 6, 26);
  final baseSources = [
    income(type: IncomeSourceType.advance, name: 'Аванс', amount: 500, dayOfMonth: 30),
    income(type: IncomeSourceType.salary, name: 'Зарплата', amount: 1200, dayOfMonth: 15),
  ];
  final balance360 = [account(id: 'card', initialBalance: 360)];

  group('computeCashflowForecast — user scenario', () {
    test('gives 90 ₽/day until the advance (4 days), reserve 0', () {
      final f = computeCashflowForecast(
        accounts: balance360,
        transactions: const [],
        incomeSources: baseSources,
        plannedExpenses: const [],
        reserve: 0,
        today: today,
      );

      expect(f.ok, isTrue);
      expect(f.currentBalance, closeTo(360, 1e-6));
      expect(f.nextIncome?.name, 'Аванс');
      expect(f.nextIncome?.daysUntil, 4);
      expect(f.dailyUntilNextIncome, closeTo(90, 1e-6));
      expect(f.hasCashGap, isFalse);

      // Two windows: today→advance, advance→salary.
      expect(f.segments.length, 2);
      expect(f.segments[0].days, 4);
      expect(f.segments[0].dailyLimit, closeTo(90, 1e-6));
      expect(f.segments[1].incomeAtEnd, closeTo(1200, 1e-6));
    });

    test('lowers the daily limit to 65 ₽/day when keeping a 100 ₽ reserve', () {
      final f = computeCashflowForecast(
        accounts: balance360,
        transactions: const [],
        incomeSources: baseSources,
        plannedExpenses: const [],
        reserve: 100,
        today: today,
      );

      expect(f.reserve, 100);
      expect(f.dailyUntilNextIncome, closeTo(65, 1e-6)); // (360 − 100) / 4
      expect(f.hasCashGap, isFalse);
    });
  });

  group('computeCashflowForecast — obligations', () {
    test('reserves an affordable obligation without flagging a gap', () {
      final f = computeCashflowForecast(
        accounts: balance360,
        transactions: const [],
        incomeSources: baseSources,
        plannedExpenses: [expense(name: 'Подписка', amount: 60, dayTo: 27)],
        reserve: 0,
        today: today,
      );

      expect(f.segments[0].obligations, closeTo(60, 1e-6));
      expect(f.segments[0].dailyLimit, closeTo((360 - 60) / 4, 1e-6)); // 75/day
      expect(f.segments[0].shortfall, isFalse);
      expect(f.hasCashGap, isFalse);
    });

    test('flags a cash gap when an obligation exceeds the balance', () {
      final f = computeCashflowForecast(
        accounts: balance360,
        transactions: const [],
        incomeSources: baseSources,
        plannedExpenses: [expense(name: 'Кредит', amount: 500, dayTo: 27)],
        reserve: 0,
        today: today,
      );

      expect(f.segments[0].shortfall, isTrue);
      expect(f.segments[0].dailyLimit, 0);
      expect(f.hasCashGap, isTrue);
    });
  });

  group('computeCashflowForecast — edge cases', () {
    test('returns ok=false when there are no active income sources', () {
      final f = computeCashflowForecast(
        accounts: balance360,
        transactions: const [],
        incomeSources: const [],
        plannedExpenses: const [],
        today: today,
      );

      expect(f.ok, isFalse);
      expect(f.segments, isEmpty);
      expect(f.dailyUntilNextIncome, 0);
    });

    test('converts multi-currency balances into the base currency', () {
      // 1 USD = 3 BYN.
      const rates = {'BYN': 1.0, 'USD': 3.0};
      num convert(num amount, String from, String to) {
        if (from == to) return amount;
        return amount * (rates[from]! / rates[to]!);
      }

      final f = computeCashflowForecast(
        accounts: [
          account(id: 'byn', initialBalance: 360, currency: 'BYN'),
          account(id: 'usd', initialBalance: 50, currency: 'USD'),
        ],
        transactions: const [],
        incomeSources: baseSources,
        plannedExpenses: const [],
        convert: convert,
        baseCurrency: 'BYN',
        reserve: 0,
        today: today,
      );

      // 360 BYN + 50 USD × 3 = 510 BYN.
      expect(f.currentBalance, closeTo(510, 1e-6));
      expect(f.dailyUntilNextIncome, closeTo(510 / 4, 1e-6));
    });
  });

  group('computeCurrentBalance', () {
    test('applies income, expense and transfers per account', () {
      final accounts = [
        account(id: 'a', initialBalance: 1000, currency: 'BYN'),
        account(id: 'b', initialBalance: 0, currency: 'BYN'),
      ];
      final transactions = [
        Transaction(
            id: '1',
            type: TransactionType.income,
            amount: 200,
            category: 'x',
            date: '2026-06-01',
            accountId: 'a'),
        Transaction(
            id: '2',
            type: TransactionType.expense,
            amount: 50,
            category: 'x',
            date: '2026-06-02',
            accountId: 'a'),
        Transaction(
            id: '3',
            type: TransactionType.transfer,
            amount: 300,
            category: 'x',
            date: '2026-06-03',
            accountId: 'a',
            toAccountId: 'b'),
      ];

      // a: 1000 + 200 − 50 − 300 = 850; b: 0 + 300 = 300; total = 1150.
      final total = computeCurrentBalance(
        accounts: accounts,
        transactions: transactions,
        baseCurrency: 'BYN',
      );
      expect(total, closeTo(1150, 1e-6));
    });
  });

  group('PR review regressions', () {
    test('counts an unpaid obligation whose deadline is today', () {
      final todayJun28 = DateTime(2026, 6, 28);
      final advance30 = [
        income(type: IncomeSourceType.advance, name: 'Аванс', amount: 500, dayOfMonth: 30),
      ];
      final rentToday = PlannedExpense(
        id: 'rent',
        name: 'Квартира',
        amount: 1000,
        dayFrom: 28,
        dayTo: 28,
        category: 'Жильё',
        isPaid: false,
        isActive: true,
        createdAt: '2025-01-01',
      );
      final f = computeCashflowForecast(
        accounts: balance360,
        transactions: const [],
        incomeSources: advance30,
        plannedExpenses: [rentToday],
        baseCurrency: 'BYN',
        reserve: 0,
        today: todayJun28,
        rangeMode: CashflowRangeMode.next,
      );
      expect(f.range?.totalObligations, closeTo(1000, 1e-6));
    });

    test('keeps future monthly occurrences when isPaid clears only the current cycle', () {
      final todayJun26 = DateTime(2026, 6, 26);
      final salary5 = [
        income(type: IncomeSourceType.salary, name: 'Зарплата', amount: 2000, dayOfMonth: 5),
      ];
      final paidRent = PlannedExpense(
        id: 'rent',
        name: 'Квартира',
        amount: 1000,
        dayFrom: 10,
        dayTo: 10,
        category: 'Жильё',
        isPaid: true,
        isActive: true,
        createdAt: '2025-01-01',
      );
      final f = computeCashflowForecast(
        accounts: [account(id: 'card', initialBalance: 5000)],
        transactions: const [],
        incomeSources: salary5,
        plannedExpenses: [paidRent],
        baseCurrency: 'BYN',
        reserve: 0,
        today: todayJun26,
        rangeMode: CashflowRangeMode.salaryToSalary,
      );
      // June suppressed by isPaid; the July occurrence still counts.
      expect(f.range?.totalObligations, closeTo(1000, 1e-6));
    });

    test('coalesces two income sources on the same day into one boundary', () {
      final todayJun26 = DateTime(2026, 6, 26);
      final sameDay = [
        IncomeSource(
          id: 'salary-1',
          name: 'Зарплата',
          type: IncomeSourceType.salary,
          amount: 1000,
          currency: 'BYN',
          dayOfMonth: 30,
          adjustForHolidays: false,
          isActive: true,
          createdAt: '2025-01-01',
        ),
        IncomeSource(
          id: 'extra-1',
          name: 'Подработка',
          type: IncomeSourceType.additional,
          amount: 500,
          currency: 'BYN',
          dayOfMonth: 30,
          adjustForHolidays: false,
          isActive: true,
          createdAt: '2025-01-01',
        ),
      ];
      final f = computeCashflowForecast(
        accounts: [account(id: 'card', initialBalance: 400)],
        transactions: const [],
        incomeSources: sameDay,
        plannedExpenses: const [],
        baseCurrency: 'BYN',
        reserve: 0,
        today: todayJun26,
        rangeMode: CashflowRangeMode.next,
      );
      expect(f.segments.length, 1);
      expect(f.segments[0].days, 4);
      expect(f.segments[0].incomeAtEnd, closeTo(1500, 1e-6));
      expect(f.dailyUntilNextIncome, closeTo(100, 1e-6));
    });

    test('preserves transfer FX metadata when summing only selected accounts', () {
      const rates = {'BYN': 1.0, 'USD': 3.0};
      num convert(num amount, String from, String to) {
        if (from == to) return amount;
        return amount * (rates[from]! / rates[to]!);
      }

      final accounts = [
        account(id: 'usd', initialBalance: 100, currency: 'USD'),
        account(id: 'byn', initialBalance: 0, currency: 'BYN'),
      ];
      final transactions = [
        Transaction(
          id: 't',
          type: TransactionType.transfer,
          amount: 100,
          category: 'x',
          date: '2026-06-03',
          accountId: 'usd',
          toAccountId: 'byn',
        ),
      ];
      // Only the BYN account is summed; it received a 100 USD transfer → 300 BYN.
      final total = computeCurrentBalance(
        accounts: accounts,
        transactions: transactions,
        convert: convert,
        baseCurrency: 'BYN',
        includeAccountIds: const ['byn'],
      );
      expect(total, closeTo(300, 1e-6));
    });
  });
}
