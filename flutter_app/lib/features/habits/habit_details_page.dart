import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/habit.dart';
import '../../services/streak.dart';
import '../../state/providers.dart';
import '../../widgets/habit_heatmap.dart';

/// Per-habit detail screen with streak chips, year heatmap, completion-rate
/// summary and a chronological log of recent entries.
class HabitDetailsPage extends ConsumerWidget {
  const HabitDetailsPage({super.key, required this.habitId});

  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final logs = ref.watch(habitLogsProvider);
    final habit = habits.cast<Habit?>().firstWhere(
          (h) => h?.id == habitId,
          orElse: () => null,
        );
    if (habit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Привычка')),
        body: const Center(child: Text('Привычка не найдена')),
      );
    }
    final stats = computeStreakStats(habit: habit, logs: logs);
    final habitLogs = logs.where((l) => l.habitId == habit.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await ref.read(habitsProvider.notifier).remove(habit.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _StreakHero(habit: habit, stats: stats),
          const SizedBox(height: 16),
          _HeatmapCard(habit: habit, logs: logs),
          const SizedBox(height: 16),
          _LogList(
            habit: habit,
            logs: habitLogs,
            onDelete: (l) =>
                ref.read(habitLogsProvider.notifier).remove(l.id),
            onAddNote: (l, note) => _editLog(ref, l, notes: note),
          ),
          const SizedBox(height: 16),
          _LogForToday(habit: habit, ref: ref),
        ],
      ),
    );
  }

  Future<void> _editLog(WidgetRef ref, HabitLog log,
      {String? notes}) async {
    final updated = HabitLog(
      id: log.id,
      habitId: log.habitId,
      date: log.date,
      status: log.status,
      notes: notes ?? log.notes,
      feelings: log.feelings,
      value: log.value,
    );
    await ref.read(habitLogsProvider.notifier).upsert(updated);
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.habit, required this.stats});
  final Habit habit;
  final StreakStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (stats.completionRate * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatChip(
                  icon: Icons.local_fire_department,
                  color: const Color(0xFFF97316),
                  label: 'Серия',
                  value: '${stats.current}',
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.emoji_events_outlined,
                  color: const Color(0xFFEAB308),
                  label: 'Рекорд',
                  value: '${stats.best}',
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF22C55E),
                  label: 'Всего',
                  value: '${stats.totalDone}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Выполнение за 30 дней',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: stats.completionRate.clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: scheme.surfaceContainerHighest,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$pct%',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({required this.habit, required this.logs});
  final Habit habit;
  final List<HabitLog> logs;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Активность за 16 недель',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            HabitHeatmap(
              statusFor: (iso) => statusFor(logs, habit.id, iso),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  const _LogList({
    required this.habit,
    required this.logs,
    required this.onDelete,
    required this.onAddNote,
  });

  final Habit habit;
  final List<HabitLog> logs;
  final ValueChanged<HabitLog> onDelete;
  final void Function(HabitLog log, String? note) onAddNote;

  String _statusLabel(Habit habit, HabitLogStatus s) {
    final isGood = habit.type == HabitTypeKind.good;
    switch (s) {
      case HabitLogStatus.done:
        return isGood ? 'Сделал' : 'Удержался';
      case HabitLogStatus.failed:
        return isGood ? 'Не сделал' : 'Сорвался';
      case HabitLogStatus.skipped:
        return 'Пропустил';
    }
  }

  Color _statusColor(HabitLogStatus s) {
    switch (s) {
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
    if (logs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('История', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              const Text('Пока нет отметок. Отметь сегодняшний день ниже.'),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('История', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final l in logs.take(20))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _statusColor(l.status),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat.yMMMMd('ru')
                                .format(DateTime.parse(l.date)),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _statusLabel(habit, l.status),
                            style: TextStyle(
                              color: _statusColor(l.status),
                              fontSize: 12,
                            ),
                          ),
                          if (l.notes.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                l.notes,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note, size: 20),
                      onPressed: () async {
                        final controller =
                            TextEditingController(text: l.notes);
                        final result = await showDialog<String?>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Заметка'),
                            content: TextField(
                              controller: controller,
                              autofocus: true,
                              maxLines: 3,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(null),
                                child: const Text('Отмена'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(ctx)
                                    .pop(controller.text.trim()),
                                child: const Text('Сохранить'),
                              ),
                            ],
                          ),
                        );
                        if (result != null) onAddNote(l, result);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => onDelete(l),
                    ),
                  ],
                ),
              ),
            if (logs.length > 20)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Показаны последние 20 из ${logs.length}.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LogForToday extends StatelessWidget {
  const _LogForToday({required this.habit, required this.ref});
  final Habit habit;
  final WidgetRef ref;

  Future<void> _markToday(BuildContext context, HabitLogStatus status) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final logs = ref.read(habitLogsProvider);
    final existing = logs.cast<HabitLog?>().firstWhere(
          (l) => l?.habitId == habit.id && l?.date == today,
          orElse: () => null,
        );
    final entry = HabitLog(
      id: existing?.id ?? const Uuid().v4(),
      habitId: habit.id,
      date: today,
      status: status,
      notes: existing?.notes ?? '',
      feelings: existing?.feelings ?? '',
      value: existing?.value,
    );
    await ref.read(habitLogsProvider.notifier).upsert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final isGood = habit.type == HabitTypeKind.good;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Отметка за сегодня',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.check),
                  label: Text(isGood ? 'Сделал' : 'Удержался'),
                  onPressed: () =>
                      _markToday(context, HabitLogStatus.done),
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.remove),
                  label: const Text('Пропустил'),
                  onPressed: () =>
                      _markToday(context, HabitLogStatus.skipped),
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.close),
                  label: Text(isGood ? 'Не сделал' : 'Сорвался'),
                  onPressed: () =>
                      _markToday(context, HabitLogStatus.failed),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
