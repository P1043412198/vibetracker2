import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/goal.dart';
import '../../state/providers.dart';

/// Counterpart of `src/pages/Goals.tsx`. Renders goals list + add. Detailed
/// step/sub-task editing, AI-plan generation and book-tracking comes later.
class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Цели')),
      body: goals.isEmpty
          ? const _Empty()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: goals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _GoalCard(goal: goals[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addGoal(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Цель'),
      ),
    );
  }

  Future<void> _addGoal(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    var type = GoalType.goal;
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
                  Text('Новая цель',
                      style: Theme.of(innerContext).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Название'),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<GoalType>(
                    segments: const [
                      ButtonSegment(
                        value: GoalType.goal,
                        label: Text('Цель'),
                      ),
                      ButtonSegment(
                        value: GoalType.skill,
                        label: Text('Навык'),
                      ),
                      ButtonSegment(
                        value: GoalType.book,
                        label: Text('Книга'),
                      ),
                      ButtonSegment(
                        value: GoalType.learning,
                        label: Text('Обучение'),
                      ),
                    ],
                    selected: {type},
                    onSelectionChanged: (s) =>
                        setState(() => type = s.first),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      final title = controller.text.trim();
                      if (title.isEmpty) return;
                      await ref.read(goalsProvider.notifier).add(
                            Goal(
                              id: const Uuid().v4(),
                              title: title,
                              type: type,
                              status: GoalStatus.in_progress,
                              steps: const [],
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

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal});
  final Goal goal;

  Color _statusColor(GoalStatus s) {
    switch (s) {
      case GoalStatus.completed:
        return const Color(0xFF22C55E);
      case GoalStatus.in_progress:
        return const Color(0xFF3B82F6);
      case GoalStatus.not_started:
        return const Color(0xFFF59E0B);
    }
  }

  String _typeLabel(GoalType t) {
    switch (t) {
      case GoalType.goal:
        return 'Цель';
      case GoalType.skill:
        return 'Навык';
      case GoalType.book:
        return 'Книга';
      case GoalType.learning:
        return 'Обучение';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _statusColor(goal.status);
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            goal.icon ?? '🎯',
            style: const TextStyle(fontSize: 22),
          ),
        ),
        title: Text(goal.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(_typeLabel(goal.type)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => ref.read(goalsProvider.notifier).remove(goal.id),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
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
            const Text('🎯', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Никаких целей пока нет',
                style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}
