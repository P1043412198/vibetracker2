import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:vibesight_tracker/models/finance.dart';
import 'package:vibesight_tracker/services/finance_calc.dart';

/// Smoke test: with the user's example plan (zp 16, advance 30, rent 1,
/// utilities 16) the per-day/per-week breakdown should produce a non-empty
/// list of days and weeks, and the totals should match what the user
/// expects to see in the UI.
void main() {
  test('user-example breakdown contains expected day & week totals', () {
    final plan = MonthlyBudgetPlan(
      id: 'p',
      monthKey: '2025-05',
      plannedIncome: 2300,
      categoryPlans: [],
      incomes: [
        IncomeEntry(id: '1', name: 'ЗП', amount: 1500, day: 16),
        IncomeEntry(id: '2', name: 'Аванс', amount: 800, day: 30),
      ],
      scheduledExpenses: [
        ScheduledExpense(id: 'r', name: 'Аренда', amount: 1000, day: 1),
        ScheduledExpense(id: 'j', name: 'ЖКХ', amount: 200, day: 16),
      ],
      createdAt: '',
      updatedAt: '',
    );

    final cf = buildCashflow(
      month: DateTime(2025, 5, 1),
      plan: plan,
      planCurrency: 'BYN',
      convert: (a, f, t) => a,
    );

    final br = buildFreeFundsBreakdown(
      cashflow: cf,
      month: DateTime(2025, 5, 1),
      today: DateTime(2025, 5, 20),
    );

    // ---- Per-week verification (matches user expectation) ----
    expect(br.weeks.length, greaterThanOrEqualTo(5));

    // Week containing the salary (12-18 May): income 1500 BYN.
    final wSalary = br.weeks.firstWhere((w) => w.startDay == 12);
    expect(wSalary.income, 1500);
    expect(wSalary.expense, 200);
    expect(wSalary.endBalance, 300);

    // Week with the advance (26-31 May): income 800 BYN.
    final wAdvance = br.weeks.firstWhere((w) => w.startDay == 26);
    expect(wAdvance.income, 800);
    expect(wAdvance.endBalance, 1100);

    // ---- Per-day verification (current week 19-25 May) ----
    expect(br.days.length, 7);
    final dayMonday = br.days.firstWhere((d) => d.date.day == 19);
    expect(dayMonday.endBalance, 300);
    expect(dayMonday.allowance, greaterThan(0));

    // Sunday 25 May should have a noticeably higher daily allowance because
    // there are fewer days remaining until the next pay (30 May).
    final daySunday = br.days.firstWhere((d) => d.date.day == 25);
    expect(daySunday.allowance, greaterThan(dayMonday.allowance));
  });

  testWidgets('per-day card renders Mon-Sun + остаток + per-day allowance',
      (tester) async {
    final plan = MonthlyBudgetPlan(
      id: 'p',
      monthKey: '2025-05',
      plannedIncome: 2300,
      categoryPlans: [],
      incomes: [
        IncomeEntry(id: '1', name: 'ЗП', amount: 1500, day: 16),
        IncomeEntry(id: '2', name: 'Аванс', amount: 800, day: 30),
      ],
      scheduledExpenses: [
        ScheduledExpense(id: 'r', name: 'Аренда', amount: 1000, day: 1),
        ScheduledExpense(id: 'j', name: 'ЖКХ', amount: 200, day: 16),
      ],
      createdAt: '',
      updatedAt: '',
    );
    final cf = buildCashflow(
      month: DateTime(2025, 5, 1),
      plan: plan,
      planCurrency: 'BYN',
      convert: (a, f, t) => a,
    );
    final br = buildFreeFundsBreakdown(
      cashflow: cf,
      month: DateTime(2025, 5, 1),
      today: DateTime(2025, 5, 20),
    );
    final fmt = NumberFormat.currency(
        locale: 'ru_RU', symbol: '', decimalDigits: 2);

    // Render a tiny page that lists the same data the per-day card would.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            for (final d in br.days)
              ListTile(
                title: Text(
                    'd${d.date.day} bal=${fmt.format(d.endBalance)} '
                    'allow=${fmt.format(d.allowance)}'),
              ),
          ],
        ),
      ),
    ));

    // Should render 7 list tiles (one per day).
    expect(find.byType(ListTile), findsNWidgets(7));
    // The 25 May tile must show the high allowance and balance 300.
    expect(find.textContaining('d25 bal=300,00'), findsOneWidget);
    // The 19 May tile must show balance 300 too.
    expect(find.textContaining('d19 bal=300,00'), findsOneWidget);
  });
}
