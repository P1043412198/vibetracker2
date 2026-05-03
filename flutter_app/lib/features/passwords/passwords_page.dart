import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/misc.dart';
import '../../state/providers.dart';
import '../../utils/totp.dart';
import '../../utils/password_generator.dart';

class PasswordsPage extends ConsumerStatefulWidget {
  const PasswordsPage({super.key});

  @override
  ConsumerState<PasswordsPage> createState() => _PasswordsPageState();
}

class _PasswordsPageState extends ConsumerState<PasswordsPage> {
  String _search = '';

  /// Currently opened folder. `null` means the root (categories list); a
  /// string value means we're viewing the entries of that category. Special
  /// value `__all__` shows everything (used by the search field).
  String? _openedCategory;

  static const _allKey = '__all__';
  static const _uncategorisedKey = '__none__';

  @override
  Widget build(BuildContext context) {
    final passwords = ref.watch(passwordsProvider);

    // Group by category (null/empty → "Без категории")
    final byCategory = <String, List<PasswordEntry>>{};
    for (final p in passwords) {
      final key = (p.category != null && p.category!.isNotEmpty)
          ? p.category!
          : _uncategorisedKey;
      (byCategory[key] ??= []).add(p);
    }
    final categoryOrder = byCategory.keys.toList()
      ..sort((a, b) {
        if (a == _uncategorisedKey) return 1;
        if (b == _uncategorisedKey) return -1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    final searching = _search.trim().isNotEmpty;

    // While searching, ignore selected folder and search across all entries.
    Iterable<PasswordEntry> visible;
    if (searching) {
      visible = passwords;
    } else if (_openedCategory == null) {
      visible = const [];
    } else if (_openedCategory == _allKey) {
      visible = passwords;
    } else if (_openedCategory == _uncategorisedKey) {
      visible = passwords.where(
          (p) => p.category == null || p.category!.isEmpty);
    } else {
      visible = passwords.where((p) => p.category == _openedCategory);
    }

    final filtered = visible.where((p) {
      final q = _search.toLowerCase();
      if (q.isEmpty) return true;
      return p.title.toLowerCase().contains(q) ||
          (p.username?.toLowerCase().contains(q) ?? false) ||
          (p.url?.toLowerCase().contains(q) ?? false) ||
          (p.category?.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) {
        if ((a.isPinned ?? false) && !(b.isPinned ?? false)) return -1;
        if (!(a.isPinned ?? false) && (b.isPinned ?? false)) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });

    final showCategoryGrid = !searching && _openedCategory == null;

    return Scaffold(
      appBar: AppBar(
        leading: (!showCategoryGrid && !searching)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _openedCategory = null),
              )
            : null,
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                showCategoryGrid
                    ? 'Пароли и 2FA'
                    : (_openedCategory == _allKey
                        ? 'Все пароли'
                        : (_openedCategory == _uncategorisedKey
                            ? 'Без категории'
                            : (_openedCategory ?? 'Пароли и 2FA'))),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Search (always available)
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 20),
              hintText: 'Поиск паролей…',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 16),

          // ROOT VIEW: only category cards, not individual passwords.
          if (showCategoryGrid) ...[
            if (passwords.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text('Нет сохранённых паролей',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else ...[
              _CategoryTile(
                icon: Icons.all_inclusive,
                label: 'Все пароли',
                count: passwords.length,
                onTap: () =>
                    setState(() => _openedCategory = _allKey),
              ),
              const SizedBox(height: 8),
              for (final key in categoryOrder)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CategoryTile(
                    icon: key == _uncategorisedKey
                        ? Icons.folder_off_outlined
                        : Icons.folder_outlined,
                    label: key == _uncategorisedKey
                        ? 'Без категории'
                        : key,
                    count: byCategory[key]?.length ?? 0,
                    onTap: () =>
                        setState(() => _openedCategory = key),
                  ),
                ),
            ],
          ] else ...[
            // FOLDER VIEW (or search): list passwords inside the folder.
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.key_outlined,
                          size: 48,
                          color: Colors.grey.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      const Text('Ничего не найдено',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              ...filtered.map((entry) => _PasswordCard(
                    entry: entry,
                    onEdit: () => _openEditor(context, entry: entry),
                    onDelete: () => _confirmDelete(context, entry),
                    onTogglePin: () {
                      ref.read(passwordsProvider.notifier).update(
                            entry.id,
                            (old) => PasswordEntry(
                              id: old.id,
                              title: old.title,
                              username: old.username,
                              password: old.password,
                              url: old.url,
                              totpSecret: old.totpSecret,
                              notes: old.notes,
                              category: old.category,
                              createdAt: old.createdAt,
                              updatedAt: old.updatedAt,
                              isPinned: !(old.isPinned ?? false),
                            ),
                          );
                    },
                  )),
          ],
        ],
      ),
    );
  }

  void _openEditor(BuildContext context, {PasswordEntry? entry}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PasswordEditor(
        entry: entry,
        onSave: (data) {
          if (entry != null) {
            ref.read(passwordsProvider.notifier).update(entry.id, (_) => data);
          } else {
            ref.read(passwordsProvider.notifier).add(data);
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, PasswordEntry entry) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить пароль?'),
        content: Text('«${entry.title}» будет удалён навсегда.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              ref.read(passwordsProvider.notifier).remove(entry.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Password card
// ---------------------------------------------------------------------------

class _PasswordCard extends StatefulWidget {
  const _PasswordCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
  });
  final PasswordEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  @override
  State<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends State<_PasswordCard> {
  bool _showPassword = false;
  Timer? _totpTimer;
  String? _totpCode;
  double _totpProgress = 1;

  @override
  void initState() {
    super.initState();
    _setupTotp();
  }

  @override
  void didUpdateWidget(covariant _PasswordCard old) {
    super.didUpdateWidget(old);
    if (old.entry.totpSecret != widget.entry.totpSecret) {
      _totpTimer?.cancel();
      _setupTotp();
    }
  }

  @override
  void dispose() {
    _totpTimer?.cancel();
    super.dispose();
  }

  void _setupTotp() {
    final secret = widget.entry.totpSecret;
    if (secret == null || secret.isEmpty) {
      _totpCode = null;
      return;
    }
    final parsed = parseTotpSecretFromUri(secret);
    if (parsed == null || parsed.isEmpty) return;

    void update() {
      try {
        setState(() {
          _totpCode = generateTOTP(parsed);
          _totpProgress = totpProgressFraction();
        });
      } catch (_) {
        _totpCode = null;
      }
    }

    update();
    _totpTimer = Timer.periodic(const Duration(seconds: 1), (_) => update());
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Скопировано'),
          duration: Duration(milliseconds: 800)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final pinned = e.isPinned ?? false;
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: pinned
            ? BorderSide(color: cs.primary.withAlpha(100))
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: cs.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.key, size: 16, color: cs.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(e.title,
                              style: Theme.of(context).textTheme.titleSmall,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (pinned)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.push_pin,
                                size: 12, color: cs.primary),
                          ),
                        if (e.category != null && e.category!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.grey.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(e.category!,
                                style: const TextStyle(fontSize: 9)),
                          ),
                        ],
                      ]),
                      if (e.username != null && e.username!.isNotEmpty)
                        Text(e.username!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                      pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 18,
                      color: pinned ? cs.primary : Colors.grey),
                  onPressed: widget.onTogglePin,
                  visualDensity: VisualDensity.compact,
                  tooltip: pinned ? 'Открепить' : 'Закрепить',
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: widget.onEdit,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: Colors.red[300]),
                  onPressed: widget.onDelete,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            // Password row
            if (e.password != null && e.password!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withAlpha(30)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _showPassword ? e.password! : '\u2022' * 12,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                    InkWell(
                      onTap: () =>
                          setState(() => _showPassword = !_showPassword),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 16,
                            color: Colors.grey),
                      ),
                    ),
                    InkWell(
                      onTap: () => _copy(e.password!),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child:
                            Icon(Icons.copy, size: 16, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // TOTP code
            if (_totpCode != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withAlpha(10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.primary.withAlpha(30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Icon(Icons.schedule,
                              size: 14, color: cs.primary),
                          const SizedBox(width: 4),
                          Text('КОД АУТЕНТИФИКАЦИИ',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: cs.primary,
                                  letterSpacing: 1)),
                        ]),
                        InkWell(
                          onTap: () => _copy(_totpCode!),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(Icons.copy,
                                size: 14, color: cs.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_totpCode!.substring(0, 3)} ${_totpCode!.substring(3)}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _totpProgress,
                        minHeight: 3,
                        backgroundColor: cs.primary.withAlpha(15),
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Notes
            if (e.notes != null && e.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(e.notes!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Password editor (bottom sheet)
// ---------------------------------------------------------------------------

class _PasswordEditor extends StatefulWidget {
  const _PasswordEditor({this.entry, required this.onSave});
  final PasswordEntry? entry;
  final ValueChanged<PasswordEntry> onSave;

  @override
  State<_PasswordEditor> createState() => _PasswordEditorState();
}

class _PasswordEditorState extends State<_PasswordEditor> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _totpCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _notesCtrl;

  bool _showGenerator = false;
  int _paranoiaLevel = 1; // 0-based index

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _usernameCtrl = TextEditingController(text: e?.username ?? '');
    _passwordCtrl = TextEditingController(text: e?.password ?? '');
    _urlCtrl = TextEditingController(text: e?.url ?? '');
    _totpCtrl = TextEditingController(text: e?.totpSecret ?? '');
    _categoryCtrl = TextEditingController(text: e?.category ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _urlCtrl.dispose();
    _totpCtrl.dispose();
    _categoryCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _doGenerate() {
    _passwordCtrl.text = generatePassword(_paranoiaLevel);
    setState(() {});
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    widget.onSave(PasswordEntry(
      id: widget.entry?.id ?? const Uuid().v4(),
      title: title,
      username:
          _usernameCtrl.text.trim().isEmpty ? null : _usernameCtrl.text.trim(),
      password:
          _passwordCtrl.text.isEmpty ? null : _passwordCtrl.text,
      url: _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
      totpSecret:
          _totpCtrl.text.trim().isEmpty ? null : _totpCtrl.text.trim(),
      category:
          _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: widget.entry?.createdAt ?? now,
      updatedAt: now,
      isPinned: widget.entry?.isPinned,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final level = paranoiaLevels[_paranoiaLevel];
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.entry != null ? 'Редактировать пароль' : 'Новый пароль',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            _field('Название сервиса *', _titleCtrl,
                hint: 'Google, GitHub, VK...'),
            _field('Логин / Email', _usernameCtrl,
                hint: 'user@example.com'),

            // Password + generator
            _label('Пароль'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _passwordCtrl,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.auto_fix_high, size: 20),
                  tooltip: 'Генератор',
                  onPressed: () {
                    setState(() => _showGenerator = !_showGenerator);
                    if (_showGenerator && _passwordCtrl.text.isEmpty) {
                      _doGenerate();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: 'Копировать',
                  onPressed: _passwordCtrl.text.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(
                              ClipboardData(text: _passwordCtrl.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Скопировано'),
                                duration: Duration(milliseconds: 800)),
                          );
                        },
                ),
              ],
            ),

            if (_showGenerator) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('УРОВЕНЬ ПАРАНОЙИ',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                  letterSpacing: 1)),
                          Text(level.label,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _levelColor(_paranoiaLevel))),
                        ],
                      ),
                      Slider(
                        value: _paranoiaLevel.toDouble(),
                        min: 0,
                        max: 3,
                        divisions: 3,
                        onChanged: (v) {
                          setState(() => _paranoiaLevel = v.round());
                          _doGenerate();
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Простой',
                              style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.bold)),
                          Text('Жесть',
                              style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(level.desc,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[500])),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _doGenerate,
                          child: const Text('Сгенерировать другой',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),
            _field('Ключ 2FA (TOTP Secret)', _totpCtrl,
                hint: 'JBSWY3DPEHPK3PXP', mono: true),
            _field('Категория', _categoryCtrl,
                hint: 'Работа, Личное, Финансы...'),
            _field('URL сайта', _urlCtrl, hint: 'example.com'),
            _label('Заметки'),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: 'Дополнительная информация...',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
            ),

            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Text('Сохранить'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Color _levelColor(int i) {
    switch (i) {
      case 0:
        return Colors.green;
      case 1:
        return Colors.amber;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(text,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.8)),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, bool mono = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextField(
          controller: ctrl,
          style: mono
              ? const TextStyle(fontFamily: 'monospace', fontSize: 12)
              : null,
          decoration: InputDecoration(
            isDense: true,
            border: const OutlineInputBorder(),
            hintText: hint,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          ),
        ),
      ],
    );
  }
}

/// Phase 18: clickable category folder tile shown on the root view of
/// "Пароли" so the entries don't immediately render until a folder is
/// opened.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon,
              color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
        title: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Записей: $count',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
