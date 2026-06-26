import 'package:intl/intl.dart';

import '../finance/by_holidays.dart';
import '../models/budget_planner.dart';
import '../models/enums.dart';
import '../models/finance.dart';
import 'finance_calc.dart';

/// Returns the last working day on or before [dayOfMonth] in [year]/[month].
DateTime adjustedPayDate(int year, int month, int dayOfMonth) {
  final daysInMonth = DateTime(year, month + 1, 0).day;
  final day = dayOfMonth.clamp(1, daysInMonth);
  var date = DateTime(year, month, day);

  for (var i = 0; i < 10; i++) {
    final iso = DateFormat('yyyy-MM-dd').format(date);
    if (date.weekday != DateTime.saturday &&
        date.weekday != DateTime.sunday &&
        isBYHoliday(iso) == null) {
      return date;
    }
    date = date.subtract(const Duration(days: 1));
  }
  return date;
}

/// Get the actual pay date for a given income source in a specific month.
DateTime? getPayDate(IncomeSource source, int year, int month) {
  if (source.dayOfMonth == null && source.type != IncomeSourceType.advance) {
    return null;
  }

  int targetDay;
  if (source.type == IncomeSourceType.advance &&
      (source.dayOfMonth == null || source.dayOfMonth! >= 28)) {
    targetDay = DateTime(year, month + 1, 0).day;
  } else {
    targetDay = source.dayOfMonth ?? 15;
  }

  if (source.adjustForHolidays) {
    return adjustedPayDate(year, month, targetDay);
  }
  final daysInMonth = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, targetDay.clamp(1, daysInMonth));
}

class BudgetCycle {
  BudgetCycle({
    required this.label,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.daysLeft,
    required this.totalIncome,
    required this.totalPlannedExpenses,
    required this.remainingAfterExpenses,
    required this.actualSpent,
    required this.remainingBudget,
    required this.dailyBudget,
    required this.weeklyBudget,
    required this.fullWeeks,
    required this.extraDays,
    this.accountBalance = 0,
    this.receivedIncome = 0,
    this.pendingIncome = 0,
    this.useAccountBase = false,
  });

  final String label;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final int daysLeft;
  final double totalIncome;
  final double totalPlannedExpenses;
  final double remainingAfterExpenses;
  final double actualSpent;
  final double remainingBudget;
  final double dailyBudget;
  final double weeklyBudget;
  final int fullWeeks;
  final int extraDays;
  final double accountBalance;
  final double receivedIncome;
  final double pendingIncome;
  final bool useAccountBase;
}

/// Aggregated facts for the dashboard from real transactions.
class BudgetFacts {
  BudgetFacts({
    required this.accountBalance,
    required this.monthIncome,
    required this.monthExpense,
    required this.expenseByCategory,
    required this.dailySpending,
    required this.incomeTransactions,
    required this.expenseTransactions,
  });

  final double accountBalance;
  final double monthIncome;
  final double monthExpense;
  final Map<String, double> expenseByCategory;

  /// Daily spending amounts: day-of-month (1-based) → total spent.
  final Map<int, double> dailySpending;
  final List<Transaction> incomeTransactions;
  final List<Transaction> expenseTransactions;
}

/// Compute real facts from transactions and accounts for a given month.
BudgetFacts computeBudgetFacts({
  required String monthKey,
  required List<Transaction> transactions,
  required List<Account> accounts,
  required CurrencyConvert convert,
  required String baseCurrency,
  List<String> linkedAccountIds = const [],
}) {
  double balance = 0;
  for (final a in accounts) {
    if (linkedAccountIds.isNotEmpty && !linkedAccountIds.contains(a.id)) {
      continue;
    }
    final b = accountBalance(
      account: a,
      transactions: transactions,
      accounts: accounts,
      convert: convert,
    );
    balance += convert(b, a.currency, baseCurrency).toDouble();
  }

  final monthTxs = transactions.where((t) => t.date.startsWith(monthKey));
  double income = 0;
  double expense = 0;
  final byCategory = <String, double>{};
  final dailySpend = <int, double>{};
  final incomeTxs = <Transaction>[];
  final expenseTxs = <Transaction>[];

  for (final t in monthTxs) {
    final amt = convert(t.amount, _txCurrency(t, accounts, baseCurrency),
            baseCurrency)
        .toDouble();
    if (t.type == TransactionType.income) {
      income += amt;
      incomeTxs.add(t);
    } else if (t.type == TransactionType.expense) {
      expense += amt;
      expenseTxs.add(t);
      byCategory[t.category] = (byCategory[t.category] ?? 0) + amt;
      final day = int.tryParse(t.date.substring(8, 10)) ?? 1;
      dailySpend[day] = (dailySpend[day] ?? 0) + amt;
    }
  }

  return BudgetFacts(
    accountBalance: balance,
    monthIncome: income,
    monthExpense: expense,
    expenseByCategory: byCategory,
    dailySpending: dailySpend,
    incomeTransactions: incomeTxs,
    expenseTransactions: expenseTxs,
  );
}

String _txCurrency(Transaction t, List<Account> accounts, String fallback) {
  if (t.accountId == null) return fallback;
  final acct = accounts.cast<Account?>().firstWhere(
        (a) => a?.id == t.accountId,
        orElse: () => null,
      );
  return acct?.currency ?? fallback;
}

int _diffDays(DateTime a, DateTime b) {
  final aDate = DateTime(a.year, a.month, a.day);
  final bDate = DateTime(b.year, b.month, b.day);
  return bDate.difference(aDate).inDays;
}

bool _isBefore(DateTime a, DateTime b) => _diffDays(a, b) > 0;

/// Synthesise a virtual [PlannedExpense] for each active loan so the budget
/// cycle calculator treats loan monthly payments as part of the expense plan.
///
/// The user explicitly asked for a **unified ecosystem**: loans, goals, habits
/// and budget all read from the same source of truth. So if you owe a credit
/// 250 BYN/month, it must show up in the budget plan automatically — without
/// the user re-typing it as a planned expense. Anchoring on [Loan.paymentDay]
/// (fallback to the 5th of the month) keeps the math compatible with the
/// `unpaidExpensesInRange` helper that filters by `dayFrom`.
List<PlannedExpense> loansAsPlannedExpenses({
  required List<Loan> loans,
  required CurrencyConvert? convert,
  required String baseCurrency,
  required String monthKey,
  required List<LoanPayment> loanPayments,
}) {
  if (loans.isEmpty) return const <PlannedExpense>[];
  final result = <PlannedExpense>[];
  for (final loan in loans) {
    if (loan.balance <= 0) continue;
    if (loan.monthlyPayment <= 0) continue;
    final amount = convert != null
        ? convert(loan.monthlyPayment, loan.currency, baseCurrency).toDouble()
        : loan.monthlyPayment.toDouble();
    final day = (loan.paymentDay ?? 5).clamp(1, 31);
    // Has this loan been paid for the active month? Match by month prefix.
    final paid = loanPayments.any(
      (p) => p.loanId == loan.id && p.date.startsWith(monthKey),
    );
    result.add(PlannedExpense(
      id: 'loan:${loan.id}',
      name: 'Кредит: ${loan.title}',
      amount: amount,
      currency: baseCurrency,
      dayFrom: day,
      dayTo: day,
      category: 'Кредиты',
      isPaid: paid,
      paidDate: paid ? loanPayments.firstWhere((p) => p.loanId == loan.id && p.date.startsWith(monthKey)).date : null,
      paidAmount: paid ? amount : null,
      isActive: true,
      createdAt: loan.startDate,
    ));
  }
  return result;
}

/// Calculate budget cycles anchored to the *real* current balance, using the
/// same cashflow engine as the "safe-to-spend" card so the two never diverge.
///
/// Produces, when the matching income sources exist:
///   • До ближайшего дохода   (today → next income)
///   • Аванс → Аванс          (today → the advance after next)
///   • Зарплата → Зарплата    (today → the salary after next)
///
/// Each cycle's budget is `currentBalance + income in window − obligations −
/// reserve`, and the daily figure is the steady safe spend/day for the window.
/// Loans are folded into the obligations (unified ecosystem). Mirrors
/// `computeBudgetCycles` in `src/lib/finance/budgetPlanner.ts`.
List<BudgetCycle> computeBudgetCycles({
  required List<IncomeSource> incomeSources,
  required List<PlannedExpense> plannedExpenses,
  required List<ActualExpense> actualExpenses,
  List<Transaction> transactions = const [],
  List<Account> accounts = const [],
  List<Loan> loans = const [],
  List<LoanPayment> loanPayments = const [],
  CurrencyConvert? convert,
  String baseCurrency = 'BYN',
  double accountBalance = 0,
  double reserve = 0,
  DateTime? today,
  List<String> accountIds = const [],
}) {
  final now = today ?? DateTime.now();
  final active = incomeSources.where((s) => s.isActive).toList();
  final hasAdvance = active.any((s) => s.type == IncomeSourceType.advance);
  final hasSalary = active.any((s) => s.type == IncomeSourceType.salary);
  if (!hasAdvance && !hasSalary) return const <BudgetCycle>[];

  final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  // Unified ecosystem: append virtual planned expenses derived from active
  // loans so the budget already accounts for credit payments.
  final loanExpenses = loansAsPlannedExpenses(
    loans: loans,
    convert: convert,
    baseCurrency: baseCurrency,
    monthKey: monthKey,
    loanPayments: loanPayments,
  );
  final allPlanned = [
    ...plannedExpenses.where((e) => e.isActive),
    ...loanExpenses,
  ];

  // Real expenses already spent inside a window (for the dashboard "spent" ring).
  double spentInWindow(DateTime start, DateTime end) {
    final conv = convert ?? (num amount, String from, String to) => amount;
    final from = DateTime(start.year, start.month, start.day);
    final to = _isBefore(now, end) ? now : end;
    final toDay = DateTime(to.year, to.month, to.day);
    double total = 0;
    for (final t in transactions) {
      if (t.type != TransactionType.expense) continue;
      final d = DateTime.tryParse(t.date);
      if (d == null) continue;
      final day = DateTime(d.year, d.month, d.day);
      if (_isBefore(day, from)) continue;
      if (_isAfter(day, toDay)) continue;
      total += conv(t.amount, _txCurrency(t, accounts, baseCurrency), baseCurrency)
          .toDouble();
    }
    return total;
  }

  final wanted = <CashflowRangeMode>[CashflowRangeMode.next];
  if (hasAdvance) wanted.add(CashflowRangeMode.advanceToAdvance);
  if (hasSalary) wanted.add(CashflowRangeMode.salaryToSalary);

  final cycles = <BudgetCycle>[];
  final seen = <String>{};

  for (final mode in wanted) {
    final forecast = computeCashflowForecast(
      accounts: accounts,
      transactions: transactions,
      incomeSources: incomeSources,
      plannedExpenses: allPlanned,
      convert: convert,
      baseCurrency: baseCurrency,
      reserve: reserve,
      today: now,
      rangeMode: mode,
      accountIds: accountIds,
    );
    final range = forecast.range;
    if (!forecast.ok || range == null) continue;

    // Skip duplicate windows (e.g. advance→advance coinciding with another).
    final key =
        '${range.startDate.millisecondsSinceEpoch}-${range.endDate.millisecondsSinceEpoch}-${range.label}';
    if (seen.contains(key)) continue;
    seen.add(key);

    final available = range.startBalance + range.totalIncome;
    // Keep the budget consistent with the card: total safe discretionary spend
    // over the window is the steady daily figure across all its days.
    final remainingBudget = range.smoothedDaily * range.daysLeft;
    final fullWeeks = range.daysLeft ~/ 7;
    final extraDays = range.daysLeft % 7;

    cycles.add(BudgetCycle(
      label: range.label,
      startDate: range.startDate,
      endDate: range.endDate,
      totalDays: range.days,
      daysLeft: range.daysLeft,
      totalIncome: available,
      totalPlannedExpenses: range.totalObligations,
      remainingAfterExpenses: available - range.totalObligations,
      actualSpent: spentInWindow(range.startDate, range.endDate),
      remainingBudget: remainingBudget,
      dailyBudget: range.smoothedDaily,
      weeklyBudget: range.smoothedDaily * 7,
      fullWeeks: fullWeeks,
      extraDays: extraDays,
      accountBalance: range.startBalance,
      receivedIncome: 0,
      pendingIncome: range.totalIncome,
      useAccountBase: true,
    ));
  }

  return cycles;
}

// ── Cashflow forecast / "safe-to-spend" engine ──
//
// Unlike [computeBudgetCycles] (which is anchored to calendar pay dates and uses
// income amounts as the budget), this engine starts from the *real* current
// balance across all accounts and projects how much can be spent per day until
// the next income arrives, while still covering upcoming obligations and keeping
// an optional untouchable reserve. Mirrors `computeCashflowForecast` in
// `src/lib/finance/budgetPlanner.ts`.

bool _isAfter(DateTime a, DateTime b) => _diffDays(b, a) > 0;

bool _isSameDayD(DateTime a, DateTime b) => _diffDays(a, b) == 0;

({int year, int month}) _addMonth(int year, int month, int k) {
  // month here is 1-based (Dart convention). Convert to 0-based for the maths.
  final total = (month - 1) + k;
  final y = year + (total / 12).floor();
  final m = ((total % 12) + 12) % 12;
  return (year: y, month: m + 1);
}

/// Which window the forecast should be calculated over.
/// - [auto]             until the next salary (legacy default)
/// - [next]             until the next income of any kind
/// - [advanceToAdvance] a full advance→advance cycle ahead
/// - [salaryToSalary]   a full salary→salary cycle ahead
/// - [fullHorizon]      the furthest income within `horizonDays`
/// - [custom]           a user-picked date window (`customStart`/`customEnd`)
enum CashflowRangeMode {
  auto,
  next,
  advanceToAdvance,
  salaryToSalary,
  fullHorizon,
  custom,
}

const Map<CashflowRangeMode, String> cashflowRangeLabels = {
  CashflowRangeMode.auto: 'До зарплаты',
  CashflowRangeMode.next: 'До ближайшего дохода',
  CashflowRangeMode.advanceToAdvance: 'Аванс → Аванс',
  CashflowRangeMode.salaryToSalary: 'Зарплата → Зарплата',
  CashflowRangeMode.fullHorizon: 'Весь горизонт',
  CashflowRangeMode.custom: 'Свой период',
};

/// Summary of the period the forecast was calculated over.
class CashflowRangeSummary {
  CashflowRangeSummary({
    required this.mode,
    required this.label,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.daysLeft,
    required this.startBalance,
    required this.totalIncome,
    required this.totalObligations,
    required this.smoothedDaily,
  });

  final CashflowRangeMode mode;
  final String label;
  final DateTime startDate;
  final DateTime endDate;

  /// Calendar days inside the window (>= 1).
  final int days;

  /// Calendar days from today to the window end (>= 0).
  final int daysLeft;

  /// Real balance at the window start, in base currency.
  final double startBalance;

  /// Income arriving inside the window, base currency.
  final double totalIncome;

  /// Obligations falling due inside the window, base currency.
  final double totalObligations;

  /// Steady safe spend/day across the whole window keeping the reserve.
  final double smoothedDaily;
}

/// One window between today/an income and the next income.
class CashflowSegment {
  CashflowSegment({
    required this.label,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.startBalance,
    required this.obligations,
    required this.incomeAtEnd,
    required this.dailyLimit,
    required this.endBalance,
    required this.shortfall,
  });

  final String label;
  final DateTime startDate;
  final DateTime endDate;
  final int days;
  final double startBalance;
  final double obligations;
  final double incomeAtEnd;
  final double dailyLimit;
  final double endBalance;
  final bool shortfall;
}

class NextIncome {
  NextIncome({
    required this.name,
    required this.date,
    required this.amount,
    required this.daysUntil,
  });

  final String name;
  final DateTime date;
  final double amount;
  final int daysUntil;
}

class CashflowForecast {
  CashflowForecast({
    required this.currentBalance,
    required this.reserve,
    required this.baseCurrency,
    required this.segments,
    required this.nextIncome,
    required this.dailyUntilNextIncome,
    required this.smoothedDaily,
    required this.horizonEnd,
    required this.range,
    required this.hasCashGap,
    required this.ok,
  });

  final double currentBalance;
  final double reserve;
  final String baseCurrency;
  final List<CashflowSegment> segments;
  final NextIncome? nextIncome;
  final double dailyUntilNextIncome;
  final double smoothedDaily;
  final DateTime? horizonEnd;

  /// The window the forecast was calculated over (null when no forecast).
  final CashflowRangeSummary? range;
  final bool hasCashGap;
  final bool ok;
}

class _CashEvent {
  _CashEvent({required this.date, required this.amount, required this.name});
  final DateTime date;
  final double amount;
  final String name;
}

/// Current balance per account = initialBalance + income − expense ± transfers,
/// each account's running total converted into [baseCurrency].
double computeCurrentBalance({
  required List<Account> accounts,
  required List<Transaction> transactions,
  CurrencyConvert? convert,
  String baseCurrency = 'BYN',
}) {
  final conv = convert ?? (num amount, String from, String to) => amount;
  double total = 0;
  for (final a in accounts) {
    final b = accountBalance(
      account: a,
      transactions: transactions,
      accounts: accounts,
      convert: conv,
    );
    total += conv(b, a.currency, baseCurrency).toDouble();
  }
  return total;
}

/// Result of walking the windows between a start date and a horizon end.
typedef _Walk = ({
  List<CashflowSegment> segments,
  double smoothedDaily,
  bool hasCashGap,
  double totalIncome,
  double totalObligations,
});

/// Project a cash runway from the current balance over a chosen window and work
/// out a safe spend-per-day for each segment and for the whole window.
///
/// The window is controlled by [rangeMode] (default `auto` = until the next
/// salary, preserving the original behaviour). All figures derive from the real
/// current balance across accounts, so the card and the budget cycles stay
/// consistent. Mirrors `computeCashflowForecast` in
/// `src/lib/finance/budgetPlanner.ts`.
CashflowForecast computeCashflowForecast({
  required List<Account> accounts,
  required List<Transaction> transactions,
  required List<IncomeSource> incomeSources,
  required List<PlannedExpense> plannedExpenses,
  CurrencyConvert? convert,
  String baseCurrency = 'BYN',
  double reserve = 0,
  DateTime? today,
  int horizonDays = 45,
  CashflowRangeMode rangeMode = CashflowRangeMode.auto,
  DateTime? customStart,
  DateTime? customEnd,
  List<String> accountIds = const [],
}) {
  final conv = convert ?? (num amount, String from, String to) => amount;
  final now = today ?? DateTime.now();
  DateTime startOf(DateTime d) => DateTime(d.year, d.month, d.day);
  final startOfToday = startOf(now);
  final selectedAccounts = accountIds.isEmpty
      ? accounts
      : accounts.where((a) => accountIds.contains(a.id)).toList();
  final currentBalance = computeCurrentBalance(
    accounts: selectedAccounts,
    transactions: transactions,
    convert: conv,
    baseCurrency: baseCurrency,
  );

  CashflowForecast empty() => CashflowForecast(
        currentBalance: currentBalance,
        reserve: reserve,
        baseCurrency: baseCurrency,
        segments: const [],
        nextIncome: null,
        dailyUntilNextIncome: 0,
        smoothedDaily: 0,
        horizonEnd: null,
        range: null,
        hasCashGap: false,
        ok: false,
      );

  final active = incomeSources.where((s) => s.isActive).toList();
  if (active.isEmpty) return empty();

  double toBase(double amount, String currency) =>
      conv(amount, currency, baseCurrency).toDouble();

  // Build income occurrences across the next several months (enough to find a
  // second advance/salary for the repeating-cycle modes).
  final incomeEvents = <_CashEvent>[];
  final advanceDates = <DateTime>[];
  final salaryDates = <DateTime>[];
  DateTime? firstSalary;
  for (var k = 0; k <= 6; k++) {
    final ym = _addMonth(now.year, now.month, k);
    for (final src in active) {
      final date = getPayDate(src, ym.year, ym.month);
      if (date == null) continue;
      if (!_isAfter(date, startOfToday)) continue;
      if (src.type == IncomeSourceType.salary) {
        if (firstSalary == null || _isBefore(date, firstSalary)) {
          firstSalary = date;
        }
        salaryDates.add(date);
      }
      if (src.type == IncomeSourceType.advance) advanceDates.add(date);
      incomeEvents.add(_CashEvent(
        date: date,
        amount: toBase(src.amount, src.currency),
        name: src.name,
      ));
    }
  }
  incomeEvents.sort((a, b) => a.date.compareTo(b.date));
  advanceDates.sort((a, b) => a.compareTo(b));
  salaryDates.sort((a, b) => a.compareTo(b));

  final nextIncomeDate = incomeEvents.isNotEmpty ? incomeEvents.first.date : null;
  final furthestCandidates = incomeEvents
      .map((e) => e.date)
      .where((d) => _diffDays(startOfToday, d) <= horizonDays)
      .toList()
    ..sort((a, b) => b.compareTo(a));
  final furthestWithinHorizon =
      furthestCandidates.isNotEmpty ? furthestCandidates.first : null;

  // Resolve the window [rangeStart, horizonEnd] from the requested mode.
  var rangeStart = startOfToday;
  DateTime? horizonEnd;
  switch (rangeMode) {
    case CashflowRangeMode.next:
      horizonEnd = nextIncomeDate;
      break;
    case CashflowRangeMode.advanceToAdvance:
      horizonEnd = advanceDates.length > 1
          ? advanceDates[1]
          : (advanceDates.isNotEmpty ? advanceDates[0] : null);
      break;
    case CashflowRangeMode.salaryToSalary:
      horizonEnd = salaryDates.length > 1
          ? salaryDates[1]
          : (salaryDates.isNotEmpty ? salaryDates[0] : null);
      break;
    case CashflowRangeMode.fullHorizon:
      horizonEnd = furthestWithinHorizon;
      break;
    case CashflowRangeMode.custom:
      rangeStart = customStart != null ? startOf(customStart) : startOfToday;
      horizonEnd = customEnd != null ? startOf(customEnd) : null;
      break;
    case CashflowRangeMode.auto:
      horizonEnd = firstSalary ?? furthestWithinHorizon;
      break;
  }
  // Fall back to the broadest sensible horizon if the requested one is missing.
  horizonEnd ??= firstSalary ?? furthestWithinHorizon ?? nextIncomeDate;
  if (horizonEnd == null || !_isAfter(horizonEnd, startOfToday)) return empty();
  if (_isBefore(rangeStart, startOfToday)) rangeStart = startOfToday;
  if (!_isAfter(horizonEnd, rangeStart)) return empty();
  final horizonEndFinal = horizonEnd;

  // Build obligation occurrences (unpaid planned expenses) at their deadline.
  final obligations = <_CashEvent>[];
  for (final exp in plannedExpenses) {
    if (!exp.isActive || exp.isPaid) continue;
    for (var k = 0; k <= 6; k++) {
      final ym = _addMonth(now.year, now.month, k);
      final dim = DateTime(ym.year, ym.month + 1, 0).day;
      final dayCandidate =
          exp.dayTo != 0 ? exp.dayTo : (exp.dayFrom != 0 ? exp.dayFrom : dim);
      final day = dayCandidate.clamp(1, dim);
      final date = DateTime(ym.year, ym.month, day);
      if (_isAfter(date, startOfToday) && !_isAfter(date, horizonEndFinal)) {
        obligations.add(_CashEvent(
          date: date,
          amount: toBase(exp.amount, exp.currency),
          name: exp.name,
        ));
      }
    }
  }

  /// Walk the windows between [from] and [to], splitting at each income event.
  _Walk walk(DateTime from, double startBalance, DateTime to) {
    final incs = incomeEvents
        .where((e) => _isAfter(e.date, from) && !_isAfter(e.date, to))
        .toList();
    final boundaries = <({DateTime date, double income, String? name})>[
      for (final e in incs) (date: e.date, income: e.amount, name: e.name),
    ];
    final last = boundaries.isNotEmpty ? boundaries.last : null;
    if ((last == null || _isBefore(last.date, to)) && _isAfter(to, from)) {
      boundaries.add((date: to, income: 0.0, name: null));
    }

    final segs = <CashflowSegment>[];
    var cursor = from;
    var balance = startBalance;
    var gap = false;
    var smoothed = double.infinity;
    var cumDays = 0;
    var cumObligations = 0.0;
    var cumIncomeBefore = 0.0;
    var totalIncome = 0.0;
    var totalObligations = 0.0;

    for (var i = 0; i < boundaries.length; i++) {
      final b = boundaries[i];
      final days = _diffDays(cursor, b.date).clamp(1, 1 << 30);
      final segObligations = obligations
          .where((o) => _isAfter(o.date, cursor) || _isSameDayD(o.date, cursor))
          .where((o) => !_isAfter(o.date, b.date))
          .fold<double>(0, (sum, o) => sum + o.amount);

      final spendable = balance - reserve - segObligations;
      final dailyLimit = spendable > 0 ? spendable / days : 0.0;
      final shortfall = spendable < 0;
      if (shortfall) gap = true;

      final endBalance = balance - segObligations - dailyLimit * days + b.income;
      final prevName = i > 0 ? boundaries[i - 1].name : null;
      final label = i == 0
          ? (b.name != null ? 'До «${b.name}»' : 'До конца периода')
          : (b.name != null
              ? '«${prevName ?? '…'}» → «${b.name}»'
              : '«${prevName ?? '…'}» → конец периода');

      segs.add(CashflowSegment(
        label: label,
        startDate: cursor,
        endDate: b.date,
        days: days,
        startBalance: balance,
        obligations: segObligations,
        incomeAtEnd: b.income,
        dailyLimit: dailyLimit,
        endBalance: endBalance,
        shortfall: shortfall,
      ));

      cumDays += days;
      cumObligations += segObligations;
      final feasibleBefore =
          startBalance + cumIncomeBefore - cumObligations - reserve;
      final perDay = feasibleBefore / cumDays;
      if (perDay < smoothed) smoothed = perDay;
      cumIncomeBefore += b.income;
      // Income arriving exactly at the window's closing boundary belongs to the
      // next cycle, so it is not spendable inside this window.
      if (_isBefore(b.date, to)) totalIncome += b.income;
      totalObligations += segObligations;

      balance = endBalance;
      cursor = b.date;
    }

    return (
      segments: segs,
      smoothedDaily:
          smoothed == double.infinity ? 0.0 : (smoothed > 0 ? smoothed : 0.0),
      hasCashGap: gap,
      totalIncome: totalIncome,
      totalObligations: totalObligations,
    );
  }

  // Project the balance forward to a future window start (custom ranges only),
  // assuming no discretionary spend before the window opens.
  var startBalance = currentBalance;
  if (_isAfter(rangeStart, startOfToday)) {
    var projected = currentBalance;
    for (final e in incomeEvents) {
      if (_isAfter(e.date, startOfToday) && !_isAfter(e.date, rangeStart)) {
        projected += e.amount;
      }
    }
    for (final o in obligations) {
      if (_isAfter(o.date, startOfToday) && !_isAfter(o.date, rangeStart)) {
        projected -= o.amount;
      }
    }
    startBalance = projected;
  }

  final rangeWalk = walk(rangeStart, startBalance, horizonEndFinal);
  if (rangeWalk.segments.isEmpty) return empty();

  // Headline "until next income" is always measured from today, even when the
  // selected window starts later.
  final headline =
      nextIncomeDate != null ? walk(startOfToday, currentBalance, nextIncomeDate) : null;
  final dailyUntilNextIncome =
      rangeStart.isAtSameMomentAs(startOfToday)
          ? (rangeWalk.segments.isNotEmpty ? rangeWalk.segments.first.dailyLimit : 0.0)
          : (headline != null && headline.segments.isNotEmpty
              ? headline.segments.first.dailyLimit
              : 0.0);

  final next = incomeEvents.isNotEmpty ? incomeEvents.first : null;

  return CashflowForecast(
    currentBalance: currentBalance,
    reserve: reserve,
    baseCurrency: baseCurrency,
    segments: rangeWalk.segments,
    nextIncome: next != null
        ? NextIncome(
            name: next.name,
            date: next.date,
            amount: next.amount,
            daysUntil: _diffDays(startOfToday, next.date).clamp(0, 1 << 30),
          )
        : null,
    dailyUntilNextIncome: dailyUntilNextIncome,
    smoothedDaily: rangeWalk.smoothedDaily,
    horizonEnd: horizonEndFinal,
    range: CashflowRangeSummary(
      mode: rangeMode,
      label: cashflowRangeLabels[rangeMode]!,
      startDate: rangeStart,
      endDate: horizonEndFinal,
      days: _diffDays(rangeStart, horizonEndFinal).clamp(1, 1 << 30),
      daysLeft: _diffDays(startOfToday, horizonEndFinal).clamp(0, 1 << 30),
      startBalance: startBalance,
      totalIncome: rangeWalk.totalIncome,
      totalObligations: rangeWalk.totalObligations,
      smoothedDaily: rangeWalk.smoothedDaily,
    ),
    hasCashGap: rangeWalk.hasCashGap,
    ok: true,
  );
}

// ── Spending averages (actual history) ──
//
// Groups real income/expense transactions by calendar month (converted to the
// base currency via each account's currency) and derives average daily and
// monthly figures. Shared by the monthly-analysis section (P3) and the
// average-based forecast scenarios in the safe-to-spend card (P3b). Mirrors
// `computeSpendingAverages` in `src/lib/finance/budgetPlanner.ts`.

/// Per-month actual totals plus the average daily figures for that month.
class MonthlySpending {
  MonthlySpending({
    required this.monthKey,
    required this.year,
    required this.month,
    required this.totalExpense,
    required this.totalIncome,
    required this.net,
    required this.days,
    required this.avgDailyExpense,
    required this.avgDailyIncome,
  });

  /// 'yyyy-MM'.
  final String monthKey;
  final int year;

  /// 1-based (Dart convention).
  final int month;
  final double totalExpense;
  final double totalIncome;
  final double net;

  /// Days counted for averaging (elapsed days for the current month).
  final int days;
  final double avgDailyExpense;
  final double avgDailyIncome;
}

class SpendingAverages {
  SpendingAverages({
    required this.months,
    required this.avgDailyExpense,
    required this.avgDailyIncome,
    required this.avgMonthlyExpense,
    required this.avgMonthlyIncome,
    required this.monthsCounted,
  });

  /// Months with activity, oldest → newest.
  final List<MonthlySpending> months;
  final double avgDailyExpense;
  final double avgDailyIncome;
  final double avgMonthlyExpense;
  final double avgMonthlyIncome;
  final int monthsCounted;

  static SpendingAverages empty() => SpendingAverages(
        months: const [],
        avgDailyExpense: 0,
        avgDailyIncome: 0,
        avgMonthlyExpense: 0,
        avgMonthlyIncome: 0,
        monthsCounted: 0,
      );
}

/// Compute average daily / monthly expense and income from actual transactions.
///
/// Only `income` and `expense` transactions count (transfers move money between
/// own accounts and are ignored). Amounts are converted from each account's
/// currency into [baseCurrency]. The window spans the most recent [monthsBack]
/// calendar months (including the current, partial one); the current month is
/// averaged over the days elapsed so far so its daily rate isn't diluted.
SpendingAverages computeSpendingAverages({
  required List<Account> accounts,
  required List<Transaction> transactions,
  CurrencyConvert? convert,
  String baseCurrency = 'BYN',
  DateTime? today,
  int monthsBack = 6,
  List<String> accountIds = const [],
}) {
  final conv = convert ?? (num amount, String from, String to) => amount;
  final now = today ?? DateTime.now();
  final selected = accountIds.isEmpty
      ? accounts
      : accounts.where((a) => accountIds.contains(a.id)).toList();
  if (selected.isEmpty) return SpendingAverages.empty();
  final selectedIds = selected.map((a) => a.id).toSet();

  final windowStart =
      _addMonth(now.year, now.month, -((monthsBack < 1 ? 1 : monthsBack) - 1));
  final startKey =
      '${windowStart.year}-${windowStart.month.toString().padLeft(2, '0')}';
  final curKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

  final buckets = <String, ({double expense, double income})>{};
  for (final t in transactions) {
    if (t.type != TransactionType.income && t.type != TransactionType.expense) {
      continue;
    }
    if (t.accountId == null || !selectedIds.contains(t.accountId)) continue;
    if (t.date.length < 7) continue;
    final key = t.date.substring(0, 7); // 'yyyy-MM'
    if (key.compareTo(startKey) < 0 || key.compareTo(curKey) > 0) continue;
    final base =
        conv(t.amount, _txCurrency(t, accounts, baseCurrency), baseCurrency)
            .toDouble();
    final cur = buckets[key] ?? (expense: 0.0, income: 0.0);
    buckets[key] = t.type == TransactionType.expense
        ? (expense: cur.expense + base, income: cur.income)
        : (expense: cur.expense, income: cur.income + base);
  }

  if (buckets.isEmpty) return SpendingAverages.empty();
  final keys = buckets.keys.toList()..sort();

  final months = <MonthlySpending>[];
  var sumExpense = 0.0;
  var sumIncome = 0.0;
  var sumDays = 0;
  for (final key in keys) {
    final parts = key.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]); // 1-based
    final b = buckets[key]!;
    final days = key == curKey
        ? (now.day < 1 ? 1 : now.day)
        : DateTime(year, month + 1, 0).day;
    months.add(MonthlySpending(
      monthKey: key,
      year: year,
      month: month,
      totalExpense: b.expense,
      totalIncome: b.income,
      net: b.income - b.expense,
      days: days,
      avgDailyExpense: b.expense / days,
      avgDailyIncome: b.income / days,
    ));
    sumExpense += b.expense;
    sumIncome += b.income;
    sumDays += days;
  }

  final monthsCounted = months.length;
  return SpendingAverages(
    months: months,
    avgDailyExpense: sumDays > 0 ? sumExpense / sumDays : 0,
    avgDailyIncome: sumDays > 0 ? sumIncome / sumDays : 0,
    avgMonthlyExpense: monthsCounted > 0 ? sumExpense / monthsCounted : 0,
    avgMonthlyIncome: monthsCounted > 0 ? sumIncome / monthsCounted : 0,
    monthsCounted: monthsCounted,
  );
}

// ── Safe-to-spend forecast scenarios (P3b) ──
//
// On top of a chosen window (`computeCashflowForecast`), project the ending
// balance under different spending assumptions. Critical guard against
// double-counting obligations:
//   • planToZero / customDaily — the daily figure is *discretionary* spend, so
//     planned obligations are subtracted on top.
//   • avgExpense / avgExpenseIncome — the daily figure is the *complete*
//     historical spend (obligations already inside it), so obligations are NOT
//     subtracted again. Mirrors `computeScenarioProjection` in
//     `src/lib/finance/budgetPlanner.ts`.

enum SafeToSpendScenario {
  /// Safe discretionary spend/day to reach the window end at the reserve.
  planToZero,

  /// User enters their own daily spend; we project the ending balance.
  customDaily,

  /// Daily = historical average expense/day; planned income kept.
  avgExpense,

  /// Daily = historical average expense/day AND income = historical average.
  avgExpenseIncome,
}

const Map<SafeToSpendScenario, String> scenarioLabels = {
  SafeToSpendScenario.planToZero: 'План «в 0»',
  SafeToSpendScenario.customDaily: 'Свой лимит/день',
  SafeToSpendScenario.avgExpense: 'Средний расход',
  SafeToSpendScenario.avgExpenseIncome: 'Средние расход + доход',
};

class ScenarioProjection {
  ScenarioProjection({
    required this.scenario,
    required this.dailySpend,
    required this.income,
    required this.obligations,
    required this.daysLeft,
    required this.startBalance,
    required this.endBalance,
    required this.surplusOverReserve,
    required this.shortfall,
    required this.insufficientHistory,
  });

  final SafeToSpendScenario scenario;
  final double dailySpend;
  final double income;
  final double obligations;
  final int daysLeft;
  final double startBalance;
  final double endBalance;
  final double surplusOverReserve;
  final bool shortfall;
  final bool insufficientHistory;
}

/// Project the ending balance for a forecast window under a chosen scenario.
/// Returns null when the forecast produced no window.
ScenarioProjection? computeScenarioProjection({
  required SafeToSpendScenario scenario,
  required CashflowForecast forecast,
  double? reserve,
  SpendingAverages? averages,
  double? customDaily,
}) {
  final range = forecast.range;
  if (range == null) return null;
  final res = reserve ?? forecast.reserve;

  final startBalance = range.startBalance;
  final daysLeft = range.daysLeft;
  var dailySpend = 0.0;
  var income = range.totalIncome;
  var obligations = range.totalObligations;
  var insufficientHistory = false;

  switch (scenario) {
    case SafeToSpendScenario.planToZero:
      dailySpend = range.smoothedDaily;
      break;
    case SafeToSpendScenario.customDaily:
      dailySpend = (customDaily ?? 0) < 0 ? 0 : (customDaily ?? 0);
      break;
    case SafeToSpendScenario.avgExpense:
      dailySpend = averages?.avgDailyExpense ?? 0;
      obligations = 0; // already inside the historical average
      insufficientHistory = averages == null || averages.monthsCounted == 0;
      break;
    case SafeToSpendScenario.avgExpenseIncome:
      dailySpend = averages?.avgDailyExpense ?? 0;
      obligations = 0; // already inside the historical average
      income = (averages?.avgDailyIncome ?? 0) * daysLeft;
      insufficientHistory = averages == null || averages.monthsCounted == 0;
      break;
  }

  final endBalance = startBalance + income - obligations - dailySpend * daysLeft;
  final surplusOverReserve = endBalance - res;
  final shortfall = scenario == SafeToSpendScenario.planToZero
      ? forecast.hasCashGap
      : endBalance < res;

  return ScenarioProjection(
    scenario: scenario,
    dailySpend: dailySpend,
    income: income,
    obligations: obligations,
    daysLeft: daysLeft,
    startBalance: startBalance,
    endBalance: endBalance,
    surplusOverReserve: surplusOverReserve,
    shortfall: shortfall,
    insufficientHistory: insufficientHistory,
  );
}

// ── Month-vs-month comparison (P4) ──
//
// Compares the actual income/expense of two calendar months (converted to the
// base currency), including per-category expense deltas. Built directly from
// real transactions. Mirrors `computeMonthlyComparison` in
// `src/lib/finance/budgetPlanner.ts`.

/// One month's actual totals plus its per-category expense breakdown.
class MonthComparisonSide {
  MonthComparisonSide({
    required this.monthKey,
    required this.year,
    required this.month,
    required this.totalExpense,
    required this.totalIncome,
    required this.net,
    required this.byCategory,
  });

  /// 'yyyy-MM'.
  final String monthKey;
  final int year;

  /// 1-based (Dart convention).
  final int month;
  final double totalExpense;
  final double totalIncome;
  final double net;

  /// Expense per category (base currency).
  final Map<String, double> byCategory;
}

/// Per-category expense delta between the two compared months (b − a).
class CategoryDelta {
  CategoryDelta({
    required this.category,
    required this.a,
    required this.b,
    required this.delta,
  });

  final String category;
  final double a;
  final double b;

  /// b − a: positive = spent more in month b.
  final double delta;
}

class MonthlyComparison {
  MonthlyComparison({
    required this.a,
    required this.b,
    required this.expenseDelta,
    required this.incomeDelta,
    required this.netDelta,
    required this.categories,
  });

  final MonthComparisonSide a;
  final MonthComparisonSide b;

  /// b − a for each total.
  final double expenseDelta;
  final double incomeDelta;
  final double netDelta;

  /// Per-category expense deltas, sorted by |delta| descending.
  final List<CategoryDelta> categories;
}

MonthComparisonSide _emptyComparisonSide(String monthKey) {
  final parts = monthKey.split('-');
  final year = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 0) : 0;
  final month = parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1;
  return MonthComparisonSide(
    monthKey: monthKey,
    year: year,
    month: month,
    totalExpense: 0,
    totalIncome: 0,
    net: 0,
    byCategory: {},
  );
}

/// Compare the actual income/expense of two calendar months (`'yyyy-MM'`).
///
/// Transfers are ignored; amounts are converted from each account's currency to
/// [baseCurrency]. Deltas are computed as `b − a` so a positive expense delta
/// means month `b` spent more. `categories` lists every expense category present
/// in either month, sorted by the magnitude of the change.
MonthlyComparison computeMonthlyComparison({
  required List<Account> accounts,
  required List<Transaction> transactions,
  required String monthKeyA,
  required String monthKeyB,
  CurrencyConvert? convert,
  String baseCurrency = 'BYN',
  List<String> accountIds = const [],
}) {
  final conv = convert ?? (num amount, String from, String to) => amount;
  final selectedIds = accountIds.isEmpty
      ? accounts.map((a) => a.id).toSet()
      : accountIds.toSet();

  final a = _emptyComparisonSide(monthKeyA);
  final b = _emptyComparisonSide(monthKeyB);
  var aIncome = 0.0, aExpense = 0.0, bIncome = 0.0, bExpense = 0.0;

  for (final t in transactions) {
    if (t.type != TransactionType.income && t.type != TransactionType.expense) {
      continue;
    }
    if (t.accountId == null || !selectedIds.contains(t.accountId)) continue;
    if (t.date.length < 7) continue;
    final key = t.date.substring(0, 7);
    final MonthComparisonSide? side =
        key == monthKeyA ? a : (key == monthKeyB ? b : null);
    if (side == null) continue;
    final base =
        conv(t.amount, _txCurrency(t, accounts, baseCurrency), baseCurrency)
            .toDouble();
    if (t.type == TransactionType.income) {
      if (side == a) {
        aIncome += base;
      } else {
        bIncome += base;
      }
    } else {
      if (side == a) {
        aExpense += base;
      } else {
        bExpense += base;
      }
      final cat = t.category.isEmpty ? 'Без категории' : t.category;
      side.byCategory[cat] = (side.byCategory[cat] ?? 0) + base;
    }
  }

  final aSide = MonthComparisonSide(
    monthKey: a.monthKey,
    year: a.year,
    month: a.month,
    totalExpense: aExpense,
    totalIncome: aIncome,
    net: aIncome - aExpense,
    byCategory: a.byCategory,
  );
  final bSide = MonthComparisonSide(
    monthKey: b.monthKey,
    year: b.year,
    month: b.month,
    totalExpense: bExpense,
    totalIncome: bIncome,
    net: bIncome - bExpense,
    byCategory: b.byCategory,
  );

  final cats = <String>{...aSide.byCategory.keys, ...bSide.byCategory.keys};
  final categories = <CategoryDelta>[];
  for (final category in cats) {
    final av = aSide.byCategory[category] ?? 0;
    final bv = bSide.byCategory[category] ?? 0;
    categories.add(CategoryDelta(category: category, a: av, b: bv, delta: bv - av));
  }
  categories.sort((x, y) => y.delta.abs().compareTo(x.delta.abs()));

  return MonthlyComparison(
    a: aSide,
    b: bSide,
    expenseDelta: bSide.totalExpense - aSide.totalExpense,
    incomeDelta: bSide.totalIncome - aSide.totalIncome,
    netDelta: bSide.net - aSide.net,
    categories: categories,
  );
}
