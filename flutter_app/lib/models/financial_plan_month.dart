// Models for the new, fully flexible «Финансовый план» — replaces the old
// rigid 18-section template. The user now builds each month's plan from
// scratch: any number of scenarios, any number of sections inside a
// scenario, any number of line items inside a section.
//
// Persistence is JSON inside the existing `JsonListController` storage —
// no Hive adapters or migrations required. Old config (`FinancialPlanConfig`)
// stays untouched so existing data is not lost; the new feature simply
// ignores it.

/// Top-level container for a single month's plan.
///
/// Identified by [monthKey] (`YYYY-MM`). The user can have many months in
/// the list and flip between them like pages.
class FinancialPlanMonth {
  FinancialPlanMonth({
    required this.id,
    required this.monthKey,
    required this.title,
    required this.scenarios,
    required this.activeScenarioId,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
  });

  final String id;

  /// `YYYY-MM` — the month this plan covers. Used to:
  ///   1. order the list of months;
  ///   2. match real transactions for the «факт» column.
  final String monthKey;

  /// Optional user-friendly month title (e.g. «Май — отпуск»). Defaults to
  /// the localised month name when empty.
  final String title;

  /// Free-form notes shown above the scenarios list.
  final String? notes;

  /// All scenarios the user has created for the month. Always non-empty —
  /// when the last scenario is removed we recreate a blank «Базовый».
  final List<FinPlanScenario> scenarios;

  /// Id of the currently selected scenario (drives totals / roadmap).
  final String activeScenarioId;

  final String createdAt;
  final String updatedAt;

  FinancialPlanMonth copyWith({
    String? monthKey,
    String? title,
    String? notes,
    List<FinPlanScenario>? scenarios,
    String? activeScenarioId,
    String? updatedAt,
    bool clearNotes = false,
  }) {
    return FinancialPlanMonth(
      id: id,
      monthKey: monthKey ?? this.monthKey,
      title: title ?? this.title,
      notes: clearNotes ? null : (notes ?? this.notes),
      scenarios: scenarios ?? this.scenarios,
      activeScenarioId: activeScenarioId ?? this.activeScenarioId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'monthKey': monthKey,
        'title': title,
        if (notes != null) 'notes': notes,
        'scenarios': scenarios.map((s) => s.toJson()).toList(),
        'activeScenarioId': activeScenarioId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory FinancialPlanMonth.fromJson(Map<String, dynamic> json) {
    final scenarios = (json['scenarios'] as List?)
            ?.whereType<Map>()
            .map((e) => FinPlanScenario.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v))))
            .toList() ??
        <FinPlanScenario>[];
    return FinancialPlanMonth(
      id: json['id'] as String,
      monthKey: (json['monthKey'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      notes: json['notes'] as String?,
      scenarios: scenarios.isEmpty
          ? [FinPlanScenario.blank(name: 'Базовый')]
          : scenarios,
      activeScenarioId: (json['activeScenarioId'] as String?) ??
          (scenarios.isNotEmpty ? scenarios.first.id : ''),
      createdAt:
          (json['createdAt'] ?? DateTime.now().toIso8601String()) as String,
      updatedAt:
          (json['updatedAt'] ?? DateTime.now().toIso8601String()) as String,
    );
  }
}

/// One scenario inside a month — e.g. «Базовый», «Эконом», «Идеал». Holds an
/// independent list of sections so scenarios can diverge freely.
class FinPlanScenario {
  FinPlanScenario({
    required this.id,
    required this.name,
    required this.color,
    required this.sections,
    this.notes,
  });

  final String id;
  final String name;

  /// ARGB int — kept as int so JSON round-trips without colour helpers.
  final int color;

  final String? notes;
  final List<FinPlanSection> sections;

  FinPlanScenario copyWith({
    String? name,
    int? color,
    List<FinPlanSection>? sections,
    String? notes,
    bool clearNotes = false,
  }) {
    return FinPlanScenario(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      sections: sections ?? this.sections,
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        if (notes != null) 'notes': notes,
        'sections': sections.map((s) => s.toJson()).toList(),
      };

  factory FinPlanScenario.fromJson(Map<String, dynamic> json) =>
      FinPlanScenario(
        id: json['id'] as String,
        name: (json['name'] ?? '') as String,
        color: ((json['color'] ?? 0xFF6D5CFF) as num).toInt(),
        notes: json['notes'] as String?,
        sections: (json['sections'] as List?)
                ?.whereType<Map>()
                .map((e) => FinPlanSection.fromJson(
                    e.map((k, v) => MapEntry(k.toString(), v))))
                .toList() ??
            <FinPlanSection>[],
      );

  static FinPlanScenario blank({required String name, int? color}) {
    return FinPlanScenario(
      id: '${DateTime.now().microsecondsSinceEpoch}-${name.hashCode}',
      name: name,
      color: color ?? 0xFF6D5CFF,
      sections: const [],
    );
  }
}

/// A section is a labelled bucket inside a scenario — e.g. «Доход», «Жильё»,
/// «Сбережения». Determines the sign of its items in summary totals.
enum FinPlanSectionKind {
  income,
  expense,
  savings,
  debt,
  custom,
}

class FinPlanSection {
  FinPlanSection({
    required this.id,
    required this.title,
    required this.kind,
    required this.items,
    this.icon,
    this.color,
    this.notes,
  });

  final String id;
  final String title;
  final FinPlanSectionKind kind;
  final List<FinPlanItem> items;

  /// Optional emoji used by the UI as a section icon.
  final String? icon;

  /// Optional ARGB int colour for the section header.
  final int? color;

  final String? notes;

  FinPlanSection copyWith({
    String? title,
    FinPlanSectionKind? kind,
    List<FinPlanItem>? items,
    String? icon,
    int? color,
    String? notes,
    bool clearIcon = false,
    bool clearColor = false,
    bool clearNotes = false,
  }) {
    return FinPlanSection(
      id: id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      items: items ?? this.items,
      icon: clearIcon ? null : (icon ?? this.icon),
      color: clearColor ? null : (color ?? this.color),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'kind': kind.name,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (notes != null) 'notes': notes,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory FinPlanSection.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String?;
    final kind = FinPlanSectionKind.values.firstWhere(
      (k) => k.name == kindName,
      orElse: () => FinPlanSectionKind.custom,
    );
    return FinPlanSection(
      id: json['id'] as String,
      title: (json['title'] ?? '') as String,
      kind: kind,
      icon: json['icon'] as String?,
      color: (json['color'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      items: (json['items'] as List?)
              ?.whereType<Map>()
              .map((e) => FinPlanItem.fromJson(
                  e.map((k, v) => MapEntry(k.toString(), v))))
              .toList() ??
          <FinPlanItem>[],
    );
  }
}

/// A single line item — one row inside a section.
class FinPlanItem {
  FinPlanItem({
    required this.id,
    required this.label,
    required this.amount,
    required this.currency,
    this.day,
    this.recurring = false,
    this.linkedCategory,
    this.linkedSphereId,
    this.linkedSphereCategoryId,
    this.notes,
    this.done = false,
  });

  final String id;
  final String label;
  final double amount;
  final String currency;

  /// Optional day-of-month the item happens (1..31). Powers the per-month
  /// roadmap timeline.
  final int? day;

  /// Whether the item recurs each month (used for «Скопировать в следующий
  /// месяц» heuristics).
  final bool recurring;

  /// Optional category from the user's transactions — when set the plan
  /// pulls real spend with this category to show «факт».
  final String? linkedCategory;

  /// Optional link to a sphere — for cross-linking notes/items.
  final String? linkedSphereId;

  /// Optional link to a sphere category (when [linkedSphereId] is set).
  final String? linkedSphereCategoryId;

  final String? notes;

  /// Checkbox state for action-style items (e.g. «оплатить кредит»).
  final bool done;

  FinPlanItem copyWith({
    String? label,
    double? amount,
    String? currency,
    int? day,
    bool? recurring,
    String? linkedCategory,
    String? linkedSphereId,
    String? linkedSphereCategoryId,
    String? notes,
    bool? done,
    bool clearDay = false,
    bool clearLinkedCategory = false,
    bool clearLinkedSphereId = false,
    bool clearLinkedSphereCategoryId = false,
    bool clearNotes = false,
  }) {
    return FinPlanItem(
      id: id,
      label: label ?? this.label,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      day: clearDay ? null : (day ?? this.day),
      recurring: recurring ?? this.recurring,
      linkedCategory: clearLinkedCategory
          ? null
          : (linkedCategory ?? this.linkedCategory),
      linkedSphereId: clearLinkedSphereId
          ? null
          : (linkedSphereId ?? this.linkedSphereId),
      linkedSphereCategoryId: clearLinkedSphereCategoryId
          ? null
          : (linkedSphereCategoryId ?? this.linkedSphereCategoryId),
      notes: clearNotes ? null : (notes ?? this.notes),
      done: done ?? this.done,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'amount': amount,
        'currency': currency,
        if (day != null) 'day': day,
        if (recurring) 'recurring': recurring,
        if (linkedCategory != null) 'linkedCategory': linkedCategory,
        if (linkedSphereId != null) 'linkedSphereId': linkedSphereId,
        if (linkedSphereCategoryId != null)
          'linkedSphereCategoryId': linkedSphereCategoryId,
        if (notes != null) 'notes': notes,
        if (done) 'done': done,
      };

  factory FinPlanItem.fromJson(Map<String, dynamic> json) => FinPlanItem(
        id: json['id'] as String,
        label: (json['label'] ?? '') as String,
        amount: ((json['amount'] ?? 0) as num).toDouble(),
        currency: (json['currency'] ?? 'BYN') as String,
        day: (json['day'] as num?)?.toInt(),
        recurring: json['recurring'] == true,
        linkedCategory: json['linkedCategory'] as String?,
        linkedSphereId: json['linkedSphereId'] as String?,
        linkedSphereCategoryId: json['linkedSphereCategoryId'] as String?,
        notes: json['notes'] as String?,
        done: json['done'] == true,
      );
}
