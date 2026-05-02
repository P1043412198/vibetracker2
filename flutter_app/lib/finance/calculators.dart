/// Generic financial calculators (port of src/lib/finance/calculators.ts).
import 'dart:math' as math;

// --- Compound interest ---

class CompoundPoint {
  final int year;
  final double balance;
  final double contributed;

  const CompoundPoint(
      {required this.year, required this.balance, required this.contributed});
}

class CompoundResult {
  final double finalBalance;
  final double totalContributed;
  final double totalInterest;
  final List<CompoundPoint> series;

  const CompoundResult({
    required this.finalBalance,
    required this.totalContributed,
    required this.totalInterest,
    required this.series,
  });
}

CompoundResult compoundInterest({
  required double principal,
  required double annualRatePct,
  required int years,
  double monthlyContribution = 0,
  int compoundingPerYear = 12,
}) {
  final rate = annualRatePct / 100 / compoundingPerYear;
  final totalPeriods = years * compoundingPerYear;
  double balance = principal;
  double contributed = principal;
  final series = <CompoundPoint>[
    CompoundPoint(year: 0, balance: principal, contributed: principal),
  ];
  for (int p = 1; p <= totalPeriods; p++) {
    balance = balance * (1 + rate) + monthlyContribution;
    contributed += monthlyContribution;
    if (p % compoundingPerYear == 0) {
      series.add(CompoundPoint(
        year: p ~/ compoundingPerYear,
        balance: balance,
        contributed: contributed,
      ));
    }
  }
  return CompoundResult(
    finalBalance: balance,
    totalContributed: contributed,
    totalInterest: balance - contributed,
    series: series,
  );
}

// --- Loan schedule ---

class LoanScheduleRow {
  final int month;
  final double payment;
  final double principal;
  final double interest;
  final double balance;

  const LoanScheduleRow({
    required this.month,
    required this.payment,
    required this.principal,
    required this.interest,
    required this.balance,
  });
}

class LoanResult {
  final List<LoanScheduleRow> schedule;
  final double totalPayment;
  final double totalInterest;
  final double monthlyPayment;

  const LoanResult({
    required this.schedule,
    required this.totalPayment,
    required this.totalInterest,
    required this.monthlyPayment,
  });
}

LoanResult buildLoanSchedule({
  required double amount,
  required double annualRatePct,
  required int termMonths,
  String type = 'annuity', // 'annuity' | 'differential'
}) {
  final monthlyRate = annualRatePct / 100 / 12;
  final rows = <LoanScheduleRow>[];
  double totalPaid = 0;
  double balance = amount;

  if (type == 'annuity') {
    final mp = monthlyRate > 0
        ? amount *
            (monthlyRate * math.pow(1 + monthlyRate, termMonths)) /
            (math.pow(1 + monthlyRate, termMonths) - 1)
        : amount / termMonths;
    for (int m = 1; m <= termMonths; m++) {
      final interest = balance * monthlyRate;
      final princ = mp - interest;
      balance -= princ;
      if (balance < 0) balance = 0;
      totalPaid += mp;
      rows.add(LoanScheduleRow(
        month: m,
        payment: mp,
        principal: princ,
        interest: interest,
        balance: balance,
      ));
    }
    return LoanResult(
      schedule: rows,
      totalPayment: totalPaid,
      totalInterest: totalPaid - amount,
      monthlyPayment: mp,
    );
  } else {
    // Differential
    final princPart = amount / termMonths;
    double firstPayment = 0;
    for (int m = 1; m <= termMonths; m++) {
      final interest = balance * monthlyRate;
      final payment = princPart + interest;
      if (m == 1) firstPayment = payment;
      balance -= princPart;
      if (balance < 0) balance = 0;
      totalPaid += payment;
      rows.add(LoanScheduleRow(
        month: m,
        payment: payment,
        principal: princPart,
        interest: interest,
        balance: balance,
      ));
    }
    return LoanResult(
      schedule: rows,
      totalPayment: totalPaid,
      totalInterest: totalPaid - amount,
      monthlyPayment: firstPayment,
    );
  }
}

// --- Currency stress test ---

class StressBucket {
  final String currency;
  final double amount;

  const StressBucket({required this.currency, required this.amount});
}

({double before, double after, double deltaPct}) applyDevaluation(
  List<StressBucket> buckets,
  Map<String, double> rates,
  double basePct, {
  String base = 'BYN',
}) {
  final baseRate = rates[base] ?? 1.0;
  final stressedRates = <String, double>{};
  for (final e in rates.entries) {
    stressedRates[e.key] =
        e.key == base ? e.value : e.value * (1 + basePct / 100);
  }
  final before = buckets.fold<double>(
      0, (s, b) => s + (b.amount * (rates[b.currency] ?? 1)) / baseRate);
  final after = buckets.fold<double>(
      0,
      (s, b) =>
          s + (b.amount * (stressedRates[b.currency] ?? 1)) / baseRate);
  return (
    before: before,
    after: after,
    deltaPct: before > 0 ? ((after - before) / before) * 100 : 0,
  );
}

// --- Safety fund ---

double safetyFundTarget(double monthlyExpenses, {int months = 6}) {
  return (monthlyExpenses * months).clamp(0, double.infinity);
}

// --- FIRE ---

double fireNumber({required double annualExpenses, double swrPct = 4}) {
  final swr = swrPct / 100;
  return swr == 0 ? double.infinity : annualExpenses / swr;
}

double yearsToFire({
  required double currentNet,
  required double monthlySaving,
  required double annualReturnPct,
  double annualInflationPct = 0,
  required double targetNet,
  int maxYears = 100,
}) {
  if (currentNet >= targetNet) return 0;
  final realMonthly = (annualReturnPct - annualInflationPct) / 100 / 12;
  double balance = currentNet;
  for (int m = 1; m <= maxYears * 12; m++) {
    balance = balance * (1 + realMonthly) + monthlySaving;
    if (balance >= targetNet) return (m / 12 * 100).roundToDouble() / 100;
  }
  return double.infinity;
}
