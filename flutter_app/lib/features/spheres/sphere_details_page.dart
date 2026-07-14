import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/sphere.dart';
import '../../models/task.dart';
import '../../services/ai_service.dart';
import '../../services/gemini_service.dart';
import '../../services/photo_storage.dart';
import '../../state/providers.dart';
import '../../state/settings_state.dart';
import '../../widgets/ai_response_sheet.dart';
import 'sphere_note_page.dart';

const kSpherePalette = [
  Color(0xFF6D5CFF),
  Color(0xFFEC4899),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFF3B82F6),
  Color(0xFF14B8A6),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
];

const kSphereIcons = [
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

const _spherePalette = kSpherePalette;
const _sphereIcons = kSphereIcons;

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

    final notesCount = (sphere.notesList ?? const <SphereNote>[]).length;
    final categoriesCount =
        (sphere.categories ?? const <SphereCategory>[]).length;
    final tasksCount = tasks.length;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
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
            if (_isAiAvailable(ref))
              IconButton(
                tooltip: 'Сводка по сфере (AI)',
                icon: Icon(Icons.auto_awesome,
                    color: Theme.of(context).colorScheme.primary),
                onPressed: () =>
                    _showSphereSummary(context, sphere, tasks),
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
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              const Tab(text: 'Обзор'),
              Tab(text: 'Заметки · $notesCount'),
              Tab(text: 'Категории · $categoriesCount'),
              Tab(text: 'Задачи · $tasksCount'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: overview — header + description
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _Header(sphere: sphere),
                if (sphere.description != null &&
                    sphere.description!.isNotEmpty)
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
                _SphereSummaryGrid(
                  notes: notesCount,
                  categories: categoriesCount,
                  tasks: tasksCount,
                ),
              ],
            ),
            // Tab 2: notes
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [_NotesCard(sphere: sphere)],
            ),
            // Tab 3: categories
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [_CategoriesCard(sphere: sphere)],
            ),
            // Tab 4: tasks
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [_LinkedTasksCard(sphere: sphere, tasks: tasks)],
            ),
          ],
        ),
      ),
    );
  }

  bool _isAiAvailable(WidgetRef ref) {
    final key = AiService.apiKey;
    return key != null && key.isNotEmpty && ref.read(aiEnabledProvider);
  }

  void _showSphereSummary(
    BuildContext context,
    Sphere sphere,
    List<TaskItem> tasks,
  ) {
    final notes = sphere.notesList ?? const <SphereNote>[];
    final completedTasks = tasks.where((t) => t.completed).length;
    showAiResponseSheet(
      context: context,
      title: 'Сводка: ${sphere.title}',
      icon: Icons.psychology,
      future: GeminiService.summarizeSphere(
        sphereTitle: sphere.title,
        notesCount: notes.length,
        tasksTotal: tasks.length,
        tasksCompleted: completedTasks,
        habitsCount: 0,
        categoriesCount:
            (sphere.categories ?? const <SphereCategory>[]).length,
        recentNotes: notes
            .take(5)
            .map((n) => n.content)
            .toList(),
        recentTasks: tasks
            .take(5)
            .map((t) => t.title)
            .toList(),
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

class _CategoriesCard extends ConsumerStatefulWidget {
  const _CategoriesCard({required this.sphere});
  final Sphere sphere;

  @override
  ConsumerState<_CategoriesCard> createState() => _CategoriesCardState();
}

class _CategoriesCardState extends ConsumerState<_CategoriesCard> {
  @override
  Widget build(BuildContext context) {
    final cats = [...?widget.sphere.categories];
    final notes = [...?widget.sphere.notesList];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Категории',
                      style:
                          Theme.of(context).textTheme.titleMedium),
                ),
                IconButton.filledTonal(
                  tooltip: 'Добавить категорию',
                  icon: const Icon(Icons.add),
                  onPressed: () => _addOrEdit(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (cats.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                    'Каждая категория — это отдельный раздел со своей страницей и заметками (напр. «EN» / «BY» / «семья»).'),
              )
            else
              Column(
                children: [
                  for (final c in cats)
                    _CategoryListTile(
                      sphereId: widget.sphere.id,
                      category: c,
                      notesCount:
                          notes.where((n) => n.categoryId == c.id).length,
                      onEdit: () => _addOrEdit(context, edit: c),
                      onDelete: () => _delete(c),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addOrEdit(BuildContext context, {SphereCategory? edit}) async {
    final controller = TextEditingController(text: edit?.title ?? '');
    String icon = edit?.icon ?? '';
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
                  Text(edit == null ? 'Новая категория' : 'Изменить категорию',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Название',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final ic in _sphereIcons)
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
                      final t = controller.text.trim();
                      if (t.isEmpty) return;
                      final next = (edit ??
                              SphereCategory(
                                id: const Uuid().v4(),
                                title: t,
                                createdAt:
                                    DateTime.now().toIso8601String(),
                              ))
                          .copyWith(
                        title: t,
                        icon: icon.isEmpty ? null : icon,
                        clearIcon: icon.isEmpty,
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
    final list = [...?widget.sphere.categories];
    final idx = list.indexWhere((c) => c.id == result.id);
    if (idx == -1) {
      list.add(result);
    } else {
      list[idx] = result;
    }
    await ref.read(spheresProvider.notifier).update(
          widget.sphere.id,
          (s) => s.copyWith(categories: list),
        );
  }

  Future<void> _delete(SphereCategory cat) async {
    final list = [...?widget.sphere.categories]
      ..removeWhere((c) => c.id == cat.id);
    final notes = (widget.sphere.notesList ?? [])
        .map((n) => n.categoryId == cat.id
            ? n.copyWith(clearCategoryId: true)
            : n)
        .toList();
    await ref.read(spheresProvider.notifier).update(
          widget.sphere.id,
          (s) => s.copyWith(categories: list, notesList: notes),
        );
  }
}

/// Row for a single category inside [_CategoriesCard]. Tap opens the full
/// category page; the trailing icon button shows a tiny menu for editing or
/// deleting (the old InputChip behaviour, kept for parity).
class _CategoryListTile extends StatelessWidget {
  const _CategoryListTile({
    required this.sphereId,
    required this.category,
    required this.notesCount,
    required this.onEdit,
    required this.onDelete,
  });

  final String sphereId;
  final SphereCategory category;
  final int notesCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.pushNamed(
            'sphere-category',
            pathParameters: {
              'id': sphereId,
              'categoryId': category.id,
            },
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    (category.icon == null || category.icon!.isEmpty)
                        ? '📁'
                        : category.icon!,
                    style: const TextStyle(fontSize: 18),
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
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '$notesCount заметок',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Изменить'),
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Удалить'),
                        dense: true,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.chevron_right, size: 22),
              ],
            ),
          ),
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
  String? _filterCategoryId;

  @override
  Widget build(BuildContext context) {
    final cats = [...?widget.sphere.categories];
    var notes = [...?widget.sphere.notesList];
    if (_filterCategoryId != null) {
      notes = notes.where((n) => n.categoryId == _filterCategoryId).toList();
    }
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
                IconButton.filledTonal(
                  tooltip: 'Новая страница-заметка',
                  icon: const Icon(Icons.note_add_outlined),
                  onPressed: _addPage,
                ),
              ],
            ),
            if (cats.isNotEmpty) ...[
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      selected: _filterCategoryId == null,
                      label: const Text('Все'),
                      onSelected: (_) =>
                          setState(() => _filterCategoryId = null),
                    ),
                    for (final c in cats) ...[
                      const SizedBox(width: 6),
                      ChoiceChip(
                        selected: _filterCategoryId == c.id,
                        label: Text(
                          c.icon == null ? c.title : '${c.icon} ${c.title}',
                        ),
                        onSelected: (_) =>
                            setState(() => _filterCategoryId = c.id),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _addPage,
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Новая заметка-страница'),
              ),
            ),
            const SizedBox(height: 8),
            if (notes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Тут будут идеи, фото и чек-листы по этой сфере жизни. '
                  'Нажмите «Новая заметка-страница» — откроется полноценный '
                  'редактор с Markdown и чек-листами.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.outline),
                ),
              )
            else
              for (final note in notes) SphereNoteTile(sphere: widget.sphere, note: note),
          ],
        ),
      ),
    );
  }

  Future<void> _addPage() async {
    final note = SphereNote(
      id: const Uuid().v4(),
      content: '',
      createdAt: DateTime.now().toIso8601String(),
      categoryId: _filterCategoryId,
    );
    final next = [...?widget.sphere.notesList, note];
    await ref.read(spheresProvider.notifier).update(
          widget.sphere.id,
          (s) => s.copyWith(notesList: next),
        );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SphereNotePage(sphereId: widget.sphere.id, noteId: note.id),
      ),
    );
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
      categoryId: _filterCategoryId,
    );
    final next = [...?widget.sphere.notesList, note];
    await ref.read(spheresProvider.notifier).update(
          widget.sphere.id,
          (s) => s.copyWith(notesList: next),
        );
  }
}

class SphereNoteTile extends ConsumerWidget {
  const SphereNoteTile({super.key, required this.sphere, required this.note});
  final Sphere sphere;
  final SphereNote note;

  String? _firstPhoto() {
    if (note.photoUrl != null && note.photoUrl!.isNotEmpty) return note.photoUrl;
    for (final p in note.photoUrls ?? const <String>[]) {
      if (p.isNotEmpty) return p;
    }
    return null;
  }

  int _photoCount() {
    final set = <String>{};
    if (note.photoUrl != null && note.photoUrl!.isNotEmpty) set.add(note.photoUrl!);
    for (final p in note.photoUrls ?? const <String>[]) {
      if (p.isNotEmpty) set.add(p);
    }
    return set.length;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _parseHex(sphere.color) ?? scheme.primary;
    final checked = note.isChecked == true;
    final photo = _firstPhoto();
    final photoCount = _photoCount();

    final rawTitle = note.title?.trim();
    final body = note.content.trim();
    final displayTitle = (rawTitle != null && rawTitle.isNotEmpty)
        ? rawTitle
        : (body.isNotEmpty ? body.split('\n').first : '(без названия)');
    final snippet = (rawTitle != null && rawTitle.isNotEmpty)
        ? body
        : body.split('\n').skip(1).join(' ').trim();

    final when = DateTime.tryParse(note.updatedAt ?? note.createdAt);
    final whenLabel = when == null ? '' : DateFormat('d MMM, HH:mm', 'ru').format(when);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.isCheckbox == true)
                  SizedBox(
                    width: 26,
                    child: Checkbox(
                      value: checked,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) =>
                          _replace(ref, note.copyWith(isChecked: v ?? false)),
                    ),
                  )
                else
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6, right: 12, left: 4),
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                decoration: checked
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: checked ? scheme.outline : null,
                              ),
                            ),
                          ),
                          if (note.isPinned == true)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(Icons.push_pin,
                                  size: 15, color: accent),
                            ),
                        ],
                      ),
                      if (snippet.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          snippet,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, color: scheme.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 12, color: scheme.outline),
                          const SizedBox(width: 4),
                          Text(whenLabel,
                              style: TextStyle(
                                  fontSize: 11, color: scheme.outline)),
                          if (photoCount > 0) ...[
                            const SizedBox(width: 10),
                            Icon(Icons.photo_outlined,
                                size: 12, color: scheme.outline),
                            const SizedBox(width: 3),
                            Text('$photoCount',
                                style: TextStyle(
                                    fontSize: 11, color: scheme.outline)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (photo != null) ...[
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(PhotoStorage.instance.resolve(photo)),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: scheme.surface,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined, size: 18),
                      ),
                    ),
                  ),
                ],
                Icon(Icons.chevron_right, color: scheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SphereNotePage(sphereId: sphere.id, noteId: note.id),
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

/// Compact stat grid summarising how many entities are linked to the sphere.
/// Renders on the Обзор tab to give a quick at-a-glance overview.
class _SphereSummaryGrid extends StatelessWidget {
  const _SphereSummaryGrid({
    required this.notes,
    required this.categories,
    required this.tasks,
  });
  final int notes;
  final int categories;
  final int tasks;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            icon: Icons.note_alt_outlined,
            label: 'Заметки',
            value: notes,
            color: const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(
            icon: Icons.folder_outlined,
            label: 'Категории',
            value: categories,
            color: const Color(0xFFEC4899),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(
            icon: Icons.task_alt,
            label: 'Задачи',
            value: tasks,
            color: const Color(0xFF22C55E),
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
