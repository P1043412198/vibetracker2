import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/misc.dart';
import '../../state/providers.dart';

/// Free-form personal household notes — bag reminders, water/light shutoff
/// schedule, food storage tips, seasonal chores. Grouped by user-chosen
/// category and pinned-first.
class HouseholdNotesPage extends ConsumerWidget {
  const HouseholdNotesPage({super.key});

  static const _suggestedCategories = <String>[
    'Продукты',
    'Коммунальные',
    'Уборка',
    'Сезонное',
    'Покупки',
    'Безопасность',
    'Другое',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = [...ref.watch(householdNotesProvider)]
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });

    final byCategory = <String, List<HouseholdNote>>{};
    for (final n in notes) {
      byCategory.putIfAbsent(n.category, () => []).add(n);
    }
    final categoryKeys = byCategory.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Бытовые заметки')),
      body: notes.isEmpty
          ? const _Empty()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final c in categoryKeys) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(c,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  ...byCategory[c]!.map(
                    (n) => _NoteCard(
                      note: n,
                      onEdit: () => _showEditor(context, ref, edit: n),
                      onDelete: () => ref
                          .read(householdNotesProvider.notifier)
                          .remove(n.id),
                      onTogglePin: () => ref
                          .read(householdNotesProvider.notifier)
                          .upsert(n.copyWith(pinned: !n.pinned)),
                    ),
                  ),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Заметка'),
      ),
    );
  }

  Future<void> _showEditor(
    BuildContext context,
    WidgetRef ref, {
    HouseholdNote? edit,
  }) async {
    final titleCtl = TextEditingController(text: edit?.title ?? '');
    final bodyCtl = TextEditingController(text: edit?.body ?? '');
    var category = edit?.category ?? _suggestedCategories.first;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (innerCtx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(innerCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      edit == null ? 'Новая заметка' : 'Редактировать',
                      style: Theme.of(innerCtx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleCtl,
                      autofocus: edit == null,
                      decoration: const InputDecoration(
                          labelText: 'Заголовок'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyCtl,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Текст заметки',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Категория',
                        style: Theme.of(innerCtx).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final c in _suggestedCategories)
                          ChoiceChip(
                            label: Text(c),
                            selected: category == c,
                            onSelected: (v) {
                              if (v) setState(() => category = c);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (edit != null)
                          TextButton.icon(
                            onPressed: () async {
                              await ref
                                  .read(householdNotesProvider.notifier)
                                  .remove(edit.id);
                              if (innerCtx.mounted) {
                                Navigator.of(innerCtx).pop();
                              }
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Удалить'),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(innerCtx).pop(),
                          child: const Text('Отмена'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            final title = titleCtl.text.trim();
                            final body = bodyCtl.text.trim();
                            if (title.isEmpty && body.isEmpty) return;
                            final note = HouseholdNote(
                              id: edit?.id ?? const Uuid().v4(),
                              title: title.isEmpty ? '(без названия)' : title,
                              body: body,
                              category: category,
                              createdAt: edit?.createdAt ??
                                  DateTime.now().toIso8601String(),
                              pinned: edit?.pinned ?? false,
                            );
                            await ref
                                .read(householdNotesProvider.notifier)
                                .upsert(note);
                            if (innerCtx.mounted) {
                              Navigator.of(innerCtx).pop();
                            }
                          },
                          child: const Text('Сохранить'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
  });

  final HouseholdNote note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    final created = DateTime.tryParse(note.createdAt);
    final dateLabel = created == null
        ? note.createdAt
        : DateFormat.yMMMd('ru').format(created);
    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    if (note.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(note.body,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 6),
                    Text(dateLabel,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  note.pinned
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                  size: 20,
                  color: note.pinned
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                onPressed: onTogglePin,
                tooltip: note.pinned ? 'Открепить' : 'Закрепить',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏠', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Заметок пока нет',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Сюда удобно складывать всё бытовое: «не забыть пакет в магазин», '
              '«как хранить морковь», «когда менять фильтр», «график оплаты ЖКХ».',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
