import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/habit.dart';
import '../../state/providers.dart';

/// Counterpart of `src/pages/Habits.tsx`. Lists habits with today's status
/// log (mark done / skip / failed-resisted).
class HabitsPage extends ConsumerWidget {
  const HabitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final logs = ref.watch(habitLogsProvider);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    HabitLog? logFor(String habitId) {
      try {
        return logs.firstWhere(
            (l) => l.habitId == habitId && l.date == today);
      } catch (_) {
        return null;
      }
    }

    Future<void> markStatus(Habit h, HabitLogStatus status) async {
      final existing = logFor(h.id);
      final controller = ref.read(habitLogsProvider.notifier);
      final entry = HabitLog(
        id: existing?.id ?? const Uuid().v4(),
        habitId: h.id,
        date: today,
        status: status,
        notes: existing?.notes ?? '',
        feelings: existing?.feelings ?? '',
        value: existing?.value,
      );
      await controller.upsert(entry);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Привычки')),
      body: habits.isEmpty
          ? const _EmptyHabits()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: habits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final h = habits[i];
                final log = logFor(h.id);
                return _HabitCard(
                  habit: h,
                  todaysStatus: log?.status,
                  onMark: (s) => markStatus(h, s),
                  onDelete: () =>
                      ref.read(habitsProvider.notifier).remove(h.id),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addHabit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Привычка'),
      ),
    );
  }

  Future<void> _addHabit(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    var type = HabitTypeKind.good;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (innerContext, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(innerContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Новая привычка',
                      style:
                          Theme.of(innerContext).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration:
                        const InputDecoration(labelText: 'Название'),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<HabitTypeKind>(
                    segments: const [
                      ButtonSegment(
                        value: HabitTypeKind.good,
                        icon: Icon(Icons.thumb_up_outlined),
                        label: Text('Полезная'),
                      ),
                      ButtonSegment(
                        value: HabitTypeKind.bad,
                        icon: Icon(Icons.thumb_down_outlined),
                        label: Text('Вредная'),
                      ),
                    ],
                    selected: {type},
                    onSelectionChanged: (s) =>
                        setState(() => type = s.first),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;
                      await ref.read(habitsProvider.notifier).add(
                            Habit(
                              id: const Uuid().v4(),
                              title: title,
                              type: type,
                              createdAt: DateTime.now().toIso8601String(),
                            ),
                          );
                      if (innerContext.mounted) {
                        Navigator.of(innerContext).pop();
                      }
                    },
                    child: const Text('Создать'),
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

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.habit,
    required this.todaysStatus,
    required this.onMark,
    required this.onDelete,
  });

  final Habit habit;
  final HabitLogStatus? todaysStatus;
  final ValueChanged<HabitLogStatus> onMark;
  final VoidCallback onDelete;

  Color _statusColor(BuildContext context, HabitLogStatus? status) {
    if (status == null) return Theme.of(context).colorScheme.surfaceContainerHigh;
    switch (status) {
      case HabitLogStatus.done:
        return const Color(0xFF22C55E);
      case HabitLogStatus.failed:
        return const Color(0xFFEF4444);
      case HabitLogStatus.skipped:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isGood = habit.type == HabitTypeKind.good;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (isGood
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444))
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    habit.icon ?? (isGood ? '🌱' : '🚫'),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        isGood ? 'Полезная' : 'Вредная',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: scheme.onSurfaceVariant),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<HabitLogStatus>(
              segments: [
                ButtonSegment(
                  value: HabitLogStatus.done,
                  icon: const Icon(Icons.check),
                  label: Text(isGood ? 'Сделал' : 'Удержался'),
                ),
                ButtonSegment(
                  value: HabitLogStatus.skipped,
                  icon: const Icon(Icons.remove),
                  label: const Text('Пропустил'),
                ),
                ButtonSegment(
                  value: HabitLogStatus.failed,
                  icon: const Icon(Icons.close),
                  label: Text(isGood ? 'Не сделал' : 'Сорвался'),
                ),
              ],
              selected: todaysStatus == null ? <HabitLogStatus>{} : {todaysStatus!},
              emptySelectionAllowed: true,
              onSelectionChanged: (selected) {
                if (selected.isNotEmpty) onMark(selected.first);
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return _statusColor(context, todaysStatus)
                        .withValues(alpha: 0.18);
                  }
                  return null;
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHabits extends StatelessWidget {
  const _EmptyHabits();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🪴', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Создай первую привычку',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Полезные привычки укрепляют, вредные — отслеживаются для борьбы с ними.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
