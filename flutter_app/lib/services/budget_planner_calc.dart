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
