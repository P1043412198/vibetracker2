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

/// Monthly budget config — one per month, identified by [monthKey].
class BudgetPlanConfig {
  BudgetPlanConfig({
    required this.monthKey,
    required this.incomeSources,
    required this.plannedExpenses,
    required this.actualExpenses,
    this.linkedAccountIds = const [],
  });

  /// `YYYY-MM` key for this month's budget.
  final String monthKey;
  final List<IncomeSource> incomeSources;
  final List<PlannedExpense> plannedExpenses;
  final List<ActualExpense> actualExpenses;

  /// Account IDs to track balance from (empty = all accounts).
  final List<String> linkedAccountIds;

  factory BudgetPlanConfig.empty({String? monthKey}) {
    final now = DateTime.now();
    return BudgetPlanConfig(
      monthKey: monthKey ??
          '${now.year}-${now.month.toString().padLeft(2, '0')}',
      incomeSources: [],
      plannedExpenses: [],
      actualExpenses: [],
    );
  }

  /// Create next month's config from this one (rollover).
  BudgetPlanConfig rolloverToMonth(String newMonthKey) {
    return BudgetPlanConfig(
      monthKey: newMonthKey,
      incomeSources: incomeSources
          .map((s) => IncomeSource(
                id: _uuid.v4(),
                name: s.name,
                type: s.type,
                amount: s.amount,
                currency: s.currency,
                dayOfMonth: s.dayOfMonth,
                adjustForHolidays: s.adjustForHolidays,
                isActive: s.isActive,
                createdAt: DateTime.now().toIso8601String(),
              ))
          .toList(),
      plannedExpenses: plannedExpenses
          .map((e) => PlannedExpense(
                id: _uuid.v4(),
                name: e.name,
                amount: e.amount,
                currency: e.currency,
                dayFrom: e.dayFrom,
                dayTo: e.dayTo,
                category: e.category,
                isActive: e.isActive,
                createdAt: DateTime.now().toIso8601String(),
              ))
          .toList(),
      actualExpenses: [],
      linkedAccountIds: linkedAccountIds,
    );
  }

  BudgetPlanConfig copyWith({
    List<IncomeSource>? incomeSources,
    List<PlannedExpense>? plannedExpenses,
    List<ActualExpense>? actualExpenses,
    List<String>? linkedAccountIds,
  }) {
    return BudgetPlanConfig(
      monthKey: monthKey,
      incomeSources: incomeSources ?? this.incomeSources,
      plannedExpenses: plannedExpenses ?? this.plannedExpenses,
      actualExpenses: actualExpenses ?? this.actualExpenses,
      linkedAccountIds: linkedAccountIds ?? this.linkedAccountIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'monthKey': monthKey,
        'incomeSources': incomeSources.map((e) => e.toJson()).toList(),
        'plannedExpenses': plannedExpenses.map((e) => e.toJson()).toList(),
        'actualExpenses': actualExpenses.map((e) => e.toJson()).toList(),
        'linkedAccountIds': linkedAccountIds,
      };

  factory BudgetPlanConfig.fromJson(Map<String, dynamic> j) {
    return BudgetPlanConfig(
      monthKey: (j['monthKey'] ?? '') as String,
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
      linkedAccountIds: (j['linkedAccountIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

/// Top-level store: all monthly budget configs.
class BudgetPlanStore {
  BudgetPlanStore({
    required this.months,
    required this.selectedMonthKey,
  });

  final List<BudgetPlanConfig> months;
  final String selectedMonthKey;

  BudgetPlanConfig get currentMonth {
    return months.firstWhere(
      (m) => m.monthKey == selectedMonthKey,
      orElse: () => BudgetPlanConfig.empty(monthKey: selectedMonthKey),
    );
  }

  factory BudgetPlanStore.empty() {
    final now = DateTime.now();
    final key = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return BudgetPlanStore(months: [], selectedMonthKey: key);
  }

  Map<String, dynamic> toJson() => {
        'months': months.map((m) => m.toJson()).toList(),
        'selectedMonthKey': selectedMonthKey,
      };

  factory BudgetPlanStore.fromJson(Map<String, dynamic> j) {
    final now = DateTime.now();
    final defaultKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return BudgetPlanStore(
      months: (j['months'] as List?)
              ?.whereType<Map>()
              .map((e) => BudgetPlanConfig.fromJson(
                  e.map((k, v) => MapEntry(k.toString(), v))))
              .toList() ??
          [],
      selectedMonthKey:
          (j['selectedMonthKey'] ?? defaultKey) as String,
    );
  }

  /// Migrate from old single-config format.
  factory BudgetPlanStore.migrateFromLegacy(Map<String, dynamic> j) {
    final config = BudgetPlanConfig.fromJson(j);
    final now = DateTime.now();
    final key = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final migrated = BudgetPlanConfig(
      monthKey: key,
      incomeSources: config.incomeSources,
      plannedExpenses: config.plannedExpenses,
      actualExpenses: config.actualExpenses,
    );
    return BudgetPlanStore(months: [migrated], selectedMonthKey: key);
  }
}
