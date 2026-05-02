import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/habit.dart';
import '../../models/misc.dart';
import '../../models/task.dart';
import '../../state/providers.dart';

/// GTD-style "Inbox" capture screen.
///
/// Mirrors the React `InboxWidget` workflow: jot a thought, decide later
/// whether it's a task / habit / note. Items can be promoted to the tasks
/// or habits store with one tap.
class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});

  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> {
  final _captureController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _captureController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final text = _captureController.text.trim();
    if (text.isEmpty) return;
    await ref.read(inboxProvider.notifier).add(InboxItem(
          id: const Uuid().v4(),
          content: text,
          createdAt: DateTime.now().toIso8601String(),
        ));
    _captureController.clear();
    _focusNode.requestFocus();
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
    await ref.read(inboxProvider.notifier).remove(item.id);
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
    await ref.read(inboxProvider.notifier).remove(item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Перенесено в привычки')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [...ref.watch(inboxProvider)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Инбокс'),
        actions: [
          IconButton(
            tooltip: 'Очистить весь инбокс',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: items.isEmpty
                ? null
                : () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Очистить инбокс?'),
                        content: const Text(
                            'Все необработанные записи будут удалены.'),
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
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _captureController,
                        focusNode: _focusNode,
                        autofocus: true,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _capture(),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Запиши мысль...',
                        ),
                      ),
                    ),
                    IconButton.filled(
                      icon: const Icon(Icons.send),
                      onPressed: _capture,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Свайп влево → задача, свайп вправо → привычка.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const _Empty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return Dismissible(
                        key: ValueKey(item.id),
                        background: _SwipeBg(
                          alignment: Alignment.centerLeft,
                          color: const Color(0xFF22C55E),
                          icon: Icons.eco,
                          label: 'Привычка',
                        ),
                        secondaryBackground: _SwipeBg(
                          alignment: Alignment.centerRight,
                          color: scheme.primary,
                          icon: Icons.task_alt,
                          label: 'Задача',
                        ),
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.startToEnd) {
                            await _promoteToHabit(item);
                            return false;
                          }
                          if (direction == DismissDirection.endToStart) {
                            await _promoteToTask(item);
                            return false;
                          }
                          return false;
                        },
                        child: _InboxTile(
                          item: item,
                          onTask: () => _promoteToTask(item),
                          onHabit: () => _promoteToHabit(item),
                          onDelete: () => ref
                              .read(inboxProvider.notifier)
                              .remove(item.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _InboxTile extends StatelessWidget {
  const _InboxTile({
    required this.item,
    required this.onTask,
    required this.onHabit,
    required this.onDelete,
  });
  final InboxItem item;
  final VoidCallback onTask;
  final VoidCallback onHabit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.content,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 15)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  DateFormat.MMMd('ru')
                      .add_Hm()
                      .format(DateTime.parse(item.createdAt)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.eco, size: 16),
                  label: const Text('Привычка'),
                  onPressed: onHabit,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.task_alt, size: 16),
                  label: const Text('Задача'),
                  onPressed: onTask,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  const _SwipeBg({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });
  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ],
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
            const Text('📨', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Инбокс пуст',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Записывай идеи и заметки в одно поле,\nразложишь по местам потом.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
