import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/finance.dart';
import '../../models/habit.dart';
import '../../models/misc.dart';
import '../../models/sphere.dart';
import '../../models/task.dart';
import '../../services/ai_service.dart';
import '../../services/gemini_service.dart';
import '../../services/link_preview_service.dart';
import '../../state/providers.dart';
import '../../state/settings_state.dart';

/// Chat-style "Сохранёнки" / inbox.
///
/// Replaces the original GTD-only capture: every entry can now be a plain
/// note **or** a saved link (with og:title / og:image preview), and the
/// list renders like a messenger thread (newest at the bottom, composer
/// pinned to the bottom of the screen).
///
/// Promotion to task/habit is still available via the long-press menu so
/// nothing is lost from the previous workflow — it's just no longer the
/// dominant action.
class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});

  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> {
  final _composerController = TextEditingController();
  final _composerFocus = FocusNode();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  String _filter = 'all'; // all | links | notes | <platform>
  String _query = '';
  bool _showSearch = false;

  /// Ids that the user is currently multi-selecting. The set drives the
  /// AppBar swap (count + bulk actions) and the bubble's checkmark / tinted
  /// background — there is no separate "isSelecting" flag.
  final Set<String> _selectedIds = <String>{};
  bool get _isSelecting => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _composerController.dispose();
    _composerFocus.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final text = _composerController.text.trim();
    if (text.isEmpty) return;
    await _addEntry(text);
    _composerController.clear();
    _composerFocus.requestFocus();
    _scrollToBottom();
  }

  /// Build an [InboxItem] from raw text — detect first URL, parse hashtags,
  /// fire-and-forget the link-preview fetch (which then upserts the entry
  /// once metadata is back). Returns immediately so the UI stays snappy.
  Future<void> _addEntry(String text) async {
    final parsed = parseFirstUrl(text);
    final tags = extractHashtags(text);
    final id = const Uuid().v4();
    final item = InboxItem(
      id: id,
      content: text,
      createdAt: DateTime.now().toIso8601String(),
      url: parsed.url,
      linkDomain: parsed.domain,
      platform: parsed.platform,
      tags: tags.isEmpty ? null : tags,
    );
    await ref.read(inboxProvider.notifier).add(item);

    // Preview is async; if/when it succeeds, patch the same id in place.
    if (parsed.isNotEmpty) {
      // ignore: discarded_futures
      _hydratePreview(id, parsed.url!);
    }
  }

  Future<void> _hydratePreview(String id, String url) async {
    final preview = await fetchLinkPreview(url);
    if (preview.isEmpty) return;
    final list = ref.read(inboxProvider);
    final existing = list.firstWhere(
      (e) => e.id == id,
      orElse: () => InboxItem(id: '', content: '', createdAt: ''),
    );
    if (existing.id.isEmpty) return;
    await ref.read(inboxProvider.notifier).upsert(
          existing.copyWith(
            linkTitle: preview.title,
            linkImage: preview.imageUrl,
          ),
        );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    await _addEntry(text);
    _scrollToBottom();
  }

  /// Bottom sheet that lets the user attach an image / video from the
  /// gallery or camera. Files are copied into the same private
  /// `inbox_media/` dir the share-target uses, so render and cleanup
  /// stay symmetric with shared media.
  Future<void> _pickMedia() async {
    final picked = await showModalBottomSheet<_PickChoice>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Картинка из галереи'),
              onTap: () => Navigator.of(sheetCtx).pop(_PickChoice.imageGallery),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Видео из галереи'),
              onTap: () => Navigator.of(sheetCtx).pop(_PickChoice.videoGallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Сфотографировать'),
              onTap: () => Navigator.of(sheetCtx).pop(_PickChoice.imageCamera),
            ),
            ListTile(
              leading: const Icon(Icons.video_camera_back_outlined),
              title: const Text('Снять видео'),
              onTap: () => Navigator.of(sheetCtx).pop(_PickChoice.videoCamera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final picker = ImagePicker();
    XFile? file;
    String type = 'image';
    try {
      switch (picked) {
        case _PickChoice.imageGallery:
          file = await picker.pickImage(source: ImageSource.gallery);
          type = 'image';
          break;
        case _PickChoice.imageCamera:
          file = await picker.pickImage(source: ImageSource.camera);
          type = 'image';
          break;
        case _PickChoice.videoGallery:
          file = await picker.pickVideo(source: ImageSource.gallery);
          type = 'video';
          break;
        case _PickChoice.videoCamera:
          file = await picker.pickVideo(source: ImageSource.camera);
          type = 'video';
          break;
      }
    } catch (_) {
      return;
    }
    if (file == null) return;
    final saved = await _persistMediaFile(File(file.path), type: type);
    final caption = _composerController.text.trim();
    await ref.read(inboxProvider.notifier).add(
          InboxItem(
            id: const Uuid().v4(),
            content: caption,
            createdAt: DateTime.now().toIso8601String(),
            tags: caption.isEmpty
                ? null
                : (extractHashtags(caption).isEmpty
                    ? null
                    : extractHashtags(caption)),
            mediaPath: saved.path,
            mediaType: type,
            mediaMime: file.mimeType,
          ),
        );
    _composerController.clear();
    _scrollToBottom();
  }

  /// Copy [src] into the private `inbox_media/` directory and return the
  /// resulting [File]. We always copy because [XFile.path] for camera
  /// captures lives in a tmp dir that the OS may evict at any point.
  Future<File> _persistMediaFile(File src, {required String type}) async {
    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(dir.path, 'inbox_media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    final ext = p.extension(src.path).isEmpty
        ? (type == 'image' ? '.jpg' : '.mp4')
        : p.extension(src.path);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final dst = File(p.join(mediaDir.path, '${type}_$ts$ext'));
    await src.copy(dst.path);
    return dst;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _togglePin(InboxItem item) async {
    await ref.read(inboxProvider.notifier).upsert(
          item.copyWith(pinned: !item.pinned),
        );
  }

  Future<void> _toggleArchive(InboxItem item) async {
    await ref.read(inboxProvider.notifier).upsert(
          item.copyWith(archived: !item.archived),
        );
  }

  Future<void> _delete(InboxItem item) async {
    await ref.read(inboxProvider.notifier).remove(item.id);
  }

  /// Remove [item] and show an undo snackbar that re-inserts it if pressed.
  /// Used by the swipe-to-delete action.
  Future<void> _deleteWithUndo(InboxItem item) async {
    await ref.read(inboxProvider.notifier).remove(item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Удалено'),
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () async {
            await ref.read(inboxProvider.notifier).upsert(item);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _copy(InboxItem item) async {
    await Clipboard.setData(ClipboardData(text: item.content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Скопировано')),
    );
  }

  Future<void> _open(InboxItem item) async {
    if (item.hasMedia) {
      // Hand the file off to the system viewer (gallery / video player).
      // launchUrl with file:// works on Android via FileProvider when the
      // file lives in app's private dir, but since 7.0 strict-uri rules
      // can reject it; fall back to opening the parent dir on failure.
      final uri = Uri.file(item.mediaPath!);
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
      return;
    }
    if (!item.isLink) return;
    final uri = Uri.tryParse(item.url!);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _promoteToTask(InboxItem item) async {
    await ref.read(tasksProvider.notifier).add(TaskItem(
          id: const Uuid().v4(),
          title: item.content,
          period: TaskPeriod.day,
          date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          completed: false,
          failed: false,
          createdAt: DateTime.now().toIso8601String(),
        ));
    await _delete(item);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Перенесено в задачи')),
    );
  }

  Future<void> _promoteToHabit(InboxItem item) async {
    await ref.read(habitsProvider.notifier).add(Habit(
          id: const Uuid().v4(),
          title: item.content,
          type: HabitTypeKind.good,
          createdAt: DateTime.now().toIso8601String(),
        ));
    await _delete(item);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Перенесено в привычки')),
    );
  }

  /// Move one or more inbox items to a destination chosen by the user.
  /// Pops a single sheet asking what to do (задача / привычка / заметка /
  /// сфера / категория сферы) then routes accordingly.
  Future<void> _promoteMany(List<InboxItem> items) async {
    if (items.isEmpty) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                items.length == 1
                    ? 'Перенести в…'
                    : 'Перенести ${items.length} в…',
                style: Theme.of(sheetCtx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.task_alt),
              title: const Text('В задачи'),
              onTap: () => Navigator.of(sheetCtx).pop('task'),
            ),
            ListTile(
              leading: const Icon(Icons.eco),
              title: const Text('В привычки'),
              onTap: () => Navigator.of(sheetCtx).pop('habit'),
            ),
            ListTile(
              leading: const Icon(Icons.note_alt_outlined),
              title: const Text('В заметки'),
              subtitle: const Text('Бытовые заметки (Общее)'),
              onTap: () => Navigator.of(sheetCtx).pop('note'),
            ),
            ListTile(
              leading: const Icon(Icons.bubble_chart_outlined),
              title: const Text('В сферу'),
              subtitle: const Text('Станет заметкой внутри сферы'),
              onTap: () => Navigator.of(sheetCtx).pop('sphere'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('В категорию сферы'),
              onTap: () => Navigator.of(sheetCtx).pop('sphere-cat'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null) return;

    switch (action) {
      case 'task':
        for (final item in items) {
          await _promoteToTask(item);
        }
        break;
      case 'habit':
        for (final item in items) {
          await _promoteToHabit(item);
        }
        break;
      case 'note':
        await _promoteToHouseholdNotes(items);
        break;
      case 'sphere':
        await _promoteToSphere(items, withCategory: false);
        break;
      case 'sphere-cat':
        await _promoteToSphere(items, withCategory: true);
        break;
    }
    if (mounted) setState(_selectedIds.clear);
  }

  Future<void> _promoteToHouseholdNotes(List<InboxItem> items) async {
    final notes = ref.read(householdNotesProvider);
    final cats = <String>{
      'Из инбокса',
      for (final n in notes) n.category,
    }.toList()
      ..sort();
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Категория заметки'),
        children: [
          for (final c in cats)
            SimpleDialogOption(
              child: Text(c),
              onPressed: () => Navigator.of(ctx).pop(c),
            ),
          SimpleDialogOption(
            child: const Text('+ Новая…'),
            onPressed: () async {
              final controller = TextEditingController();
              final v = await showDialog<String>(
                context: ctx,
                builder: (innerCtx) => AlertDialog(
                  title: const Text('Новая категория'),
                  content: TextField(
                      controller: controller, autofocus: true),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(innerCtx),
                        child: const Text('Отмена')),
                    FilledButton(
                        onPressed: () => Navigator.pop(
                            innerCtx, controller.text.trim()),
                        child: const Text('Создать')),
                  ],
                ),
              );
              if (!ctx.mounted) return;
              if (v != null && v.isNotEmpty) Navigator.of(ctx).pop(v);
            },
          ),
        ],
      ),
    );
    if (selected == null) return;
    final notifier = ref.read(householdNotesProvider.notifier);
    final now = DateTime.now().toIso8601String();
    for (final item in items) {
      final body = item.url == null
          ? item.content
          : '${item.content}${item.content.isEmpty ? '' : '\n\n'}${item.url}';
      final firstLine = item.content.split('\n').first;
      await notifier.add(HouseholdNote(
        id: const Uuid().v4(),
        title: firstLine.isEmpty
            ? (item.linkTitle ?? item.linkDomain ?? 'Из инбокса')
            : firstLine,
        body: body,
        category: selected,
        createdAt: now,
      ));
      await _delete(item);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(items.length == 1
          ? 'Перенесено в заметки «$selected»'
          : 'Перенесено ${items.length} в заметки «$selected»')),
    );
  }

  Future<void> _promoteToSphere(
    List<InboxItem> items, {
    required bool withCategory,
  }) async {
    final spheres = ref.read(spheresProvider);
    if (spheres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Сначала создай хотя бы одну сферу жизни')),
      );
      return;
    }
    final sphere = await showModalBottomSheet<Sphere>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('Выбери сферу',
                  style: Theme.of(sheetCtx).textTheme.titleMedium),
            ),
            for (final s in spheres)
              ListTile(
                leading: Text(s.icon ?? '✨',
                    style: const TextStyle(fontSize: 22)),
                title: Text(s.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  'заметок: ${s.notesList?.length ?? 0} · категорий: ${s.categories?.length ?? 0}',
                ),
                onTap: () => Navigator.of(sheetCtx).pop(s),
              ),
          ],
        ),
      ),
    );
    if (sphere == null) return;

    String? categoryId;
    if (withCategory) {
      final cats = sphere.categories ?? const <SphereCategory>[];
      if (cats.isEmpty) {
        // Offer to create one inline.
        if (!mounted) return;
        final controller = TextEditingController();
        final newName = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title:
                const Text('В сфере пока нет категорий'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Название новой категории'),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена')),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Создать'),
              ),
            ],
          ),
        );
        if (newName == null || newName.isEmpty) return;
        final cat = SphereCategory(
          id: const Uuid().v4(),
          title: newName,
          createdAt: DateTime.now().toIso8601String(),
        );
        await ref.read(spheresProvider.notifier).update(
              sphere.id,
              (s) => s.copyWith(
                categories: [...?s.categories, cat],
              ),
            );
        categoryId = cat.id;
      } else {
        if (!mounted) return;
        final picked = await showModalBottomSheet<SphereCategory>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (sheetCtx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text('Выбери категорию',
                      style: Theme.of(sheetCtx).textTheme.titleMedium),
                ),
                for (final c in cats)
                  ListTile(
                    leading: Text(c.icon ?? '📁',
                        style: const TextStyle(fontSize: 20)),
                    title: Text(c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.of(sheetCtx).pop(c),
                  ),
              ],
            ),
          ),
        );
        if (picked == null) return;
        categoryId = picked.id;
      }
    }

    final notifier = ref.read(spheresProvider.notifier);
    for (final item in items) {
      final body = item.url == null
          ? item.content
          : '${item.content}${item.content.isEmpty ? '' : '\n\n'}${item.url}';
      final note = SphereNote(
        id: const Uuid().v4(),
        content: body,
        createdAt: DateTime.now().toIso8601String(),
        photoUrl: item.hasMedia && item.isImage ? item.mediaPath : null,
        categoryId: categoryId,
      );
      await notifier.update(
        sphere.id,
        (s) => s.copyWith(notesList: [...?s.notesList, note]),
      );
      await _delete(item);
    }
    if (!mounted) return;
    final dest = withCategory
        ? '«${sphere.title}» → ${(sphere.categories ?? []).where((c) => c.id == categoryId).map((c) => c.title).firstOrNull ?? ''}'
        : '«${sphere.title}»';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(items.length == 1
            ? 'Перенесено в сферу $dest'
            : 'Перенесено ${items.length} в сферу $dest'),
      ),
    );
  }

  /// Toggle a single id in the selection set. Pressing on an already-
  /// selected bubble removes it; pressing the last one drops back to
  /// normal mode automatically (because the AppBar reads [_isSelecting]).
  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  void _selectAllVisible(List<InboxItem> visible) {
    setState(() {
      _selectedIds.addAll(visible.map((e) => e.id));
    });
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Удалить $count?'),
        content: const Text('Записи будут удалены без возможности восстановления.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final notifier = ref.read(inboxProvider.notifier);
    for (final id in _selectedIds.toList()) {
      await notifier.remove(id);
    }
    if (!mounted) return;
    setState(_selectedIds.clear);
  }

  Future<void> _bulkArchive({required bool archive}) async {
    if (_selectedIds.isEmpty) return;
    final notifier = ref.read(inboxProvider.notifier);
    final list = ref.read(inboxProvider);
    for (final id in _selectedIds) {
      final found = list.where((e) => e.id == id);
      if (found.isEmpty) continue;
      await notifier.upsert(found.first.copyWith(archived: archive));
    }
    if (!mounted) return;
    setState(_selectedIds.clear);
  }

  Future<void> _bulkPin({required bool pin}) async {
    if (_selectedIds.isEmpty) return;
    final notifier = ref.read(inboxProvider.notifier);
    final list = ref.read(inboxProvider);
    for (final id in _selectedIds) {
      final found = list.where((e) => e.id == id);
      if (found.isEmpty) continue;
      await notifier.upsert(found.first.copyWith(pinned: pin));
    }
    if (!mounted) return;
    setState(_selectedIds.clear);
  }

  bool get _isAiAvailable {
    final key = AiService.apiKey;
    return key != null && key.isNotEmpty && ref.read(aiEnabledProvider);
  }

  Future<void> _aiClassify(InboxItem item) async {
    if (item.content.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final result = await GeminiService.classifyInbox(item.content);
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss spinner
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI не смог классифицировать')),
        );
        return;
      }
      final type = (result['type'] as String?) ?? 'note';
      final title = (result['suggestedTitle'] as String?) ?? item.content;
      final amount = result['suggestedAmount'];
      final category = result['suggestedCategory'] as String?;
      final confidence = result['confidence'];

      final confStr = confidence != null
          ? ' (${(confidence * 100).toStringAsFixed(0)}%)'
          : '';

      final action = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheetCtx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        color: Theme.of(sheetCtx).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI: это $type$confStr',
                        style: Theme.of(sheetCtx).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              if (title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('«$title»',
                      style: Theme.of(sheetCtx).textTheme.bodyMedium),
                ),
              if (amount != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  child: Text(
                    'Сумма: $amount ${result['suggestedCurrency'] ?? 'BYN'}',
                    style: Theme.of(sheetCtx).textTheme.bodySmall,
                  ),
                ),
              if (category != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 2),
                  child: Text('Категория: $category',
                      style: Theme.of(sheetCtx).textTheme.bodySmall),
                ),
              const Divider(),
              if (type == 'task' || type == 'reminder')
                ListTile(
                  leading: const Icon(Icons.task_alt),
                  title: const Text('Создать задачу'),
                  onTap: () => Navigator.of(sheetCtx).pop('task'),
                ),
              if (type == 'expense' || type == 'income')
                ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text(type == 'income'
                      ? 'Создать доход'
                      : 'Создать расход'),
                  onTap: () => Navigator.of(sheetCtx).pop('transaction'),
                ),
              if (type == 'habit')
                ListTile(
                  leading: const Icon(Icons.eco),
                  title: const Text('Создать привычку'),
                  onTap: () => Navigator.of(sheetCtx).pop('habit'),
                ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outline),
                title: const Text('Перенести в…'),
                onTap: () => Navigator.of(sheetCtx).pop('promote'),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Отмена'),
                onTap: () => Navigator.of(sheetCtx).pop(null),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (action == null || !mounted) return;
      switch (action) {
        case 'task':
          await _promoteToTask(item);
          break;
        case 'habit':
          await _promoteToHabit(item);
          break;
        case 'transaction':
          await _aiCreateTransaction(item, result);
          break;
        case 'promote':
          await _promoteMany([item]);
          break;
      }
    } on AiServiceException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI ошибка: $e')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _aiCreateTransaction(
      InboxItem item, Map<String, dynamic> aiResult) async {
    final amount = (aiResult['suggestedAmount'] as num?)?.toDouble() ?? 0;
    final category =
        (aiResult['suggestedCategory'] as String?) ?? 'Без категории';
    final title =
        (aiResult['suggestedTitle'] as String?) ?? item.content;
    final type = aiResult['type'] == 'income'
        ? TransactionType.income
        : TransactionType.expense;
    final dateStr = (aiResult['suggestedDate'] as String?) ??
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    final tx = Transaction(
      id: const Uuid().v4(),
      amount: amount,
      type: type,
      category: category,
      date: dateStr,
      notes: title,
      source: 'ai-inbox',
    );
    await ref.read(transactionsProvider.notifier).add(tx);
    await _delete(item);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${type == TransactionType.income ? "Доход" : "Расход"}: $title — $amount'),
      ),
    );
  }

  void _showItemMenu(InboxItem item) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Выделить'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                setState(() => _selectedIds.add(item.id));
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(item.pinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(item.pinned ? 'Открепить' : 'Закрепить'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _togglePin(item);
              },
            ),
            if (item.isLink)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Открыть ссылку'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _open(item);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Скопировать текст'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _copy(item);
              },
            ),
            if (_isAiAvailable)
              ListTile(
                leading: Icon(Icons.auto_awesome,
                    color: Theme.of(context).colorScheme.primary),
                title: const Text('AI классификация'),
                subtitle: const Text('Gemini определит тип и предложит действие'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _aiClassify(item);
                },
              ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('Перенести в…'),
              subtitle: const Text(
                  'Задача / привычка / заметка / сфера'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _promoteMany([item]);
              },
            ),
            ListTile(
              leading: Icon(
                  item.archived ? Icons.unarchive_outlined : Icons.archive_outlined),
              title: Text(item.archived ? 'Вернуть из архива' : 'В архив'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _toggleArchive(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Удалить',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _delete(item);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Sort + filter in one pass:
  /// - drop archived items (unless `_filter == 'archived'`);
  /// - apply text/platform/kind filter;
  /// - put pinned ones at the top, then chronological newest-last so the
  ///   timeline reads like a chat (oldest first, newest at bottom).
  List<InboxItem> _visibleItems(List<InboxItem> all) {
    final filtered = all.where((e) {
      if (_filter == 'archived') return e.archived;
      if (e.archived) return false;
      switch (_filter) {
        case 'all':
          break;
        case 'links':
          if (!e.isLink) return false;
          break;
        case 'notes':
          if (e.isLink) return false;
          break;
        default:
          if (e.platform != _filter) return false;
      }
      if (_query.isNotEmpty) {
        final hay = '${e.content} ${e.linkTitle ?? ''} '
                '${e.linkDomain ?? ''} ${(e.tags ?? []).join(' ')}'
            .toLowerCase();
        if (!hay.contains(_query)) return false;
      }
      return true;
    }).toList();
    filtered.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return a.createdAt.compareTo(b.createdAt);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(inboxProvider);
    final items = _visibleItems(all);
    final scheme = Theme.of(context).colorScheme;
    final platforms = <String>{
      for (final e in all) if (e.platform != null) e.platform!,
    }.toList()
      ..sort();

    final allPinned = _isSelecting &&
        _selectedIds.every(
          (id) => all.any((e) => e.id == id && e.pinned),
        );
    final allArchived = _isSelecting &&
        _selectedIds.every(
          (id) => all.any((e) => e.id == id && e.archived),
        );

    return PopScope(
      canPop: !_isSelecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSelecting) _clearSelection();
      },
      child: Scaffold(
      appBar: _isSelecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Снять выделение',
                onPressed: _clearSelection,
              ),
              title: Text('${_selectedIds.length} выбрано'),
              actions: [
                IconButton(
                  tooltip: 'Выбрать все',
                  icon: const Icon(Icons.select_all),
                  onPressed: () => _selectAllVisible(items),
                ),
                IconButton(
                  tooltip: 'Перенести в…',
                  icon: const Icon(Icons.drive_file_move_outline),
                  onPressed: () {
                    final list = ref.read(inboxProvider);
                    final picked = list
                        .where((e) => _selectedIds.contains(e.id))
                        .toList();
                    _promoteMany(picked);
                  },
                ),
                IconButton(
                  tooltip: allPinned ? 'Открепить' : 'Закрепить',
                  icon: Icon(
                      allPinned ? Icons.push_pin : Icons.push_pin_outlined),
                  onPressed: () => _bulkPin(pin: !allPinned),
                ),
                IconButton(
                  tooltip: allArchived ? 'Из архива' : 'В архив',
                  icon: Icon(allArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined),
                  onPressed: () => _bulkArchive(archive: !allArchived),
                ),
                IconButton(
                  tooltip: 'Удалить',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _bulkDelete,
                ),
              ],
            )
          : AppBar(
        leading: const BackButton(),
        title: Text(_showSearch ? '' : 'Сохранёнки'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            tooltip: _showSearch ? 'Закрыть поиск' : 'Поиск',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  _query = '';
                }
              });
            },
          ),
          if (!_showSearch)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) async {
                if (v == 'archive') {
                  setState(() => _filter = 'archived');
                } else if (v == 'clear') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Очистить инбокс?'),
                      content: const Text(
                          'Все записи будут удалены без возможности восстановления.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Отмена'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Очистить'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref
                        .read(inboxProvider.notifier)
                        .replaceAll(const []);
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'archive', child: Text('Показать архив')),
                PopupMenuItem(value: 'clear', child: Text('Очистить всё')),
              ],
            ),
        ],
        bottom: _showSearch
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Поиск по тексту, домену, тегам',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          _FilterBar(
            current: _filter,
            platforms: platforms,
            onChanged: (v) => setState(() => _filter = v),
          ),
          Expanded(
            child: items.isEmpty
                ? _Empty(filter: _filter)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final showDateHeader = i == 0 ||
                          !_sameDay(items[i - 1].createdAt, item.createdAt);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDateHeader)
                            _DateChip(date: DateTime.parse(item.createdAt)),
                          Slidable(
                            key: ValueKey('inbox-${item.id}'),
                            groupTag: 'inbox',
                            startActionPane: ActionPane(
                              extentRatio: 0.55,
                              motion: const DrawerMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (_) {
                                    HapticFeedback.selectionClick();
                                    _promoteMany([item]);
                                  },
                                  backgroundColor: const Color(0xFF6366F1),
                                  foregroundColor: Colors.white,
                                  icon: Icons.drive_file_move_outline,
                                  label: 'Перенести',
                                ),
                                SlidableAction(
                                  onPressed: (_) {
                                    HapticFeedback.selectionClick();
                                    _togglePin(item);
                                  },
                                  backgroundColor: const Color(0xFFEAB308),
                                  foregroundColor: Colors.white,
                                  icon: item.pinned
                                      ? Icons.push_pin
                                      : Icons.push_pin_outlined,
                                  label: item.pinned
                                      ? 'Открепить'
                                      : 'Закрепить',
                                ),
                              ],
                            ),
                            endActionPane: ActionPane(
                              extentRatio: 0.55,
                              motion: const DrawerMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (_) {
                                    HapticFeedback.selectionClick();
                                    _toggleArchive(item);
                                  },
                                  backgroundColor: const Color(0xFF6B7280),
                                  foregroundColor: Colors.white,
                                  icon: item.archived
                                      ? Icons.unarchive_outlined
                                      : Icons.archive_outlined,
                                  label: item.archived ? 'Назад' : 'В архив',
                                ),
                                SlidableAction(
                                  onPressed: (_) async {
                                    HapticFeedback.mediumImpact();
                                    await _deleteWithUndo(item);
                                  },
                                  backgroundColor: const Color(0xFFEF4444),
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete_outline,
                                  label: 'Удалить',
                                ),
                              ],
                            ),
                            child: _Bubble(
                              item: item,
                              selected: _selectedIds.contains(item.id),
                              selectionMode: _isSelecting,
                              onTap: () {
                                if (_isSelecting) {
                                  _toggleSelected(item.id);
                                } else if (item.isLink || item.hasMedia) {
                                  _open(item);
                                }
                              },
                              onLongPress: () {
                                if (_isSelecting) {
                                  _toggleSelected(item.id);
                                } else {
                                  _showItemMenu(item);
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          if (!_isSelecting)
            _Composer(
              controller: _composerController,
              focusNode: _composerFocus,
              onSubmit: _capture,
              onPaste: _pasteFromClipboard,
              onAttach: _pickMedia,
            ),
        ],
      ),
      ),
    );
  }

  bool _sameDay(String aIso, String bIso) {
    final a = DateTime.parse(aIso);
    final b = DateTime.parse(bIso);
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

/// Filter chip row right under the AppBar. Always offers "Все / Ссылки /
/// Заметки", then appends a chip per platform that actually appears in
/// the inbox so we don't show meaningless empty filters.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.current,
    required this.platforms,
    required this.onChanged,
  });
  final String current;
  final List<String> platforms;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = <_FilterEntry>[
      const _FilterEntry('all', 'Все', Icons.inbox_outlined),
      const _FilterEntry('links', 'Ссылки', Icons.link),
      const _FilterEntry('notes', 'Заметки', Icons.notes),
      for (final p in platforms)
        _FilterEntry(p, _platformLabel(p), _platformIcon(p)),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final e = entries[i];
          final selected = e.value == current;
          return ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(e.icon, size: 16),
                const SizedBox(width: 6),
                Text(e.label),
              ],
            ),
            selected: selected,
            onSelected: (_) => onChanged(e.value),
          );
        },
      ),
    );
  }
}

class _FilterEntry {
  const _FilterEntry(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;
}

/// Chat-style bubble. Layout depends on whether the entry is a plain note
/// or a link with preview metadata; in both cases pinned items get a small
/// tack indicator and tags render as compact chips below the body.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.item,
    required this.onTap,
    required this.onLongPress,
    this.selected = false,
    this.selectionMode = false,
  });
  final InboxItem item;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;
  final bool selected;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = DateFormat.Hm().format(DateTime.parse(item.createdAt));
    final bubbleColor = selected
        ? scheme.primaryContainer
        : scheme.surfaceContainerHigh;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (selectionMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color:
                    selected ? scheme.primary : scheme.outlineVariant,
                size: 22,
              ),
            ),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.86,
              ),
              child: Material(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.pinned)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.push_pin,
                                    size: 12, color: scheme.primary),
                                const SizedBox(width: 4),
                                Text('Закреплено',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        if (item.hasMedia) _MediaPreview(item: item),
                        if (item.isLink) _LinkPreview(item: item),
                        if (item.content.trim().isNotEmpty &&
                            item.content.trim() != item.url)
                          Padding(
                            padding: EdgeInsets.only(
                                top: (item.isLink || item.hasMedia) ? 8 : 0),
                            child: SelectableText(
                              item.content,
                              style: const TextStyle(fontSize: 15, height: 1.3),
                            ),
                          ),
                        if (item.tags != null && item.tags!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final t in item.tags!)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: scheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('#$t',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: scheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Spacer(),
                            Text(time,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                )),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline link-card. Shows og:image at the top (if we have one), and
/// always shows a colored platform-icon row + domain + og:title (or just
/// the URL when og fetch hasn't returned yet). Tap on the parent bubble
/// opens the link in the system browser.
/// Inline media card for shared / picked attachments. Renders the image
/// straight from disk (with a graceful "image gone" fallback) and shows
/// a video as a dark thumbnail with a centred play button — tap on the
/// surrounding bubble hands the file off to the system viewer.
class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.item});
  final InboxItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final file = item.mediaPath != null ? File(item.mediaPath!) : null;
    final exists = file != null && file.existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.isImage && exists)
              Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _MediaFallback(
                  icon: Icons.broken_image_outlined,
                  label: 'Файл недоступен',
                  scheme: scheme,
                ),
              )
            else if (item.isVideo && exists)
              Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.play_circle_fill,
                        size: 56, color: Colors.white.withValues(alpha: 0.9)),
                  ],
                ),
              )
            else
              _MediaFallback(
                icon: item.isVideo
                    ? Icons.videocam_off_outlined
                    : Icons.image_not_supported_outlined,
                label: 'Медиа не найдено',
                scheme: scheme,
              ),
            if (exists)
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.isVideo
                            ? Icons.videocam_outlined
                            : Icons.photo_outlined,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.isVideo ? 'Видео' : 'Фото',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback({
    required this.icon,
    required this.label,
    required this.scheme,
  });
  final IconData icon;
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: scheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              )),
        ],
      ),
    );
  }
}

class _LinkPreview extends StatelessWidget {
  const _LinkPreview({required this.item});
  final InboxItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _platformColor(item.platform, scheme);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.linkImage != null && item.linkImage!.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                item.linkImage!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: color.withValues(alpha: 0.12),
                  alignment: Alignment.center,
                  child: Icon(_platformIcon(item.platform),
                      color: color, size: 36),
                ),
                loadingBuilder: (ctx, child, p) =>
                    p == null ? child : Container(
                      color: color.withValues(alpha: 0.06),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_platformIcon(item.platform),
                              size: 12, color: color),
                          const SizedBox(width: 4),
                          Text(_platformLabel(item.platform ?? 'web'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color,
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.linkDomain ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.linkTitle != null && item.linkTitle!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.linkTitle!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  item.url ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onPaste,
    required this.onAttach,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final VoidCallback onPaste;
  final VoidCallback onAttach;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechReady = await _speech.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      _speechReady = false;
    }
  }

  Future<void> _toggleListen() async {
    if (!_speechReady) {
      await _initSpeech();
      if (!_speechReady) return;
    }
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _listening = true);
    await _speech.listen(
      localeId: 'ru_RU',
      onResult: (result) {
        widget.controller.text = result.recognizedWords;
        widget.controller.selection = TextSelection.collapsed(
          offset: widget.controller.text.length,
        );
        if (result.finalResult) {
          setState(() => _listening = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Прикрепить файл',
              icon: const Icon(Icons.attach_file),
              onPressed: widget.onAttach,
            ),
            IconButton(
              tooltip: 'Вставить из буфера',
              icon: const Icon(Icons.content_paste_outlined),
              onPressed: widget.onPaste,
            ),
            IconButton(
              tooltip: _listening ? 'Остановить' : 'Голосовой ввод',
              icon: Icon(_listening ? Icons.mic : Icons.mic_none),
              color: _listening ? scheme.error : null,
              onPressed: _toggleListen,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  minLines: 1,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Заметка или ссылка…',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              icon: const Icon(Icons.send_rounded),
              onPressed: widget.onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final diff = today.difference(date).inDays;
    String label;
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      label = 'Сегодня';
    } else if (diff == 1) {
      label = 'Вчера';
    } else {
      label = DateFormat.yMMMMd('ru').format(date);
    }
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              )),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filter});
  final String filter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String title;
    String subtitle;
    switch (filter) {
      case 'links':
        title = 'Нет сохранённых ссылок';
        subtitle =
            'Поделись ссылкой из любой соцсети — она появится здесь автоматически.';
        break;
      case 'notes':
        title = 'Заметок ещё нет';
        subtitle = 'Записывай идеи, цитаты, todo одной строкой.';
        break;
      case 'archived':
        title = 'Архив пуст';
        subtitle = 'Сюда переедут записи, которые ты уберёшь из ленты.';
        break;
      default:
        title = 'Пока пусто';
        subtitle =
            'Сохраняй сюда заметки, идеи и ссылки из Instagram, YouTube, Telegram и любых других приложений.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border_rounded,
                size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Map a short platform key to its human-readable label. Falls through to
/// "Сайт" for the generic `web` bucket and unknown keys.
String _platformLabel(String? p) {
  switch (p) {
    case 'youtube':
      return 'YouTube';
    case 'instagram':
      return 'Instagram';
    case 'tiktok':
      return 'TikTok';
    case 'twitter':
      return 'X / Twitter';
    case 'threads':
      return 'Threads';
    case 'telegram':
      return 'Telegram';
    case 'vk':
      return 'VK';
    case 'reddit':
      return 'Reddit';
    case 'pinterest':
      return 'Pinterest';
    case 'facebook':
      return 'Facebook';
    case 'spotify':
      return 'Spotify';
    case 'github':
      return 'GitHub';
    default:
      return 'Сайт';
  }
}

/// Pick a Material icon that loosely fits the platform. We avoid bringing
/// in a brand-icon dependency for now — generic Material glyphs are OK at
/// this size and color them by [_platformColor].
IconData _platformIcon(String? p) {
  switch (p) {
    case 'youtube':
      return Icons.play_circle_filled;
    case 'instagram':
      return Icons.camera_alt;
    case 'tiktok':
      return Icons.music_video;
    case 'twitter':
      return Icons.alternate_email;
    case 'threads':
      return Icons.alternate_email;
    case 'telegram':
      return Icons.send;
    case 'vk':
      return Icons.public;
    case 'reddit':
      return Icons.forum;
    case 'pinterest':
      return Icons.push_pin;
    case 'facebook':
      return Icons.thumb_up;
    case 'spotify':
      return Icons.music_note;
    case 'github':
      return Icons.code;
    default:
      return Icons.public;
  }
}

/// Brand-ish color per platform. Uses the theme's primary as a safe
/// fallback so dark-mode and custom seed colors stay readable.
Color _platformColor(String? p, ColorScheme scheme) {
  switch (p) {
    case 'youtube':
      return const Color(0xFFFF0000);
    case 'instagram':
      return const Color(0xFFE1306C);
    case 'tiktok':
      return const Color(0xFF000000);
    case 'twitter':
      return const Color(0xFF1D9BF0);
    case 'threads':
      return const Color(0xFF000000);
    case 'telegram':
      return const Color(0xFF229ED9);
    case 'vk':
      return const Color(0xFF0077FF);
    case 'reddit':
      return const Color(0xFFFF4500);
    case 'pinterest':
      return const Color(0xFFE60023);
    case 'facebook':
      return const Color(0xFF1877F2);
    case 'spotify':
      return const Color(0xFF1DB954);
    case 'github':
      return const Color(0xFF24292F);
    default:
      return scheme.primary;
  }
}


enum _PickChoice { imageGallery, imageCamera, videoGallery, videoCamera }
