// 1:1 port of the `Sphere` and `SphereNote` types from `src/types.ts`.

class NoteComment {
  NoteComment({
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

  factory NoteComment.fromJson(Map<String, dynamic> json) => NoteComment(
        id: json['id'] as String,
        content: json['content'] as String,
        createdAt: json['createdAt'] as String,
      );
}

class SphereNote {
  SphereNote({
    required this.id,
    required this.content,
    required this.createdAt,
    this.youtubeUrl,
    this.photoUrl,
    this.isCheckbox,
    this.isChecked,
    this.comments,
    this.isPinned,
  });

  final String id;
  final String content;
  final String createdAt;
  final String? youtubeUrl;
  final String? photoUrl;
  final bool? isCheckbox;
  final bool? isChecked;
  final List<NoteComment>? comments;
  final bool? isPinned;

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'createdAt': createdAt,
        if (youtubeUrl != null) 'youtubeUrl': youtubeUrl,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (isCheckbox != null) 'isCheckbox': isCheckbox,
        if (isChecked != null) 'isChecked': isChecked,
        if (comments != null)
          'comments': comments!.map((e) => e.toJson()).toList(),
        if (isPinned != null) 'isPinned': isPinned,
      };

  factory SphereNote.fromJson(Map<String, dynamic> json) => SphereNote(
        id: json['id'] as String,
        content: json['content'] as String,
        createdAt: json['createdAt'] as String,
        youtubeUrl: json['youtubeUrl'] as String?,
        photoUrl: json['photoUrl'] as String?,
        isCheckbox: json['isCheckbox'] as bool?,
        isChecked: json['isChecked'] as bool?,
        comments: (json['comments'] as List?)
            ?.whereType<Map>()
            .map((e) =>
                NoteComment.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
            .toList(),
        isPinned: json['isPinned'] as bool?,
      );
}

class Sphere {
  Sphere({
    required this.id,
    required this.title,
    required this.notes,
    required this.createdAt,
    this.description,
    this.deadline,
    this.notesList,
    this.color,
    this.icon,
    this.isPinned,
    this.order,
  });

  final String id;
  final String title;
  final String? description;
  final String? deadline;
  final String notes;
  final List<SphereNote>? notesList;
  final String createdAt;
  final String? color;
  final String? icon;
  final bool? isPinned;
  final int? order;

  Sphere copyWith({
    String? title,
    String? description,
    String? deadline,
    String? notes,
    List<SphereNote>? notesList,
    String? color,
    String? icon,
    bool? isPinned,
    int? order,
  }) {
    return Sphere(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      notes: notes ?? this.notes,
      notesList: notesList ?? this.notesList,
      createdAt: createdAt,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isPinned: isPinned ?? this.isPinned,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'createdAt': createdAt,
        if (description != null) 'description': description,
        if (deadline != null) 'deadline': deadline,
        if (notesList != null)
          'notesList': notesList!.map((e) => e.toJson()).toList(),
        if (color != null) 'color': color,
        if (icon != null) 'icon': icon,
        if (isPinned != null) 'isPinned': isPinned,
        if (order != null) 'order': order,
      };

  factory Sphere.fromJson(Map<String, dynamic> json) => Sphere(
        id: json['id'] as String,
        title: json['title'] as String,
        notes: (json['notes'] ?? '') as String,
        createdAt: json['createdAt'] as String,
        description: json['description'] as String?,
        deadline: json['deadline'] as String?,
        notesList: (json['notesList'] as List?)
            ?.whereType<Map>()
            .map((e) =>
                SphereNote.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
            .toList(),
        color: json['color'] as String?,
        icon: json['icon'] as String?,
        isPinned: json['isPinned'] as bool?,
        order: (json['order'] as num?)?.toInt(),
      );
}
