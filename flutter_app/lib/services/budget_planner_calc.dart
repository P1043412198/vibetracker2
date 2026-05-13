/// Budget planner calculation service — port of `src/lib/finance/budgetPlanner.ts`.
///
/// Computes actual pay dates for salary/advance considering Belarus weekends
/// and public holidays, and calculates daily/weekly allowances between pay cycles.

import 'package:intl/intl.dart';

import '../finance/by_holidays.dart';
import '../models/budget_planner.dart';

/// Returns the last working day on or before [dayOfMonth] in [year]/[month].
/// Adjusts backward for weekends and Belarus holidays.
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
    targetDay = DateTime(year, month + 1, 0).day; // last day of month
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

int _diffDays(DateTime a, DateTime b) {
  final aDate = DateTime(a.year, a.month, a.day);
  final bDate = DateTime(b.year, b.month, b.day);
  return bDate.difference(aDate).inDays;
}

bool _isBefore(DateTime a, DateTime b) => _diffDays(a, b) > 0;
bool _isBeforeOrSame(DateTime a, DateTime b) => _diffDays(a, b) >= 0;

/// Calculate budget cycles based on income sources and expenses.
/// Returns cycles: salary→advance, advance→salary, salary→salary.
List<BudgetCycle> computeBudgetCycles({
  required List<IncomeSource> incomeSources,
  required List<PlannedExpense> plannedExpenses,
  required List<ActualExpense> actualExpenses,
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

  final salaryDate = salarySource != null ? getPayDate(salarySource, year, month) : null;
  final advanceDate = advanceSource != null ? getPayDate(advanceSource, year, month) : null;

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

  double actualSpentInRange(DateTime start, DateTime end) {
    return actualExpenses
        .where((e) {
          final d = DateTime.tryParse(e.date);
          if (d == null) return false;
          return _isBeforeOrSame(start, d) && _isBeforeOrSame(d, end);
        })
        .fold<double>(0, (sum, e) => sum + e.amount);
  }

  BudgetCycle buildCycle(String label, DateTime startDate, DateTime endDate, double income) {
    final totalDays = _diffDays(startDate, endDate);
    final daysFromToday = _isBefore(now, startDate)
        ? totalDays
        : (_diffDays(now, endDate)).clamp(1, totalDays);
    final expenses = expensesInRange(startDate, endDate);
    final paid = paidExpensesInRange(startDate, endDate);
    final actual = actualSpentInRange(startDate, endDate);
    final totalSpent = paid + actual;
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
  if (salaryDate != null && advanceDate != null && _isBefore(salaryDate, advanceDate)) {
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
    final totalIncome =
        (salarySource?.amount ?? 0) + (advanceSource?.amount ?? 0) + additionalTotal;
    cycles.add(buildCycle(
      'От зарплаты до зарплаты',
      salaryDate,
      nextSalaryDate,
      totalIncome,
    ));
  }

  return cycles;
}
