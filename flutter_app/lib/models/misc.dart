import 'enums.dart';

class WaterLog {
  WaterLog({
    required this.id,
    required this.date,
    required this.timestamp,
    required this.amount,
  });

  final String id;
  final String date;
  final String timestamp;
  final num amount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'timestamp': timestamp,
        'amount': amount,
      };

  factory WaterLog.fromJson(Map<String, dynamic> json) => WaterLog(
        id: json['id'] as String,
        date: json['date'] as String,
        timestamp: json['timestamp'] as String,
        amount: (json['amount'] ?? 0) as num,
      );
}

class InboxItem {
  InboxItem({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String content;
  final String createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'createdAt': createdAt,
      };

  factory InboxItem.fromJson(Map<String, dynamic> json) => InboxItem(
        id: json['id'] as String,
        content: (json['content'] ?? '') as String,
        createdAt: json['createdAt'] as String,
      );
}

class SleepLog {
  SleepLog({
    required this.id,
    required this.date,
    required this.hours,
    required this.quality,
    this.notes,
  });

  final String id;
  final String date;
  final num hours;
  final int quality;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'hours': hours,
        'quality': quality,
        if (notes != null) 'notes': notes,
      };

  factory SleepLog.fromJson(Map<String, dynamic> json) => SleepLog(
        id: json['id'] as String,
        date: json['date'] as String,
        hours: (json['hours'] ?? 0) as num,
        quality: ((json['quality'] ?? 3) as num).toInt(),
        notes: json['notes'] as String?,
      );
}

class ShoppingItem {
  ShoppingItem({
    required this.id,
    required this.text,
    required this.completed,
    required this.createdAt,
    this.price,
    this.category,
    this.hashtags,
    this.photo,
    this.completedAt,
  });

  final String id;
  final String text;
  final bool completed;
  final num? price;
  final String? category;
  final List<String>? hashtags;
  final String? photo;
  final String createdAt;
  final String? completedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'completed': completed,
        'createdAt': createdAt,
        if (price != null) 'price': price,
        if (category != null) 'category': category,
        if (hashtags != null) 'hashtags': hashtags,
        if (photo != null) 'photo': photo,
        if (completedAt != null) 'completedAt': completedAt,
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
        id: json['id'] as String,
        text: (json['text'] ?? '') as String,
        completed: (json['completed'] ?? false) as bool,
        createdAt: json['createdAt'] as String,
        price: json['price'] as num?,
        category: json['category'] as String?,
        hashtags: (json['hashtags'] as List?)?.whereType<String>().toList(),
        photo: json['photo'] as String?,
        completedAt: json['completedAt'] as String?,
      );
}

class PasswordEntry {
  PasswordEntry({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.username,
    this.password,
    this.url,
    this.totpSecret,
    this.notes,
    this.category,
    this.isPinned,
  });

  final String id;
  final String title;
  final String? username;
  final String? password;
  final String? url;
  final String? totpSecret;
  final String? notes;
  final String? category;
  final String createdAt;
  final String updatedAt;
  final bool? isPinned;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (username != null) 'username': username,
        if (password != null) 'password': password,
        if (url != null) 'url': url,
        if (totpSecret != null) 'totpSecret': totpSecret,
        if (notes != null) 'notes': notes,
        if (category != null) 'category': category,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        if (isPinned != null) 'isPinned': isPinned,
      };

  factory PasswordEntry.fromJson(Map<String, dynamic> json) => PasswordEntry(
        id: json['id'] as String,
        title: (json['title'] ?? '') as String,
        username: json['username'] as String?,
        password: json['password'] as String?,
        url: json['url'] as String?,
        totpSecret: json['totpSecret'] as String?,
        notes: json['notes'] as String?,
        category: json['category'] as String?,
        createdAt: json['createdAt'] as String,
        updatedAt: json['updatedAt'] as String,
        isPinned: json['isPinned'] as bool?,
      );
}

class WorkoutNode {
  WorkoutNode({
    required this.id,
    required this.parentId,
    required this.name,
    required this.type,
    this.notes,
    this.videoUrl,
    this.metrics,
    this.restTime,
    this.muscleGroup,
    this.isTemplate,
  });

  final String id;
  final String? parentId;
  final String name;
  final WorkoutNodeType type;
  final String? notes;
  final String? videoUrl;
  final List<WorkoutMetric>? metrics;
  final int? restTime;
  final MuscleGroup? muscleGroup;
  final bool? isTemplate;

  Map<String, dynamic> toJson() => {
        'id': id,
        'parentId': parentId,
        'name': name,
        'type': type.name,
        if (notes != null) 'notes': notes,
        if (videoUrl != null) 'videoUrl': videoUrl,
        if (metrics != null) 'metrics': metrics!.map((e) => e.name).toList(),
        if (restTime != null) 'restTime': restTime,
        if (muscleGroup != null) 'muscleGroup': muscleGroup!.name,
        if (isTemplate != null) 'isTemplate': isTemplate,
      };

  factory WorkoutNode.fromJson(Map<String, dynamic> json) => WorkoutNode(
        id: json['id'] as String,
        parentId: json['parentId'] as String?,
        name: (json['name'] ?? '') as String,
        type: enumFromName(WorkoutNodeType.values, json['type'] as String?,
            WorkoutNodeType.exercise),
        notes: json['notes'] as String?,
        videoUrl: json['videoUrl'] as String?,
        metrics: (json['metrics'] as List?)
            ?.whereType<String>()
            .map((e) => enumFromName(
                WorkoutMetric.values, e, WorkoutMetric.weight))
            .toList(),
        restTime: (json['restTime'] as num?)?.toInt(),
        muscleGroup: json['muscleGroup'] != null
            ? enumFromName(MuscleGroup.values,
                json['muscleGroup'] as String?, MuscleGroup.chest)
            : null,
        isTemplate: json['isTemplate'] as bool?,
      );

  WorkoutNode copyWith({
    String? parentId,
    String? name,
    WorkoutNodeType? type,
    String? notes,
    String? videoUrl,
    List<WorkoutMetric>? metrics,
    int? restTime,
    MuscleGroup? muscleGroup,
    bool? isTemplate,
  }) {
    return WorkoutNode(
      id: id,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      videoUrl: videoUrl ?? this.videoUrl,
      metrics: metrics ?? this.metrics,
      restTime: restTime ?? this.restTime,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      isTemplate: isTemplate ?? this.isTemplate,
    );
  }
}

class ExerciseLog {
  ExerciseLog({
    required this.id,
    required this.exerciseId,
    required this.date,
    required this.metrics,
    this.notes,
    this.restTime,
  });

  final String id;
  final String exerciseId;
  final String date; // YYYY-MM-DD
  final Map<WorkoutMetric, num> metrics;
  final String? notes;
  final int? restTime;

  Map<String, dynamic> toJson() => {
        'id': id,
        'exerciseId': exerciseId,
        'date': date,
        'metrics': {
          for (final e in metrics.entries) e.key.name: e.value,
        },
        if (notes != null) 'notes': notes,
        if (restTime != null) 'restTime': restTime,
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> json) {
    final raw = (json['metrics'] as Map?) ?? const {};
    final m = <WorkoutMetric, num>{};
    raw.forEach((k, v) {
      if (k is String && v is num) {
        m[enumFromName(
                WorkoutMetric.values, k, WorkoutMetric.weight)] =
            v;
      }
    });
    return ExerciseLog(
      id: json['id'] as String,
      exerciseId: json['exerciseId'] as String,
      date: json['date'] as String,
      metrics: m,
      notes: json['notes'] as String?,
      restTime: (json['restTime'] as num?)?.toInt(),
    );
  }
}

class BodyMeasurement {
  BodyMeasurement({
    required this.id,
    required this.date,
    this.weight,
    this.height,
    this.neck,
    this.gender,
    this.measurements,
    this.photos,
  });

  final String id;
  final String date; // YYYY-MM-DD
  final num? weight;
  final num? height;
  final num? neck;
  final String? gender; // 'male' | 'female'
  /// chest / waist / hips / biceps / thighs / calves etc.
  final Map<String, num>? measurements;
  final List<String>? photos;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        if (weight != null) 'weight': weight,
        if (height != null) 'height': height,
        if (neck != null) 'neck': neck,
        if (gender != null) 'gender': gender,
        if (measurements != null) 'measurements': measurements,
        if (photos != null) 'photos': photos,
      };

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) {
    final raw = json['measurements'];
    Map<String, num>? meas;
    if (raw is Map) {
      meas = {
        for (final e in raw.entries)
          if (e.key is String && e.value is num)
            e.key as String: e.value as num,
      };
      if (meas.isEmpty) meas = null;
    }
    return BodyMeasurement(
      id: json['id'] as String,
      date: json['date'] as String,
      weight: json['weight'] as num?,
      height: json['height'] as num?,
      neck: json['neck'] as num?,
      gender: json['gender'] as String?,
      measurements: meas,
      photos:
          (json['photos'] as List?)?.whereType<String>().toList(growable: false),
    );
  }
}

class PomodoroSettings {
  PomodoroSettings({
    this.workTime = 25,
    this.shortBreakTime = 5,
    this.longBreakTime = 15,
    this.soundEnabled = true,
  });

  final int workTime;
  final int shortBreakTime;
  final int longBreakTime;
  final bool soundEnabled;

  Map<String, dynamic> toJson() => {
        'workTime': workTime,
        'shortBreakTime': shortBreakTime,
        'longBreakTime': longBreakTime,
        'soundEnabled': soundEnabled,
      };

  factory PomodoroSettings.fromJson(Map<String, dynamic> json) =>
      PomodoroSettings(
        workTime: ((json['workTime'] ?? 25) as num).toInt(),
        shortBreakTime: ((json['shortBreakTime'] ?? 5) as num).toInt(),
        longBreakTime: ((json['longBreakTime'] ?? 15) as num).toInt(),
        soundEnabled: (json['soundEnabled'] ?? true) as bool,
      );

  PomodoroSettings copyWith({
    int? workTime,
    int? shortBreakTime,
    int? longBreakTime,
    bool? soundEnabled,
  }) {
    return PomodoroSettings(
      workTime: workTime ?? this.workTime,
      shortBreakTime: shortBreakTime ?? this.shortBreakTime,
      longBreakTime: longBreakTime ?? this.longBreakTime,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }
}

class PomodoroState {
  PomodoroState({
    required this.timeLeft,
    required this.totalTime,
    this.isRunning = false,
    this.type = 'work',
    this.sessionsCompleted = 0,
    PomodoroSettings? settings,
  }) : settings = settings ?? PomodoroSettings();

  final int timeLeft;
  final int totalTime;
  final bool isRunning;
  final String type; // 'work' | 'shortBreak' | 'longBreak'
  final int sessionsCompleted;
  final PomodoroSettings settings;

  Map<String, dynamic> toJson() => {
        'timeLeft': timeLeft,
        'totalTime': totalTime,
        'isRunning': isRunning,
        'type': type,
        'sessionsCompleted': sessionsCompleted,
        'settings': settings.toJson(),
      };

  factory PomodoroState.fromJson(Map<String, dynamic> json) => PomodoroState(
        timeLeft: ((json['timeLeft'] ?? 1500) as num).toInt(),
        totalTime: ((json['totalTime'] ?? 1500) as num).toInt(),
        isRunning: (json['isRunning'] ?? false) as bool,
        type: (json['type'] ?? 'work') as String,
        sessionsCompleted: ((json['sessionsCompleted'] ?? 0) as num).toInt(),
        settings: json['settings'] is Map<String, dynamic>
            ? PomodoroSettings.fromJson(json['settings'] as Map<String, dynamic>)
            : PomodoroSettings(),
      );

  PomodoroState copyWith({
    int? timeLeft,
    int? totalTime,
    bool? isRunning,
    String? type,
    int? sessionsCompleted,
    PomodoroSettings? settings,
  }) {
    return PomodoroState(
      timeLeft: timeLeft ?? this.timeLeft,
      totalTime: totalTime ?? this.totalTime,
      isRunning: isRunning ?? this.isRunning,
      type: type ?? this.type,
      sessionsCompleted: sessionsCompleted ?? this.sessionsCompleted,
      settings: settings ?? this.settings,
    );
  }
}

class PlannedWorkout {
  PlannedWorkout({
    required this.id,
    required this.date,
    required this.status,
    this.programId,
    this.label,
  });

  final String id;
  final String date; // YYYY-MM-DD
  final PlannedWorkoutStatus status;
  final String? programId;
  final String? label;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'status': status.name,
        if (programId != null) 'programId': programId,
        if (label != null) 'label': label,
      };

  factory PlannedWorkout.fromJson(Map<String, dynamic> json) =>
      PlannedWorkout(
        id: json['id'] as String,
        date: json['date'] as String,
        status: enumFromName(PlannedWorkoutStatus.values,
            json['status'] as String?, PlannedWorkoutStatus.planned),
        programId: json['programId'] as String?,
        label: json['label'] as String?,
      );

  PlannedWorkout copyWith({
    String? date,
    PlannedWorkoutStatus? status,
    String? programId,
    String? label,
  }) {
    return PlannedWorkout(
      id: id,
      date: date ?? this.date,
      status: status ?? this.status,
      programId: programId ?? this.programId,
      label: label ?? this.label,
    );
  }
}
