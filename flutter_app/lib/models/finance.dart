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
    this.merchant,
    this.receiptPaths,
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
  // Phase 11: cashier / merchant name parsed from receipt OCR.
  final String? merchant;
  // Phase 11: relative paths (under app docs `receipts/`) of receipt
  // photos. Multiple per transaction supported (front + back of slip etc).
  final List<String>? receiptPaths;

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
    String? merchant,
    List<String>? receiptPaths,
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
      merchant: merchant ?? this.merchant,
      receiptPaths: receiptPaths ?? this.receiptPaths,
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
        if (merchant != null) 'merchant': merchant,
        if (receiptPaths != null && receiptPaths!.isNotEmpty)
          'receiptPaths': receiptPaths,
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
        merchant: json['merchant'] as String?,
        receiptPaths:
            (json['receiptPaths'] as List?)?.whereType<String>().toList(),
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
    this.excludedAccountIds,
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
  // Phase 12: account ids to ignore when computing plan facts (e.g. emergency
  // fund / savings buckets that shouldn't be drawn down by month-to-month
  // budgeting).
  final List<String>? excludedAccountIds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'monthKey': monthKey,
        'plannedIncome': plannedIncome,
        if (currency != null) 'currency': currency,
        'categoryPlans': categoryPlans.map((e) => e.toJson()).toList(),
        if (freeFundsTarget != null) 'freeFundsTarget': freeFundsTarget,
        if (rollover != null) 'rollover': rollover,
        if (notes != null) 'notes': notes,
        if (excludedAccountIds != null && excludedAccountIds!.isNotEmpty)
          'excludedAccountIds': excludedAccountIds,
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
        excludedAccountIds: (json['excludedAccountIds'] as List?)
            ?.map((e) => e.toString())
            .toList(),
        createdAt: json['createdAt'] as String,
        updatedAt: json['updatedAt'] as String,
      );
}

/// Phase 13: kredit / loan tracker. Keeps the loan as a separate entity so
/// monthly payments can be projected without polluting the transaction log.
class Loan {
  Loan({
    required this.id,
    required this.title,
    required this.principal,
    required this.balance,
    required this.annualRate,
    required this.monthlyPayment,
    required this.startDate,
    required this.currency,
    this.endDate,
    this.accountId,
    this.notes,
    this.kind,
  });

  final String id;
  final String title;
  /// Original amount borrowed (in [currency]).
  final num principal;
  /// Current outstanding balance.
  final num balance;
  /// Annual interest rate, e.g. 21.5 means 21.5%.
  final num annualRate;
  /// Scheduled monthly payment (annuity).
  final num monthlyPayment;
  /// ISO date — first month the loan was issued.
  final String startDate;
  /// ISO date — projected end (optional).
  final String? endDate;
  final Currency currency;
  /// Optional account from which payments are drawn — used to compute net
  /// available money in the monthly plan.
  final String? accountId;
  final String? notes;
  /// 'consumer', 'mortgage', 'card', 'auto', 'personal', 'other'.
  final String? kind;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'principal': principal,
        'balance': balance,
        'annualRate': annualRate,
        'monthlyPayment': monthlyPayment,
        'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        'currency': currency,
        if (accountId != null) 'accountId': accountId,
        if (notes != null) 'notes': notes,
        if (kind != null) 'kind': kind,
      };

  factory Loan.fromJson(Map<String, dynamic> json) => Loan(
        id: json['id'] as String,
        title: (json['title'] ?? '') as String,
        principal: (json['principal'] ?? 0) as num,
        balance: (json['balance'] ?? 0) as num,
        annualRate: (json['annualRate'] ?? 0) as num,
        monthlyPayment: (json['monthlyPayment'] ?? 0) as num,
        startDate: (json['startDate'] ?? '') as String,
        endDate: json['endDate'] as String?,
        currency: (json['currency'] ?? 'BYN') as String,
        accountId: json['accountId'] as String?,
        notes: json['notes'] as String?,
        kind: json['kind'] as String?,
      );

  Loan copyWith({
    String? title,
    num? principal,
    num? balance,
    num? annualRate,
    num? monthlyPayment,
    String? startDate,
    Object? endDate = _loanSentinel,
    Currency? currency,
    Object? accountId = _loanSentinel,
    Object? notes = _loanSentinel,
    Object? kind = _loanSentinel,
  }) {
    return Loan(
      id: id,
      title: title ?? this.title,
      principal: principal ?? this.principal,
      balance: balance ?? this.balance,
      annualRate: annualRate ?? this.annualRate,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      startDate: startDate ?? this.startDate,
      endDate: identical(endDate, _loanSentinel)
          ? this.endDate
          : endDate as String?,
      currency: currency ?? this.currency,
      accountId: identical(accountId, _loanSentinel)
          ? this.accountId
          : accountId as String?,
      notes: identical(notes, _loanSentinel)
          ? this.notes
          : notes as String?,
      kind: identical(kind, _loanSentinel) ? this.kind : kind as String?,
    );
  }
}

const Object _loanSentinel = Object();

class LoanPayment {
  LoanPayment({
    required this.id,
    required this.loanId,
    required this.date,
    required this.amount,
    this.principalPart,
    this.interestPart,
    this.notes,
  });

  final String id;
  final String loanId;
  final String date;
  final num amount;
  final num? principalPart;
  final num? interestPart;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'loanId': loanId,
        'date': date,
        'amount': amount,
        if (principalPart != null) 'principalPart': principalPart,
        if (interestPart != null) 'interestPart': interestPart,
        if (notes != null) 'notes': notes,
      };

  factory LoanPayment.fromJson(Map<String, dynamic> json) => LoanPayment(
        id: json['id'] as String,
        loanId: json['loanId'] as String,
        date: json['date'] as String,
        amount: (json['amount'] ?? 0) as num,
        principalPart: json['principalPart'] as num?,
        interestPart: json['interestPart'] as num?,
        notes: json['notes'] as String?,
      );
}
