/// Models for the budget planner (План Доходов / Расходов / Факт).
///
/// Port of `src/types.ts` IncomeSource, PlannedExpense, ActualExpense and
/// BudgetPlanConfig types.

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum IncomeSourceType { salary, advance, additional }

class IncomeSource {
  IncomeSource({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    this.currency = 'BYN',
    this.dayOfMonth,
    this.adjustForHolidays = true,
    this.isActive = true,
    required this.createdAt,
  });

  final String id;
  final String name;
  final IncomeSourceType type;
  final double amount;
  final String currency;
  final int? dayOfMonth;
  final bool adjustForHolidays;
  final bool isActive;
  final String createdAt;

  IncomeSource copyWith({
    String? name,
    IncomeSourceType? type,
    double? amount,
    String? currency,
    int? dayOfMonth,
    bool? adjustForHolidays,
    bool? isActive,
  }) {
    return IncomeSource(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      adjustForHolidays: adjustForHolidays ?? this.adjustForHolidays,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'amount': amount,
        'currency': currency,
        if (dayOfMonth != null) 'dayOfMonth': dayOfMonth,
        'adjustForHolidays': adjustForHolidays,
        'isActive': isActive,
        'createdAt': createdAt,
      };

  factory IncomeSource.fromJson(Map<String, dynamic> j) => IncomeSource(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        type: IncomeSourceType.values
            .firstWhere((e) => e.name == j['type'], orElse: () => IncomeSourceType.additional),
        amount: (j['amount'] as num).toDouble(),
        currency: (j['currency'] ?? 'BYN') as String,
        dayOfMonth: j['dayOfMonth'] as int?,
        adjustForHolidays: (j['adjustForHolidays'] ?? true) as bool,
        isActive: (j['isActive'] ?? true) as bool,
        createdAt: (j['createdAt'] ?? DateTime.now().toIso8601String()) as String,
      );

  factory IncomeSource.blank({
    required String name,
    required IncomeSourceType type,
    double amount = 0,
    int? dayOfMonth,
  }) =>
      IncomeSource(
        id: _uuid.v4(),
        name: name,
        type: type,
        amount: amount,
        dayOfMonth: dayOfMonth,
        createdAt: DateTime.now().toIso8601String(),
      );
}

class PlannedExpense {
  PlannedExpense({
    required this.id,
    required this.name,
    required this.amount,
    this.currency = 'BYN',
    required this.dayFrom,
    required this.dayTo,
    this.category,
    this.isPaid = false,
    this.paidDate,
    this.paidAmount,
    this.isActive = true,
    required this.createdAt,
  });

  final String id;
  final String name;
  final double amount;
  final String currency;
  final int dayFrom;
  final int dayTo;
  final String? category;
  final bool isPaid;
  final String? paidDate;
  final double? paidAmount;
  final bool isActive;
  final String createdAt;

  PlannedExpense copyWith({
    String? name,
    double? amount,
    String? currency,
    int? dayFrom,
    int? dayTo,
    String? category,
    bool? isPaid,
    String? paidDate,
    double? paidAmount,
    bool? isActive,
    bool clearPaid = false,
  }) {
    return PlannedExpense(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      dayFrom: dayFrom ?? this.dayFrom,
      dayTo: dayTo ?? this.dayTo,
      category: category ?? this.category,
      isPaid: clearPaid ? false : (isPaid ?? this.isPaid),
      paidDate: clearPaid ? null : (paidDate ?? this.paidDate),
      paidAmount: clearPaid ? null : (paidAmount ?? this.paidAmount),
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'currency': currency,
        'dayFrom': dayFrom,
        'dayTo': dayTo,
        if (category != null) 'category': category,
        'isPaid': isPaid,
        if (paidDate != null) 'paidDate': paidDate,
        if (paidAmount != null) 'paidAmount': paidAmount,
        'isActive': isActive,
        'createdAt': createdAt,
      };

  factory PlannedExpense.fromJson(Map<String, dynamic> j) => PlannedExpense(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        amount: (j['amount'] as num).toDouble(),
        currency: (j['currency'] ?? 'BYN') as String,
        dayFrom: (j['dayFrom'] as num).toInt(),
        dayTo: (j['dayTo'] as num).toInt(),
        category: j['category'] as String?,
        isPaid: (j['isPaid'] ?? false) as bool,
        paidDate: j['paidDate'] as String?,
        paidAmount: j['paidAmount'] != null
            ? (j['paidAmount'] as num).toDouble()
            : null,
        isActive: (j['isActive'] ?? true) as bool,
        createdAt: (j['createdAt'] ?? DateTime.now().toIso8601String()) as String,
      );

  factory PlannedExpense.blank({
    required String name,
    double amount = 0,
    int dayFrom = 1,
    int dayTo = 31,
  }) =>
      PlannedExpense(
        id: _uuid.v4(),
        name: name,
        amount: amount,
        dayFrom: dayFrom,
        dayTo: dayTo,
        createdAt: DateTime.now().toIso8601String(),
      );
}

class ActualExpense {
  ActualExpense({
    required this.id,
    this.plannedExpenseId,
    required this.name,
    required this.amount,
    this.currency = 'BYN',
    required this.date,
    this.category,
  });

  final String id;
  final String? plannedExpenseId;
  final String name;
  final double amount;
  final String currency;
  final String date; // YYYY-MM-DD
  final String? category;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'currency': currency,
        'date': date,
        if (plannedExpenseId != null) 'plannedExpenseId': plannedExpenseId,
        if (category != null) 'category': category,
      };

  factory ActualExpense.fromJson(Map<String, dynamic> j) => ActualExpense(
        id: j['id'] as String,
        plannedExpenseId: j['plannedExpenseId'] as String?,
        name: (j['name'] ?? '') as String,
        amount: (j['amount'] as num).toDouble(),
        currency: (j['currency'] ?? 'BYN') as String,
        date: (j['date'] ?? '') as String,
        category: j['category'] as String?,
      );

  factory ActualExpense.blank({
    required String name,
    double amount = 0,
    required String date,
  }) =>
      ActualExpense(
        id: _uuid.v4(),
        name: name,
        amount: amount,
        date: date,
      );
}

/// Top-level container persisted as a single JSON map.
class BudgetPlanConfig {
  BudgetPlanConfig({
    required this.incomeSources,
    required this.plannedExpenses,
    required this.actualExpenses,
  });

  final List<IncomeSource> incomeSources;
  final List<PlannedExpense> plannedExpenses;
  final List<ActualExpense> actualExpenses;

  factory BudgetPlanConfig.empty() => BudgetPlanConfig(
        incomeSources: [],
        plannedExpenses: [],
        actualExpenses: [],
      );

  Map<String, dynamic> toJson() => {
        'incomeSources': incomeSources.map((e) => e.toJson()).toList(),
        'plannedExpenses': plannedExpenses.map((e) => e.toJson()).toList(),
        'actualExpenses': actualExpenses.map((e) => e.toJson()).toList(),
      };

  factory BudgetPlanConfig.fromJson(Map<String, dynamic> j) {
    return BudgetPlanConfig(
      incomeSources: (j['incomeSources'] as List?)
              ?.whereType<Map>()
              .map((e) => IncomeSource.fromJson(
                  e.map((k, v) => MapEntry(k.toString(), v))))
              .toList() ??
          [],
      plannedExpenses: (j['plannedExpenses'] as List?)
              ?.whereType<Map>()
              .map((e) => PlannedExpense.fromJson(
                  e.map((k, v) => MapEntry(k.toString(), v))))
              .toList() ??
          [],
      actualExpenses: (j['actualExpenses'] as List?)
              ?.whereType<Map>()
              .map((e) => ActualExpense.fromJson(
                  e.map((k, v) => MapEntry(k.toString(), v))))
              .toList() ??
          [],
    );
  }
}
