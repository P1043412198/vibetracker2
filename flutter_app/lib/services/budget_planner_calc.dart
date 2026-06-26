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

/// Check if a planned income source has a matching real income transaction.
/// Matches by: amount within 20% tolerance, date within ±5 days of pay date.
bool _isIncomeReceived({
  required IncomeSource source,
  required DateTime? payDate,
  required List<Transaction> incomeTxs,
  required List<Account> accounts,
  required CurrencyConvert? convert,
  required String baseCurrency,
}) {
  if (payDate == null || incomeTxs.isEmpty || convert == null) return false;

  for (final t in incomeTxs) {
    // Date within ±5 days
    final txDate = DateTime.tryParse(t.date);
    if (txDate == null) continue;
    final diff = (txDate.difference(payDate).inDays).abs();
    if (diff > 5) continue;

    // Amount within 20% tolerance
    final txAmt =
        convert(t.amount, _txCurrency(t, accounts, baseCurrency), baseCurrency)
            .toDouble();
    final ratio = source.amount > 0 ? txAmt / source.amount : 0.0;
    if (ratio >= 0.8 && ratio <= 1.2) return true;
  }
  return false;
}

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

/// Calculate budget cycles using real account balance as the base.
///
/// Logic:
/// 1. Account balance = real money available now (includes leftover from
///    previous months)
/// 2. Check each planned income: if it already arrived as a real transaction,
///    it is already inside the account balance — do NOT add again.
///    If it hasn't arrived yet, add it as pending future income.
/// 3. Subtract unpaid planned expenses (including loans → see [loans] param).
/// 4. Divide by remaining days = real daily/weekly budget.
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
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final year = now.year;
  final month = now.month;
  final cycles = <BudgetCycle>[];

  final activeSources = incomeSources.where((s) => s.isActive).toList();
  final salarySource =
      activeSources.where((s) => s.type == IncomeSourceType.salary).firstOrNull;
  final advanceSource =
      activeSources.where((s) => s.type == IncomeSourceType.advance).firstOrNull;
  final additionalSources =
      activeSources.where((s) => s.type == IncomeSourceType.additional).toList();
  final additionalTotal =
      additionalSources.fold<double>(0, (sum, s) => sum + s.amount);

  if (salarySource == null && advanceSource == null) return cycles;

  final salaryDate =
      salarySource != null ? getPayDate(salarySource, year, month) : null;
  final advanceDate =
      advanceSource != null ? getPayDate(advanceSource, year, month) : null;

  final nextMonth = month == 12 ? 1 : month + 1;
  final nextYear = month == 12 ? year + 1 : year;
  final nextSalaryDate = salarySource != null
      ? getPayDate(salarySource, nextYear, nextMonth)
      : null;

  final monthKey = '$year-${month.toString().padLeft(2, '0')}';

  // Unified ecosystem: append virtual planned expenses derived from active
  // loans so the daily/weekly budget already accounts for credit payments.
  final loanExpenses = loansAsPlannedExpenses(
    loans: loans,
    convert: convert,
    baseCurrency: baseCurrency,
    monthKey: monthKey,
    loanPayments: loanPayments,
  );
  final activeExpenses = [
    ...plannedExpenses.where((e) => e.isActive),
    ...loanExpenses,
  ];

  // Gather real income transactions this month for matching
  final realIncomeTxs = transactions
      .where(
          (t) => t.type == TransactionType.income && t.date.startsWith(monthKey))
      .toList();

  // Determine which planned income sources have already been received
  final salaryReceived = salarySource != null &&
      _isIncomeReceived(
        source: salarySource,
        payDate: salaryDate,
        incomeTxs: realIncomeTxs,
        accounts: accounts,
        convert: convert,
        baseCurrency: baseCurrency,
      );
  final advanceReceived = advanceSource != null &&
      _isIncomeReceived(
        source: advanceSource,
        payDate: advanceDate,
        incomeTxs: realIncomeTxs,
        accounts: accounts,
        convert: convert,
        baseCurrency: baseCurrency,
      );

  // Helper: unpaid planned expenses in date range
  double unpaidExpensesInRange(DateTime start, DateTime end) {
    return activeExpenses
        .where((e) {
          if (e.isPaid) return false;
          final expDay = e.dayFrom;
          final startDay = start.day;
          final endDay = end.day;
          if (start.month == end.month) {
            return expDay >= startDay && expDay <= endDay;
          }
          return expDay >= startDay || expDay <= endDay;
        })
        .fold<double>(0, (sum, e) => sum + e.amount);
  }

  // Paid expenses total (already spent — reflected in account balance)
  double paidExpensesTotal() {
    return activeExpenses
        .where((e) => e.isPaid)
        .fold<double>(0, (sum, e) => sum + (e.paidAmount ?? e.amount));
  }

  // Manual actual expenses total
  double manualActualTotal() {
    return actualExpenses.fold<double>(0, (sum, e) => sum + e.amount);
  }

  /// Build a cycle using account balance as the real base.
  ///
  /// remaining = accountBalance
  ///           + pendingIncome (planned income not yet received)
  ///           - unpaidPlannedExpenses
  /// dailyBudget = remaining / daysLeft
  BudgetCycle buildCycle(
    String label,
    DateTime startDate,
    DateTime endDate, {
    required double plannedIncome,
    required double pendingIncome,
    required double receivedIncome,
  }) {
    final totalDays = _diffDays(startDate, endDate);
    final daysFromToday = _isBefore(now, startDate)
        ? totalDays
        : (_diffDays(now, endDate)).clamp(1, totalDays);
    final unpaidExpenses = unpaidExpensesInRange(startDate, endDate);
    final totalActualSpent = paidExpensesTotal() + manualActualTotal();

    // Real remaining money:
    // Account balance already has: leftover + received income - actual spent
    // We add only pending (future) income and subtract only unpaid expenses
    final remaining = accountBalance + pendingIncome - unpaidExpenses;
    final daily = daysFromToday > 0 ? remaining / daysFromToday : 0.0;
    final fullWeeks = daysFromToday ~/ 7;
    final extraDays = daysFromToday % 7;

    return BudgetCycle(
      label: label,
      startDate: startDate,
      endDate: endDate,
      totalDays: totalDays,
      daysLeft: daysFromToday,
      totalIncome: plannedIncome,
      totalPlannedExpenses: unpaidExpenses,
      remainingAfterExpenses: accountBalance + pendingIncome,
      actualSpent: totalActualSpent,
      remainingBudget: remaining,
      dailyBudget: daily > 0 ? daily : 0,
      weeklyBudget: daily > 0 ? daily * 7 : 0,
      fullWeeks: fullWeeks,
      extraDays: extraDays,
      accountBalance: accountBalance,
      receivedIncome: receivedIncome,
      pendingIncome: pendingIncome,
      useAccountBase: true,
    );
  }

  // ── Cycle 1: Salary → Advance ──
  if (salaryDate != null &&
      advanceDate != null &&
      _isBefore(salaryDate, advanceDate)) {
    // In this cycle, salary should be the income.
    // If salary already received → it's in the account balance.
    // Advance is NOT in this cycle yet.
    final salaryAmt = salarySource!.amount;
    final pending = salaryReceived ? 0.0 : salaryAmt;
    final received = salaryReceived ? salaryAmt : 0.0;
    cycles.add(buildCycle(
      'От зарплаты до аванса',
      salaryDate,
      advanceDate,
      plannedIncome: salaryAmt,
      pendingIncome: pending,
      receivedIncome: received,
    ));
  }

  // ── Cycle 2: Advance → Next Salary ──
  if (advanceDate != null && nextSalaryDate != null) {
    final advanceAmt = advanceSource!.amount;
    final pending = advanceReceived ? 0.0 : advanceAmt;
    final received = advanceReceived ? advanceAmt : 0.0;
    cycles.add(buildCycle(
      'От аванса до зарплаты',
      advanceDate,
      nextSalaryDate,
      plannedIncome: advanceAmt,
      pendingIncome: pending,
      receivedIncome: received,
    ));
  }

  // ── Cycle 3: Salary → Next Salary (full cycle) ──
  if (salaryDate != null && nextSalaryDate != null) {
    final totalPlanned = (salarySource?.amount ?? 0) +
        (advanceSource?.amount ?? 0) +
        additionalTotal;
    double pending = 0;
    double received = 0;
    if (salarySource != null) {
      if (salaryReceived) {
        received += salarySource.amount;
      } else {
        pending += salarySource.amount;
      }
    }
    if (advanceSource != null) {
      if (advanceReceived) {
        received += advanceSource.amount;
      } else {
        pending += advanceSource.amount;
      }
    }
    // Additional income: assume not yet received (conservative)
    pending += additionalTotal;

    cycles.add(buildCycle(
      'От зарплаты до зарплаты',
      salaryDate,
      nextSalaryDate,
      plannedIncome: totalPlanned,
      pendingIncome: pending,
      receivedIncome: received,
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

/// Project a cash runway from the current balance until the next salary (or the
/// furthest income within [horizonDays] when there is no salary source), and
/// work out a safe spend-per-day for each window and for the whole horizon.
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
}) {
  final conv = convert ?? (num amount, String from, String to) => amount;
  final now = today ?? DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final currentBalance = computeCurrentBalance(
    accounts: accounts,
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
        hasCashGap: false,
        ok: false,
      );

  final active = incomeSources.where((s) => s.isActive).toList();
  if (active.isEmpty) return empty();

  double toBase(double amount, String currency) =>
      conv(amount, currency, baseCurrency).toDouble();

  // Build income occurrences across the next few months.
  final incomeEvents = <_CashEvent>[];
  DateTime? firstSalary;
  for (var k = 0; k <= 3; k++) {
    final ym = _addMonth(now.year, now.month, k);
    for (final src in active) {
      final date = getPayDate(src, ym.year, ym.month);
      if (date == null) continue;
      if (!_isAfter(date, startOfToday)) continue;
      if (src.type == IncomeSourceType.salary &&
          (firstSalary == null || _isBefore(date, firstSalary))) {
        firstSalary = date;
      }
      incomeEvents.add(_CashEvent(
        date: date,
        amount: toBase(src.amount, src.currency),
        name: src.name,
      ));
    }
  }

  // Horizon: up to and including the next salary; otherwise the furthest income
  // within horizonDays.
  DateTime? horizonEnd = firstSalary;
  if (horizonEnd == null) {
    final candidates = incomeEvents
        .map((e) => e.date)
        .where((d) => _diffDays(startOfToday, d) <= horizonDays)
        .toList()
      ..sort((a, b) => b.compareTo(a));
    horizonEnd = candidates.isNotEmpty ? candidates.first : null;
  }
  if (horizonEnd == null) return empty();

  final incomesInHorizon = incomeEvents
      .where((e) => !_isAfter(e.date, horizonEnd!))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  if (incomesInHorizon.isEmpty) return empty();

  // Build obligation occurrences (unpaid planned expenses) at their deadline.
  final obligations = <_CashEvent>[];
  for (final exp in plannedExpenses) {
    if (!exp.isActive || exp.isPaid) continue;
    for (var k = 0; k <= 3; k++) {
      final ym = _addMonth(now.year, now.month, k);
      final dim = DateTime(ym.year, ym.month + 1, 0).day;
      final dayCandidate = exp.dayTo != 0 ? exp.dayTo : (exp.dayFrom != 0 ? exp.dayFrom : dim);
      final day = dayCandidate.clamp(1, dim);
      final date = DateTime(ym.year, ym.month, day);
      if (_isAfter(date, startOfToday) && !_isAfter(date, horizonEnd)) {
        obligations.add(_CashEvent(
          date: date,
          amount: toBase(exp.amount, exp.currency),
          name: exp.name,
        ));
      }
    }
  }

  // Walk segments between today and each income boundary.
  final segments = <CashflowSegment>[];
  var cursor = startOfToday;
  var balance = currentBalance;
  var hasCashGap = false;

  // Feasibility accumulators for the smoothed daily figure.
  var smoothedDaily = double.infinity;
  var cumDays = 0;
  var cumObligations = 0.0;
  var cumIncomeBefore = 0.0;

  for (var i = 0; i < incomesInHorizon.length; i++) {
    final inc = incomesInHorizon[i];
    final days = _diffDays(cursor, inc.date).clamp(1, 1 << 30);
    final segObligations = obligations
        .where((o) => _isAfter(o.date, cursor) || _isSameDayD(o.date, cursor))
        .where((o) => !_isAfter(o.date, inc.date))
        .fold<double>(0, (sum, o) => sum + o.amount);

    final spendable = balance - reserve - segObligations;
    final dailyLimit = spendable > 0 ? spendable / days : 0.0;
    final shortfall = spendable < 0;
    if (shortfall) hasCashGap = true;

    final endBalance = balance - segObligations - dailyLimit * days + inc.amount;

    segments.add(CashflowSegment(
      label: i == 0
          ? 'До «${inc.name}»'
          : '«${incomesInHorizon[i - 1].name}» → «${inc.name}»',
      startDate: cursor,
      endDate: inc.date,
      days: days,
      startBalance: balance,
      obligations: segObligations,
      incomeAtEnd: inc.amount,
      dailyLimit: dailyLimit,
      endBalance: endBalance,
      shortfall: shortfall,
    ));

    // Smoothed daily: keep balance ≥ reserve just before each income arrives.
    cumDays += days;
    cumObligations += segObligations;
    final feasibleBefore =
        currentBalance + cumIncomeBefore - cumObligations - reserve;
    final perDay = feasibleBefore / cumDays;
    if (perDay < smoothedDaily) smoothedDaily = perDay;
    cumIncomeBefore += inc.amount;

    balance = endBalance;
    cursor = inc.date;
  }

  final next = incomesInHorizon.first;
  return CashflowForecast(
    currentBalance: currentBalance,
    reserve: reserve,
    baseCurrency: baseCurrency,
    segments: segments,
    nextIncome: NextIncome(
      name: next.name,
      date: next.date,
      amount: next.amount,
      daysUntil: _diffDays(startOfToday, next.date).clamp(0, 1 << 30),
    ),
    dailyUntilNextIncome: segments.isNotEmpty ? segments.first.dailyLimit : 0,
    smoothedDaily:
        smoothedDaily == double.infinity ? 0 : (smoothedDaily > 0 ? smoothedDaily : 0),
    horizonEnd: horizonEnd,
    hasCashGap: hasCashGap,
    ok: true,
  );
}
