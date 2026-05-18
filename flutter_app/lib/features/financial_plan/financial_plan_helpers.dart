import '../../models/finance.dart';
import '../../models/enums.dart';
import '../../models/financial_plan_month.dart';

/// Result of summing a scenario's items by section kind.
class FinPlanSummary {
  FinPlanSummary({
    required this.income,
    required this.expense,
    required this.savings,
    required this.debt,
    required this.custom,
  });

  final double income;
  final double expense;
  final double savings;
  final double debt;
  final double custom;

  double get balance => income - expense - savings - debt;
}

/// Compute total amounts grouped by section kind. The resulting `expense`
/// is positive (subtracted from income inside [balance]).
FinPlanSummary computeSummary(
  FinPlanScenario scenario,
  List<Transaction> transactions,
  String monthKey,
) {
  // Real transactions are reserved for future overlays at section/scenario
  // level; for now we only sum the planned amounts.
  // ignore: unused_local_variable
  final unusedTx = transactions;
  // ignore: unused_local_variable
  final unusedKey = monthKey;
  double income = 0;
  double expense = 0;
  double savings = 0;
  double debt = 0;
  double custom = 0;
  for (final section in scenario.sections) {
    final total = section.items.fold<double>(0, (sum, it) => sum + it.amount);
    switch (section.kind) {
      case FinPlanSectionKind.income:
        income += total;
        break;
      case FinPlanSectionKind.expense:
        expense += total;
        break;
      case FinPlanSectionKind.savings:
        savings += total;
        break;
      case FinPlanSectionKind.debt:
        debt += total;
        break;
      case FinPlanSectionKind.custom:
        custom += total;
        break;
    }
  }
  return FinPlanSummary(
    income: income,
    expense: expense,
    savings: savings,
    debt: debt,
    custom: custom,
  );
}

/// Sum of real transactions matching [item.linkedCategory] inside [monthKey].
/// Returns 0 if the item has no linked category or no transactions match.
double factForItem(
  FinPlanItem item,
  List<Transaction> transactions,
  String monthKey,
) {
  if (item.linkedCategory == null || item.linkedCategory!.isEmpty) return 0;
  return transactions
      .where((t) => t.date.startsWith(monthKey))
      .where((t) => t.category == item.linkedCategory)
      .fold<double>(0, (sum, t) => sum + t.amount.toDouble());
}

/// Real income / expense for the month (used in roadmap headers).
class MonthFact {
  MonthFact({required this.income, required this.expense});
  final double income;
  final double expense;
}

MonthFact factForMonth(List<Transaction> transactions, String monthKey) {
  double income = 0;
  double expense = 0;
  for (final t in transactions) {
    if (!t.date.startsWith(monthKey)) continue;
    if (t.type == TransactionType.income) {
      income += t.amount.toDouble();
    } else if (t.type == TransactionType.expense) {
      expense += t.amount.toDouble();
    }
  }
  return MonthFact(income: income, expense: expense);
}

/// `2026-05` for any [DateTime] (UTC offset is irrelevant — we only care
/// about year + month).
String monthKeyForDate(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  return '${d.year}-$m';
}

/// Parse `YYYY-MM` back into a [DateTime] anchored at the 1st of the month.
DateTime? parseMonthKey(String? key) {
  if (key == null || key.isEmpty) return null;
  final parts = key.split('-');
  if (parts.length != 2) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null) return null;
  if (month < 1 || month > 12) return null;
  return DateTime(year, month, 1);
}

/// Suggest the next monthKey that is not yet taken by an existing plan.
/// Defaults to «current month», then «next month», then advances until a
/// gap is found.
String nextEmptyMonthKey(List<FinancialPlanMonth> existing) {
  final taken = {for (final p in existing) p.monthKey};
  var d = DateTime(DateTime.now().year, DateTime.now().month, 1);
  for (var i = 0; i < 36; i++) {
    final key = monthKeyForDate(d);
    if (!taken.contains(key)) return key;
    d = DateTime(d.year, d.month + 1, 1);
  }
  return monthKeyForDate(DateTime.now());
}

/// Russian human label `«Май 2026»` for `2026-05`.
String humanMonth(String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) return monthKey;
  final year = parts[0];
  final m = int.tryParse(parts[1]);
  if (m == null) return monthKey;
  const names = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];
  return '${names[(m - 1).clamp(0, 11)]} $year';
}

/// 0..1 progress through the month for the «roadmap» indicator.
double monthProgress(DateTime now, String monthKey) {
  final start = parseMonthKey(monthKey);
  if (start == null) return 0;
  if (now.year != start.year || now.month != start.month) {
    final cmp = DateTime(now.year, now.month, now.day)
        .compareTo(DateTime(start.year, start.month, 1));
    return cmp < 0 ? 0 : 1;
  }
  final daysInMonth = DateTime(start.year, start.month + 1, 0).day;
  return (now.day / daysInMonth).clamp(0.0, 1.0);
}

/// Russian label for a section kind ("Доход", "Расход", ...).
String labelForSectionKind(FinPlanSectionKind kind) {
  switch (kind) {
    case FinPlanSectionKind.income:
      return 'Доход';
    case FinPlanSectionKind.expense:
      return 'Расход';
    case FinPlanSectionKind.savings:
      return 'Сбережения';
    case FinPlanSectionKind.debt:
      return 'Долги/кредиты';
    case FinPlanSectionKind.custom:
      return 'Другое';
  }
}

int defaultColorForKind(FinPlanSectionKind kind) {
  switch (kind) {
    case FinPlanSectionKind.income:
      return 0xFF22C55E;
    case FinPlanSectionKind.expense:
      return 0xFFEF4444;
    case FinPlanSectionKind.savings:
      return 0xFF6366F1;
    case FinPlanSectionKind.debt:
      return 0xFFF59E0B;
    case FinPlanSectionKind.custom:
      return 0xFF14B8A6;
  }
}
