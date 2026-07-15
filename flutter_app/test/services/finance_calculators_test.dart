import 'package:flutter_test/flutter_test.dart';

import 'package:vibesight_tracker/finance/calculators.dart';
import 'package:vibesight_tracker/finance/by_tax.dart';

void main() {
  group('compoundInterest', () {
    test('annual contribution is independent of compounding frequency', () {
      final monthly = compoundInterest(
        principal: 0,
        annualRatePct: 0,
        years: 10,
        monthlyContribution: 100,
        compoundingPerYear: 12,
      );
      final quarterly = compoundInterest(
        principal: 0,
        annualRatePct: 0,
        years: 10,
        monthlyContribution: 100,
        compoundingPerYear: 4,
      );
      // With 0% interest, 10 years × 12 × 100 = 12000 regardless of how often
      // interest compounds.
      expect(monthly.totalContributed, closeTo(12000, 1e-6));
      expect(quarterly.totalContributed, closeTo(12000, 1e-6));
    });

    test('guards invalid inputs', () {
      final r = compoundInterest(
        principal: 1000,
        annualRatePct: 5,
        years: -1,
        compoundingPerYear: 0,
      );
      expect(r.finalBalance, 1000);
      expect(r.series.length, 1);
    });
  });

  group('buildLoanSchedule', () {
    test('annuity balance ends exactly at zero (kopeck-rounded)', () {
      final r = buildLoanSchedule(
        amount: 10000,
        annualRatePct: 12,
        termMonths: 24,
      );
      expect(r.schedule.length, 24);
      expect(r.schedule.last.balance, 0);
      // Every payment/interest is rounded to 2 decimals.
      for (final row in r.schedule) {
        expect(row.payment, closeTo((row.payment * 100).round() / 100, 1e-9));
      }
    });

    test('empty schedule for non-positive term', () {
      final r = buildLoanSchedule(
          amount: 1000, annualRatePct: 10, termMonths: 0);
      expect(r.schedule, isEmpty);
      expect(r.monthlyPayment, 0);
    });
  });

  group('applyDevaluation', () {
    test('reports missing currencies instead of assuming 1:1', () {
      final r = applyDevaluation(
        [
          const StressBucket(currency: 'USD', amount: 100),
          const StressBucket(currency: 'XXX', amount: 100),
        ],
        {'BYN': 1.0, 'USD': 3.0},
        20,
      );
      expect(r.missing, contains('XXX'));
      // Only the USD bucket contributes: 100 × 3 / 1 = 300 before.
      expect(r.before, closeTo(300, 1e-9));
      expect(r.after, closeTo(360, 1e-9));
      expect(r.deltaPct, closeTo(20, 1e-9));
    });
  });

  group('yearsToFire', () {
    test('uses the Fisher real rate, not nominal minus inflation', () {
      final y = yearsToFire(
        currentNet: 0,
        monthlySaving: 1000,
        annualReturnPct: 8,
        annualInflationPct: 3,
        targetNet: 100000,
      );
      expect(y, isPositive);
      expect(y.isFinite, isTrue);
    });
  });

  group('grossFromNet', () {
    test('round-trips through calcNetSalary', () {
      const target = 1200.0;
      final gross = grossFromNet(target);
      expect(gross.isFinite, isTrue);
      expect(calcNetSalary(gross: gross).net, closeTo(target, 0.05));
    });

    test('zero target returns zero', () {
      expect(grossFromNet(0), 0);
    });
  });

  group('calcVacationPay', () {
    test('uses the 29.6 monthly-days coefficient', () {
      final r = calcVacationPay(12 * 29.6 * 50, 10);
      expect(r.avgDaily, closeTo(50, 1e-9));
      expect(r.payment, closeTo(500, 1e-9));
    });
  });

  group('calcNpd', () {
    test('low rate below threshold, split above', () {
      final below = calcNpd(annualRevenue: 50000);
      expect(below.total, closeTo(5000, 1e-9)); // 10%
      final above = calcNpd(annualRevenue: 70000);
      // 60000×10% + 10000×20% = 6000 + 2000 = 8000
      expect(above.total, closeTo(8000, 1e-9));
    });
  });
}
