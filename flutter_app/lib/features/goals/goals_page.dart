import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/goal.dart';
import '../../state/providers.dart';

/// Counterpart of `src/pages/Goals.tsx`. Renders the goals list with
/// progress bars, status pills and tap-to-edit deep navigation.
class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = [...ref.watch(goalsProvider)];
    // Pinned first, then in_progress, then everything else.
    int rank(Goal g) {
      if (g.isPinned == true) return 0;
      if (g.status == GoalStatus.in_progress) return 1;
      if (g.status == GoalStatus.not_started) return 2;
      return 3;
    }

    goals.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      return a.createdAt.compareTo(b.createdAt) * -1;
    });
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Цели'),
      ),
      body: goals.isEmpty
          ? const _Empty()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: goals.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i == 0) return _GoalsStatsHeader(goals: goals);
                return _GoalCard(goal: goals[i - 1]);
              },
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

  String _statusLabel(GoalStatus s) {
    switch (s) {
      case GoalStatus.completed:
        return 'Готово';
      case GoalStatus.in_progress:
        return 'В работе';
      case GoalStatus.not_started:
        return 'Не начато';
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

  String _defaultIcon(GoalType t) {
    switch (t) {
      case GoalType.goal:
        return '🎯';
      case GoalType.skill:
        return '⚡️';
      case GoalType.book:
        return '📖';
      case GoalType.learning:
        return '🎓';
    }
  }

  /// Compute a 0..1 progress value following the same precedence as the
  /// React app: book (readPages/totalPages) → numeric (currentValue/targetValue)
  /// → manual (`progress`) → steps (% completed).
  double _progress() {
    if (goal.type == GoalType.book &&
        (goal.totalPages ?? 0) > 0) {
      return ((goal.readPages ?? 0) / (goal.totalPages!)).clamp(0.0, 1.0);
    }
    if ((goal.targetValue ?? 0) > 0) {
      return ((goal.currentValue ?? 0) / (goal.targetValue!))
          .toDouble()
          .clamp(0.0, 1.0);
    }
    if (goal.progress != null) {
      return (goal.progress! / 100).clamp(0.0, 1.0);
    }
    if (goal.steps.isNotEmpty) {
      final done = goal.steps.where((s) => s.completed).length;
      return done / goal.steps.length;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final color = _statusColor(goal.status);
    final progress = _progress();
    final pct = (progress * 100).round();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go('/goals/${goal.id}'),
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
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      goal.icon ?? _defaultIcon(goal.type),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                goal.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (goal.isPinned == true)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.push_pin,
                                    size: 16, color: Colors.amber),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _Pill(
                                text: _typeLabel(goal.type),
                                color: scheme.primary),
                            _Pill(
                                text: _statusLabel(goal.status), color: color),
                            if (goal.deadline != null)
                              _Pill(
                                  text: 'до ${goal.deadline!.split('T').first}',
                                  color: Colors.deepOrange),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$pct%',
                      style: Theme.of(context).textTheme.labelMedium),
                  if (goal.type == GoalType.book &&
                      goal.totalPages != null)
                    Text(
                      '${goal.readPages ?? 0} / ${goal.totalPages} стр.',
                      style: Theme.of(context).textTheme.labelMedium,
                    )
                  else if (goal.targetValue != null)
                    Text(
                      '${goal.currentValue ?? 0} / ${goal.targetValue}',
                      style: Theme.of(context).textTheme.labelMedium,
                    )
                  else if (goal.steps.isNotEmpty)
                    Text(
                      '${goal.steps.where((s) => s.completed).length} / ${goal.steps.length} шагов',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700),
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
            const SizedBox(height: 8),
            Text(
              'Жми «+ Цель», чтобы добавить первую',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalsStatsHeader extends StatelessWidget {
  const _GoalsStatsHeader({required this.goals});
  final List<Goal> goals;

  double _progressOf(Goal g) {
    if (g.progress != null) return (g.progress! / 100).clamp(0.0, 1.0).toDouble();
    if ((g.targetValue ?? 0) > 0) {
      final v = (g.currentValue ?? 0) / g.targetValue!;
      return v.clamp(0.0, 1.0).toDouble();
    }
    if ((g.totalPages ?? 0) > 0) {
      final v = (g.readPages ?? 0) / g.totalPages!;
      return v.clamp(0.0, 1.0).toDouble();
    }
    if (g.steps.isNotEmpty) {
      final done = g.steps
          .where((s) => s.status == GoalStepStatus.done)
          .length;
      return (done / g.steps.length).clamp(0.0, 1.0).toDouble();
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) return const SizedBox.shrink();
    final byStatus = <GoalStatus, int>{};
    for (final g in goals) {
      byStatus[g.status] = (byStatus[g.status] ?? 0) + 1;
    }
    final avg = goals.isEmpty
        ? 0.0
        : goals.fold<double>(0.0, (a, g) => a + _progressOf(g)) / goals.length;
    final scheme = Theme.of(context).colorScheme;
    Color colorFor(GoalStatus s) {
      switch (s) {
        case GoalStatus.completed:
          return const Color(0xFF22C55E);
        case GoalStatus.in_progress:
          return const Color(0xFF6D5CFF);
        case GoalStatus.not_started:
          return const Color(0xFF94A3B8);
      }
    }

    String labelFor(GoalStatus s) {
      switch (s) {
        case GoalStatus.completed:
          return 'Сделано';
        case GoalStatus.in_progress:
          return 'В работе';
        case GoalStatus.not_started:
          return 'Не начато';
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.flag_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              Text('Обзор целей',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text('${(avg * 100).round()}%',
                  style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 28,
                      sections: [
                        for (final s in GoalStatus.values)
                          if ((byStatus[s] ?? 0) > 0)
                            PieChartSectionData(
                              value: byStatus[s]!.toDouble(),
                              color: colorFor(s),
                              title: byStatus[s].toString(),
                              radius: 28,
                              titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final s in GoalStatus.values)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: colorFor(s),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(labelFor(s))),
                            Text('${byStatus[s] ?? 0}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: avg,
                          minHeight: 8,
                          color: const Color(0xFF6D5CFF),
                          backgroundColor:
                              scheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('Средний прогресс по всем целям',
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
