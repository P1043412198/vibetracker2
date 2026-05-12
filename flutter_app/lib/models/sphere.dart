// 1:1 port of the `Sphere` and `SphereNote` types from `src/types.ts` —
// extended with [SphereCategory] so the user can group notes inside a
// sphere (Family → Home / Kids / Travel etc.).

class SphereCategory {
  SphereCategory({
    required this.id,
    required this.title,
    required this.createdAt,
    this.icon,
    this.color,
    this.notes,
  });

  final String id;
  final String title;
  final String createdAt;
  final String? icon;
  final String? color;
  final String? notes;

  SphereCategory copyWith({
    String? title,
    String? icon,
    String? color,
    String? notes,
    bool clearIcon = false,
    bool clearColor = false,
    bool clearNotes = false,
  }) {
    return SphereCategory(
      id: id,
      createdAt: createdAt,
      title: title ?? this.title,
      icon: clearIcon ? null : (icon ?? this.icon),
      color: clearColor ? null : (color ?? this.color),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (notes != null) 'notes': notes,
      };

  factory SphereCategory.fromJson(Map<String, dynamic> json) => SphereCategory(
        id: json['id'] as String,
        title: (json['title'] ?? '') as String,
        createdAt:
            (json['createdAt'] ?? DateTime.now().toIso8601String()) as String,
        icon: json['icon'] as String?,
        color: json['color'] as String?,
        notes: json['notes'] as String?,
      );
}

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
    this.categoryId,
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

  /// Optional id of a [SphereCategory] inside the same sphere — when set
  /// the note is grouped under that category in the UI.
  final String? categoryId;

  SphereNote copyWith({
    String? content,
    String? youtubeUrl,
    String? photoUrl,
    bool? isCheckbox,
    bool? isChecked,
    List<NoteComment>? comments,
    bool? isPinned,
    String? categoryId,
    bool clearCategoryId = false,
  }) {
    return SphereNote(
      id: id,
      createdAt: createdAt,
      content: content ?? this.content,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      photoUrl: photoUrl ?? this.photoUrl,
      isCheckbox: isCheckbox ?? this.isCheckbox,
      isChecked: isChecked ?? this.isChecked,
      comments: comments ?? this.comments,
      isPinned: isPinned ?? this.isPinned,
      categoryId:
          clearCategoryId ? null : (categoryId ?? this.categoryId),
    );
  }

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
        if (categoryId != null) 'categoryId': categoryId,
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
        categoryId: json['categoryId'] as String?,
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
    this.categories,
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
  final List<SphereCategory>? categories;
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
    List<SphereCategory>? categories,
    String? color,
    String? icon,
    bool? isPinned,
    int? order,
    bool clearDescription = false,
    bool clearColor = false,
    bool clearIcon = false,
  }) {
    return Sphere(
      id: id,
      title: title ?? this.title,
      description:
          clearDescription ? null : (description ?? this.description),
      deadline: deadline ?? this.deadline,
      notes: notes ?? this.notes,
      notesList: notesList ?? this.notesList,
      categories: categories ?? this.categories,
      createdAt: createdAt,
      color: clearColor ? null : (color ?? this.color),
      icon: clearIcon ? null : (icon ?? this.icon),
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
        if (categories != null)
          'categories': categories!.map((e) => e.toJson()).toList(),
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
        categories: (json['categories'] as List?)
            ?.whereType<Map>()
            .map((e) => SphereCategory.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v))))
            .toList(),
        color: json['color'] as String?,
        icon: json['icon'] as String?,
        isPinned: json['isPinned'] as bool?,
        order: (json['order'] as num?)?.toInt(),
      );
}
