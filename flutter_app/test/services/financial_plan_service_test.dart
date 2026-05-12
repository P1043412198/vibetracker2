import 'package:flutter_test/flutter_test.dart';

import 'package:vibesight_tracker/models/finance.dart';
import 'package:vibesight_tracker/models/financial_plan.dart';
import 'package:vibesight_tracker/services/financial_plan_service.dart';

/// Pure-Dart unit tests for [FinancialPlanService]. The service is meant to
/// be stateless and trivially testable: every section of the report should
/// degrade gracefully when input data is empty.
void main() {
  const service = FinancialPlanService();

  group('FinancialPlanService', () {
    test('buildFinancialPlan returns a complete report on empty inputs', () {
      final config = FinancialPlanConfig.defaults();
      final report = service.buildFinancialPlan(
        config: config,
        plans: const [],
        loans: const [],
        accounts: const [],
      );
      expect(report.config, same(config));
      expect(report.income.gross, equals(config.salaryGross));
      expect(report.kpis, hasLength(4));
      expect(report.scenarioCompare, hasLength(config.scenarios.length));
      expect(report.calendar.weeks, isNotEmpty);
      expect(report.heatmap.weeks, isNotEmpty);
      expect(report.dailyBalance.scenarios, hasLength(config.scenarios.length));
      expect(report.actionPlan, isNotEmpty);
      expect(report.scatter.points, isNotEmpty);
    });

    test('computeIncomeBreakdown waterfall sums back to gross', () {
      final config = FinancialPlanConfig.defaults();
      final inc = service.computeIncomeBreakdown(config);
      expect(inc.gross, equals(config.salaryGross));
      // Net = gross − tax − fszn − tradeUnion (rounding tolerance).
      final reconstructed =
          inc.gross - inc.incomeTax - inc.fszn - inc.tradeUnion;
      expect((inc.net - reconstructed).abs(), lessThan(0.5));
      expect(inc.netRemainder, lessThanOrEqualTo(inc.net));
      // The waterfall should always include at least the gross + net + remainder pillars.
      final kinds = inc.steps.map((s) => s.kind).toSet();
      expect(kinds, containsAll([
        WaterfallKind.gross,
        WaterfallKind.net,
        WaterfallKind.remainder,
      ]));
    });

    test('computeLongTermTrajectory finds month when goal is reached', () {
      final config = FinancialPlanConfig.defaults();
      final t = service.computeLongTermTrajectory(config: config, months: 36);
      expect(t.tracks, hasLength(config.scenarios.length));
      // At least one scenario should reach the goal within the projected window.
      final reaching = t.tracks.where(
        (tr) => tr.points.any((p) => p >= t.goalUsd),
      );
      expect(reaching, isNotEmpty,
          reason:
              'At least one scenario should accumulate up to the goal in 36 months');
      for (final tr in t.tracks) {
        expect(tr.points.length, equals(t.months));
      }
      final aggressive = reaching.first;
      expect(aggressive.monthsToGoal, greaterThan(0));
      expect(aggressive.monthsToGoal, lessThanOrEqualTo(t.months));
    });

    test('generateActionPlan flags loans with rate above 18%', () {
      final config = FinancialPlanConfig.defaults();
      final loans = [
        Loan(
          id: 'l_high',
          title: 'Дорогой кредит',
          principal: 1000,
          balance: 800,
          annualRate: 24,
          monthlyPayment: 100,
          startDate: DateTime.now().toIso8601String(),
          currency: 'BYN',
          paymentDay: 15,
          termMonths: 12,
        ),
      ];
      final accounts = <Account>[];
      final expenses = service.computeExpenseStructure(
        config: config,
        plans: const [],
        loans: loans,
      );
      final actions = service.generateActionPlan(
        config: config,
        expenses: expenses,
        loans: loans,
        accounts: accounts,
      );
      final hasRefinanceStep = actions.any((a) =>
          a.text.contains('Дорогой кредит') &&
          a.urgency == ActionUrgency.future);
      expect(hasRefinanceStep, isTrue,
          reason: 'High-rate loan should trigger a refinance action step');
    });
  });
}
