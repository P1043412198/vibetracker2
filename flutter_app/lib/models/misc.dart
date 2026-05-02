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
}
