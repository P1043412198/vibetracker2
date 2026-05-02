import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/sphere.dart';
import '../state/providers.dart';

/// Receives Android Sharesheet (`ACTION_SEND`, `text/plain`) handoffs and
/// stores them as a note inside the "Заметки" sphere — counterpart of
/// `src/pages/ShareTarget.tsx` in the React build.
class ShareIntentService {
  ShareIntentService._();
  static final ShareIntentService instance = ShareIntentService._();

  static const _channel = MethodChannel('ai.vibesight.tracker/share');
  bool _attached = false;

  Future<void> attach(WidgetRef ref) async {
    if (_attached) return;
    _attached = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShare') {
        final payload = call.arguments;
        if (payload is String && payload.isNotEmpty) {
          await _saveToNotes(ref, payload);
        }
      }
    });

    // Drain any cold-start payload that the activity captured before we
    // hooked up the channel.
    try {
      final pending = await _channel.invokeMethod<String?>('consumePending');
      if (pending != null && pending.isNotEmpty) {
        await _saveToNotes(ref, pending);
      }
    } catch (_) {
      // Channel might not be available outside Android — safe to ignore.
    }
  }

  Future<void> _saveToNotes(WidgetRef ref, String content) async {
    final spheres = ref.read(spheresProvider);
    final controller = ref.read(spheresProvider.notifier);
    final uuid = const Uuid();
    final now = DateTime.now().toIso8601String();

    Sphere? notesSphere = spheres.firstWhereOrNull(
      (s) => s.title.trim().toLowerCase() == 'заметки',
    );

    final newNote = SphereNote(
      id: uuid.v4(),
      content: content,
      createdAt: now,
    );

    if (notesSphere == null) {
      final created = Sphere(
        id: uuid.v4(),
        title: 'Заметки',
        notes: '',
        createdAt: now,
        description: 'Сохранённые ссылки и идеи',
        notesList: [newNote],
      );
      await controller.add(created);
    } else {
      final next = [...?notesSphere.notesList, newNote];
      await controller.upsert(notesSphere.copyWith(notesList: next));
    }
  }
}

extension _FirstWhere<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
