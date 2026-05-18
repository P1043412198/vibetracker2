import '../../widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/misc.dart';
import '../../state/providers.dart';

Future<void> _openUrl(BuildContext context, String raw) async {
  var s = raw.trim();
  if (s.isEmpty) return;
  if (!s.startsWith('http://') && !s.startsWith('https://')) {
    s = 'https://$s';
  }
  final uri = Uri.tryParse(s);
  if (uri == null) return;
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось открыть ссылку: $s')),
    );
  }
}

/// History + planned overview of workouts.
///
/// Top: month-grouped list of [PlannedWorkout]s. Bottom: per-exercise
/// volume sparkline (weight × reps over time). The user can pick a
/// program (folder) and check off exercises completed for any planned
/// session.
class WorkoutHistoryPage extends ConsumerStatefulWidget {
  const WorkoutHistoryPage({super.key});

  @override
  ConsumerState<WorkoutHistoryPage> createState() =>
      _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends ConsumerState<WorkoutHistoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('История тренировок'),
        bottom: TabBar(
          controller: _controller,
          tabs: const [
            Tab(text: 'Запланированные'),
            Tab(text: 'Выполненные'),
            Tab(text: 'Прогресс'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: const [
          _PlannedTab(),
          _CompletedTab(),
          _ProgressTab(),
        ],
      ),
    );
  }
}

class _PlannedTab extends ConsumerWidget {
  const _PlannedTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planned = [...ref.watch(plannedWorkoutsProvider)]
      ..sort((a, b) => a.date.compareTo(b.date));
    final upcoming = planned
        .where((p) => p.status == PlannedWorkoutStatus.planned)
        .toList();
    if (upcoming.isEmpty) {
      return const _Empty(
        emoji: '📅',
        title: 'Нет запланированных',
        subtitle: 'Запланируй тренировку в календаре, она появится здесь.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: upcoming.length,
      itemBuilder: (_, i) {
        final pw = upcoming[i];
        return _PlannedCard(plan: pw);
      },
    );
  }
}

class _CompletedTab extends ConsumerWidget {
  const _CompletedTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = [...ref.watch(exerciseLogsProvider)]
      ..sort((a, b) => b.date.compareTo(a.date));
    final nodes = ref.watch(workoutNodesProvider);
    final completedPlans = ref
        .watch(plannedWorkoutsProvider)
        .where((p) => p.status == PlannedWorkoutStatus.completed)
        .toList();
    final logsByDate = <String, List<ExerciseLog>>{};
    for (final l in logs) {
      logsByDate.putIfAbsent(l.date, () => []).add(l);
    }
    final plansByDate = <String, List<PlannedWorkout>>{};
    for (final p in completedPlans) {
      plansByDate.putIfAbsent(p.date, () => []).add(p);
    }
    final dates = <String>{...logsByDate.keys, ...plansByDate.keys}.toList()
      ..sort((a, b) => b.compareTo(a));
    if (dates.isEmpty) {
      return const _Empty(
        emoji: '🏋️',
        title: 'Истории пока нет',
        subtitle:
            'Отметь запланированную как «Готово» или запиши сет вручную — оно появится здесь.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: dates.length,
      itemBuilder: (_, i) {
        final d = dates[i];
        final dayLogs = logsByDate[d] ?? const <ExerciseLog>[];
        final dayPlans = plansByDate[d] ?? const <PlannedWorkout>[];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_humanDate(d),
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final p in dayPlans)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Color(0xFF22C55E), size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            p.label?.isNotEmpty == true
                                ? p.label!
                                : _programName(p.programId, nodes),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (dayPlans.isNotEmpty && dayLogs.isNotEmpty)
                  const Divider(height: 12),
                for (final l in dayLogs)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _exerciseName(l.exerciseId, nodes),
                            style: const TextStyle(
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(_metricsLabel(l.metrics)),
                      ],
                    ),
                  ),
                if (dayPlans.isNotEmpty && dayLogs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Сеты не записаны',
                        style:
                            Theme.of(context).textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _programName(String? id, List<WorkoutNode> nodes) {
    if (id == null) return 'Тренировка';
    final n = nodes
        .cast<WorkoutNode?>()
        .firstWhere((x) => x?.id == id, orElse: () => null);
    return n?.name ?? 'Тренировка';
  }

  String _humanDate(String iso) {
    final dt = DateTime.tryParse(iso);
    return dt == null ? iso : DateFormat.yMMMMd('ru').format(dt);
  }

  String _exerciseName(String id, List<WorkoutNode> nodes) {
    final node =
        nodes.cast<WorkoutNode?>().firstWhere((n) => n?.id == id, orElse: () => null);
    return node?.name ?? '(удалено)';
  }

  String _metricsLabel(Map<WorkoutMetric, num> m) {
    final parts = <String>[];
    if (m.containsKey(WorkoutMetric.weight) &&
        m.containsKey(WorkoutMetric.reps)) {
      parts.add('${m[WorkoutMetric.weight]} кг × ${m[WorkoutMetric.reps]}');
    } else {
      m.forEach((k, v) => parts.add('${_metricLabel(k)}: $v'));
    }
    return parts.join('  ·  ');
  }

  String _metricLabel(WorkoutMetric m) => switch (m) {
        WorkoutMetric.weight => 'кг',
        WorkoutMetric.reps => 'повт.',
        WorkoutMetric.distance => 'км',
        WorkoutMetric.time => 'мин',
        WorkoutMetric.speed => 'км/ч',
        WorkoutMetric.calories => 'ккал',
      };
}

class _ProgressTab extends ConsumerWidget {
  const _ProgressTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(workoutNodesProvider);
    final logs = ref.watch(exerciseLogsProvider);
    final exercises =
        nodes.where((n) => n.type == WorkoutNodeType.exercise).toList();
    if (exercises.isEmpty) {
      return const _Empty(
        emoji: '📊',
        title: 'Нет упражнений',
        subtitle: 'Создай хотя бы одно упражнение в разделе «Тренировки».',
      );
    }
    final stats = exercises
        .map((e) {
          final exLogs = logs.where((l) => l.exerciseId == e.id).toList()
            ..sort((a, b) => a.date.compareTo(b.date));
          return _ExerciseStat(
            node: e,
            logs: exLogs,
          );
        })
        .where((s) => s.logs.isNotEmpty)
        .toList();
    if (stats.isEmpty) {
      return const _Empty(
        emoji: '📈',
        title: 'Пока нет данных',
        subtitle: 'Сделай первый сет — на графике появится прогресс.',
      );
    }
    stats.sort((a, b) => b.logs.length.compareTo(a.logs.length));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: stats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _ExerciseProgressCard(stat: stats[i]),
    );
  }
}

class _ExerciseStat {
  _ExerciseStat({required this.node, required this.logs});
  final WorkoutNode node;
  final List<ExerciseLog> logs;

  num get bestVolume {
    num best = 0;
    for (final l in logs) {
      final w = l.metrics[WorkoutMetric.weight] ?? 0;
      final r = l.metrics[WorkoutMetric.reps] ?? 1;
      final v = w * r;
      if (v > best) best = v;
    }
    return best;
  }

  num get bestWeight {
    num best = 0;
    for (final l in logs) {
      final w = l.metrics[WorkoutMetric.weight] ?? 0;
      if (w > best) best = w;
    }
    return best;
  }

  num get totalReps {
    num total = 0;
    for (final l in logs) {
      total += l.metrics[WorkoutMetric.reps] ?? 0;
    }
    return total;
  }
}

class _ExerciseProgressCard extends StatelessWidget {
  const _ExerciseProgressCard({required this.stat});
  final _ExerciseStat stat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fitness_center, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(stat.node.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                      overflow: TextOverflow.ellipsis),
                ),
                Text('${stat.logs.length} сетов',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 56,
              child: CustomPaint(
                size: const Size.fromHeight(56),
                painter: _SparklinePainter(
                  values: stat.logs
                      .map((l) =>
                          ((l.metrics[WorkoutMetric.weight] ?? 0) *
                              (l.metrics[WorkoutMetric.reps] ?? 1))
                              .toDouble())
                      .toList(),
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _Metric(label: 'Лучший объём',
                    value: stat.bestVolume.toStringAsFixed(0)),
                _Metric(label: 'Макс. вес',
                    value: '${stat.bestWeight} кг'),
                _Metric(label: 'Всего повт.',
                    value: stat.totalReps.toStringAsFixed(0)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final stepX = values.length == 1 ? 0.0 : size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = stepX * i;
      final y = size.height - ((values[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = color.withValues(alpha: 0.18),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    // Last point dot
    final lastX = stepX * (values.length - 1);
    final lastY = size.height -
        ((values.last - minV) / range) * size.height;
    canvas.drawCircle(Offset(lastX, lastY), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.color != color;
}

class _PlannedCard extends ConsumerWidget {
  const _PlannedCard({required this.plan});
  final PlannedWorkout plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(workoutNodesProvider);
    final program = nodes
        .cast<WorkoutNode?>()
        .firstWhere((n) => n?.id == plan.programId, orElse: () => null);
    final exercises = program == null
        ? <WorkoutNode>[]
        : nodes
            .where((n) =>
                n.parentId == program.id &&
                n.type == WorkoutNodeType.exercise)
            .toList();
    final dt = DateTime.tryParse(plan.date);
    final dateLabel =
        dt == null ? plan.date : DateFormat.yMMMMd('ru').format(dt);
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
                  child: Text(
                    plan.label?.isNotEmpty == true
                        ? plan.label!
                        : (program?.name ?? 'Тренировка'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
                Text(dateLabel,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            if (program == null)
              const Text('Программа не выбрана',
                  style: TextStyle(fontStyle: FontStyle.italic))
            else if (exercises.isEmpty)
              const Text('В программе пока нет упражнений')
            else ...[
              for (final ex in exercises)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.check_box_outline_blank, size: 22),
                  title: Text(ex.name),
                  subtitle: ex.muscleGroup == null
                      ? null
                      : Text(ex.muscleGroup!.name),
                  trailing: Wrap(
                    spacing: 0,
                    children: [
                      if (ex.videoUrl != null)
                        IconButton(
                          tooltip: 'Видео',
                          icon: const Icon(Icons.play_circle, size: 20),
                          onPressed: () =>
                              _openUrl(context, ex.videoUrl!),
                        ),
                      if (ex.articleUrls?.isNotEmpty ?? false)
                        IconButton(
                          tooltip: 'Статья',
                          icon: const Icon(Icons.article, size: 20),
                          onPressed: () => _openUrl(
                              context, ex.articleUrls!.first),
                        ),
                    ],
                  ),
                  onTap: () => _logSet(context, ref, ex),
                ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _markStatus(
                      context,
                      ref,
                      plan,
                      PlannedWorkoutStatus.missed,
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text('Пропущено'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _markStatus(
                      context,
                      ref,
                      plan,
                      PlannedWorkoutStatus.completed,
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Готово'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markStatus(
    BuildContext context,
    WidgetRef ref,
    PlannedWorkout plan,
    PlannedWorkoutStatus status,
  ) async {
    await ref
        .read(plannedWorkoutsProvider.notifier)
        .upsert(plan.copyWith(status: status));
    if (status != PlannedWorkoutStatus.completed) return;
    final nodes = ref.read(workoutNodesProvider);
    final exercises = nodes
        .where((n) =>
            n.parentId == plan.programId &&
            n.type == WorkoutNodeType.exercise)
        .toList();
    if (exercises.isEmpty) return;
    if (!context.mounted) return;
    final logs = ref.read(exerciseLogsProvider);
    final hasLogsToday = exercises.any((e) =>
        logs.any((l) => l.exerciseId == e.id && l.date == plan.date));
    if (hasLogsToday) return;
    final fill = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Записать упражнения?'),
        content: Text(
          'Создать запись о выполнении ${exercises.length} упражнений из программы? Подходы добавятся с отметкой «выполнено», без веса/повторений — позже сможешь уточнить тапом.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Только статус')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Да, записать')),
        ],
      ),
    );
    if (fill != true) return;
    final ctl = ref.read(exerciseLogsProvider.notifier);
    for (final e in exercises) {
      await ctl.add(ExerciseLog(
        id: const Uuid().v4(),
        exerciseId: e.id,
        date: plan.date,
        metrics: const {WorkoutMetric.reps: 0},
        notes: 'Отмечено как выполнено',
      ));
    }
  }

  Future<void> _logSet(
    BuildContext context,
    WidgetRef ref,
    WorkoutNode exercise,
  ) async {
    final weightCtl = TextEditingController();
    final repsCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(exercise.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Вес, кг'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: repsCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Повторений'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Записать')),
        ],
      ),
    );
    if (ok != true) return;
    final w = num.tryParse(weightCtl.text.trim()) ?? 0;
    final r = num.tryParse(repsCtl.text.trim()) ?? 0;
    if (r <= 0) return;
    await ref.read(exerciseLogsProvider.notifier).add(ExerciseLog(
          id: const Uuid().v4(),
          exerciseId: exercise.id,
          date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          metrics: {
            if (w > 0) WorkoutMetric.weight: w,
            WorkoutMetric.reps: r,
          },
        ));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Записано: ${exercise.name}')),
      );
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
  final String emoji;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
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
