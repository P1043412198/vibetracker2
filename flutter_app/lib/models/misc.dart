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

/// Captured inbox entry — used to be a plain GTD note. With the chat-inbox
/// rework it also stores share-target links and link-preview metadata.
///
/// Persistence is via JSON in Hive (see [JsonListController]); all fields
/// added after the initial release are optional so older entries keep
/// loading.
class InboxItem {
  InboxItem({
    required this.id,
    required this.content,
    required this.createdAt,
    this.url,
    this.linkTitle,
    this.linkDomain,
    this.linkImage,
    this.platform,
    this.tags,
    this.pinned = false,
    this.archived = false,
    this.mediaPath,
    this.mediaType,
    this.mediaMime,
  });

  final String id;
  final String content;
  final String createdAt;

  /// First detected URL inside [content], when the entry is a saved link.
  /// `null` when the entry is a plain note.
  final String? url;

  /// `og:title` / `<title>` of the linked page, fetched lazily on first
  /// preview and cached here. Falls back to [url] domain when missing.
  final String? linkTitle;

  /// Bare domain of [url] (e.g. `www.youtube.com`). Stored to render the
  /// chip without re-parsing on every build.
  final String? linkDomain;

  /// `og:image` URL — fetched once and cached as-is. The widget renders it
  /// via `Image.network` and falls back to a platform icon on error.
  final String? linkImage;

  /// Detected social platform (`instagram` | `youtube` | `tiktok` |
  /// `telegram` | `twitter` | `vk` | `reddit` | `pinterest` | `threads` |
  /// `web`). Used purely for the colored badge / icon.
  final String? platform;

  /// Hashtags pulled from [content] (e.g. `#идея`, `#купить`). Lower-cased.
  final List<String>? tags;

  final bool pinned;
  final bool archived;

  /// Absolute path to a shared image / video that the native side copied
  /// into the app's private files dir. `null` for text-only entries.
  final String? mediaPath;

  /// Coarse media kind: `image` or `video`. Drives which widget renders
  /// the bubble.
  final String? mediaType;

  /// Original MIME type — kept around so we can pick the correct viewer
  /// when the user taps the media (`launchUrl(file://…)` honors it).
  final String? mediaMime;

  bool get isLink => url != null && url!.isNotEmpty;
  bool get hasMedia => mediaPath != null && mediaPath!.isNotEmpty;
  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'video';

  InboxItem copyWith({
    String? content,
    String? url,
    String? linkTitle,
    String? linkDomain,
    String? linkImage,
    String? platform,
    List<String>? tags,
    bool? pinned,
    bool? archived,
    String? mediaPath,
    String? mediaType,
    String? mediaMime,
  }) =>
      InboxItem(
        id: id,
        content: content ?? this.content,
        createdAt: createdAt,
        url: url ?? this.url,
        linkTitle: linkTitle ?? this.linkTitle,
        linkDomain: linkDomain ?? this.linkDomain,
        linkImage: linkImage ?? this.linkImage,
        platform: platform ?? this.platform,
        tags: tags ?? this.tags,
        pinned: pinned ?? this.pinned,
        archived: archived ?? this.archived,
        mediaPath: mediaPath ?? this.mediaPath,
        mediaType: mediaType ?? this.mediaType,
        mediaMime: mediaMime ?? this.mediaMime,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'createdAt': createdAt,
        if (url != null) 'url': url,
        if (linkTitle != null) 'linkTitle': linkTitle,
        if (linkDomain != null) 'linkDomain': linkDomain,
        if (linkImage != null) 'linkImage': linkImage,
        if (platform != null) 'platform': platform,
        if (tags != null && tags!.isNotEmpty) 'tags': tags,
        if (pinned) 'pinned': pinned,
        if (archived) 'archived': archived,
        if (mediaPath != null) 'mediaPath': mediaPath,
        if (mediaType != null) 'mediaType': mediaType,
        if (mediaMime != null) 'mediaMime': mediaMime,
      };

  factory InboxItem.fromJson(Map<String, dynamic> json) => InboxItem(
        id: json['id'] as String,
        content: (json['content'] ?? '') as String,
        createdAt: json['createdAt'] as String,
        url: json['url'] as String?,
        linkTitle: json['linkTitle'] as String?,
        linkDomain: json['linkDomain'] as String?,
        linkImage: json['linkImage'] as String?,
        platform: json['platform'] as String?,
        tags: (json['tags'] as List?)?.whereType<String>().toList(),
        pinned: json['pinned'] == true,
        archived: json['archived'] == true,
        mediaPath: json['mediaPath'] as String?,
        mediaType: json['mediaType'] as String?,
        mediaMime: json['mediaMime'] as String?,
      );
}

/// Phase 12: free-form household notes — bag reminders, water/light shutoff
/// schedule, food storage tips, seasonal chores, etc. The user organizes
/// them via the [category] tag.
class HouseholdNote {
  HouseholdNote({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    this.pinned = false,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final String createdAt;
  final bool pinned;

  HouseholdNote copyWith({
    String? title,
    String? body,
    String? category,
    bool? pinned,
  }) =>
      HouseholdNote(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        category: category ?? this.category,
        createdAt: createdAt,
        pinned: pinned ?? this.pinned,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'category': category,
        'createdAt': createdAt,
        if (pinned) 'pinned': pinned,
      };

  factory HouseholdNote.fromJson(Map<String, dynamic> json) => HouseholdNote(
        id: json['id'] as String,
        title: (json['title'] ?? '') as String,
        body: (json['body'] ?? '') as String,
        category: (json['category'] ?? 'Общее') as String,
        createdAt: (json['createdAt'] ?? DateTime.now().toIso8601String())
            as String,
        pinned: json['pinned'] == true,
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
    this.articleUrls,
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
  final List<String>? articleUrls;
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
        if (articleUrls != null && articleUrls!.isNotEmpty)
          'articleUrls': articleUrls,
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
        articleUrls: (json['articleUrls'] as List?)
            ?.whereType<String>()
            .toList(),
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
    List<String>? articleUrls,
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
      articleUrls: articleUrls ?? this.articleUrls,
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
    Object? programId = _sentinel,
    Object? label = _sentinel,
  }) {
    return PlannedWorkout(
      id: id,
      date: date ?? this.date,
      status: status ?? this.status,
      programId: identical(programId, _sentinel)
          ? this.programId
          : programId as String?,
      label: identical(label, _sentinel) ? this.label : label as String?,
    );
  }
}

const Object _sentinel = Object();

// ---------------------------------------------------------------------------
// Phase 9 models
// ---------------------------------------------------------------------------

class Vacation {
  Vacation({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
  });

  final String id;
  final String title;
  final String startDate;
  final String endDate;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startDate': startDate,
        'endDate': endDate,
      };

  factory Vacation.fromJson(Map<String, dynamic> json) => Vacation(
        id: json['id'] as String,
        title: (json['title'] ?? '') as String,
        startDate: json['startDate'] as String,
        endDate: json['endDate'] as String,
      );
}

class WorkScheduleData {
  WorkScheduleData({
    required this.anchorDate,
    required this.cycle,
    this.vacations = const [],
  });

  final String anchorDate;
  final List<String> cycle;
  final List<Vacation> vacations;

  Map<String, dynamic> toJson() => {
        'anchorDate': anchorDate,
        'cycle': cycle,
        'vacations': vacations.map((v) => v.toJson()).toList(),
      };

  factory WorkScheduleData.fromJson(Map<String, dynamic> json) =>
      WorkScheduleData(
        anchorDate: json['anchorDate'] as String,
        cycle: (json['cycle'] as List?)?.whereType<String>().toList() ?? [],
        vacations: (json['vacations'] as List?)
                ?.map((e) => Vacation.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  WorkScheduleData copyWith({
    String? anchorDate,
    List<String>? cycle,
    List<Vacation>? vacations,
  }) {
    return WorkScheduleData(
      anchorDate: anchorDate ?? this.anchorDate,
      cycle: cycle ?? this.cycle,
      vacations: vacations ?? this.vacations,
    );
  }
}

class ShoppingCategory {
  ShoppingCategory({
    required this.id,
    required this.name,
    required this.color,
  });

  final String id;
  final String name;
  final String color;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
      };

  factory ShoppingCategory.fromJson(Map<String, dynamic> json) =>
      ShoppingCategory(
        id: json['id'] as String,
        name: (json['name'] ?? '') as String,
        color: (json['color'] ?? '#71717a') as String,
      );
}

class PriceHistoryEntry {
  PriceHistoryEntry({
    required this.id,
    required this.itemName,
    required this.price,
    required this.date,
    this.store,
  });

  final String id;
  final String itemName;
  final num price;
  final String date;
  final String? store;

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemName': itemName,
        'price': price,
        'date': date,
        if (store != null) 'store': store,
      };

  factory PriceHistoryEntry.fromJson(Map<String, dynamic> json) =>
      PriceHistoryEntry(
        id: json['id'] as String,
        itemName: (json['itemName'] ?? '') as String,
        price: (json['price'] ?? 0) as num,
        date: json['date'] as String,
        store: json['store'] as String?,
      );
}

/// Phase 15: streak-style challenges — "30 days without sugar", "21 day
/// meditation". Stored alongside daily check-ins with a status and an
/// optional feeling/note.
class Challenge {
  Challenge({
    required this.id,
    required this.title,
    required this.kind,
    required this.durationDays,
    required this.startDate,
    this.description,
    this.target,
    this.icon,
    this.color,
    this.archived = false,
  });

  final String id;
  final String title;

  /// `'avoid'` for "30 days without X", `'do'` for "do X for N days".
  final String kind;
  final int durationDays;

  /// `YYYY-MM-DD`.
  final String startDate;
  final String? description;
  final String? target;
  final String? icon;
  final int? color;
  final bool archived;

  Challenge copyWith({
    String? title,
    String? kind,
    int? durationDays,
    String? startDate,
    String? description,
    String? target,
    String? icon,
    int? color,
    bool? archived,
  }) =>
      Challenge(
        id: id,
        title: title ?? this.title,
        kind: kind ?? this.kind,
        durationDays: durationDays ?? this.durationDays,
        startDate: startDate ?? this.startDate,
        description: description ?? this.description,
        target: target ?? this.target,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        archived: archived ?? this.archived,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'kind': kind,
        'durationDays': durationDays,
        'startDate': startDate,
        if (description != null) 'description': description,
        if (target != null) 'target': target,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        'archived': archived,
      };

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
        id: json['id'] as String,
        title: (json['title'] ?? '') as String,
        kind: (json['kind'] ?? 'avoid') as String,
        durationDays: (json['durationDays'] as num?)?.toInt() ?? 30,
        startDate: (json['startDate'] ?? '') as String,
        description: json['description'] as String?,
        target: json['target'] as String?,
        icon: json['icon'] as String?,
        color: (json['color'] as num?)?.toInt(),
        archived: (json['archived'] ?? false) as bool,
      );
}

/// One day inside a [Challenge]. `status` is one of `done`, `failed`, `skip`.
class ChallengeCheckIn {
  ChallengeCheckIn({
    required this.id,
    required this.challengeId,
    required this.date,
    required this.status,
    this.feeling,
    this.note,
    this.mood,
  });

  final String id;
  final String challengeId;
  final String date; // YYYY-MM-DD
  final String status;
  final String? feeling;
  final String? note;
  final int? mood; // 1..5

  ChallengeCheckIn copyWith({
    String? status,
    String? feeling,
    String? note,
    int? mood,
  }) =>
      ChallengeCheckIn(
        id: id,
        challengeId: challengeId,
        date: date,
        status: status ?? this.status,
        feeling: feeling ?? this.feeling,
        note: note ?? this.note,
        mood: mood ?? this.mood,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'challengeId': challengeId,
        'date': date,
        'status': status,
        if (feeling != null) 'feeling': feeling,
        if (note != null) 'note': note,
        if (mood != null) 'mood': mood,
      };

  factory ChallengeCheckIn.fromJson(Map<String, dynamic> json) =>
      ChallengeCheckIn(
        id: json['id'] as String,
        challengeId: (json['challengeId'] ?? '') as String,
        date: (json['date'] ?? '') as String,
        status: (json['status'] ?? 'done') as String,
        feeling: json['feeling'] as String?,
        note: json['note'] as String?,
        mood: (json['mood'] as num?)?.toInt(),
      );
}

/// Phase 15: progress-photos for the body tab. Photos are stored on disk
/// (see `PhotoStorage`); we only persist the path + label/date.
class BodyPhoto {
  BodyPhoto({
    required this.id,
    required this.path,
    required this.takenAt,
    this.label,
    this.weight,
    this.note,
  });

  final String id;
  final String path;
  final String takenAt; // YYYY-MM-DD
  final String? label;
  final num? weight;
  final String? note;

  BodyPhoto copyWith({
    String? label,
    num? weight,
    String? note,
  }) =>
      BodyPhoto(
        id: id,
        path: path,
        takenAt: takenAt,
        label: label ?? this.label,
        weight: weight ?? this.weight,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'takenAt': takenAt,
        if (label != null) 'label': label,
        if (weight != null) 'weight': weight,
        if (note != null) 'note': note,
      };

  factory BodyPhoto.fromJson(Map<String, dynamic> json) => BodyPhoto(
        id: json['id'] as String,
        path: (json['path'] ?? '') as String,
        takenAt: (json['takenAt'] ?? '') as String,
        label: json['label'] as String?,
        weight: json['weight'] as num?,
        note: json['note'] as String?,
      );
}

// ───────────────────────── Outdoor Run ─────────────────────────

class RunSession {
  RunSession({
    required this.id,
    required this.startedAt,
    this.finishedAt,
    this.distanceMeters = 0,
    this.steps = 0,
    this.caloriesBurned = 0,
    this.durationSeconds = 0,
    this.route = const [],
    this.notes,
  });

  final String id;
  final String startedAt;
  final String? finishedAt;
  final double distanceMeters;
  final int steps;
  final int caloriesBurned;
  final int durationSeconds;
  final List<List<double>> route; // [[lat, lng], ...]
  final String? notes;

  double get distanceKm => distanceMeters / 1000;
  double get avgPaceMinPerKm =>
      distanceKm > 0 ? (durationSeconds / 60) / distanceKm : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt,
        if (finishedAt != null) 'finishedAt': finishedAt,
        'distanceMeters': distanceMeters,
        'steps': steps,
        'caloriesBurned': caloriesBurned,
        'durationSeconds': durationSeconds,
        'route': route,
        if (notes != null) 'notes': notes,
      };

  factory RunSession.fromJson(Map<String, dynamic> json) => RunSession(
        id: json['id'] as String,
        startedAt: (json['startedAt'] ?? '') as String,
        finishedAt: json['finishedAt'] as String?,
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
        steps: (json['steps'] as num?)?.toInt() ?? 0,
        caloriesBurned: (json['caloriesBurned'] as num?)?.toInt() ?? 0,
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        route: (json['route'] as List?)
                ?.map((e) =>
                    (e as List).map((v) => (v as num).toDouble()).toList())
                .toList() ??
            const [],
        notes: json['notes'] as String?,
      );

  RunSession copyWith({
    String? finishedAt,
    double? distanceMeters,
    int? steps,
    int? caloriesBurned,
    int? durationSeconds,
    List<List<double>>? route,
    String? notes,
  }) {
    return RunSession(
      id: id,
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      steps: steps ?? this.steps,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      route: route ?? this.route,
      notes: notes ?? this.notes,
    );
  }
}
