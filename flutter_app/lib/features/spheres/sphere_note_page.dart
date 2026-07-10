import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/sphere.dart';
import '../../services/photo_storage.dart';
import '../../state/providers.dart';

/// Full-screen editor that turns a single [SphereNote] into a proper page:
/// large title + body, photo gallery, category, pin / checkbox and metadata.
class SphereNotePage extends ConsumerStatefulWidget {
  const SphereNotePage({
    super.key,
    required this.sphereId,
    required this.noteId,
  });

  final String sphereId;
  final String noteId;

  @override
  ConsumerState<SphereNotePage> createState() => _SphereNotePageState();
}

class _SphereNotePageState extends ConsumerState<SphereNotePage> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  Timer? _debounce;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final note = _currentNote();
    _title = TextEditingController(text: note?.title ?? '');
    _body = TextEditingController(text: note?.content ?? '');
    _title.addListener(_onChanged);
    _body.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  SphereNote? _currentNote() {
    final sphere = ref
        .read(spheresProvider)
        .cast<Sphere?>()
        .firstWhere((s) => s?.id == widget.sphereId, orElse: () => null);
    return (sphere?.notesList ?? const <SphereNote>[])
        .cast<SphereNote?>()
        .firstWhere((n) => n?.id == widget.noteId, orElse: () => null);
  }

  void _onChanged() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _flushText);
  }

  void _flushText() {
    if (!_dirty) return;
    _dirty = false;
    _update((n) => n.copyWith(
          title: _title.text.trim().isEmpty ? null : _title.text.trim(),
          clearTitle: _title.text.trim().isEmpty,
          content: _body.text,
          updatedAt: DateTime.now().toIso8601String(),
        ));
  }

  void _update(SphereNote Function(SphereNote) transform) {
    final sphere = ref
        .read(spheresProvider)
        .cast<Sphere?>()
        .firstWhere((s) => s?.id == widget.sphereId, orElse: () => null);
    if (sphere == null) return;
    final list = [...?sphere.notesList];
    final idx = list.indexWhere((n) => n.id == widget.noteId);
    if (idx == -1) return;
    list[idx] = transform(list[idx]);
    ref
        .read(spheresProvider.notifier)
        .update(widget.sphereId, (s) => s.copyWith(notesList: list));
  }

  List<String> _photos(SphereNote note) {
    final out = <String>[];
    if (note.photoUrl != null && note.photoUrl!.isNotEmpty) {
      out.add(note.photoUrl!);
    }
    for (final p in note.photoUrls ?? const <String>[]) {
      if (p.isNotEmpty && !out.contains(p)) out.add(p);
    }
    return out;
  }

  Future<void> _addPhoto({required bool fromCamera}) async {
    final path = fromCamera
        ? await PhotoStorage.instance
            .captureAndStore(bucket: 'sphere_photos', entityId: widget.sphereId)
        : await PhotoStorage.instance
            .pickAndStore(bucket: 'sphere_photos', entityId: widget.sphereId);
    if (path == null) return;
    _update((n) {
      final photos = _photos(n)..add(path);
      return n.copyWith(
        photoUrls: photos,
        clearTitle: false,
        updatedAt: DateTime.now().toIso8601String(),
      );
    });
  }

  Future<void> _removePhoto(String path) async {
    await PhotoStorage.instance.delete(path);
    _update((n) {
      final photos = _photos(n)..remove(path);
      // Legacy single photoUrl gets folded into the list, so clear it too.
      return SphereNote(
        id: n.id,
        content: n.content,
        createdAt: n.createdAt,
        title: n.title,
        updatedAt: DateTime.now().toIso8601String(),
        youtubeUrl: n.youtubeUrl,
        photoUrl: null,
        isCheckbox: n.isCheckbox,
        isChecked: n.isChecked,
        comments: n.comments,
        isPinned: n.isPinned,
        categoryId: n.categoryId,
        links: n.links,
        photoUrls: photos,
        videoUrls: n.videoUrls,
        audioUrls: n.audioUrls,
        documentPaths: n.documentPaths,
      );
    });
  }

  Future<bool> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить заметку?'),
        content: const Text('Заметку и её фото нельзя будет восстановить.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _deleteNote() async {
    final note = _currentNote();
    for (final p in note == null ? const <String>[] : _photos(note)) {
      await PhotoStorage.instance.delete(p);
    }
    final sphere = ref
        .read(spheresProvider)
        .cast<Sphere?>()
        .firstWhere((s) => s?.id == widget.sphereId, orElse: () => null);
    if (sphere != null) {
      final list = [...?sphere.notesList]
        ..removeWhere((n) => n.id == widget.noteId);
      await ref
          .read(spheresProvider.notifier)
          .update(widget.sphereId, (s) => s.copyWith(notesList: list));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final sphere = ref.watch(spheresProvider).cast<Sphere?>().firstWhere(
        (s) => s?.id == widget.sphereId,
        orElse: () => null);
    final note = (sphere?.notesList ?? const <SphereNote>[])
        .cast<SphereNote?>()
        .firstWhere((n) => n?.id == widget.noteId, orElse: () => null);

    if (sphere == null || note == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Заметка не найдена')),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final accent = _parseHex(sphere.color) ?? scheme.primary;
    final cats = [...?sphere.categories];
    final photos = _photos(note);
    final created = _fmt(note.createdAt);
    final updated = note.updatedAt == null ? null : _fmt(note.updatedAt!);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) => _flushText(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(sphere.title, style: const TextStyle(fontSize: 16)),
          actions: [
            IconButton(
              tooltip: note.isPinned == true ? 'Открепить' : 'Закрепить',
              icon: Icon(note.isPinned == true
                  ? Icons.push_pin
                  : Icons.push_pin_outlined),
              onPressed: () => _update((n) =>
                  n.copyWith(isPinned: !(n.isPinned ?? false))),
            ),
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await _confirmDelete()) await _deleteNote();
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'Заголовок',
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule, size: 13, color: scheme.outline),
                const SizedBox(width: 5),
                Text(
                  updated == null ? created : '$created · изм. $updated',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.outline),
                ),
              ],
            ),
            const Divider(height: 24),
            TextField(
              controller: _body,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 16, height: 1.5),
              maxLines: null,
              minLines: 6,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: 'Начните писать…',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 20),

            // Attributes row: checkbox + category.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  avatar: Icon(
                    note.isCheckbox == true
                        ? (note.isChecked == true
                            ? Icons.check_box
                            : Icons.check_box_outline_blank)
                        : Icons.check_box_outlined,
                    size: 18,
                  ),
                  label: Text(note.isCheckbox == true
                      ? 'Чек-пункт'
                      : 'Сделать чек-пунктом'),
                  selected: note.isCheckbox == true,
                  onSelected: (sel) => _update((n) => n.copyWith(
                        isCheckbox: sel,
                        isChecked: sel ? (n.isChecked ?? false) : false,
                      )),
                ),
                if (note.isCheckbox == true)
                  FilterChip(
                    avatar: Icon(
                      note.isChecked == true
                          ? Icons.task_alt
                          : Icons.radio_button_unchecked,
                      size: 18,
                    ),
                    label: Text(note.isChecked == true
                        ? 'Выполнено'
                        : 'Не выполнено'),
                    selected: note.isChecked == true,
                    onSelected: (sel) =>
                        _update((n) => n.copyWith(isChecked: sel)),
                  ),
              ],
            ),
            if (cats.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.folder_outlined, size: 18, color: scheme.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: note.categoryId,
                      hint: const Text('Без категории'),
                      underline: const SizedBox.shrink(),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Без категории'),
                        ),
                        for (final c in cats)
                          DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(
                              c.icon == null ? c.title : '${c.icon} ${c.title}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => _update((n) => v == null
                          ? n.copyWith(clearCategoryId: true)
                          : n.copyWith(categoryId: v)),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),
            Row(
              children: [
                Text('Фото', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton.filledTonal(
                  tooltip: 'Камера',
                  icon: const Icon(Icons.photo_camera_outlined),
                  onPressed: () => _addPhoto(fromCamera: true),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: 'Галерея',
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  onPressed: () => _addPhoto(fromCamera: false),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (photos.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Icon(Icons.image_outlined, color: scheme.outline),
                    const SizedBox(height: 6),
                    Text('Нет фото',
                        style: TextStyle(color: scheme.outline)),
                  ],
                ),
              )
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  for (final p in photos)
                    _PhotoThumb(
                      path: p,
                      accent: accent,
                      onView: () => _showPhoto(context, p),
                      onRemove: () => _removePhoto(p),
                    ),
                ],
              ),
          ],
        ),
      ),
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

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({
    required this.path,
    required this.accent,
    required this.onView,
    required this.onRemove,
  });

  final String path;
  final Color accent;
  final VoidCallback onView;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: onView,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
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

String _fmt(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  return DateFormat('d MMM yyyy, HH:mm', 'ru').format(dt);
}
