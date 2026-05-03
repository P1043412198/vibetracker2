import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:go_router/go_router.dart';

import '../../models/enums.dart';
import '../../models/habit.dart';
import '../../services/streak.dart';
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

    Future<void> editTodayNote(Habit h) async {
      final existing = logFor(h.id);
      final controller = TextEditingController(text: existing?.notes ?? '');
      final result = await showDialog<String?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Заметка — ${h.title}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Как прошло, что чувствовал…',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      );
      if (result == null) return;
      final logs0 = ref.read(habitLogsProvider);
      final cur = logs0.cast<HabitLog?>().firstWhere(
            (l) => l?.habitId == h.id && l?.date == today,
            orElse: () => null,
          );
      final entry = HabitLog(
        id: cur?.id ?? const Uuid().v4(),
        habitId: h.id,
        date: today,
        status: cur?.status ?? HabitLogStatus.done,
        notes: result,
        feelings: cur?.feelings ?? '',
        value: cur?.value,
      );
      await ref.read(habitLogsProvider.notifier).upsert(entry);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Привычки')),
      body: habits.isEmpty
          ? const _EmptyHabits()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: habits.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _HabitsStatsHeader(
                    habits: habits,
                    logs: logs,
                  );
                }
                final h = habits[i - 1];
                final log = logFor(h.id);
                final stats = computeStreakStats(habit: h, logs: logs);
                return _HabitCard(
                  habit: h,
                  todaysStatus: log?.status,
                  todaysNote: log?.notes ?? '',
                  streak: stats.current,
                  best: stats.best,
                  onMark: (s) => markStatus(h, s),
                  onEditNote: () => editTodayNote(h),
                  onDelete: () =>
                      ref.read(habitsProvider.notifier).remove(h.id),
                  onTap: () => context.push('/habits/${h.id}'),
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
    final descriptionController = TextEditingController();
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Заметка / описание (необязательно)',
                      hintText: 'Зачем эта привычка, как её отмечать…',
                    ),
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
                      final desc = descriptionController.text.trim();
                      await ref.read(habitsProvider.notifier).add(
                            Habit(
                              id: const Uuid().v4(),
                              title: title,
                              type: type,
                              description: desc.isEmpty ? null : desc,
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
    required this.todaysNote,
    required this.streak,
    required this.best,
    required this.onMark,
    required this.onEditNote,
    required this.onDelete,
    required this.onTap,
  });

  final Habit habit;
  final HabitLogStatus? todaysStatus;
  final String todaysNote;
  final int streak;
  final int best;
  final ValueChanged<HabitLogStatus> onMark;
  final VoidCallback onEditNote;
  final VoidCallback onDelete;
  final VoidCallback onTap;

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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
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
                        Row(
                          children: [
                            Text(
                              isGood ? 'Полезная' : 'Вредная',
                              style:
                                  Theme.of(context).textTheme.bodySmall,
                            ),
                            if (streak > 0) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.local_fire_department,
                                  size: 14, color: Color(0xFFF97316)),
                              const SizedBox(width: 2),
                              Text(
                                '$streak',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFF97316),
                                ),
                              ),
                            ],
                            if (best > streak) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.emoji_events_outlined,
                                  size: 13, color: Color(0xFFEAB308)),
                              const SizedBox(width: 2),
                              Text(
                                '$best',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFEAB308),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: todaysNote.isEmpty
                        ? 'Добавить заметку за сегодня'
                        : 'Изменить заметку',
                    icon: Icon(
                      todaysNote.isEmpty
                          ? Icons.sticky_note_2_outlined
                          : Icons.sticky_note_2,
                      color: todaysNote.isEmpty
                          ? scheme.onSurfaceVariant
                          : scheme.primary,
                    ),
                    onPressed: onEditNote,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: scheme.onSurfaceVariant),
                    onPressed: onDelete,
                  ),
                ],
              ),
              if (todaysNote.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.format_quote,
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          todaysNote,
                          style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurface,
                              fontStyle: FontStyle.italic),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                selected: todaysStatus == null
                    ? <HabitLogStatus>{}
                    : {todaysStatus!},
                emptySelectionAllowed: true,
                onSelectionChanged: (selected) {
                  if (selected.isNotEmpty) onMark(selected.first);
                },
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.resolveWith((states) {
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

class _HabitsStatsHeader extends StatelessWidget {
  const _HabitsStatsHeader({required this.habits, required this.logs});
  final List<Habit> habits;
  final List<HabitLog> logs;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayIso = _iso(today);
    final doneToday = logs
        .where((l) => l.date == todayIso && l.status == HabitLogStatus.done)
        .map((l) => l.habitId)
        .toSet()
        .length;
    final last30 = List.generate(30, (i) {
      final d = DateTime(today.year, today.month, today.day - (29 - i));
      return d;
    });
    final completedByDay = <String, int>{};
    for (final l in logs) {
      if (l.status == HabitLogStatus.done) {
        completedByDay[l.date] = (completedByDay[l.date] ?? 0) + 1;
      }
    }
    final habitTotal = habits.length;
    final monthTotal =
        last30.fold<int>(0, (s, d) => s + (completedByDay[_iso(d)] ?? 0));
    final possible = habitTotal * 30;
    final percent = possible == 0 ? 0 : (monthTotal * 100 / possible).round();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.spa_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Статистика 30 дней',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text('$percent%',
                    style: TextStyle(
                        color: scheme.primary, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _HMetric(
                    label: 'Сегодня',
                    value: '$doneToday / $habitTotal'),
                const SizedBox(width: 16),
                _HMetric(
                    label: 'За 30 дней',
                    value: '$monthTotal'),
                const SizedBox(width: 16),
                _HMetric(
                    label: 'Привычек',
                    value: '$habitTotal'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in last30)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: () {
                          final v = completedByDay[_iso(d)] ?? 0;
                          final ratio = habitTotal == 0
                              ? 0.0
                              : (v / habitTotal).clamp(0, 1).toDouble();
                          return Container(
                            height: ratio == 0 ? 4 : 4 + ratio * 32,
                            decoration: BoxDecoration(
                              color: ratio == 0
                                  ? scheme.surfaceContainerHighest
                                  : const Color(0xFF22C55E)
                                      .withValues(alpha: 0.4 + ratio * 0.6),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _HMetric extends StatelessWidget {
  const _HMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value,
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ],
    );
  }
}
