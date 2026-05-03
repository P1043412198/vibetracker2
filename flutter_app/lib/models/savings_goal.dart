/// Phase 19: a savings goal anchored to the finance plan.
///
/// Independent from the generic `Goal` model in `goal.dart` — that one is
/// used by the broader life-tracker (reading, weight, projects, …). This
/// one is a finance-specific cup with target, currency and an optional
/// deadline so the planning tab can compute "хватит ли при текущей скорости
/// откладывания свободного остатка".
class SavingsGoal {
  SavingsGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currency,
    required this.createdAt,
    this.currentAmount = 0,
    this.deadline,
    this.color,
    this.icon,
    this.notes,
  });

  final String id;
  final String title;
  final num targetAmount;
  final num currentAmount;
  final String currency;

  /// ISO date (YYYY-MM-DD) when the goal should be reached. Null = open-
  /// ended.
  final String? deadline;

  final String? color;
  final String? icon;
  final String? notes;
  final String createdAt;

  num get remaining {
    final r = targetAmount - currentAmount;
    return r < 0 ? 0 : r;
  }

  double get progress {
    if (targetAmount <= 0) return 0;
    final p = currentAmount / targetAmount;
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p.toDouble();
  }

  bool get isCompleted => currentAmount >= targetAmount;

  SavingsGoal copyWith({
    String? title,
    num? targetAmount,
    num? currentAmount,
    String? currency,
    Object? deadline = _sentinel,
    Object? color = _sentinel,
    Object? icon = _sentinel,
    Object? notes = _sentinel,
  }) =>
      SavingsGoal(
        id: id,
        createdAt: createdAt,
        title: title ?? this.title,
        targetAmount: targetAmount ?? this.targetAmount,
        currentAmount: currentAmount ?? this.currentAmount,
        currency: currency ?? this.currency,
        deadline: identical(deadline, _sentinel)
            ? this.deadline
            : deadline as String?,
        color: identical(color, _sentinel) ? this.color : color as String?,
        icon: identical(icon, _sentinel) ? this.icon : icon as String?,
        notes: identical(notes, _sentinel) ? this.notes : notes as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'currency': currency,
        if (deadline != null) 'deadline': deadline,
        if (color != null) 'color': color,
        if (icon != null) 'icon': icon,
        if (notes != null) 'notes': notes,
        'createdAt': createdAt,
      };

  factory SavingsGoal.fromJson(Map<String, dynamic> json) => SavingsGoal(
        id: json['id'] as String,
        title: (json['title'] ?? '') as String,
        targetAmount: (json['targetAmount'] ?? 0) as num,
        currentAmount: (json['currentAmount'] ?? 0) as num,
        currency: (json['currency'] ?? 'BYN') as String,
        deadline: json['deadline'] as String?,
        color: json['color'] as String?,
        icon: json['icon'] as String?,
        notes: json['notes'] as String?,
        createdAt: (json['createdAt'] ??
            DateTime.now().toIso8601String()) as String,
      );
}

const Object _sentinel = Object();
