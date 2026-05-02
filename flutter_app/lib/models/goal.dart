import 'enums.dart';

class GoalStep {
  GoalStep({
    required this.id,
    required this.title,
    required this.completed,
    this.status,
  });

  final String id;
  final String title;
  final bool completed;
  final GoalStepStatus? status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completed': completed,
        if (status != null) 'status': status!.name,
      };

  factory GoalStep.fromJson(Map<String, dynamic> json) => GoalStep(
        id: json['id'] as String,
        title: json['title'] as String,
        completed: (json['completed'] ?? false) as bool,
        status: json['status'] != null
            ? enumFromName(GoalStepStatus.values, json['status'] as String?,
                GoalStepStatus.todo)
            : null,
      );
}

class GoalProgressEntry {
  GoalProgressEntry({
    required this.id,
    required this.date,
    required this.value,
    this.note,
  });

  final String id;
  final String date;
  final num value;
  final String? note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'value': value,
        if (note != null) 'note': note,
      };

  factory GoalProgressEntry.fromJson(Map<String, dynamic> json) =>
      GoalProgressEntry(
        id: json['id'] as String,
        date: json['date'] as String,
        value: (json['value'] ?? 0) as num,
        note: json['note'] as String?,
      );
}

class Goal {
  Goal({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.steps,
    required this.createdAt,
    this.description,
    this.deadline,
    this.coverUrl,
    this.icon,
    this.author,
    this.totalPages,
    this.readPages,
    this.progressHistory,
    this.targetValue,
    this.currentValue,
    this.progress,
    this.showOnDashboard,
    this.isPinned,
    this.photoPaths,
  });

  final String id;
  final String title;
  final String? description;
  final GoalType type;
  final GoalStatus status;
  final List<GoalStep> steps;
  final String createdAt;
  final String? deadline;
  final String? coverUrl;
  final String? icon;
  final String? author;
  final int? totalPages;
  final int? readPages;
  final List<GoalProgressEntry>? progressHistory;
  final num? targetValue;
  final num? currentValue;
  final num? progress;
  final bool? showOnDashboard;
  final bool? isPinned;

  /// Local file paths to photo notes attached to this goal. Stored under
  /// `app_docs/goal_photos/{goalId}/...` and persisted as absolute paths
  /// in JSON. Null = no photos.
  final List<String>? photoPaths;

  Goal copyWith({
    String? title,
    String? description,
    GoalType? type,
    GoalStatus? status,
    List<GoalStep>? steps,
    String? deadline,
    String? coverUrl,
    String? icon,
    String? author,
    int? totalPages,
    int? readPages,
    List<GoalProgressEntry>? progressHistory,
    num? targetValue,
    num? currentValue,
    num? progress,
    bool? showOnDashboard,
    bool? isPinned,
    List<String>? photoPaths,
    bool clearDescription = false,
    bool clearDeadline = false,
    bool clearProgress = false,
  }) {
    return Goal(
      id: id,
      createdAt: createdAt,
      title: title ?? this.title,
      type: type ?? this.type,
      status: status ?? this.status,
      steps: steps ?? this.steps,
      description:
          clearDescription ? null : (description ?? this.description),
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      coverUrl: coverUrl ?? this.coverUrl,
      icon: icon ?? this.icon,
      author: author ?? this.author,
      totalPages: totalPages ?? this.totalPages,
      readPages: readPages ?? this.readPages,
      progressHistory: progressHistory ?? this.progressHistory,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      progress: clearProgress ? null : (progress ?? this.progress),
      showOnDashboard: showOnDashboard ?? this.showOnDashboard,
      isPinned: isPinned ?? this.isPinned,
      photoPaths: photoPaths ?? this.photoPaths,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (description != null) 'description': description,
        'type': type.name,
        'status': status.name,
        'steps': steps.map((e) => e.toJson()).toList(),
        'createdAt': createdAt,
        if (deadline != null) 'deadline': deadline,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (icon != null) 'icon': icon,
        if (author != null) 'author': author,
        if (totalPages != null) 'totalPages': totalPages,
        if (readPages != null) 'readPages': readPages,
        if (progressHistory != null)
          'progressHistory':
              progressHistory!.map((e) => e.toJson()).toList(),
        if (targetValue != null) 'targetValue': targetValue,
        if (currentValue != null) 'currentValue': currentValue,
        if (progress != null) 'progress': progress,
        if (showOnDashboard != null) 'showOnDashboard': showOnDashboard,
        if (isPinned != null) 'isPinned': isPinned,
        if (photoPaths != null) 'photoPaths': photoPaths,
      };

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        type: enumFromName(
            GoalType.values, json['type'] as String?, GoalType.goal),
        status: enumFromName(GoalStatus.values, json['status'] as String?,
            GoalStatus.not_started),
        steps: (json['steps'] as List? ?? const [])
            .whereType<Map>()
            .map((e) =>
                GoalStep.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
            .toList(),
        createdAt: json['createdAt'] as String,
        deadline: json['deadline'] as String?,
        coverUrl: json['coverUrl'] as String?,
        icon: json['icon'] as String?,
        author: json['author'] as String?,
        totalPages: (json['totalPages'] as num?)?.toInt(),
        readPages: (json['readPages'] as num?)?.toInt(),
        progressHistory: (json['progressHistory'] as List?)
            ?.whereType<Map>()
            .map((e) => GoalProgressEntry.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v))))
            .toList(),
        targetValue: json['targetValue'] as num?,
        currentValue: json['currentValue'] as num?,
        progress: json['progress'] as num?,
        showOnDashboard: json['showOnDashboard'] as bool?,
        isPinned: json['isPinned'] as bool?,
        photoPaths: (json['photoPaths'] as List?)
            ?.whereType<String>()
            .toList(),
      );
}
