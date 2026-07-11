import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../models/misc.dart';
import '../../state/providers.dart';
import '../../widgets/app_back_button.dart';
import 'workout_charts.dart';
import 'workout_format.dart';

/// Full history of a single exercise: summary infographics, trend charts and
/// a day-grouped list of every recorded set with the user-selected metrics.
class WorkoutExerciseDetailPage extends ConsumerWidget {
  const WorkoutExerciseDetailPage({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(workoutNodesProvider);
    final node = nodes
        .cast<WorkoutNode?>()
        .firstWhere((n) => n?.id == exerciseId, orElse: () => null);
    final logs = ref
        .watch(exerciseLogsProvider)
        .where((l) => l.exerciseId == exerciseId)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final byDate = <String, List<ExerciseLog>>{};
    for (final l in logs) {
      byDate.putIfAbsent(l.date, () => []).add(l);
    }
    final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    // Metrics to chart: the exercise's chosen ones, falling back to recorded.
    final metrics = (node?.metrics?.toSet() ?? <WorkoutMetric>{})
      ..addAll(logs.expand((l) => l.metrics.keys));

    final hasGoal = node?.targetWeight != null || node?.targetReps != null;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(node?.name ?? 'Упражнение'),
        actions: [
          if (node != null)
            IconButton(
              tooltip: hasGoal ? 'Изменить цель' : 'Задать цель',
              icon: Icon(hasGoal ? Icons.flag : Icons.flag_outlined),
              onPressed: () => _editGoal(context, ref, node),
            ),
        ],
      ),
      body: logs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Нет записей по этому упражнению.'),
                    if (node != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _editGoal(context, ref, node),
                        icon: const Icon(Icons.flag_outlined),
                        label: Text(hasGoal ? 'Изменить цель' : 'Задать цель'),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                _SummaryGrid(logs: logs, sessions: dates.length),
                if (node != null && hasGoal) ...[
                  const SizedBox(height: 16),
                  _GoalCard(node: node, logs: logs),
                ],
                const SizedBox(height: 16),
                _Charts(byDate: byDate, dates: dates, metrics: metrics),
                const SizedBox(height: 16),
                Text('История по дням',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final d in dates)
                  _DaySetsCard(date: d, sets: byDate[d]!),
              ],
            ),
    );
  }

  Future<void> _editGoal(
      BuildContext context, WidgetRef ref, WorkoutNode node) async {
    final weightCtrl = TextEditingController(
        text: node.targetWeight == null ? '' : fmtNum(node.targetWeight!));
    final repsCtrl = TextEditingController(
        text: node.targetReps == null ? '' : '${node.targetReps}');

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Цель по упражнению'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Задайте целевой рабочий вес и/или повторы. На странице '
              'появится индикатор приближения к рекорду.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Целевой вес, кг',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: repsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Целевые повторы',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          if (node.targetWeight != null || node.targetReps != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'clear'),
              child: const Text('Убрать цель'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (action == null || action == 'cancel') return;
    final notifier = ref.read(workoutNodesProvider.notifier);
    if (action == 'clear') {
      await notifier.update(node.id, (n) => n.copyWith(clearGoal: true));
      return;
    }
    final w = double.tryParse(weightCtrl.text.trim().replaceAll(',', '.'));
    final r = int.tryParse(repsCtrl.text.trim());
    if (w == null && r == null) {
      await notifier.update(node.id, (n) => n.copyWith(clearGoal: true));
      return;
    }
    await notifier.update(
      node.id,
      (n) => n.copyWith(clearGoal: true).copyWith(
            targetWeight: w,
            targetReps: r,
          ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.node, required this.logs});
  final WorkoutNode node;
  final List<ExerciseLog> logs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tw = node.targetWeight;
    final tr = node.targetReps;
    final bestW = bestMetric(logs, WorkoutMetric.weight);
    final bestEst = bestE1RM(logs);

    // Progress toward the target working weight.
    final weightPct = (tw != null && tw > 0)
        ? (bestW / tw).clamp(0.0, 1.0).toDouble()
        : null;

    // Progress toward the target estimated 1RM (needs both weight & reps).
    final targetE1RM = (tw != null && tr != null)
        ? estimatedOneRepMax(tw, tr)
        : null;
    final e1rmPct = (targetE1RM != null && targetE1RM > 0)
        ? (bestEst / targetE1RM).clamp(0.0, 1.0).toDouble()
        : null;

    final goalLabel = [
      if (tw != null) '${fmtNum(tw)} кг',
      if (tr != null) '× $tr',
    ].join(' ');

    final reached = (weightPct != null && weightPct >= 1.0) ||
        (e1rmPct != null && e1rmPct >= 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(reached ? Icons.emoji_events : Icons.flag,
                    size: 20,
                    color: reached ? const Color(0xFFF59E0B) : scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Цель: $goalLabel',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                if (reached)
                  Text('Достигнута! 🎉',
                      style: TextStyle(
                          color: const Color(0xFFF59E0B),
                          fontWeight: FontWeight.w700)),
              ],
            ),
            if (weightPct != null) ...[
              const SizedBox(height: 12),
              _GoalBar(
                label: 'Рабочий вес',
                value: '${fmtNum(bestW)} / ${fmtNum(tw!)} кг',
                pct: weightPct,
                color: scheme.primary,
              ),
              if (weightPct < 1.0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Осталось ${fmtNum(tw - bestW)} кг',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
            ],
            if (e1rmPct != null) ...[
              const SizedBox(height: 12),
              _GoalBar(
                label: '1ПМ (оценка, Epley)',
                value: '${fmtNum(bestEst)} / ${fmtNum(targetE1RM!)} кг',
                pct: e1rmPct,
                color: const Color(0xFF22C55E),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  e1rmPct < 1.0
                      ? 'До рекорда ${fmtNum(targetE1RM - bestEst)} кг '
                          '(${(e1rmPct * 100).round()}%)'
                      : 'Расчётный рекорд взят!',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalBar extends StatelessWidget {
  const _GoalBar({
    required this.label,
    required this.value,
    required this.pct,
    required this.color,
  });
  final String label;
  final String value;
  final double pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.logs, required this.sessions});
  final List<ExerciseLog> logs;
  final int sessions;

  @override
  Widget build(BuildContext context) {
    final hasWeight = logs.any((l) => l.metrics.containsKey(WorkoutMetric.weight));
    final tiles = <Widget>[
      _StatTile(label: 'Сессий', value: '$sessions', icon: Icons.event),
      _StatTile(label: 'Подходов', value: '${logs.length}', icon: Icons.repeat),
      if (hasWeight)
        _StatTile(
          label: 'Макс. вес',
          value: '${_fmt(bestMetric(logs, WorkoutMetric.weight))} кг',
          icon: Icons.trending_up,
        ),
      _StatTile(
        label: 'Объём',
        value: _fmt(totalVolume(logs)),
        icon: Icons.fitness_center,
      ),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in tiles)
          SizedBox(
            width: (MediaQuery.of(context).size.width - 32 - 8) / 2,
            child: t,
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 17),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Charts extends StatelessWidget {
  const _Charts({
    required this.byDate,
    required this.dates,
    required this.metrics,
  });
  final Map<String, List<ExerciseLog>> byDate;
  final List<String> dates; // newest first
  final Set<WorkoutMetric> metrics;

  @override
  Widget build(BuildContext context) {
    // Oldest → newest for trend charts.
    final ordered = [...dates]..sort();
    final volumeSeries = ordered
        .map((d) => totalVolume(byDate[d]!).toDouble())
        .toList();
    final weights = ordered
        .map((d) => bestMetric(byDate[d]!, WorkoutMetric.weight).toDouble())
        .toList();

    final children = <Widget>[];
    if (volumeSeries.length >= 2) {
      children.add(_ChartCard(
        title: 'Объём за тренировку',
        child: WorkoutLineChart(values: volumeSeries),
      ));
    }
    if (metrics.contains(WorkoutMetric.weight) &&
        weights.where((w) => w > 0).length >= 2) {
      children.add(_ChartCard(
        title: 'Максимальный вес',
        child: WorkoutLineChart(
          values: weights,
          color: const Color(0xFFF59E0B),
        ),
      ));
    }
    // Weekly frequency (last 8 ISO weeks).
    final freq = _weeklyFrequency(dates);
    if (freq.values.any((v) => v > 0)) {
      children.add(_ChartCard(
        title: 'Частота по неделям',
        child: WorkoutBarChart(
          values: freq.values.map((v) => v.toDouble()).toList(),
          labels: freq.keys.toList(),
          color: const Color(0xFF22C55E),
        ),
      ));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    );
  }

  /// Sessions per ISO week for the most recent 8 weeks (oldest → newest).
  Map<String, int> _weeklyFrequency(List<String> dates) {
    final counts = <String, int>{};
    for (final d in dates) {
      final dt = DateTime.tryParse(d);
      if (dt == null) continue;
      final monday = dt.subtract(Duration(days: dt.weekday - 1));
      final key = DateFormat('dd.MM').format(monday);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final keys = counts.keys.toList()
      ..sort((a, b) {
        final pa = a.split('.');
        final pb = b.split('.');
        return '${pa[1]}${pa[0]}'.compareTo('${pb[1]}${pb[0]}');
      });
    final recent = keys.length > 8 ? keys.sublist(keys.length - 8) : keys;
    return {for (final k in recent) k: counts[k]!};
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            SizedBox(height: 80, child: child),
          ],
        ),
      ),
    );
  }
}

class _DaySetsCard extends StatelessWidget {
  const _DaySetsCard({required this.date, required this.sets});
  final String date;
  final List<ExerciseLog> sets;

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(date);
    final label = dt == null
        ? date
        : '${DateFormat.EEEE('ru').format(dt)}, ${DateFormat.yMMMMd('ru').format(dt)}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_cap(label),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text('${sets.length} подх.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < sets.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text('${i + 1}.',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                    Expanded(child: Text(setSummary(sets[i]))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

String _fmt(num v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}
