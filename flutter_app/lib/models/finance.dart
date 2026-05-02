import 'enums.dart';

typedef Currency = String;

class Account {
  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.initialBalance,
    required this.color,
    required this.createdAt,
  });

  final String id;
  final String name;
  final AccountType type;
  final Currency currency;
  final num initialBalance;
  final String color;
  final String createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'currency': currency,
        'initialBalance': initialBalance,
        'color': color,
        'createdAt': createdAt,
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        name: json['name'] as String,
        type: enumFromName(
            AccountType.values, json['type'] as String?, AccountType.card),
        currency: (json['currency'] ?? 'BYN') as String,
        initialBalance: (json['initialBalance'] ?? 0) as num,
        color: (json['color'] ?? '#6D5CFF') as String,
        createdAt: json['createdAt'] as String,
      );
}

class Transaction {
  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    this.notes,
    this.photoUrl,
    this.paymentMethod,
    this.cashGiven,
    this.accountId,
    this.toAccountId,
    this.tags,
    this.source,
  });

  final String id;
  final TransactionType type;
  final num amount;
  final String category;
  final String date;
  final String? notes;
  final String? photoUrl;
  final PaymentMethod? paymentMethod;
  final num? cashGiven;
  final String? accountId;
  final String? toAccountId;
  final List<String>? tags;
  final String? source;

  Transaction copyWith({
    TransactionType? type,
    num? amount,
    String? category,
    String? date,
    String? notes,
    String? accountId,
    String? toAccountId,
    List<String>? tags,
    String? source,
  }) {
    return Transaction(
      id: id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      photoUrl: photoUrl,
      paymentMethod: paymentMethod,
      cashGiven: cashGiven,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      tags: tags ?? this.tags,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'category': category,
        'date': date,
        if (notes != null) 'notes': notes,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (paymentMethod != null) 'paymentMethod': paymentMethod!.name,
        if (cashGiven != null) 'cashGiven': cashGiven,
        if (accountId != null) 'accountId': accountId,
        if (toAccountId != null) 'toAccountId': toAccountId,
        if (tags != null) 'tags': tags,
        if (source != null) 'source': source,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        type: enumFromName(TransactionType.values, json['type'] as String?,
            TransactionType.expense),
        amount: (json['amount'] ?? 0) as num,
        category: (json['category'] ?? '') as String,
        date: json['date'] as String,
        notes: json['notes'] as String?,
        photoUrl: json['photoUrl'] as String?,
        paymentMethod: json['paymentMethod'] != null
            ? enumFromName(PaymentMethod.values,
                json['paymentMethod'] as String?, PaymentMethod.card)
            : null,
        cashGiven: json['cashGiven'] as num?,
        accountId: json['accountId'] as String?,
        toAccountId: json['toAccountId'] as String?,
        tags: (json['tags'] as List?)?.whereType<String>().toList(),
        source: json['source'] as String?,
      );
}

class BudgetLimit {
  BudgetLimit({
    required this.id,
    required this.category,
    required this.amount,
    this.currency,
    this.period = 'month',
  });

  final String id;
  final String category;
  final num amount;
  final Currency? currency;
  final String period;

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'amount': amount,
        if (currency != null) 'currency': currency,
        'period': period,
      };

  factory BudgetLimit.fromJson(Map<String, dynamic> json) => BudgetLimit(
        id: json['id'] as String,
        category: (json['category'] ?? '') as String,
        amount: (json['amount'] ?? 0) as num,
        currency: json['currency'] as String?,
        period: (json['period'] ?? 'month') as String,
      );
}

class CategoryPlan {
  CategoryPlan({required this.category, required this.planned});
  final String category;
  final num planned;

  Map<String, dynamic> toJson() =>
      {'category': category, 'planned': planned};

  factory CategoryPlan.fromJson(Map<String, dynamic> json) => CategoryPlan(
        category: (json['category'] ?? '') as String,
        planned: (json['planned'] ?? 0) as num,
      );
}

class MonthlyBudgetPlan {
  MonthlyBudgetPlan({
    required this.id,
    required this.monthKey,
    required this.plannedIncome,
    required this.categoryPlans,
    required this.createdAt,
    required this.updatedAt,
    this.currency,
    this.freeFundsTarget,
    this.rollover,
    this.notes,
  });

  final String id;
  final String monthKey;
  final num plannedIncome;
  final Currency? currency;
  final List<CategoryPlan> categoryPlans;
  final num? freeFundsTarget;
  final bool? rollover;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'monthKey': monthKey,
        'plannedIncome': plannedIncome,
        if (currency != null) 'currency': currency,
        'categoryPlans': categoryPlans.map((e) => e.toJson()).toList(),
        if (freeFundsTarget != null) 'freeFundsTarget': freeFundsTarget,
        if (rollover != null) 'rollover': rollover,
        if (notes != null) 'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory MonthlyBudgetPlan.fromJson(Map<String, dynamic> json) =>
      MonthlyBudgetPlan(
        id: json['id'] as String,
        monthKey: json['monthKey'] as String,
        plannedIncome: (json['plannedIncome'] ?? 0) as num,
        currency: json['currency'] as String?,
        categoryPlans: (json['categoryPlans'] as List? ?? const [])
            .whereType<Map>()
            .map((e) =>
                CategoryPlan.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
            .toList(),
        freeFundsTarget: json['freeFundsTarget'] as num?,
        rollover: json['rollover'] as bool?,
        notes: json['notes'] as String?,
        createdAt: json['createdAt'] as String,
        updatedAt: json['updatedAt'] as String,
      );
}
