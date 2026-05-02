import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/sphere.dart';
import '../../models/task.dart';
import '../../services/photo_storage.dart';
import '../../state/providers.dart';

const _spherePalette = [
  Color(0xFF6D5CFF),
  Color(0xFFEC4899),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFF3B82F6),
  Color(0xFF14B8A6),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
];

const _sphereIcons = [
  '✨',
  '💼',
  '🏠',
  '💪',
  '📚',
  '❤️',
  '🎨',
  '💰',
  '👨‍👩‍👧',
  '🌱',
  '🧠',
  '🎯',
];

class SphereDetailsPage extends ConsumerWidget {
  const SphereDetailsPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sphere = ref.watch(spheresProvider).cast<Sphere?>().firstWhere(
          (s) => s?.id == id,
          orElse: () => null,
        );
    if (sphere == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Сфера')),
        body: const Center(child: Text('Сфера не найдена')),
      );
    }

    final tasks = ref
        .watch(tasksProvider)
        .where((t) => t.sphereId == sphere.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(sphere.title),
        actions: [
          IconButton(
            tooltip: sphere.isPinned == true ? 'Открепить' : 'Закрепить',
            icon: Icon(sphere.isPinned == true
                ? Icons.push_pin
                : Icons.push_pin_outlined),
            onPressed: () => ref.read(spheresProvider.notifier).update(
                sphere.id,
                (s) => s.copyWith(isPinned: !(s.isPinned ?? false))),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editMeta(context, ref, sphere),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await ref.read(spheresProvider.notifier).remove(sphere.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _Header(sphere: sphere),
          if (sphere.description != null && sphere.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(sphere.description!),
                ),
              ),
            ),
          const SizedBox(height: 16),
          _NotesCard(sphere: sphere),
          const SizedBox(height: 16),
          _LinkedTasksCard(sphere: sphere, tasks: tasks),
        ],
      ),
    );
  }

  Future<void> _editMeta(
      BuildContext context, WidgetRef ref, Sphere sphere) async {
    final title = TextEditingController(text: sphere.title);
    final desc = TextEditingController(text: sphere.description ?? '');
    String icon = sphere.icon ?? '✨';
    Color? color = _parseHex(sphere.color);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Изменить сферу',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextField(
                      controller: title,
                      decoration:
                          const InputDecoration(labelText: 'Название')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: desc,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(labelText: 'Описание')),
                  const SizedBox(height: 16),
                  Text('Иконка',
                      style: Theme.of(ctx).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final ic in _sphereIcons)
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => icon = ic),
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: icon == ic
                                  ? Theme.of(ctx)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.18)
                                  : Theme.of(ctx)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: icon == ic
                                    ? Theme.of(ctx).colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child:
                                Text(ic, style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Цвет', style: Theme.of(ctx).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    children: [
                      for (final c in _spherePalette)
                        GestureDetector(
                          onTap: () => setState(() => color = c),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _sameColor(color, c)
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: () => setState(() => color = null),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Theme.of(ctx)
                                .colorScheme
                                .surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      final t = title.text.trim();
                      if (t.isEmpty) return;
                      final descText = desc.text.trim();
                      await ref.read(spheresProvider.notifier).update(
                            sphere.id,
                            (s) => s.copyWith(
                              title: t,
                              description:
                                  descText.isEmpty ? null : descText,
                              clearDescription: descText.isEmpty,
                              icon: icon,
                              color:
                                  color != null ? _toHex(color!) : null,
                              clearColor: color == null,
                            ),
                          );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: const Text('Сохранить'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

Color? _parseHex(String? hex) {
  if (hex == null) return null;
  var s = hex.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  final v = int.tryParse(s, radix: 16);
  return v == null ? null : Color(v);
}

String _toHex(Color c) {
  // Stable Material-style "#RRGGBB" string for storage. Avoids the
  // deprecated `Color.value` getter by using the byte channel accessors.
  int b(double v) => (v * 255).round() & 0xff;
  final r = b(c.r).toRadixString(16).padLeft(2, '0');
  final g = b(c.g).toRadixString(16).padLeft(2, '0');
  final bl = b(c.b).toRadixString(16).padLeft(2, '0');
  return '#$r$g$bl';
}

bool _sameColor(Color? a, Color? b) {
  if (a == null || b == null) return false;
  return _toHex(a).toLowerCase() == _toHex(b).toLowerCase();
}

class _Header extends StatelessWidget {
  const _Header({required this.sphere});
  final Sphere sphere;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _parseHex(sphere.color) ?? scheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(sphere.icon ?? '✨',
                  style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sphere.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  if (sphere.deadline != null)
                    Text('до ${sphere.deadline!.split('T').first}',
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesCard extends ConsumerStatefulWidget {
  const _NotesCard({required this.sphere});
  final Sphere sphere;

  @override
  ConsumerState<_NotesCard> createState() => _NotesCardState();
}

class _NotesCardState extends ConsumerState<_NotesCard> {
  final _newNote = TextEditingController();
  bool _asCheckbox = false;

  @override
  void dispose() {
    _newNote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = [...?widget.sphere.notesList];
    notes.sort((a, b) {
      final pa = a.isPinned == true ? 0 : 1;
      final pb = b.isPinned == true ? 0 : 1;
      if (pa != pb) return pa.compareTo(pb);
      return b.createdAt.compareTo(a.createdAt);
    });
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Заметки',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: 'Камера',
                  icon: const Icon(Icons.photo_camera_outlined),
                  onPressed: () => _addPhoto(fromCamera: true),
                ),
                IconButton(
                  tooltip: 'Из галереи',
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  onPressed: () => _addPhoto(fromCamera: false),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newNote,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText:
                          _asCheckbox ? 'Новый чек-пункт' : 'Новая заметка',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addText(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip:
                      _asCheckbox ? 'Сделать обычной' : 'Сделать чек-пунктом',
                  icon: Icon(_asCheckbox
                      ? Icons.check_box_outlined
                      : Icons.check_box_outline_blank),
                  onPressed: () => setState(() => _asCheckbox = !_asCheckbox),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add),
                  onPressed: _addText,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (notes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                    'Тут будут идеи, фото и чек-листы по этой сфере жизни.'),
              )
            else
              for (final note in notes) _NoteTile(sphere: widget.sphere, note: note),
          ],
        ),
      ),
    );
  }

  void _addText() {
    final text = _newNote.text.trim();
    if (text.isEmpty) return;
    final note = SphereNote(
      id: const Uuid().v4(),
      content: text,
      createdAt: DateTime.now().toIso8601String(),
      isCheckbox: _asCheckbox ? true : null,
      isChecked: _asCheckbox ? false : null,
    );
    final next = [...?widget.sphere.notesList, note];
    ref.read(spheresProvider.notifier).update(
          widget.sphere.id,
          (s) => s.copyWith(notesList: next),
        );
    _newNote.clear();
  }

  Future<void> _addPhoto({required bool fromCamera}) async {
    final path = fromCamera
        ? await PhotoStorage.instance.captureAndStore(
            bucket: 'sphere_photos', entityId: widget.sphere.id)
        : await PhotoStorage.instance.pickAndStore(
            bucket: 'sphere_photos', entityId: widget.sphere.id);
    if (path == null) return;
    final note = SphereNote(
      id: const Uuid().v4(),
      content: '',
      createdAt: DateTime.now().toIso8601String(),
      photoUrl: path,
    );
    final next = [...?widget.sphere.notesList, note];
    await ref.read(spheresProvider.notifier).update(
          widget.sphere.id,
          (s) => s.copyWith(notesList: next),
        );
  }
}

class _NoteTile extends ConsumerWidget {
  const _NoteTile({required this.sphere, required this.note});
  final Sphere sphere;
  final SphereNote note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPhoto = note.photoUrl != null && note.photoUrl!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.isCheckbox == true)
                  Checkbox(
                    value: note.isChecked ?? false,
                    onChanged: (v) => _replace(ref,
                        note.copyWith(isChecked: v ?? false)),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(right: 8, top: 2),
                    child: Icon(Icons.note_outlined, size: 18),
                  ),
                Expanded(
                  child: note.content.isEmpty
                      ? const SizedBox.shrink()
                      : Text(
                          note.content,
                          style: TextStyle(
                            decoration: note.isChecked == true
                                ? TextDecoration.lineThrough
                                : null,
                            color: note.isChecked == true
                                ? Theme.of(context).disabledColor
                                : null,
                          ),
                        ),
                ),
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  tooltip:
                      note.isPinned == true ? 'Открепить' : 'Закрепить',
                  icon: Icon(note.isPinned == true
                      ? Icons.push_pin
                      : Icons.push_pin_outlined),
                  onPressed: () => _replace(
                      ref, note.copyWith(isPinned: !(note.isPinned ?? false))),
                ),
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(ref),
                ),
              ],
            ),
            if (hasPhoto) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _showPhoto(context, note.photoUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(note.photoUrl!),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Theme.of(context).colorScheme.surface,
                      height: 80,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _replace(WidgetRef ref, SphereNote updated) async {
    final list = [...?sphere.notesList];
    final idx = list.indexWhere((n) => n.id == note.id);
    if (idx == -1) return;
    list[idx] = updated;
    await ref.read(spheresProvider.notifier).update(
          sphere.id,
          (s) => s.copyWith(notesList: list),
        );
  }

  Future<void> _delete(WidgetRef ref) async {
    final list = [...?sphere.notesList]..removeWhere((n) => n.id == note.id);
    if (note.photoUrl != null && note.photoUrl!.isNotEmpty) {
      await PhotoStorage.instance.delete(note.photoUrl!);
    }
    await ref.read(spheresProvider.notifier).update(
          sphere.id,
          (s) => s.copyWith(notesList: list),
        );
  }

  void _showPhoto(BuildContext context, String path) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: InteractiveViewer(child: Image.file(File(path))),
        ),
      ),
    );
  }
}

class _LinkedTasksCard extends StatelessWidget {
  const _LinkedTasksCard({required this.sphere, required this.tasks});
  final Sphere sphere;
  final List<TaskItem> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Связанные задачи',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              const Text(
                  'Нет задач, привязанных к этой сфере. Привяжи задачу через её редактор.'),
            ],
          ),
        ),
      );
    }
    final ordered = [...tasks]..sort((a, b) {
        final ca = a.completed ? 1 : 0;
        final cb = b.completed ? 1 : 0;
        if (ca != cb) return ca.compareTo(cb);
        return a.createdAt.compareTo(b.createdAt);
      });
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Связанные задачи',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Все'),
                  onPressed: () => context.go('/tasks'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final t in ordered)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(t.completed
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked),
                title: Text(
                  t.title,
                  style: TextStyle(
                    decoration:
                        t.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(_periodLabel(t)),
              ),
          ],
        ),
      ),
    );
  }

  String _periodLabel(TaskItem t) => switch (t.period) {
        TaskPeriod.day => 'День · ${t.date}',
        TaskPeriod.week => 'Неделя · ${t.date}',
        TaskPeriod.month => 'Месяц · ${t.date}',
        TaskPeriod.year => 'Год · ${t.date}',
        TaskPeriod.history => 'Архив · ${t.date}',
      };
}
