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
bool _isBeforeOrSame(DateTime a, DateTime b) => _diffDays(a, b) >= 0;

/// Calculate budget cycles based on income sources and expenses.
/// Now also considers real transactions for actual spending.
List<BudgetCycle> computeBudgetCycles({
  required List<IncomeSource> incomeSources,
  required List<PlannedExpense> plannedExpenses,
  required List<ActualExpense> actualExpenses,
  List<Transaction> transactions = const [],
  List<Account> accounts = const [],
  CurrencyConvert? convert,
  String baseCurrency = 'BYN',
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
  final additionalTotal = activeSources
      .where((s) => s.type == IncomeSourceType.additional)
      .fold<double>(0, (sum, s) => sum + s.amount);

  if (salarySource == null && advanceSource == null) return cycles;

  final salaryDate =
      salarySource != null ? getPayDate(salarySource, year, month) : null;
  final advanceDate =
      advanceSource != null ? getPayDate(advanceSource, year, month) : null;

  final nextMonth = month == 12 ? 1 : month + 1;
  final nextYear = month == 12 ? year + 1 : year;
  final nextSalaryDate =
      salarySource != null ? getPayDate(salarySource, nextYear, nextMonth) : null;

  final activeExpenses = plannedExpenses.where((e) => e.isActive).toList();

  double expensesInRange(DateTime start, DateTime end) {
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

  double paidExpensesInRange(DateTime start, DateTime end) {
    return activeExpenses
        .where((e) => e.isPaid && e.paidDate != null)
        .where((e) {
          final d = DateTime.tryParse(e.paidDate!);
          if (d == null) return false;
          return _isBeforeOrSame(start, d) && _isBeforeOrSame(d, end);
        })
        .fold<double>(0, (sum, e) => e.paidAmount ?? e.amount);
  }

  double manualActualInRange(DateTime start, DateTime end) {
    return actualExpenses
        .where((e) {
          final d = DateTime.tryParse(e.date);
          if (d == null) return false;
          return _isBeforeOrSame(start, d) && _isBeforeOrSame(d, end);
        })
        .fold<double>(0, (sum, e) => sum + e.amount);
  }

  double realTransactionExpensesInRange(DateTime start, DateTime end) {
    if (transactions.isEmpty || convert == null) return 0;
    final fmt = DateFormat('yyyy-MM-dd');
    final startStr = fmt.format(start);
    final endStr = fmt.format(end);
    return transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.compareTo(startStr) >= 0 &&
            t.date.compareTo(endStr) <= 0)
        .fold<double>(0, (sum, t) {
      final cur = _txCurrency(t, accounts, baseCurrency);
      return sum + convert(t.amount, cur, baseCurrency).toDouble();
    });
  }

  BudgetCycle buildCycle(
      String label, DateTime startDate, DateTime endDate, double income) {
    final totalDays = _diffDays(startDate, endDate);
    final daysFromToday = _isBefore(now, startDate)
        ? totalDays
        : (_diffDays(now, endDate)).clamp(1, totalDays);
    final expenses = expensesInRange(startDate, endDate);
    final paid = paidExpensesInRange(startDate, endDate);
    final manual = manualActualInRange(startDate, endDate);
    final realTx = realTransactionExpensesInRange(startDate, endDate);
    final totalSpent = paid + manual + realTx;
    final remaining = income - expenses - totalSpent;
    final daily = daysFromToday > 0 ? remaining / daysFromToday : 0.0;
    final fullWeeks = daysFromToday ~/ 7;
    final extraDays = daysFromToday % 7;

    return BudgetCycle(
      label: label,
      startDate: startDate,
      endDate: endDate,
      totalDays: totalDays,
      daysLeft: daysFromToday,
      totalIncome: income,
      totalPlannedExpenses: expenses,
      remainingAfterExpenses: income - expenses,
      actualSpent: totalSpent,
      remainingBudget: remaining,
      dailyBudget: daily > 0 ? daily : 0,
      weeklyBudget: daily > 0 ? daily * 7 : 0,
      fullWeeks: fullWeeks,
      extraDays: extraDays,
    );
  }

  // Cycle 1: Salary → Advance
  if (salaryDate != null &&
      advanceDate != null &&
      _isBefore(salaryDate, advanceDate)) {
    cycles.add(buildCycle(
      'От зарплаты до аванса',
      salaryDate,
      advanceDate,
      salarySource!.amount,
    ));
  }

  // Cycle 2: Advance → Next Salary
  if (advanceDate != null && nextSalaryDate != null) {
    cycles.add(buildCycle(
      'От аванса до зарплаты',
      advanceDate,
      nextSalaryDate,
      advanceSource!.amount,
    ));
  }

  // Cycle 3: Salary → Next Salary (full cycle)
  if (salaryDate != null && nextSalaryDate != null) {
    final totalIncome = (salarySource?.amount ?? 0) +
        (advanceSource?.amount ?? 0) +
        additionalTotal;
    cycles.add(buildCycle(
      'От зарплаты до зарплаты',
      salaryDate,
      nextSalaryDate,
      totalIncome,
    ));
  }

  return cycles;
}
