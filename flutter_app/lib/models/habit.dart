import 'enums.dart';

class HabitFrequency {
  HabitFrequency({required this.type, this.days, this.count});

  final HabitFrequencyType type;
  final List<int>? days;
  final int? count;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (days != null) 'days': days,
        if (count != null) 'count': count,
      };

  factory HabitFrequency.fromJson(Map<String, dynamic> json) => HabitFrequency(
        type: enumFromName(HabitFrequencyType.values, json['type'] as String?,
            HabitFrequencyType.daily),
        days: (json['days'] as List?)
            ?.whereType<num>()
            .map((e) => e.toInt())
            .toList(),
        count: (json['count'] as num?)?.toInt(),
      );
}

class Habit {
  Habit({
    required this.id,
    required this.title,
    required this.type,
    required this.createdAt,
    this.description,
    this.frequency,
    this.targetValue,
    this.unit,
    this.icon,
    this.isPinned,
    this.order,
  });

  final String id;
  final String title;
  final HabitTypeKind type;
  final String? description;
  final String createdAt;
  final HabitFrequency? frequency;
  final num? targetValue;
  final String? unit;
  final String? icon;
  final bool? isPinned;
  final int? order;

  Habit copyWith({
    String? title,
    HabitTypeKind? type,
    String? description,
    HabitFrequency? frequency,
    num? targetValue,
    String? unit,
    String? icon,
    bool? isPinned,
    int? order,
  }) {
    return Habit(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      createdAt: createdAt,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      icon: icon ?? this.icon,
      isPinned: isPinned ?? this.isPinned,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'createdAt': createdAt,
        if (description != null) 'description': description,
        if (frequency != null) 'frequency': frequency!.toJson(),
        if (targetValue != null) 'targetValue': targetValue,
        if (unit != null) 'unit': unit,
        if (icon != null) 'icon': icon,
        if (isPinned != null) 'isPinned': isPinned,
        if (order != null) 'order': order,
      };

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String,
        title: json['title'] as String,
        type: enumFromName(
            HabitTypeKind.values, json['type'] as String?, HabitTypeKind.good),
        createdAt: json['createdAt'] as String,
        description: json['description'] as String?,
        frequency: json['frequency'] != null
            ? HabitFrequency.fromJson(
                (json['frequency'] as Map).map((k, v) => MapEntry(k.toString(), v)))
            : null,
        targetValue: json['targetValue'] as num?,
        unit: json['unit'] as String?,
        icon: json['icon'] as String?,
        isPinned: json['isPinned'] as bool?,
        order: (json['order'] as num?)?.toInt(),
      );
}

class HabitLog {
  HabitLog({
    required this.id,
    required this.habitId,
    required this.date,
    required this.status,
    required this.notes,
    required this.feelings,
    this.value,
  });

  final String id;
  final String habitId;
  final String date;
  final HabitLogStatus status;
  final String notes;
  final String feelings;
  final num? value;

  Map<String, dynamic> toJson() => {
        'id': id,
        'habitId': habitId,
        'date': date,
        'status': status.name,
        'notes': notes,
        'feelings': feelings,
        if (value != null) 'value': value,
      };

  factory HabitLog.fromJson(Map<String, dynamic> json) => HabitLog(
        id: json['id'] as String,
        habitId: json['habitId'] as String,
        date: json['date'] as String,
        status: enumFromName(HabitLogStatus.values, json['status'] as String?,
            HabitLogStatus.done),
        notes: (json['notes'] ?? '') as String,
        feelings: (json['feelings'] ?? '') as String,
        value: json['value'] as num?,
      );
}
