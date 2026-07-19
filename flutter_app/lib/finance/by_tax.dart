// Belarus-specific tax calculators (port of src/lib/finance/byTax.ts).

/// Year-dependent НК РБ parameters. МЗП, base value and deduction thresholds
/// change almost every year, so they live in a table keyed by year — updating
/// is a one-line addition. Port of `BY_TAX_BY_YEAR` in `src/lib/finance/byTax.ts`.
///
/// ⚠️ Only 2024 values are confirmed. Add 2025/2026 from official sources
/// (Совмин postановления for МЗП/БВ and art. 209 НК РБ for deductions).
class ByTaxYearConstants {
  final double baseValueByn;
  final double minWageByn;
  final double stdDeductionIncomeLimit;
  final double stdDeduction;
  final double childDeduction;
  final double childDeductionTwoPlus;
  final double incomeTaxPct;
  final double fsznEmployeePct;

  const ByTaxYearConstants({
    required this.baseValueByn,
    required this.minWageByn,
    required this.stdDeductionIncomeLimit,
    required this.stdDeduction,
    required this.childDeduction,
    required this.childDeductionTwoPlus,
    required this.incomeTaxPct,
    required this.fsznEmployeePct,
  });
}

const Map<int, ByTaxYearConstants> byTaxByYear = {
  2024: ByTaxYearConstants(
    baseValueByn: 42,
    minWageByn: 626,
    stdDeductionIncomeLimit: 1054,
    stdDeduction: 174,
    childDeduction: 51,
    childDeductionTwoPlus: 97,
    incomeTaxPct: 13,
    fsznEmployeePct: 1,
  ),
};

/// Latest year with confirmed values — used by default.
const int currentTaxYear = 2024;

/// Returns constants for [year]: exact match → nearest earlier filled year →
/// latest available, so the calculator never breaks for an un-filled year.
ByTaxYearConstants getByTaxConstants([int year = currentTaxYear]) {
  final exact = byTaxByYear[year];
  if (exact != null) return exact;
  final years = byTaxByYear.keys.toList()..sort();
  final fallbackYear = years.reversed.firstWhere(
    (y) => y <= year,
    orElse: () => years.last,
  );
  return byTaxByYear[fallbackYear]!;
}

final ByTaxYearConstants _current = getByTaxConstants(currentTaxYear);

final double baseValueByn = _current.baseValueByn;
final double minWageByn = _current.minWageByn;
final double stdDeductionIncomeLimit = _current.stdDeductionIncomeLimit;
final double stdDeduction = _current.stdDeduction;
final double childDeduction = _current.childDeduction;
final double childDeductionTwoPlus = _current.childDeductionTwoPlus;
final double incomeTaxPct = _current.incomeTaxPct;
final double fsznEmployeePct = _current.fsznEmployeePct;

// NPD
const double npdLowRatePct = 10;
const double npdHighRatePct = 20;
const double npdHighRateThreshold = 60000;

class SalaryDeduction {
  final String id;
  final String label;
  final String kind; // 'percent' | 'fixed'
  final double value;
  final bool taxable;

  const SalaryDeduction({
    required this.id,
    required this.label,
    required this.kind,
    required this.value,
    this.taxable = false,
  });
}

class SalaryDeductionLine {
  final String id;
  final String label;
  final double amount;
  final bool taxable;

  const SalaryDeductionLine({
    required this.id,
    required this.label,
    required this.amount,
    required this.taxable,
  });
}

class SalaryResult {
  final double gross;
  final double fszn;
  final double taxableBase;
  final double deductions;
  final double pretaxDeductions;
  final double postTaxDeductions;
  final List<SalaryDeductionLine> extraDeductionsApplied;
  final double incomeTax;
  final double net;

  const SalaryResult({
    required this.gross,
    required this.fszn,
    required this.taxableBase,
    required this.deductions,
    required this.pretaxDeductions,
    required this.postTaxDeductions,
    required this.extraDeductionsApplied,
    required this.incomeTax,
    required this.net,
  });
}

SalaryResult calcNetSalary({
  required double gross,
  int children = 0,
  int dependents = 0,
  bool applyStandardDeduction = true,
  List<SalaryDeduction> extraDeductions = const [],
}) {
  double deductions = 0;
  if (applyStandardDeduction && gross <= stdDeductionIncomeLimit) {
    deductions += stdDeduction;
  }
  if (children > 0) {
    if (children == 1) {
      deductions += childDeduction;
    } else {
      deductions += children * childDeductionTwoPlus;
    }
  }
  if (dependents > 0) {
    deductions += dependents * childDeduction;
  }

  final extraLines = extraDeductions
      .map((d) => SalaryDeductionLine(
            id: d.id,
            label: d.label,
            amount:
                d.kind == 'percent' ? (gross * d.value) / 100 : d.value,
            taxable: d.taxable,
          ))
      .toList();

  final pretax =
      extraLines.where((l) => l.taxable).fold(0.0, (s, l) => s + l.amount);
  final postTax =
      extraLines.where((l) => !l.taxable).fold(0.0, (s, l) => s + l.amount);

  final taxBase = (gross - deductions - pretax).clamp(0.0, double.infinity);
  final tax = (taxBase * incomeTaxPct) / 100;
  final fszn = (gross * fsznEmployeePct) / 100;
  final net = gross - tax - fszn - pretax - postTax;

  return SalaryResult(
    gross: gross,
    fszn: fszn,
    taxableBase: taxBase,
    deductions: deductions,
    pretaxDeductions: pretax,
    postTaxDeductions: postTax,
    extraDeductionsApplied: extraLines,
    incomeTax: tax,
    net: net,
  );
}

double grossFromNet(double targetNet,
    {int children = 0,
    int dependents = 0,
    bool applyStandardDeduction = true,
    List<SalaryDeduction> extraDeductions = const []}) {
  if (targetNet <= 0) return 0;

  double netAt(double gross) => calcNetSalary(
        gross: gross,
        children: children,
        dependents: dependents,
        applyStandardDeduction: applyStandardDeduction,
        extraDeductions: extraDeductions,
      ).net;

  // Expand the upper bound until it actually brackets the target (percentage
  // deductions can push the effective net-to-gross ratio well below 1), rather
  // than assuming 3× is always enough.
  double lo = 0;
  double hi = targetNet <= 0 ? 1 : targetNet * 1.5;
  var guard = 0;
  while (netAt(hi) < targetNet && guard < 60) {
    lo = hi;
    hi *= 2;
    guard++;
  }
  // No gross yields the requested net (e.g. deductions exceed 100%).
  if (netAt(hi) < targetNet) return double.nan;

  double mid = hi;
  for (int i = 0; i < 100; i++) {
    mid = (lo + hi) / 2;
    final net = netAt(mid);
    if ((net - targetNet).abs() < 0.005) return mid;
    if (net < targetNet) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return mid;
}

// --- Deposit BY (13% tax on short-term) ---

class DepositResult {
  final double totalInterestGross;
  final double totalTax;
  final double totalInterestNet;
  final double finalBalance;

  const DepositResult({
    required this.totalInterestGross,
    required this.totalTax,
    required this.totalInterestNet,
    required this.finalBalance,
  });
}

DepositResult calcDepositBY({
  required double amount,
  required double annualRatePct,
  required int termMonths,
  bool taxApplies = true,
  bool capitalize = true,
}) {
  if (termMonths <= 0 || amount <= 0) {
    return const DepositResult(
      totalInterestGross: 0,
      totalTax: 0,
      totalInterestNet: 0,
      finalBalance: 0,
    );
  }
  final monthlyRate = annualRatePct / 100 / 12;
  double balance = amount;
  double interestGross = 0;
  for (int m = 1; m <= termMonths; m++) {
    final i = balance * monthlyRate;
    interestGross += i;
    if (capitalize) balance += i;
  }
  final tax = taxApplies ? (interestGross * incomeTaxPct) / 100 : 0.0;
  final interestNet = interestGross - tax;
  return DepositResult(
    totalInterestGross: interestGross,
    totalTax: tax,
    totalInterestNet: interestNet,
    finalBalance: capitalize ? balance - tax : amount + interestNet,
  );
}

// --- IP USN (5% / 3%) ---

class IpUsnResult {
  final double usnTax;
  final double fsznTotal;
  final double totalLoad;
  final double net;
  final double effectivePct;

  const IpUsnResult({
    required this.usnTax,
    required this.fsznTotal,
    required this.totalLoad,
    required this.net,
    required this.effectivePct,
  });
}

/// ⚠️ Historical/reference only. The УСН regime for ИП was abolished in
/// Belarus from 2023; new activity uses ОСН/подоходный or НПД instead. Kept for
/// modelling legacy periods — do not present as a current option.
IpUsnResult calcIpUsn({
  required double annualRevenue,
  required int ratePct,
  required double fsznMonthly,
}) {
  final usnTax = (annualRevenue * ratePct) / 100;
  final fsznTotal = fsznMonthly * 12;
  final totalLoad = usnTax + fsznTotal;
  final net = annualRevenue - totalLoad;
  return IpUsnResult(
    usnTax: usnTax,
    fsznTotal: fsznTotal,
    totalLoad: totalLoad,
    net: net,
    effectivePct: annualRevenue > 0 ? (totalLoad / annualRevenue) * 100 : 0,
  );
}

// --- NPD (self-employed) ---

class NpdResult {
  final double taxLow;
  final double taxHigh;
  final double total;
  final double net;
  final double effectivePct;

  const NpdResult({
    required this.taxLow,
    required this.taxHigh,
    required this.total,
    required this.net,
    required this.effectivePct,
  });
}

NpdResult calcNpd({required double annualRevenue}) {
  final r = annualRevenue;
  final low = r < npdHighRateThreshold ? r : npdHighRateThreshold;
  final high = (r - npdHighRateThreshold).clamp(0.0, double.infinity).toDouble();
  final taxLow = (low * npdLowRatePct) / 100;
  final taxHigh = (high * npdHighRatePct) / 100;
  final total = taxLow + taxHigh;
  return NpdResult(
    taxLow: taxLow,
    taxHigh: taxHigh,
    total: total,
    net: r - total,
    effectivePct: r > 0 ? (total / r) * 100 : 0,
  );
}

// --- Vacation pay ---

/// Vacation pay via the average-daily-earnings method.
///
/// Uses the 29.6 average-monthly-days coefficient (Постановление Совмина РБ
/// № 1290 as amended); the exact figure is periodically revised, so treat the
/// result as an approximation for planning rather than a payroll-exact number.
({double avgDaily, double payment}) calcVacationPay(
    double totalEarningsLast12m, int daysOff) {
  final avgDaily = totalEarningsLast12m / (12 * 29.6);
  return (avgDaily: avgDaily, payment: avgDaily * daysOff);
}
