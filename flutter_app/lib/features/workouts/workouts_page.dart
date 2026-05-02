import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/misc.dart';
import '../../services/ai_service.dart';
import '../../state/providers.dart';
import 'workout_camera_page.dart';

/// Counterpart of `src/pages/Workouts.tsx`. Phase 4 ships four tabs:
/// programs (tree of folders/exercises), calendar (planned workouts),
/// analytics (basic charts off exercise logs), and profile (body
/// measurements).
class WorkoutsPage extends ConsumerStatefulWidget {
  const WorkoutsPage({super.key});

  @override
  ConsumerState<WorkoutsPage> createState() => _WorkoutsPageState();
}

class _WorkoutsPageState extends ConsumerState<WorkoutsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тренировки'),
        actions: [
          IconButton(
            tooltip: 'Камера-тренер',
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const WorkoutCameraPage()));
            },
          ),
          IconButton(
            tooltip: 'AI-план',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () => _showAiPlanDialog(context, ref),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Программы'),
            Tab(text: 'Календарь'),
            Tab(text: 'Аналитика'),
            Tab(text: 'Тело'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _ProgramsTab(),
          _CalendarTab(),
          _AnalyticsTab(),
          _BodyTab(),
        ],
      ),
    );
  }
}

/* ────────────────────────── Programs / tree ─────────────────────────── */

class _ProgramsTab extends ConsumerWidget {
  const _ProgramsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(workoutNodesProvider);
    final roots = nodes.where((n) => n.parentId == null).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return Stack(
      children: [
        if (roots.isEmpty)
          const _EmptyHint(
            emoji: '🏋️',
            title: 'Нет программ',
            subtitle: 'Жми «+» чтобы добавить папку или упражнение.',
          )
        else
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
            itemCount: roots.length,
            itemBuilder: (context, i) =>
                _NodeTile(node: roots[i], depth: 0),
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'workouts_root_add',
            onPressed: () =>
                _showNodeEditor(context, ref, parentId: null),
            icon: const Icon(Icons.add),
            label: const Text('Папка'),
          ),
        ),
      ],
    );
  }
}

class _NodeTile extends ConsumerStatefulWidget {
  const _NodeTile({required this.node, required this.depth});
  final WorkoutNode node;
  final int depth;

  @override
  ConsumerState<_NodeTile> createState() => _NodeTileState();
}

class _NodeTileState extends ConsumerState<_NodeTile> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final children = ref
        .watch(workoutNodesProvider)
        .where((n) => n.parentId == node.id)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final isFolder = node.type == WorkoutNodeType.folder;
    final padding = EdgeInsets.only(left: 8.0 + widget.depth * 16, right: 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: padding,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (isFolder) {
                setState(() => _expanded = !_expanded);
              } else {
                _openExercise(context, ref, node);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isFolder
                        ? (_expanded
                            ? Icons.folder_open
                            : Icons.folder_outlined)
                        : Icons.fitness_center,
                    color: isFolder
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(node.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        if (node.muscleGroup != null || node.metrics != null)
                          Text(
                            [
                              if (node.muscleGroup != null)
                                _muscleLabel(node.muscleGroup!),
                              if (node.metrics != null)
                                node.metrics!
                                    .map(_metricLabel)
                                    .join(' · '),
                            ].join(' · '),
                            style:
                                Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (v) async {
                      switch (v) {
                        case 'add_folder':
                          await _showNodeEditor(context, ref,
                              parentId: node.id, isFolder: true);
                          break;
                        case 'add_ex':
                          await _showNodeEditor(context, ref,
                              parentId: node.id, isFolder: false);
                          break;
                        case 'edit':
                          await _showNodeEditor(context, ref,
                              parentId: node.parentId, existing: node);
                          break;
                        case 'delete':
                          await _confirmDelete(context, ref, node);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      if (isFolder) ...[
                        const PopupMenuItem(
                            value: 'add_folder',
                            child: Text('+ Подпапка')),
                        const PopupMenuItem(
                            value: 'add_ex',
                            child: Text('+ Упражнение')),
                      ],
                      const PopupMenuItem(
                          value: 'edit', child: Text('Редактировать')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Удалить')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isFolder && _expanded)
          for (final child in children)
            _NodeTile(node: child, depth: widget.depth + 1),
      ],
    );
  }
}

void _openExercise(
    BuildContext context, WidgetRef ref, WorkoutNode exercise) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ExerciseSheet(exercise: exercise),
  );
}

class _ExerciseSheet extends ConsumerStatefulWidget {
  const _ExerciseSheet({required this.exercise});
  final WorkoutNode exercise;

  @override
  ConsumerState<_ExerciseSheet> createState() => _ExerciseSheetState();
}

class _ExerciseSheetState extends ConsumerState<_ExerciseSheet> {
  late final Map<WorkoutMetric, TextEditingController> _ctrls;
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();

  List<WorkoutMetric> get _metricsList =>
      widget.exercise.metrics ??
      const [WorkoutMetric.weight, WorkoutMetric.reps];

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final m in _metricsList) m: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref
        .watch(exerciseLogsProvider)
        .where((l) => l.exerciseId == widget.exercise.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(widget.exercise.name,
              style: Theme.of(context).textTheme.titleLarge),
          if (widget.exercise.muscleGroup != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_muscleLabel(widget.exercise.muscleGroup!),
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          if (widget.exercise.notes != null &&
              widget.exercise.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(widget.exercise.notes!),
            ),
          const SizedBox(height: 16),
          Text('Новый подход',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final m in _metricsList)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _ctrls[m],
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: false),
                decoration: InputDecoration(
                  labelText: '${_metricLabel(m)}, ${_metricUnit(m)}',
                ),
              ),
            ),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(
                labelText: 'Заметка (необязательно)'),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(
                'Дата: ${DateFormat('d MMM y', 'ru').format(_date)}'),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate:
                    DateTime.now().subtract(const Duration(days: 365 * 3)),
                lastDate:
                    DateTime.now().add(const Duration(days: 365 * 1)),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.save_outlined),
            onPressed: _saveLog,
            label: const Text('Записать'),
          ),
          const SizedBox(height: 16),
          Text('История (${logs.length})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          if (logs.isEmpty)
            const Text('Подходов пока нет.')
          else
            for (final l in logs.take(40))
              Dismissible(
                key: ValueKey('log-${l.id}'),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => ref
                    .read(exerciseLogsProvider.notifier)
                    .remove(l.id),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.redAccent,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.history),
                  title: Text(l.metrics.entries
                      .map((e) =>
                          '${_metricLabel(e.key)}: ${e.value}')
                      .join(' · ')),
                  subtitle: Text(
                      '${l.date}${l.notes != null && l.notes!.isNotEmpty ? ' · ${l.notes}' : ''}'),
                ),
              ),
        ],
      ),
    );
  }

  void _saveLog() {
    final metrics = <WorkoutMetric, num>{};
    for (final m in _metricsList) {
      final raw = _ctrls[m]!.text.trim().replaceAll(',', '.');
      final v = num.tryParse(raw);
      if (v != null) metrics[m] = v;
    }
    if (metrics.isEmpty) return;
    final log = ExerciseLog(
      id: const Uuid().v4(),
      exerciseId: widget.exercise.id,
      date: DateFormat('y-MM-dd').format(_date),
      metrics: metrics,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    ref.read(exerciseLogsProvider.notifier).add(log);
    for (final c in _ctrls.values) {
      c.clear();
    }
    _notes.clear();
  }
}

Future<void> _showNodeEditor(
  BuildContext context,
  WidgetRef ref, {
  required String? parentId,
  bool isFolder = true,
  WorkoutNode? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  WorkoutNodeType type =
      existing?.type ?? (isFolder ? WorkoutNodeType.folder : WorkoutNodeType.exercise);
  MuscleGroup? muscle = existing?.muscleGroup;
  Set<WorkoutMetric> metrics = {
    ...(existing?.metrics ??
        (type == WorkoutNodeType.exercise
            ? const [WorkoutMetric.weight, WorkoutMetric.reps]
            : const <WorkoutMetric>[])),
  };

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 4,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(existing == null ? 'Новый узел' : 'Редактировать',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                SegmentedButton<WorkoutNodeType>(
                  segments: const [
                    ButtonSegment(
                        value: WorkoutNodeType.folder,
                        icon: Icon(Icons.folder_outlined),
                        label: Text('Папка')),
                    ButtonSegment(
                        value: WorkoutNodeType.exercise,
                        icon: Icon(Icons.fitness_center),
                        label: Text('Упражнение')),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => setState(() => type = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Название')),
                const SizedBox(height: 8),
                TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Заметка/схема')),
                if (type == WorkoutNodeType.exercise) ...[
                  const SizedBox(height: 12),
                  Text('Группа мышц',
                      style: Theme.of(ctx).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final m in MuscleGroup.values)
                        ChoiceChip(
                          label: Text(_muscleLabel(m)),
                          selected: muscle == m,
                          onSelected: (v) =>
                              setState(() => muscle = v ? m : null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Метрики',
                      style: Theme.of(ctx).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final m in WorkoutMetric.values)
                        FilterChip(
                          label: Text(_metricLabel(m)),
                          selected: metrics.contains(m),
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                metrics.add(m);
                              } else {
                                metrics.remove(m);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final notesText = notesCtrl.text.trim();
                    if (existing != null) {
                      await ref.read(workoutNodesProvider.notifier).upsert(
                            WorkoutNode(
                              id: existing.id,
                              parentId: existing.parentId,
                              name: name,
                              type: type,
                              notes: notesText.isEmpty ? null : notesText,
                              videoUrl: existing.videoUrl,
                              metrics: type == WorkoutNodeType.exercise
                                  ? metrics.toList()
                                  : null,
                              restTime: existing.restTime,
                              muscleGroup:
                                  type == WorkoutNodeType.exercise
                                      ? muscle
                                      : null,
                              isTemplate: existing.isTemplate,
                            ),
                          );
                    } else {
                      await ref.read(workoutNodesProvider.notifier).add(
                            WorkoutNode(
                              id: const Uuid().v4(),
                              parentId: parentId,
                              name: name,
                              type: type,
                              notes: notesText.isEmpty ? null : notesText,
                              metrics: type == WorkoutNodeType.exercise
                                  ? metrics.toList()
                                  : null,
                              muscleGroup:
                                  type == WorkoutNodeType.exercise
                                      ? muscle
                                      : null,
                            ),
                          );
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child:
                      Text(existing == null ? 'Создать' : 'Сохранить'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> _confirmDelete(
    BuildContext context, WidgetRef ref, WorkoutNode node) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Удалить «${node.name}»?'),
      content: const Text(
          'Будут удалены все вложенные папки и упражнения. Логи останутся в журнале.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена')),
        FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить')),
      ],
    ),
  );
  if (ok != true) return;
  // Cascade delete: collect descendants first.
  final all = ref.read(workoutNodesProvider);
  final toDelete = <String>{node.id};
  bool changed;
  do {
    changed = false;
    for (final n in all) {
      if (n.parentId != null &&
          toDelete.contains(n.parentId) &&
          !toDelete.contains(n.id)) {
        toDelete.add(n.id);
        changed = true;
      }
    }
  } while (changed);
  for (final id in toDelete) {
    await ref.read(workoutNodesProvider.notifier).remove(id);
  }
}

/* ───────────────────────────── Calendar ─────────────────────────────── */

class _CalendarTab extends ConsumerStatefulWidget {
  const _CalendarTab();

  @override
  ConsumerState<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<_CalendarTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final planned = ref.watch(plannedWorkoutsProvider);
    final logs = ref.watch(exerciseLogsProvider);

    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth =
        DateTime(_month.year, _month.month + 1, 0).day;
    // Mon=1..Sun=7; render as Mon-first
    final shift = (firstDay.weekday - 1) % 7;

    String iso(DateTime d) => DateFormat('y-MM-dd').format(d);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() =>
                  _month = DateTime(_month.year, _month.month - 1)),
            ),
            Expanded(
              child: Center(
                child: Text(
                  DateFormat('LLLL y', 'ru').format(_month),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() =>
                  _month = DateTime(_month.year, _month.month + 1)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final d in const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'])
              Expanded(
                child: Center(
                  child: Text(d,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (var i = 0; i < shift; i++) const SizedBox.shrink(),
            for (var d = 1; d <= daysInMonth; d++)
              _DayCell(
                date: DateTime(_month.year, _month.month, d),
                planned: planned.firstWhere(
                  (p) =>
                      p.date == iso(DateTime(_month.year, _month.month, d)),
                  orElse: () => PlannedWorkout(
                    id: '',
                    date: '',
                    status: PlannedWorkoutStatus.planned,
                  ),
                ),
                hasLog: logs.any((l) =>
                    l.date == iso(DateTime(_month.year, _month.month, d))),
                onTap: () => _openDay(
                    DateTime(_month.year, _month.month, d)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _LegendDot(color: scheme.primary, label: 'Запланировано'),
            _LegendDot(color: Colors.green, label: 'Выполнено'),
            _LegendDot(color: Colors.redAccent, label: 'Пропущено'),
            _LegendDot(
                color: scheme.tertiary, label: 'Есть логи (без плана)'),
          ],
        ),
      ],
    );
  }

  Future<void> _openDay(DateTime d) async {
    final iso = DateFormat('y-MM-dd').format(d);
    final all = ref.read(plannedWorkoutsProvider);
    final existing = all.cast<PlannedWorkout?>().firstWhere(
        (p) => p?.date == iso,
        orElse: () => null);
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    PlannedWorkoutStatus status =
        existing?.status ?? PlannedWorkoutStatus.planned;

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 4,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(DateFormat('EEEE, d MMM y', 'ru').format(d),
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                      controller: labelCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Программа дня (например, "Ноги")')),
                  const SizedBox(height: 12),
                  SegmentedButton<PlannedWorkoutStatus>(
                    segments: const [
                      ButtonSegment(
                          value: PlannedWorkoutStatus.planned,
                          label: Text('План')),
                      ButtonSegment(
                          value: PlannedWorkoutStatus.completed,
                          label: Text('Сделано')),
                      ButtonSegment(
                          value: PlannedWorkoutStatus.missed,
                          label: Text('Пропуск')),
                    ],
                    selected: {status},
                    onSelectionChanged: (s) =>
                        setState(() => status = s.first),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final label = labelCtrl.text.trim();
                            if (existing != null) {
                              await ref
                                  .read(plannedWorkoutsProvider.notifier)
                                  .update(existing.id, (p) => p.copyWith(
                                        status: status,
                                        label:
                                            label.isEmpty ? null : label,
                                      ));
                            } else {
                              await ref
                                  .read(plannedWorkoutsProvider.notifier)
                                  .add(PlannedWorkout(
                                    id: const Uuid().v4(),
                                    date: iso,
                                    status: status,
                                    label: label.isEmpty ? null : label,
                                  ));
                            }
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                          child: const Text('Сохранить'),
                        ),
                      ),
                      if (existing != null) ...[
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await ref
                                .read(plannedWorkoutsProvider.notifier)
                                .remove(existing.id);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                        ),
                      ],
                    ],
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

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.planned,
    required this.hasLog,
    required this.onTap,
  });
  final DateTime date;
  final PlannedWorkout planned;
  final bool hasLog;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPlanned = planned.id.isNotEmpty;
    Color? bg;
    if (isPlanned) {
      switch (planned.status) {
        case PlannedWorkoutStatus.completed:
          bg = Colors.green.withValues(alpha: 0.25);
          break;
        case PlannedWorkoutStatus.missed:
          bg = Colors.redAccent.withValues(alpha: 0.20);
          break;
        case PlannedWorkoutStatus.planned:
          bg = scheme.primary.withValues(alpha: 0.20);
          break;
      }
    } else if (hasLog) {
      bg = scheme.tertiary.withValues(alpha: 0.20);
    }
    final isToday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg ?? scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: scheme.primary, width: 2)
              : null,
        ),
        alignment: Alignment.center,
        child: Text('${date.day}',
            style: TextStyle(
                fontWeight:
                    isPlanned ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/* ───────────────────────────── Analytics ────────────────────────────── */

class _AnalyticsTab extends ConsumerWidget {
  const _AnalyticsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(exerciseLogsProvider);
    final nodes = ref.watch(workoutNodesProvider);
    final exercises = nodes
        .where((n) => n.type == WorkoutNodeType.exercise)
        .toList();
    if (logs.isEmpty) {
      return const _EmptyHint(
        emoji: '📈',
        title: 'Пока нет записей',
        subtitle: 'Запиши первый подход — графики появятся здесь.',
      );
    }
    // Frequency by day for the last 30 days
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 29));
    final isoStart = DateFormat('y-MM-dd').format(start);
    final last30 = logs.where((l) => l.date.compareTo(isoStart) >= 0).toList();
    final byDay = <String, int>{};
    for (final l in last30) {
      byDay[l.date] = (byDay[l.date] ?? 0) + 1;
    }
    final spots = <FlSpot>[];
    for (var i = 0; i < 30; i++) {
      final d =
          DateFormat('y-MM-dd').format(start.add(Duration(days: i)));
      spots.add(FlSpot(i.toDouble(), (byDay[d] ?? 0).toDouble()));
    }

    // Top 5 exercises by total log count
    final byExercise = <String, int>{};
    for (final l in logs) {
      byExercise[l.exerciseId] = (byExercise[l.exerciseId] ?? 0) + 1;
    }
    final top = byExercise.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = top.take(5).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Подходов в день — последние 30 дней',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: 0,
              titlesData: const FlTitlesData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.5),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  barWidth: 3,
                  color: Theme.of(context).colorScheme.primary,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.18),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Топ-5 упражнений',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final e in top5)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.trending_up),
            title: Text(exercises.cast<WorkoutNode?>().firstWhere(
                          (n) => n?.id == e.key,
                          orElse: () => null,
                        )?.name ??
                'Удалённое упражнение'),
            trailing: Text('${e.value} подх.',
                style: Theme.of(context).textTheme.bodyMedium),
          ),
      ],
    );
  }
}

/* ─────────────────────────────── Body ───────────────────────────────── */

class _BodyTab extends ConsumerWidget {
  const _BodyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = [...ref.watch(bodyMeasurementsProvider)]
      ..sort((a, b) => a.date.compareTo(b.date));
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (all.length >= 2) _weightChart(context, all),
            if (all.length >= 2) const SizedBox(height: 24),
            Text('История замеров',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (all.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                    'Замеров пока нет. Жми «+» чтобы добавить первый.'),
              )
            else
              for (final m in all.reversed)
                Dismissible(
                  key: ValueKey('m-${m.id}'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => ref
                      .read(bodyMeasurementsProvider.notifier)
                      .remove(m.id),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: Colors.redAccent,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                DateFormat('d MMM y', 'ru')
                                    .format(DateTime.parse(m.date)),
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.primary),
                              ),
                              const Spacer(),
                              if (m.weight != null)
                                Text('${m.weight} кг',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              if (m.height != null)
                                _kv('рост', '${m.height} см'),
                              if (m.neck != null)
                                _kv('шея', '${m.neck} см'),
                              for (final entry
                                  in (m.measurements ?? const {}).entries)
                                _kv(_measurementLabel(entry.key),
                                    '${entry.value} см'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'workouts_body_add',
            onPressed: () => _showMeasurementForm(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Замер'),
          ),
        ),
      ],
    );
  }

  Widget _weightChart(BuildContext context, List<BodyMeasurement> all) {
    final scheme = Theme.of(context).colorScheme;
    final pts = <FlSpot>[];
    final labels = <String>[];
    var idx = 0;
    for (final m in all) {
      if (m.weight == null) continue;
      pts.add(FlSpot(idx.toDouble(), m.weight!.toDouble()));
      labels.add(m.date.substring(5));
      idx++;
    }
    if (pts.length < 2) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Вес по дате замера',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: pts.map((e) => e.y).reduce((a, b) => a < b ? a : b) - 1,
              maxY: pts.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 1,
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (v, _) => Text(
                      v.toStringAsFixed(0),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(labels[i],
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: pts,
                  isCurved: true,
                  barWidth: 3,
                  color: scheme.primary,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: scheme.primary.withValues(alpha: 0.18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _kv(String k, String v) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$k: ',
            style: const TextStyle(
                color: Colors.grey, fontSize: 12),
          ),
          TextSpan(
            text: v,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

Future<void> _showMeasurementForm(
    BuildContext context, WidgetRef ref) async {
  final weight = TextEditingController();
  final height = TextEditingController();
  final neck = TextEditingController();
  final chest = TextEditingController();
  final waist = TextEditingController();
  final hips = TextEditingController();
  final biceps = TextEditingController();
  final thighs = TextEditingController();
  final calves = TextEditingController();
  String? gender;
  DateTime date = DateTime.now();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 4,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Новый замер',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(DateFormat('d MMM y', 'ru').format(date)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 365 * 5)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => date = picked);
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: weight,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Вес, кг'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: height,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Рост, см'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: neck,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Шея, см'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SegmentedButton<String?>(
                        segments: const [
                          ButtonSegment(value: 'male', label: Text('М')),
                          ButtonSegment(
                              value: 'female', label: Text('Ж')),
                        ],
                        selected: {gender},
                        emptySelectionAllowed: true,
                        onSelectionChanged: (s) => setState(
                            () => gender = s.isEmpty ? null : s.first),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: chest,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Грудь'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: waist,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Талия'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: hips,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Бёдра'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: biceps,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Бицепс'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: thighs,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Ляжки'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: calves,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Икры'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    num? parse(TextEditingController c) {
                      final s = c.text.trim().replaceAll(',', '.');
                      if (s.isEmpty) return null;
                      return num.tryParse(s);
                    }

                    final meas = <String, num>{};
                    final ch = parse(chest);
                    final wa = parse(waist);
                    final hi = parse(hips);
                    final bi = parse(biceps);
                    final th = parse(thighs);
                    final ca = parse(calves);
                    if (ch != null) meas['chest'] = ch;
                    if (wa != null) meas['waist'] = wa;
                    if (hi != null) meas['hips'] = hi;
                    if (bi != null) meas['biceps'] = bi;
                    if (th != null) meas['thighs'] = th;
                    if (ca != null) meas['calves'] = ca;
                    final entry = BodyMeasurement(
                      id: const Uuid().v4(),
                      date: DateFormat('y-MM-dd').format(date),
                      weight: parse(weight),
                      height: parse(height),
                      neck: parse(neck),
                      gender: gender,
                      measurements: meas.isEmpty ? null : meas,
                    );
                    await ref
                        .read(bodyMeasurementsProvider.notifier)
                        .add(entry);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/* ───────────────────────────── helpers ──────────────────────────────── */

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(
      {required this.emoji, required this.title, required this.subtitle});
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
            const SizedBox(height: 12),
            Text(title,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

String _muscleLabel(MuscleGroup g) => switch (g) {
      MuscleGroup.chest => 'Грудь',
      MuscleGroup.back => 'Спина',
      MuscleGroup.legs => 'Ноги',
      MuscleGroup.shoulders => 'Плечи',
      MuscleGroup.arms => 'Руки',
      MuscleGroup.core => 'Кор',
      MuscleGroup.cardio => 'Кардио',
    };

String _metricLabel(WorkoutMetric m) => switch (m) {
      WorkoutMetric.weight => 'Вес',
      WorkoutMetric.reps => 'Повторы',
      WorkoutMetric.distance => 'Дистанция',
      WorkoutMetric.time => 'Время',
      WorkoutMetric.speed => 'Скорость',
      WorkoutMetric.calories => 'Ккал',
    };

String _metricUnit(WorkoutMetric m) => switch (m) {
      WorkoutMetric.weight => 'кг',
      WorkoutMetric.reps => 'шт',
      WorkoutMetric.distance => 'км',
      WorkoutMetric.time => 'сек',
      WorkoutMetric.speed => 'км/ч',
      WorkoutMetric.calories => 'ккал',
    };

String _measurementLabel(String key) => switch (key) {
      'chest' => 'грудь',
      'waist' => 'талия',
      'hips' => 'бёдра',
      'biceps' => 'бицепс',
      'thighs' => 'ляжки',
      'calves' => 'икры',
      _ => key,
    };

/* ───────────────────────────── AI plan ─────────────────────────────── */

Future<void> _showAiPlanDialog(BuildContext context, WidgetRef ref) async {
  if (AiService.apiKey == null) {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Нужен GEMINI_API_KEY'),
        content: const Text(
            'Чтобы сгенерировать план тренировки, добавь ключ в Настройки → '
            'AI (Gemini).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Открыть Настройки')),
        ],
      ),
    );
    if (go == true && context.mounted) {
      // Settings is reachable via the bottom nav "Ещё" sheet. We don't have
      // a global push for it from here, so just hint and close.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Открой «Ещё» → Настройки и сохрани ключ.'),
      ));
    }
    return;
  }

  Set<MuscleGroup> targets = {MuscleGroup.legs};
  int duration = 60;
  String focus = 'general';
  String equipment = 'all';

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 4,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('AI-план тренировки',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text('Целевые группы',
                    style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final g in MuscleGroup.values)
                      FilterChip(
                        label: Text(_muscleLabel(g)),
                        selected: targets.contains(g),
                        onSelected: (v) => setState(() {
                          if (v) {
                            targets.add(g);
                          } else {
                            targets.remove(g);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: duration,
                        decoration: const InputDecoration(
                            labelText: 'Длительность'),
                        items: const [
                          DropdownMenuItem(value: 30, child: Text('30 мин')),
                          DropdownMenuItem(value: 45, child: Text('45 мин')),
                          DropdownMenuItem(value: 60, child: Text('60 мин')),
                          DropdownMenuItem(value: 90, child: Text('90 мин')),
                        ],
                        onChanged: (v) =>
                            setState(() => duration = v ?? 60),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: focus,
                        decoration:
                            const InputDecoration(labelText: 'Фокус'),
                        items: const [
                          DropdownMenuItem(
                              value: 'general', child: Text('Общий')),
                          DropdownMenuItem(
                              value: 'strength', child: Text('Сила')),
                          DropdownMenuItem(
                              value: 'hypertrophy',
                              child: Text('Гипертрофия')),
                          DropdownMenuItem(
                              value: 'endurance',
                              child: Text('Выносливость')),
                        ],
                        onChanged: (v) =>
                            setState(() => focus = v ?? 'general'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: equipment,
                  decoration:
                      const InputDecoration(labelText: 'Инвентарь'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Любой')),
                    DropdownMenuItem(
                        value: 'bodyweight', child: Text('Без снарядов')),
                    DropdownMenuItem(
                        value: 'dumbbells', child: Text('Гантели')),
                    DropdownMenuItem(
                        value: 'barbell',
                        child: Text('Штанга + гантели')),
                    DropdownMenuItem(
                        value: 'gym', child: Text('Тренажёрный зал')),
                  ],
                  onChanged: (v) =>
                      setState(() => equipment = v ?? 'all'),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  onPressed: targets.isEmpty
                      ? null
                      : () async {
                          Navigator.of(ctx).pop();
                          await _runAiPlan(
                            context,
                            ref,
                            targets: targets.toList(),
                            duration: duration,
                            focus: focus,
                            equipment: equipment,
                          );
                        },
                  label: const Text('Сгенерировать'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> _runAiPlan(
  BuildContext context,
  WidgetRef ref, {
  required List<MuscleGroup> targets,
  required int duration,
  required String focus,
  required String equipment,
}) async {
  final scaffold = ScaffoldMessenger.of(context);
  final progress = scaffold.showSnackBar(const SnackBar(
    content: Text('Запрашиваем план у Gemini…'),
    duration: Duration(seconds: 30),
  ));
  try {
    final logs =
        ref.read(exerciseLogsProvider).take(50).map((l) => l.toJson()).toList();
    final result = await AiService.generateWorkout(
      targetMuscleGroups: targets.map((g) => g.name).toList(),
      duration: duration,
      focus: focus,
      equipment: [equipment],
      pastLogs: logs,
    );
    progress.close();
    if (result == null) {
      scaffold.showSnackBar(const SnackBar(
          content: Text('Не удалось распарсить ответ Gemini.')));
      return;
    }
    final title = (result['title'] as String?) ?? 'AI-план';
    final exercises = (result['exercises'] as List?) ?? const [];
    if (exercises.isEmpty) {
      scaffold.showSnackBar(
          const SnackBar(content: Text('AI вернул пустой план.')));
      return;
    }
    final folderId = const Uuid().v4();
    await ref.read(workoutNodesProvider.notifier).add(WorkoutNode(
          id: folderId,
          parentId: null,
          name: '🤖 $title',
          type: WorkoutNodeType.folder,
          isTemplate: true,
        ));
    final primaryGroup = targets.first;
    for (final raw in exercises) {
      if (raw is! Map) continue;
      final name = (raw['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      final sets = (raw['sets'] as num?)?.toInt();
      final reps = (raw['reps'] as String?)?.trim();
      final notes = [
        if (sets != null) '$sets подх.',
        if (reps != null && reps.isNotEmpty) reps,
        if ((raw['notes'] as String?)?.isNotEmpty == true)
          raw['notes'] as String,
      ].join(' · ');
      await ref.read(workoutNodesProvider.notifier).add(WorkoutNode(
            id: const Uuid().v4(),
            parentId: folderId,
            name: name,
            type: WorkoutNodeType.exercise,
            metrics: const [WorkoutMetric.weight, WorkoutMetric.reps],
            muscleGroup: primaryGroup,
            notes: notes.isEmpty ? null : notes,
          ));
    }
    scaffold.showSnackBar(SnackBar(
      content: Text('Добавлен план «$title» (${exercises.length} упр.)'),
    ));
  } catch (e) {
    progress.close();
    scaffold.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
  }
}
