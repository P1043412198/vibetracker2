import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
  late bool _preview;

  @override
  void initState() {
    super.initState();
    final note = _currentNote();
    _title = TextEditingController(text: note?.title ?? '');
    _body = TextEditingController(text: note?.content ?? '');
    // Open existing notes in read/preview mode; brand-new empty notes start
    // in edit mode so the user can begin typing right away.
    _preview = (note?.content ?? '').trim().isNotEmpty ||
        (note?.title ?? '').trim().isNotEmpty;
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

  /// Insert [snippet] at the caret, placing the caret at the end of it. When
  /// [atLineStart] the snippet is pushed to the beginning of the current line
  /// (used for block prefixes like headings / list bullets).
  void _insert(String snippet, {bool atLineStart = false}) {
    final text = _body.text;
    final sel = _body.selection;
    var start = sel.start < 0 ? text.length : sel.start;
    var end = sel.end < 0 ? text.length : sel.end;
    if (atLineStart) {
      final lineStart = text.lastIndexOf('\n', start - 1) + 1;
      start = lineStart;
      end = lineStart;
    }
    final next = text.replaceRange(start, end, snippet);
    _body.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + snippet.length),
    );
  }

  /// Wrap the current selection (or caret word) with [marker] on both sides.
  void _wrap(String marker) {
    final text = _body.text;
    final sel = _body.selection;
    if (sel.start < 0 || sel.end < 0 || sel.start == sel.end) {
      _insert('$marker$marker');
      // Park the caret between the markers.
      final pos = _body.selection.start - marker.length;
      _body.selection = TextSelection.collapsed(offset: pos);
      return;
    }
    final selected = text.substring(sel.start, sel.end);
    final next = text.replaceRange(sel.start, sel.end, '$marker$selected$marker');
    _body.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
          offset: sel.end + marker.length * 2),
    );
  }

  /// Toggle the checkbox on the source line at [lineIndex] (`- [ ]`↔`- [x]`)
  /// and persist immediately so preview taps stick.
  void _toggleTaskLine(int lineIndex) {
    final lines = _body.text.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return;
    final m = _taskLine.firstMatch(lines[lineIndex]);
    if (m == null) return;
    final done = m.group(2)!.toLowerCase() == 'x';
    lines[lineIndex] = '${m.group(1)}- [${done ? ' ' : 'x'}] ${m.group(3)}';
    _body.text = lines.join('\n');
    _flushText();
    setState(() {});
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
              tooltip: _preview ? 'Редактировать' : 'Просмотр',
              icon: Icon(_preview
                  ? Icons.edit_outlined
                  : Icons.visibility_outlined),
              onPressed: () {
                if (!_preview) _flushText();
                setState(() => _preview = !_preview);
              },
            ),
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
            if (_preview)
              _MarkdownNote(
                text: _body.text,
                accent: accent,
                onToggleTask: _toggleTaskLine,
              )
            else ...[
              _MarkdownToolbar(
                onHeading: () => _insert('## ', atLineStart: true),
                onBullet: () => _insert('- ', atLineStart: true),
                onCheckbox: () => _insert('- [ ] ', atLineStart: true),
                onBold: () => _wrap('**'),
                onItalic: () => _wrap('*'),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _body,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 16, height: 1.5),
                maxLines: null,
                minLines: 6,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Начните писать… поддерживается Markdown: '
                      '## заголовок, **жирный**, - список, - [ ] чек-пункт',
                  border: InputBorder.none,
                ),
              ),
            ],
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

/// Matches a GitHub-style task list line: optional indent, `- [ ]`/`- [x]`,
/// then the label. Group 1 = indent, group 2 = the check char, group 3 = label.
final RegExp _taskLine = RegExp(r'^(\s*)[-*]\s\[([ xX])\]\s?(.*)$');

/// A compact formatting toolbar for the note body.
class _MarkdownToolbar extends StatelessWidget {
  const _MarkdownToolbar({
    required this.onHeading,
    required this.onBullet,
    required this.onCheckbox,
    required this.onBold,
    required this.onItalic,
  });

  final VoidCallback onHeading;
  final VoidCallback onBullet;
  final VoidCallback onCheckbox;
  final VoidCallback onBold;
  final VoidCallback onItalic;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String tip, VoidCallback onTap) => IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: tip,
          icon: Icon(icon, size: 20),
          onPressed: onTap,
        );
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            btn(Icons.title, 'Заголовок', onHeading),
            btn(Icons.format_bold, 'Жирный', onBold),
            btn(Icons.format_italic, 'Курсив', onItalic),
            btn(Icons.format_list_bulleted, 'Список', onBullet),
            btn(Icons.checklist, 'Чек-пункт', onCheckbox),
          ],
        ),
      ),
    );
  }
}

/// Renders the note body as Markdown, with GitHub-style task items shown as
/// tappable checkboxes that toggle the underlying source line.
class _MarkdownNote extends StatelessWidget {
  const _MarkdownNote({
    required this.text,
    required this.accent,
    required this.onToggleTask,
  });

  final String text;
  final Color accent;
  final void Function(int lineIndex) onToggleTask;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return Text('Пусто — нажмите «Редактировать», чтобы начать писать.',
          style: TextStyle(color: Theme.of(context).colorScheme.outline));
    }

    final styleSheet = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: const TextStyle(fontSize: 16, height: 1.5),
    );
    void openLink(String? href) {
      if (href == null) return;
      final uri = Uri.tryParse(href);
      if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    final lines = text.split('\n');
    final children = <Widget>[];
    final buffer = <String>[];

    void flushBuffer() {
      if (buffer.isEmpty) return;
      children.add(MarkdownBody(
        data: buffer.join('\n'),
        selectable: true,
        styleSheet: styleSheet,
        onTapLink: (_, href, __) => openLink(href),
      ));
      buffer.clear();
    }

    for (var i = 0; i < lines.length; i++) {
      final m = _taskLine.firstMatch(lines[i]);
      if (m == null) {
        buffer.add(lines[i]);
        continue;
      }
      flushBuffer();
      final done = m.group(2)!.toLowerCase() == 'x';
      final label = m.group(3) ?? '';
      final idx = i;
      children.add(
        InkWell(
          onTap: () => onToggleTask(idx),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  done ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 22,
                  color: done ? accent : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: MarkdownBody(
                      data: label.isEmpty ? '\u200b' : label,
                      selectable: false,
                      styleSheet: styleSheet.copyWith(
                        p: TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          color: done
                              ? Theme.of(context).colorScheme.outline
                              : null,
                        ),
                      ),
                      onTapLink: (_, href, __) => openLink(href),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    flushBuffer();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
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
