import 'enums.dart';

class Subtask {
  Subtask({required this.id, required this.title, required this.completed});

  final String id;
  final String title;
  final bool completed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completed': completed,
      };

  factory Subtask.fromJson(Map<String, dynamic> json) => Subtask(
        id: json['id'] as String,
        title: json['title'] as String,
        completed: (json['completed'] ?? false) as bool,
      );
}

class TaskItem {
  TaskItem({
    required this.id,
    required this.title,
    required this.period,
    required this.date,
    required this.completed,
    required this.failed,
    required this.createdAt,
    this.sphereId,
    this.subtasks,
    this.order,
    this.isPinned,
    this.priority,
    this.context,
  });

  final String id;
  final String title;
  final String? sphereId;
  final TaskPeriod period;
  final String date;
  final bool completed;
  final bool failed;
  final String createdAt;
  final List<Subtask>? subtasks;
  final int? order;
  final bool? isPinned;
  final TaskPriority? priority;
  final String? context;

  TaskItem copyWith({
    String? title,
    String? sphereId,
    TaskPeriod? period,
    String? date,
    bool? completed,
    bool? failed,
    List<Subtask>? subtasks,
    int? order,
    bool? isPinned,
    TaskPriority? priority,
    String? context,
    bool clearPriority = false,
    bool clearContext = false,
  }) {
    return TaskItem(
      id: id,
      title: title ?? this.title,
      sphereId: sphereId ?? this.sphereId,
      period: period ?? this.period,
      date: date ?? this.date,
      completed: completed ?? this.completed,
      failed: failed ?? this.failed,
      createdAt: createdAt,
      subtasks: subtasks ?? this.subtasks,
      order: order ?? this.order,
      isPinned: isPinned ?? this.isPinned,
      priority: clearPriority ? null : (priority ?? this.priority),
      context: clearContext ? null : (context ?? this.context),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (sphereId != null) 'sphereId': sphereId,
        'period': period.name,
        'date': date,
        'completed': completed,
        'failed': failed,
        'createdAt': createdAt,
        if (subtasks != null)
          'subtasks': subtasks!.map((e) => e.toJson()).toList(),
        if (order != null) 'order': order,
        if (isPinned != null) 'isPinned': isPinned,
        if (priority != null) 'priority': priority!.name,
        if (context != null) 'context': context,
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'] as String,
        title: json['title'] as String,
        sphereId: json['sphereId'] as String?,
        period: enumFromName(
            TaskPeriod.values, json['period'] as String?, TaskPeriod.day),
        date: json['date'] as String,
        completed: (json['completed'] ?? false) as bool,
        failed: (json['failed'] ?? false) as bool,
        createdAt: json['createdAt'] as String,
        subtasks: (json['subtasks'] as List?)
            ?.whereType<Map>()
            .map((e) =>
                Subtask.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
            .toList(),
        order: (json['order'] as num?)?.toInt(),
        isPinned: json['isPinned'] as bool?,
        priority: json['priority'] != null
            ? enumFromName(TaskPriority.values, json['priority'] as String?,
                TaskPriority.later)
            : null,
        context: json['context'] as String?,
      );
}
