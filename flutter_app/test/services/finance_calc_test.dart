import 'package:flutter_test/flutter_test.dart';

import 'package:vibesight_tracker/models/finance.dart';
import 'package:vibesight_tracker/services/finance_calc.dart';

/// Phase 18 — verify the per-day / per-week free-funds breakdown matches
/// the user's mental model:
/// "salary on the 16th + advance on the 30th, rent 1000 on the 1st,
///  utilities on the 16th — what's free per day and per week?"
void main() {
  /// Builds a plan that mirrors the example from the user feedback:
  /// month = 2025-05 (31 days), planned income 2300 (1500 on the 16th
  /// + 800 on the 30th), rent 1000 on the 1st, utilities 200 on the 16th.
  MonthlyBudgetPlan samplePlan({num? plannedIncome}) {
    return MonthlyBudgetPlan(
      id: 'p1',
      monthKey: '2025-05',
      plannedIncome: plannedIncome ?? 2300,
      categoryPlans: [],
      incomes: [
        IncomeEntry(id: 'i1', name: 'Зарплата', amount: 1500, day: 16),
        IncomeEntry(id: 'i2', name: 'Аванс', amount: 800, day: 30),
      ],
      scheduledExpenses: [
        ScheduledExpense(id: 'r', name: 'Аренда', amount: 1000, day: 1),
        ScheduledExpense(id: 'jkh', name: 'ЖКХ', amount: 200, day: 16),
      ],
      createdAt: '2025-05-01',
      updatedAt: '2025-05-01',
    );
  }

  num identity(num amount, String from, String to) => amount;

  group('buildCashflow', () {
    test('running balance reflects scheduled income/expense by day', () {
      final cf = buildCashflow(
        month: DateTime(2025, 5, 1),
        plan: samplePlan(),
        planCurrency: 'BYN',
        convert: identity,
      );

      expect(cf.timeline.length, 31);
      // Day 1: -1000 (rent), running = -1000.
      expect(cf.timeline[0].balance, -1000);
      // Days 2..15: no events, balance stays at -1000.
      expect(cf.timeline[14].balance, -1000);
      // Day 16: +1500 income, -200 utilities → net +1300, running 300.
      expect(cf.timeline[15].balance, 300);
      // Days 17..29: balance stays at 300.
      expect(cf.timeline[28].balance, 300);
      // Day 30: +800 advance, running 1100.
      expect(cf.timeline[29].balance, 1100);
      // Day 31: no change.
      expect(cf.timeline[30].balance, 1100);
    });

    test('carryIn shifts the entire running balance', () {
      final cf = buildCashflow(
        month: DateTime(2025, 5, 1),
        plan: samplePlan(),
        planCurrency: 'BYN',
        convert: identity,
        carryIn: 500,
      );
      expect(cf.timeline[0].balance, -500); // -1000 + 500 carryIn
      expect(cf.timeline[15].balance, 800); // 300 + 500
      expect(cf.timeline[30].balance, 1600); // 1100 + 500
    });
  });

  group('buildFreeFundsBreakdown', () {
    test('per-week aggregates: income/expense in each Mon-Sun stretch', () {
      final cf = buildCashflow(
        month: DateTime(2025, 5, 1),
        plan: samplePlan(),
        planCurrency: 'BYN',
        convert: identity,
      );
      final br = buildFreeFundsBreakdown(
        cashflow: cf,
        month: DateTime(2025, 5, 1),
        today: DateTime(2025, 5, 20),
      );

      // Mon-Sun weeks of May 2025:
      // Week 1: 1 May (Thu) → 4 May (Sun)
      expect(br.weeks[0].startDay, 1);
      expect(br.weeks[0].endDay, 4);
      // Rent 1000 lands in week 1; no income.
      expect(br.weeks[0].income, 0);
      expect(br.weeks[0].expense, 1000);

      // Week 3: 12–18 May contains the salary (16th) and utilities (16th).
      final w3 = br.weeks.firstWhere((w) => w.startDay == 12);
      expect(w3.endDay, 18);
      expect(w3.income, 1500);
      expect(w3.expense, 200);

      // Week 5: 26 May → 31 May contains the advance on the 30th.
      final w5 = br.weeks.firstWhere((w) => w.startDay == 26);
      expect(w5.endDay, 31);
      expect(w5.income, 800);
      expect(w5.expense, 0);
    });

    test('weekly free funds = max(0, endBalance − upcomingCommits) and is '
        'never larger than the actual end-balance pool', () {
      final cf = buildCashflow(
        month: DateTime(2025, 5, 1),
        plan: samplePlan(),
        planCurrency: 'BYN',
        convert: identity,
      );
      final br = buildFreeFundsBreakdown(
        cashflow: cf,
        month: DateTime(2025, 5, 1),
        today: DateTime(2025, 5, 20),
      );

      // Week 5 (May 26-31): endBalance = 1100 (after advance on the 30th)
      // and no expenses are scheduled after the 31st → free pool = 1100.
      // Critical regression guard: weeklyFree must NOT spike to ~7700 by
      // multiplying day-31's dailyAllowance (= 1100, daysAhead=1) by 7.
      final w5 = br.weeks.firstWhere((w) => w.startDay == 26);
      expect(w5.endBalance, 1100);
      expect(w5.weeklyFree, 1100);
      expect(w5.dailyAllowance, closeTo(1100 / 6, 0.01));

      // Week 4 (May 19-25): endBalance = 300 (no events between 17 and
      // 30). No expenses scheduled before next income on day 30 → pool
      // = 300, dailyAllowance = 300 / 7 ≈ 42.86.
      final w4 = br.weeks.firstWhere((w) => w.startDay == 19);
      expect(w4.endBalance, 300);
      expect(w4.weeklyFree, 300);
      expect(w4.dailyAllowance, closeTo(300 / 7, 0.01));

      // Week 1 (May 1-4): end balance = -1000 (after rent).
      // No income comes until day 16 → available is negative → pool = 0.
      final w1 = br.weeks[0];
      expect(w1.endBalance, -1000);
      expect(w1.dailyAllowance, 0); // negative balance ⇒ no allowance
      expect(w1.weeklyFree, 0);

      // Sanity: total weeklyFree across all weeks should never exceed
      // the maximum running balance reached during the month — i.e. the
      // chart Y-axis cannot blow up to many times the actual budget.
      final maxBalance = cf.timeline
          .map((d) => d.balance)
          .fold<num>(0, (a, b) => b > a ? b : a);
      for (final w in br.weeks) {
        expect(w.weeklyFree, lessThanOrEqualTo(maxBalance),
            reason: 'week ${w.index} weeklyFree=${w.weeklyFree} exceeds '
                'peak running balance $maxBalance');
      }
    });

    test('per-day allowance is non-negative and decreases towards next pay',
        () {
      final cf = buildCashflow(
        month: DateTime(2025, 5, 1),
        plan: samplePlan(),
        planCurrency: 'BYN',
        convert: identity,
      );
      // Anchor today = 20 May → current Mon-Sun is 19..25 May.
      final br = buildFreeFundsBreakdown(
        cashflow: cf,
        month: DateTime(2025, 5, 1),
        today: DateTime(2025, 5, 20),
      );

      // After payday on 16th, balance = 300 BYN. Next income = 30 May.
      // For day 19 (Mon), upcoming commits between 20..29 = 0 → available
      // = 300 BYN spread over 11 days (20..30). Should be ≈ 27.27.
      final mon = br.days.firstWhere((d) => d.date.day == 19);
      expect(mon.endBalance, 300);
      expect(mon.allowance, greaterThan(20));
      expect(mon.allowance, lessThan(40));

      // For day 25 (Sun), available = 300 BYN spread over 5 days (26..30).
      // Should be ≈ 60.
      final sun = br.days.firstWhere((d) => d.date.day == 25);
      expect(sun.allowance, greaterThan(50));
      expect(sun.allowance, lessThan(70));
    });

    test('endBalance grows monotonically across days where there are no '
        'expenses, so the per-day display is a true running balance', () {
      final cf = buildCashflow(
        month: DateTime(2025, 5, 1),
        plan: samplePlan(),
        planCurrency: 'BYN',
        convert: identity,
      );
      // Ensure timeline is monotonically increasing across the gap 17..29.
      for (var d = 17; d <= 29; d++) {
        expect(cf.timeline[d - 1].balance, cf.timeline[d - 2].balance,
            reason: 'no expense between days 17 and 29 → balance flat');
      }
    });
  });

  group('computeFreeFunds + carryIn', () {
    test('carryIn from the previous month boosts the income reference', () {
      final r = computeFreeFunds(
        plannedIncome: 1000,
        actualIncome: 0,
        actualExpense: 0,
        plannedExpense: 0,
        carryIn: 500,
      );
      expect(r.incomeRef, 1500);
      expect(r.free, 1500);
    });

    test('zero carryIn behaves the same as before (regression)', () {
      final r = computeFreeFunds(
        plannedIncome: 1000,
        actualIncome: 0,
        actualExpense: 0,
        plannedExpense: 200,
      );
      expect(r.incomeRef, 1000);
      expect(r.free, 800);
    });
  });

  group('computeMonthLeftoverFree', () {
    test('returns positive leftover when plan exceeds spending', () {
      final plan = MonthlyBudgetPlan(
        id: 'p',
        monthKey: '2025-04',
        plannedIncome: 1500,
        categoryPlans: [
          CategoryPlan(category: 'food', planned: 500),
        ],
        createdAt: '',
        updatedAt: '',
      );
      final facts = MonthFacts(
        income: 1500,
        expense: 300,
        expenseByCategory: const {'food': 300},
        monthTransactions: const [],
      );
      final leftover = computeMonthLeftoverFree(
        plan: plan,
        facts: facts,
        loansMonthlyPayments: 0,
      );
      // committed = max(plannedFood 500, actualFood 300) = 500 → free = 1000
      expect(leftover, 1000);
    });

    test('clamps overspend to zero (no negative carry)', () {
      final plan = MonthlyBudgetPlan(
        id: 'p',
        monthKey: '2025-04',
        plannedIncome: 1000,
        categoryPlans: [
          CategoryPlan(category: 'food', planned: 500),
        ],
        createdAt: '',
        updatedAt: '',
      );
      final facts = MonthFacts(
        income: 1000,
        expense: 1500,
        expenseByCategory: const {'food': 1500},
        monthTransactions: const [],
      );
      final leftover = computeMonthLeftoverFree(
        plan: plan,
        facts: facts,
        loansMonthlyPayments: 0,
      );
      expect(leftover, 0);
    });
  });
}
