import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/habit.dart';
import '../../models/misc.dart';
import '../../models/task.dart';
import '../../services/link_preview_service.dart';
import '../../state/providers.dart';

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

  Future<void> _copy(InboxItem item) async {
    await Clipboard.setData(ClipboardData(text: item.content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Скопировано')),
    );
  }

  Future<void> _open(InboxItem item) async {
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
            ListTile(
              leading: const Icon(Icons.task_alt),
              title: const Text('В задачи'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _promoteToTask(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.eco),
              title: const Text('В привычки'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _promoteToHabit(item);
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
                          _Bubble(
                            item: item,
                            selected: _selectedIds.contains(item.id),
                            selectionMode: _isSelecting,
                            onTap: () {
                              if (_isSelecting) {
                                _toggleSelected(item.id);
                              } else if (item.isLink) {
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
                        if (item.isLink) _LinkPreview(item: item),
                        if (item.content.trim().isNotEmpty &&
                            item.content.trim() != item.url)
                          Padding(
                            padding: EdgeInsets.only(
                                top: item.isLink ? 8 : 0),
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

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onPaste,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Вставить из буфера',
              icon: const Icon(Icons.content_paste_outlined),
              onPressed: onPaste,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
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
              onPressed: onSubmit,
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
