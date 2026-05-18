import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../models/sphere.dart';
import '../../services/photo_storage.dart';
import '../../state/providers.dart';
import 'sphere_details_page.dart';

/// Full-screen page for a single [SphereCategory].
///
/// Before this page existed categories looked like tags inside the sphere —
/// the user asked to "create a separate section with its own page". This
/// page shows the category as a first-class entity: header with title +
/// icon + optional description, then all notes that belong to it, with the
/// same add-note / add-photo controls as the sphere page.
class SphereCategoryPage extends ConsumerWidget {
  const SphereCategoryPage({
    super.key,
    required this.sphereId,
    required this.categoryId,
  });

  final String sphereId;
  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sphere = ref.watch(spheresProvider).cast<Sphere?>().firstWhere(
          (s) => s?.id == sphereId,
          orElse: () => null,
        );
    if (sphere == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Категория')),
        body: const Center(child: Text('Сфера не найдена')),
      );
    }
    final cats = sphere.categories ?? const <SphereCategory>[];
    final category = cats.cast<SphereCategory?>().firstWhere(
          (c) => c?.id == categoryId,
          orElse: () => null,
        );
    if (category == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Категория')),
        body: const Center(child: Text('Категория не найдена')),
      );
    }
    final notes = (sphere.notesList ?? const <SphereNote>[])
        .where((n) => n.categoryId == category.id)
        .toList()
      ..sort((a, b) {
        final pa = a.isPinned == true ? 0 : 1;
        final pb = b.isPinned == true ? 0 : 1;
        if (pa != pb) return pa.compareTo(pb);
        return b.createdAt.compareTo(a.createdAt);
      });
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              (category.icon == null || category.icon!.isEmpty)
                  ? '📁'
                  : category.icon!,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(category.title, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Изменить',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                _editCategory(context, ref, sphere, category),
          ),
          IconButton(
            tooltip: 'Удалить',
            icon: const Icon(Icons.delete_outline),
            onPressed: () =>
                _deleteCategory(context, ref, sphere, category),
          ),
        ],
        leading: BackButton(
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Header card.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (category.icon == null || category.icon!.isEmpty)
                        ? '📁'
                        : category.icon!,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'В сфере «${sphere.title}» · ${notes.length} заметок',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (category.notes != null && category.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(category.notes!),
            ),
          ],
          const SizedBox(height: 16),
          _AddNoteCard(sphere: sphere, categoryId: category.id),
          const SizedBox(height: 12),
          if (notes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Здесь пока пусто.\nДобавь первую заметку выше.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
            )
          else
            for (final n in notes)
              SphereNoteTile(sphere: sphere, note: n),
        ],
      ),
    );
  }

  Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref,
    Sphere sphere,
    SphereCategory category,
  ) async {
    final titleCtrl = TextEditingController(text: category.title);
    final notesCtrl = TextEditingController(text: category.notes ?? '');
    String icon = category.icon ?? '';

    final result = await showModalBottomSheet<SphereCategory?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
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
                  Text(
                    'Категория',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Название',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Описание (необязательно)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final ic in kSphereIcons)
                        InkWell(
                          onTap: () => setState(() {
                            icon = icon == ic ? '' : ic;
                          }),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 36,
                            height: 36,
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
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child:
                                Text(ic, style: const TextStyle(fontSize: 20)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      final t = titleCtrl.text.trim();
                      if (t.isEmpty) return;
                      final n = notesCtrl.text.trim();
                      final next = category.copyWith(
                        title: t,
                        icon: icon.isEmpty ? null : icon,
                        clearIcon: icon.isEmpty,
                        notes: n.isEmpty ? null : n,
                        clearNotes: n.isEmpty,
                      );
                      Navigator.of(ctx).pop(next);
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
    if (result == null) return;
    final list = [...?sphere.categories];
    final idx = list.indexWhere((c) => c.id == result.id);
    if (idx == -1) {
      list.add(result);
    } else {
      list[idx] = result;
    }
    await ref.read(spheresProvider.notifier).update(
          sphere.id,
          (s) => s.copyWith(categories: list),
        );
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    Sphere sphere,
    SphereCategory category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить категорию?'),
        content: Text(
          'Категория «${category.title}» будет удалена. '
          'Заметки внутри останутся в сфере без категории.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final list = [...?sphere.categories]
      ..removeWhere((c) => c.id == category.id);
    final notes = (sphere.notesList ?? const <SphereNote>[])
        .map((n) => n.categoryId == category.id
            ? n.copyWith(clearCategoryId: true)
            : n)
        .toList();
    await ref.read(spheresProvider.notifier).update(
          sphere.id,
          (s) => s.copyWith(categories: list, notesList: notes),
        );
    if (!context.mounted) return;
    context.pop();
  }
}

/// Inline note-creation card for the category page. Mirrors the controls
/// from `_NotesCard` but always pins the new note to [categoryId].
class _AddNoteCard extends ConsumerStatefulWidget {
  const _AddNoteCard({required this.sphere, required this.categoryId});

  final Sphere sphere;
  final String categoryId;

  @override
  ConsumerState<_AddNoteCard> createState() => _AddNoteCardState();
}

class _AddNoteCardState extends ConsumerState<_AddNoteCard> {
  final _ctrl = TextEditingController();
  bool _asCheckbox = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    isDense: true,
                    labelText: _asCheckbox
                        ? 'Новый чек-пункт'
                        : 'Новая заметка',
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
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  onPressed: () => _addPhoto(fromCamera: true),
                  label: const Text('Камера'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_photo_alternate_outlined,
                      size: 18),
                  onPressed: () => _addPhoto(fromCamera: false),
                  label: const Text('Из галереи'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addText() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final note = SphereNote(
      id: const Uuid().v4(),
      content: text,
      createdAt: DateTime.now().toIso8601String(),
      isCheckbox: _asCheckbox ? true : null,
      isChecked: _asCheckbox ? false : null,
      categoryId: widget.categoryId,
    );
    final next = [...?widget.sphere.notesList, note];
    ref.read(spheresProvider.notifier).update(
          widget.sphere.id,
          (s) => s.copyWith(notesList: next),
        );
    _ctrl.clear();
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
      categoryId: widget.categoryId,
    );
    final next = [...?widget.sphere.notesList, note];
    await ref.read(spheresProvider.notifier).update(
          widget.sphere.id,
          (s) => s.copyWith(notesList: next),
        );
  }
}
