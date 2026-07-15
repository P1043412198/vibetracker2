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
  // Guard against nonsensical inputs instead of producing NaN/negative series.
  if (years < 0 ||
      compoundingPerYear <= 0 ||
      principal < 0 ||
      monthlyContribution < 0) {
    final p = principal < 0 ? 0.0 : principal;
    return CompoundResult(
      finalBalance: p,
      totalContributed: p,
      totalInterest: 0,
      series: [CompoundPoint(year: 0, balance: p, contributed: p)],
    );
  }

  final rate = annualRatePct / 100 / compoundingPerYear;
  final totalPeriods = years * compoundingPerYear;
  // Contributions are conceptually monthly. Spreading a full year's worth
  // (12·monthlyContribution) across the compounding periods keeps the annual
  // deposit independent of the compounding frequency.
  final contributionPerPeriod = monthlyContribution * 12 / compoundingPerYear;
  double balance = principal;
  double contributed = principal;
  final series = <CompoundPoint>[
    CompoundPoint(year: 0, balance: principal, contributed: principal),
  ];
  for (int p = 1; p <= totalPeriods; p++) {
    balance = balance * (1 + rate) + contributionPerPeriod;
    contributed += contributionPerPeriod;
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

/// Rounds a monetary amount to whole kopecks (2 decimal places).
double _kopecks(double v) => (v * 100).roundToDouble() / 100;

LoanResult buildLoanSchedule({
  required double amount,
  required double annualRatePct,
  required int termMonths,
  String type = 'annuity', // 'annuity' | 'differential'
}) {
  if (termMonths <= 0 || amount <= 0) {
    return const LoanResult(
      schedule: [],
      totalPayment: 0,
      totalInterest: 0,
      monthlyPayment: 0,
    );
  }
  final monthlyRate = annualRatePct / 100 / 12;
  final rows = <LoanScheduleRow>[];
  double totalPaid = 0;
  double balance = amount;

  if (type == 'annuity') {
    final rawMp = monthlyRate > 0
        ? amount *
            (monthlyRate * math.pow(1 + monthlyRate, termMonths)) /
            (math.pow(1 + monthlyRate, termMonths) - 1)
        : amount / termMonths;
    final mp = _kopecks(rawMp);
    for (int m = 1; m <= termMonths; m++) {
      final interest = _kopecks(balance * monthlyRate);
      // The final instalment absorbs accumulated rounding so the balance
      // lands exactly on zero rather than drifting by a few kopecks.
      final payment = m == termMonths ? _kopecks(balance + interest) : mp;
      final princ = payment - interest;
      balance = _kopecks(balance - princ);
      if (balance < 0) balance = 0;
      totalPaid += payment;
      rows.add(LoanScheduleRow(
        month: m,
        payment: payment,
        principal: princ,
        interest: interest,
        balance: balance,
      ));
    }
    return LoanResult(
      schedule: rows,
      totalPayment: _kopecks(totalPaid),
      totalInterest: _kopecks(totalPaid - amount),
      monthlyPayment: mp,
    );
  } else {
    // Differential
    final princPart = _kopecks(amount / termMonths);
    double firstPayment = 0;
    for (int m = 1; m <= termMonths; m++) {
      final interest = _kopecks(balance * monthlyRate);
      // Last month settles whatever principal is left after rounding.
      final princ = m == termMonths ? balance : princPart;
      final payment = _kopecks(princ + interest);
      if (m == 1) firstPayment = payment;
      balance = _kopecks(balance - princ);
      if (balance < 0) balance = 0;
      totalPaid += payment;
      rows.add(LoanScheduleRow(
        month: m,
        payment: payment,
        principal: princ,
        interest: interest,
        balance: balance,
      ));
    }
    return LoanResult(
      schedule: rows,
      totalPayment: _kopecks(totalPaid),
      totalInterest: _kopecks(totalPaid - amount),
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

({double before, double after, double deltaPct, List<String> missing})
    applyDevaluation(
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
  // A missing rate must not silently collapse to 1:1 — that would understate
  // exposure. Such buckets are excluded from the totals and reported back.
  final missing = <String>{};
  double before = 0;
  double after = 0;
  for (final b in buckets) {
    final rate = b.currency == base ? baseRate : rates[b.currency];
    if (rate == null) {
      missing.add(b.currency);
      continue;
    }
    before += (b.amount * rate) / baseRate;
    final stressed = stressedRates[b.currency] ?? rate;
    after += (b.amount * stressed) / baseRate;
  }
  return (
    before: before,
    after: after,
    deltaPct: before > 0 ? ((after - before) / before) * 100 : 0,
    missing: missing.toList(),
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
  // Fisher-correct real rate: (1+nominal)/(1+inflation) − 1, converted to a
  // monthly compounding rate — not the naive (nominal − inflation).
  final realAnnual =
      (1 + annualReturnPct / 100) / (1 + annualInflationPct / 100) - 1;
  final realMonthly = math.pow(1 + realAnnual, 1 / 12) - 1;
  double balance = currentNet;
  for (int m = 1; m <= maxYears * 12; m++) {
    balance = balance * (1 + realMonthly) + monthlySaving;
    if (balance >= targetNet) return (m / 12 * 100).roundToDouble() / 100;
  }
  return double.infinity;
}
