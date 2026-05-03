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
  CategoryPlan({
    required this.category,
    required this.planned,
    this.dueDay,
  });
  final String category;
  final num planned;

  /// Optional day-of-month (1..31) when this expense actually leaves the
  /// account — used by the period-aware daily-allowance calculator. When
  /// null, the expense is treated as evenly spread over the month.
  final int? dueDay;

  CategoryPlan copyWith({
    String? category,
    num? planned,
    Object? dueDay = _planSentinel,
  }) =>
      CategoryPlan(
        category: category ?? this.category,
        planned: planned ?? this.planned,
        dueDay:
            identical(dueDay, _planSentinel) ? this.dueDay : dueDay as int?,
      );

  Map<String, dynamic> toJson() => {
        'category': category,
        'planned': planned,
        if (dueDay != null) 'dueDay': dueDay,
      };

  factory CategoryPlan.fromJson(Map<String, dynamic> json) => CategoryPlan(
        category: (json['category'] ?? '') as String,
        planned: (json['planned'] ?? 0) as num,
        dueDay: (json['dueDay'] as num?)?.toInt(),
      );
}

const Object _planSentinel = Object();

/// Phase 14: scheduled income line inside a monthly plan. Captures multiple
/// salary/bonus inflows with the day they arrive so the daily-allowance
/// calculator can split the month into periods.
class IncomeEntry {
  IncomeEntry({
    required this.id,
    required this.name,
    required this.amount,
    required this.day,
  });

  final String id;
  final String name;
  final num amount;

  /// Day-of-month (1..31). Day > daysInMonth is clamped to the last day.
  final int day;

  IncomeEntry copyWith({String? name, num? amount, int? day}) => IncomeEntry(
        id: id,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        day: day ?? this.day,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'day': day,
      };

  factory IncomeEntry.fromJson(Map<String, dynamic> json) => IncomeEntry(
        id: (json['id'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        amount: (json['amount'] ?? 0) as num,
        day: (json['day'] as num?)?.toInt() ?? 1,
      );
}

/// Phase 17: a single one-off planned expense bound to a date.
/// Sits alongside `CategoryPlan` (which is monthly limit per category) and
/// represents concrete bills like "internet on the 25th", "rent on the 1st".
class ScheduledExpense {
  ScheduledExpense({
    required this.id,
    required this.name,
    required this.amount,
    required this.day,
    this.category,
  });

  final String id;
  final String name;
  final num amount;

  /// Day-of-month (1..31). Day > daysInMonth is clamped to the last day.
  final int day;
  final String? category;

  ScheduledExpense copyWith(
          {String? name, num? amount, int? day, String? category}) =>
      ScheduledExpense(
        id: id,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        day: day ?? this.day,
        category: category ?? this.category,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'day': day,
        if (category != null) 'category': category,
      };

  factory ScheduledExpense.fromJson(Map<String, dynamic> json) =>
      ScheduledExpense(
        id: (json['id'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        amount: (json['amount'] ?? 0) as num,
        day: (json['day'] as num?)?.toInt() ?? 1,
        category: json['category'] as String?,
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
    this.freeFundsCarryover,
    this.notes,
    this.excludedAccountIds,
    this.incomes,
    this.scheduledExpenses,
  });

  final String id;
  final String monthKey;
  final num plannedIncome;
  final Currency? currency;
  final List<CategoryPlan> categoryPlans;
  final num? freeFundsTarget;
  final bool? rollover;

  /// Phase 18: when true, leftover free funds from the previous month are
  /// rolled into this month's free-funds pool. This is independent of
  /// per-category [rollover] (which only carries unused category limit).
  final bool? freeFundsCarryover;

  final String? notes;
  final String createdAt;
  final String updatedAt;
  // Phase 12: account ids to ignore when computing plan facts (e.g. emergency
  // fund / savings buckets that shouldn't be drawn down by month-to-month
  // budgeting).
  final List<String>? excludedAccountIds;

  /// Phase 14: scheduled income lines (e.g. salary on the 5th, bonus on the
  /// 25th). When non-empty, [plannedIncome] is treated as a fallback total —
  /// the period-aware daily-allowance calculator uses individual entries.
  final List<IncomeEntry>? incomes;

  /// Phase 17: one-off planned expenses bound to specific dates
  /// (e.g. "интернет 25го", "квартплата 1го"). They feed cashflow
  /// directly so "свободно/день" shifts on each due date.
  final List<ScheduledExpense>? scheduledExpenses;

  MonthlyBudgetPlan copyWith({
    num? plannedIncome,
    Currency? currency,
    List<CategoryPlan>? categoryPlans,
    num? freeFundsTarget,
    bool? rollover,
    bool? freeFundsCarryover,
    String? notes,
    List<String>? excludedAccountIds,
    List<IncomeEntry>? incomes,
    List<ScheduledExpense>? scheduledExpenses,
    String? updatedAt,
  }) =>
      MonthlyBudgetPlan(
        id: id,
        monthKey: monthKey,
        plannedIncome: plannedIncome ?? this.plannedIncome,
        currency: currency ?? this.currency,
        categoryPlans: categoryPlans ?? this.categoryPlans,
        freeFundsTarget: freeFundsTarget ?? this.freeFundsTarget,
        rollover: rollover ?? this.rollover,
        freeFundsCarryover: freeFundsCarryover ?? this.freeFundsCarryover,
        notes: notes ?? this.notes,
        excludedAccountIds: excludedAccountIds ?? this.excludedAccountIds,
        incomes: incomes ?? this.incomes,
        scheduledExpenses: scheduledExpenses ?? this.scheduledExpenses,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'monthKey': monthKey,
        'plannedIncome': plannedIncome,
        if (currency != null) 'currency': currency,
        'categoryPlans': categoryPlans.map((e) => e.toJson()).toList(),
        if (freeFundsTarget != null) 'freeFundsTarget': freeFundsTarget,
        if (rollover != null) 'rollover': rollover,
        if (freeFundsCarryover != null)
          'freeFundsCarryover': freeFundsCarryover,
        if (notes != null) 'notes': notes,
        if (excludedAccountIds != null && excludedAccountIds!.isNotEmpty)
          'excludedAccountIds': excludedAccountIds,
        if (incomes != null && incomes!.isNotEmpty)
          'incomes': incomes!.map((e) => e.toJson()).toList(),
        if (scheduledExpenses != null && scheduledExpenses!.isNotEmpty)
          'scheduledExpenses':
              scheduledExpenses!.map((e) => e.toJson()).toList(),
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
        freeFundsCarryover: json['freeFundsCarryover'] as bool?,
        notes: json['notes'] as String?,
        excludedAccountIds: (json['excludedAccountIds'] as List?)
            ?.map((e) => e.toString())
            .toList(),
        incomes: (json['incomes'] as List?)
            ?.whereType<Map>()
            .map((e) => IncomeEntry.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v))))
            .toList(),
        scheduledExpenses: (json['scheduledExpenses'] as List?)
            ?.whereType<Map>()
            .map((e) => ScheduledExpense.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v))))
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
    this.paymentDay,
    this.termMonths,
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

  /// Phase 14: day-of-month (1..31) when the monthly payment is debited.
  /// Used by the monthly-plan period calculator and the "real free funds"
  /// dashboard widget.
  final int? paymentDay;

  /// Phase 14: full term in months (used to project total payoff & interest
  /// even when [endDate] is not set).
  final int? termMonths;

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
        if (paymentDay != null) 'paymentDay': paymentDay,
        if (termMonths != null) 'termMonths': termMonths,
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
        paymentDay: (json['paymentDay'] as num?)?.toInt(),
        termMonths: (json['termMonths'] as num?)?.toInt(),
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
    Object? paymentDay = _loanSentinel,
    Object? termMonths = _loanSentinel,
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
      paymentDay: identical(paymentDay, _loanSentinel)
          ? this.paymentDay
          : paymentDay as int?,
      termMonths: identical(termMonths, _loanSentinel)
          ? this.termMonths
          : termMonths as int?,
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
