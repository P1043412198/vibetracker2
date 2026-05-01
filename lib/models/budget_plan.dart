class BudgetPlan {
  final String monthKey; // 'YYYY-MM'
  final double incomePlan;
  final Map<String, double> categoryPlans;

  const BudgetPlan({
    required this.monthKey,
    required this.incomePlan,
    required this.categoryPlans,
  });

  double get totalExpensePlan =>
      categoryPlans.values.fold(0.0, (a, b) => a + b);

  double get freePlan => incomePlan - totalExpensePlan;

  BudgetPlan copyWith({
    String? monthKey,
    double? incomePlan,
    Map<String, double>? categoryPlans,
  }) {
    return BudgetPlan(
      monthKey: monthKey ?? this.monthKey,
      incomePlan: incomePlan ?? this.incomePlan,
      categoryPlans: categoryPlans ?? Map<String, double>.from(this.categoryPlans),
    );
  }

  Map<String, dynamic> toJson() => {
        'monthKey': monthKey,
        'incomePlan': incomePlan,
        'categoryPlans': categoryPlans,
      };

  factory BudgetPlan.fromJson(Map<String, dynamic> json) {
    final raw = (json['categoryPlans'] as Map?) ?? const {};
    return BudgetPlan(
      monthKey: json['monthKey'] as String,
      incomePlan: (json['incomePlan'] as num?)?.toDouble() ?? 0.0,
      categoryPlans: raw.map(
        (k, v) => MapEntry(k as String, (v as num).toDouble()),
      ),
    );
  }

  factory BudgetPlan.empty(String monthKey) =>
      BudgetPlan(monthKey: monthKey, incomePlan: 0, categoryPlans: const {});
}
