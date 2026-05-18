import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/task.dart';
import '../../services/notification_service.dart';
import '../../state/providers.dart';

/// Counterpart of `src/pages/Tasks.tsx`. Lists tasks grouped by period
/// (today / week / month / year) with Eisenhower-style priority chips,
/// subtasks, pinning and inline editing.
class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  static const _periods = [
    TaskPeriod.day,
    TaskPeriod.week,
    TaskPeriod.month,
    TaskPeriod.year,
  ];
  static const _labels = ['Сегодня', 'Неделя', 'Месяц', 'Год'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _periods.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _bucketKey(TaskPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case TaskPeriod.day:
        return DateFormat('yyyy-MM-dd').format(now);
      case TaskPeriod.week:
        final monday =
            now.subtract(Duration(days: (now.weekday - DateTime.monday) % 7));
        return DateFormat('yyyy-MM-dd').format(monday);
      case TaskPeriod.month:
        return DateFormat('yyyy-MM').format(now);
      case TaskPeriod.year:
        return DateFormat('yyyy').format(now);
      case TaskPeriod.history:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Задачи'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [for (final l in _labels) Tab(text: l)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final period in _periods)
            _TaskList(
              period: period,
              date: _bucketKey(period),
              tasks: tasks
                  .where((t) =>
                      t.period == period && t.date == _bucketKey(period))
                  .toList(),
              allTasks: tasks,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditTask(context),
        icon: const Icon(Icons.add),
        label: const Text('Задача'),
      ),
    );
  }

  Future<void> _addOrEditTask(BuildContext context, {TaskItem? edit}) async {
    final period = edit?.period ?? _periods[_tabController.index];
    final date = edit?.date ?? _bucketKey(period);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TaskFormSheet(
        period: period,
        date: date,
        existing: edit,
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({
    required this.period,
    required this.date,
    required this.tasks,
    required this.allTasks,
  });

  final TaskPeriod period;
  final String date;
  final List<TaskItem> tasks;

  /// All tasks across periods, used to drive 30-day completion / streak
  /// charts in [_TasksStatsCard] (Phase 18 visualisations).
  final List<TaskItem> allTasks;

  int _priorityOrder(TaskPriority? p) {
    switch (p) {
      case TaskPriority.urgent_important:
        return 0;
      case TaskPriority.important:
        return 1;
      case TaskPriority.urgent:
        return 2;
      case TaskPriority.later:
        return 3;
      case null:
        return 4;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) {
      // Phase 18: even with no tasks in the current bucket, show the global
      // last-30-days completion / streak charts so the page never feels
      // empty.
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          if (allTasks.isNotEmpty) ...[
            _TasksOverviewCard(allTasks: allTasks),
            const SizedBox(height: 12),
          ],
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🌿', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 16),
                  Text(
                    'Никаких задач в этом периоде',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Нажми «Задача» внизу, чтобы добавить'),
                ],
              ),
            ),
          ),
        ],
      );
    }
    final pending = tasks.where((t) => !t.completed).toList()
      ..sort((a, b) {
        final aPin = a.isPinned == true ? 0 : 1;
        final bPin = b.isPinned == true ? 0 : 1;
        if (aPin != bPin) return aPin - bPin;
        return _priorityOrder(a.priority) - _priorityOrder(b.priority);
      });
    final done = tasks.where((t) => t.completed).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        _TasksStatsCard(tasks: tasks),
        const SizedBox(height: 12),
        _TasksOverviewCard(allTasks: allTasks),
        const SizedBox(height: 12),
        if (pending.isNotEmpty) ...[
          Text('Активные (${pending.length})',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          for (final t in pending) _TaskTile(task: t),
        ],
        if (done.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Выполненные (${done.length})',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          for (final t in done) _TaskTile(task: t),
        ],
      ],
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task});
  final TaskItem task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hasSubtasks = (task.subtasks?.isNotEmpty ?? false);
    final doneSubtasks =
        task.subtasks?.where((s) => s.completed).length ?? 0;
    final totalSubtasks = task.subtasks?.length ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showTaskActions(context, ref, task),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: task.completed,
                    onChanged: (_) => ref
                        .read(tasksProvider.notifier)
                        .toggleCompleted(task.id),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (task.isPinned == true)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(Icons.push_pin,
                                    size: 14, color: scheme.primary),
                              ),
                            Flexible(
                              child: Text(
                                task.title,
                                style: TextStyle(
                                  decoration: task.completed
                                      ? TextDecoration.lineThrough
                                      : null,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (task.priority != null)
                              _PriorityBadge(priority: task.priority!),
                            if (hasSubtasks)
                              _MetaChip(
                                icon: Icons.checklist,
                                label: '$doneSubtasks/$totalSubtasks',
                              ),
                            if ((task.context ?? '').isNotEmpty)
                              _MetaChip(
                                icon: Icons.label_outline,
                                label: task.context!,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showTaskActions(context, ref, task),
                  ),
                ],
              ),
              if (hasSubtasks) _SubtaskList(task: task),
            ],
          ),
        ),
      ),
    );
  }

  void _showTaskActions(
      BuildContext context, WidgetRef ref, TaskItem task) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                    task.isPinned == true ? Icons.push_pin : Icons.push_pin_outlined),
                title: Text(task.isPinned == true
                    ? 'Открепить'
                    : 'Закрепить наверху'),
                onTap: () {
                  ref.read(tasksProvider.notifier).update(task.id,
                      (t) => t.copyWith(isPinned: !(t.isPinned ?? false)));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Приоритет'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickPriority(context, ref, task);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_task),
                title: const Text('Добавить подзадачу'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _addSubtask(context, ref, task);
                },
              ),
              ListTile(
                leading: const Icon(Icons.label_outline),
                title: const Text('Контекст / тег'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _editContext(context, ref, task);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Редактировать'),
                onTap: () async {
                  Navigator.pop(ctx);
                  // The state widget owns the form; emit a temporary route
                  // by re-opening the sheet here.
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => _TaskFormSheet(
                      period: task.period,
                      date: task.date,
                      existing: task,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Удалить'),
                onTap: () {
                  ref.read(tasksProvider.notifier).remove(task.id);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickPriority(
      BuildContext context, WidgetRef ref, TaskItem task) async {
    final selected = await showDialog<TaskPriority?>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('Приоритет'),
          children: [
            for (final p in TaskPriority.values)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, p),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _priorityColor(p),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(_priorityLabel(p)),
                  ],
                ),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('— Снять —'),
            ),
          ],
        );
      },
    );
    await ref.read(tasksProvider.notifier).update(
          task.id,
          (t) => selected == null
              ? t.copyWith(clearPriority: true)
              : t.copyWith(priority: selected),
        );
  }

  Future<void> _addSubtask(
      BuildContext context, WidgetRef ref, TaskItem task) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подзадача'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Название'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Добавить')),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    final next = [
      ...?task.subtasks,
      Subtask(id: const Uuid().v4(), title: result, completed: false),
    ];
    await ref
        .read(tasksProvider.notifier)
        .update(task.id, (t) => t.copyWith(subtasks: next));
  }

  Future<void> _editContext(
      BuildContext context, WidgetRef ref, TaskItem task) async {
    final controller = TextEditingController(text: task.context ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Контекст / тег'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'дом, работа, звонки...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Сохранить')),
        ],
      ),
    );
    if (result == null) return;
    await ref.read(tasksProvider.notifier).update(
          task.id,
          (t) => result.isEmpty
              ? t.copyWith(clearContext: true)
              : t.copyWith(context: result),
        );
  }
}

class _SubtaskList extends ConsumerWidget {
  const _SubtaskList({required this.task});
  final TaskItem task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(left: 36, right: 8, top: 4, bottom: 4),
      child: Column(
        children: [
          for (final s in task.subtasks ?? <Subtask>[])
            Row(
              children: [
                Checkbox(
                  visualDensity: VisualDensity.compact,
                  value: s.completed,
                  onChanged: (_) {
                    final next = task.subtasks!
                        .map((x) => x.id == s.id
                            ? Subtask(
                                id: x.id,
                                title: x.title,
                                completed: !x.completed,
                              )
                            : x)
                        .toList();
                    ref.read(tasksProvider.notifier).update(
                        task.id, (t) => t.copyWith(subtasks: next));
                  },
                ),
                Expanded(
                  child: Text(
                    s.title,
                    style: TextStyle(
                      fontSize: 13,
                      decoration:
                          s.completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    final next = task.subtasks!
                        .where((x) => x.id != s.id)
                        .toList();
                    ref.read(tasksProvider.notifier).update(
                        task.id, (t) => t.copyWith(subtasks: next));
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});
  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _priorityLabel(priority),
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label,
              style:
                  TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

Color _priorityColor(TaskPriority p) {
  switch (p) {
    case TaskPriority.urgent_important:
      return const Color(0xFFE11D48);
    case TaskPriority.important:
      return const Color(0xFF2563EB);
    case TaskPriority.urgent:
      return const Color(0xFFD97706);
    case TaskPriority.later:
      return const Color(0xFF6B7280);
  }
}

String _priorityLabel(TaskPriority p) {
  switch (p) {
    case TaskPriority.urgent_important:
      return 'Сделать сейчас';
    case TaskPriority.important:
      return 'Важно';
    case TaskPriority.urgent:
      return 'Срочно';
    case TaskPriority.later:
      return 'Потом';
  }
}

class _TaskFormSheet extends ConsumerStatefulWidget {
  const _TaskFormSheet({
    required this.period,
    required this.date,
    this.existing,
  });
  final TaskPeriod period;
  final String date;
  final TaskItem? existing;

  @override
  ConsumerState<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<_TaskFormSheet> {
  late final TextEditingController _title;
  late final TextEditingController _contextController;
  TaskPriority? _priority;
  bool _pinned = false;
  DateTime? _reminderAt;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _contextController =
        TextEditingController(text: widget.existing?.context ?? '');
    _priority = widget.existing?.priority;
    _pinned = widget.existing?.isPinned ?? false;
    final raw = widget.existing?.reminderAt;
    _reminderAt = (raw == null || raw.isEmpty) ? null : DateTime.tryParse(raw);
  }

  @override
  void dispose() {
    _title.dispose();
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    if (widget.existing == null) {
      final task = TaskItem(
        id: const Uuid().v4(),
        title: title,
        period: widget.period,
        date: widget.date,
        completed: false,
        failed: false,
        priority: _priority,
        isPinned: _pinned ? true : null,
        context: _contextController.text.trim().isEmpty
            ? null
            : _contextController.text.trim(),
        reminderAt: _reminderAt?.toIso8601String(),
        createdAt: DateTime.now().toIso8601String(),
      );
      await ref.read(tasksProvider.notifier).add(task);
    } else {
      final ctxText = _contextController.text.trim();
      await ref.read(tasksProvider.notifier).update(
            widget.existing!.id,
            (t) => t.copyWith(
              title: title,
              priority: _priority,
              clearPriority: _priority == null,
              isPinned: _pinned,
              context: ctxText.isEmpty ? null : ctxText,
              clearContext: ctxText.isEmpty,
              reminderAt: _reminderAt?.toIso8601String(),
              clearReminder: _reminderAt == null,
            ),
          );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? 'Новая задача' : 'Изменить задачу',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Что сделать?'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contextController,
            decoration: const InputDecoration(
                labelText: 'Контекст / тег (опционально)',
                hintText: 'дом, работа, звонки...'),
          ),
          const SizedBox(height: 12),
          Text('Приоритет', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final p in TaskPriority.values)
                ChoiceChip(
                  label: Text(_priorityLabel(p)),
                  selected: _priority == p,
                  onSelected: (v) =>
                      setState(() => _priority = v ? p : null),
                  selectedColor:
                      _priorityColor(p).withValues(alpha: 0.18),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Закрепить наверху'),
            value: _pinned,
            onChanged: (v) => setState(() => _pinned = v),
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(_reminderAt == null
                ? 'Напомнить (не выбрано)'
                : 'Напомнить: '
                    '${DateFormat("d MMM, HH:mm", 'ru').format(_reminderAt!)}'),
            trailing: _reminderAt == null
                ? const Icon(Icons.add)
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _reminderAt = null),
                  ),
            onTap: () async {
              final granted = await NotificationService.instance
                  .requestPermissions();
              if (!context.mounted) return;
              if (!granted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Разреши уведомления в настройках Android')),
                );
                return;
              }
              final base = _reminderAt ?? DateTime.now();
              final date = await showDatePicker(
                context: context,
                initialDate: base,
                firstDate: DateTime.now()
                    .subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date == null) return;
              if (!context.mounted) return;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(base),
              );
              if (time == null) return;
              setState(() => _reminderAt = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute));
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _save,
            child: Text(widget.existing == null ? 'Добавить' : 'Сохранить'),
          ),
        ],
      ),
    );
  }
}

class _TasksStatsCard extends StatelessWidget {
  const _TasksStatsCard({required this.tasks});
  final List<TaskItem> tasks;

  @override
  Widget build(BuildContext context) {
    final total = tasks.length;
    final done = tasks.where((t) => t.completed).length;
    final pending = total - done;
    final percent = total == 0 ? 0 : (done * 100 / total).round();
    final byPriority = <TaskPriority, int>{};
    for (final t in tasks) {
      if (t.priority == null) continue;
      byPriority[t.priority!] = (byPriority[t.priority!] ?? 0) + 1;
    }

    // Eisenhower 2x2: count each task in one of four quadrants.
    final eisenhower = <TaskPriority, int>{
      TaskPriority.urgent_important: 0,
      TaskPriority.important: 0,
      TaskPriority.urgent: 0,
      TaskPriority.later: 0,
    };
    for (final t in tasks) {
      final p = t.priority;
      if (p != null) eisenhower[p] = (eisenhower[p] ?? 0) + 1;
    }
    // Subtask aggregate progress (everything that's not done).
    var subDone = 0;
    var subTotal = 0;
    for (final t in tasks) {
      final s = t.subtasks;
      if (s == null) continue;
      subTotal += s.length;
      subDone += s.where((x) => x.completed).length;
    }

    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.donut_small, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Прогресс периода',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text('$done / $total',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            // Hero row: animated donut on the left, big percentage on the
            // right with a stack of mini stats (done / pending / subtasks).
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: _TaskDonut(
                    done: done,
                    pending: pending,
                    percent: percent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatRow(
                        color: const Color(0xFF22C55E),
                        label: 'Выполнено',
                        value: '$done',
                      ),
                      const SizedBox(height: 6),
                      _StatRow(
                        color: scheme.outlineVariant,
                        label: 'Осталось',
                        value: '$pending',
                      ),
                      if (subTotal > 0) ...[
                        const SizedBox(height: 6),
                        _StatRow(
                          color: const Color(0xFF8B5CF6),
                          label: 'Подзадачи',
                          value: '$subDone / $subTotal',
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                color: const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(height: 6),
            Text('$percent% выполнено',
                style: Theme.of(context).textTheme.bodySmall),
            if (byPriority.isNotEmpty) ...[
              const SizedBox(height: 12),
              // Eisenhower 2x2 matrix infographic.
              _EisenhowerMatrix(counts: eisenhower),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final entry in byPriority.entries)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: _priorityColor(entry.key)
                          .withValues(alpha: 0.15),
                      side: BorderSide(color: _priorityColor(entry.key)),
                      label: Text(
                          '${_priorityLabel(entry.key)} · ${entry.value}',
                          style: TextStyle(
                              color: _priorityColor(entry.key),
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _priorityColor(TaskPriority p) => switch (p) {
        TaskPriority.urgent_important => const Color(0xFFEF4444),
        TaskPriority.important => const Color(0xFFF59E0B),
        TaskPriority.urgent => const Color(0xFF3B82F6),
        TaskPriority.later => const Color(0xFF6B7280),
      };
  String _priorityLabel(TaskPriority p) => switch (p) {
        TaskPriority.urgent_important => 'Срочно+важно',
        TaskPriority.important => 'Важно',
        TaskPriority.urgent => 'Срочно',
        TaskPriority.later => 'Потом',
      };
}

/// Phase 18: cross-bucket productivity overview shown at the top of every
/// period tab. Renders three things:
///   * a 30-day "completed daily-tasks" bar chart so you can see ramps and
///     dry spells at a glance;
///   * a current and best streak counter for consecutive days with at
///     least one completed task;
///   * a 4×N donut breaking down completion rate by [TaskPeriod].
class _TasksOverviewCard extends StatelessWidget {
  const _TasksOverviewCard({required this.allTasks});

  final List<TaskItem> allTasks;

  @override
  Widget build(BuildContext context) {
    if (allTasks.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();

    // ---- 30-day daily completion ----
    final dayCounts = List<int>.filled(30, 0);
    final dayTotals = List<int>.filled(30, 0);
    for (final t in allTasks) {
      if (t.period != TaskPeriod.day) continue;
      final d = DateTime.tryParse(t.date);
      if (d == null) continue;
      final delta = today.difference(DateTime(d.year, d.month, d.day)).inDays;
      if (delta < 0 || delta >= 30) continue;
      final idx = 29 - delta;
      dayTotals[idx] += 1;
      if (t.completed) dayCounts[idx] += 1;
    }
    final maxCount =
        dayCounts.fold<int>(0, (a, b) => math.max(a, b)).toDouble();
    final yMax = (maxCount == 0 ? 4 : maxCount * 1.25).toDouble();

    // ---- streaks ----
    int current = 0;
    int best = 0;
    int run = 0;
    for (var i = 0; i < dayCounts.length; i++) {
      if (dayCounts[i] > 0) {
        run += 1;
        best = math.max(best, run);
      } else {
        run = 0;
      }
    }
    // current = longest tail of consecutive non-zero counts ending today.
    for (var i = dayCounts.length - 1; i >= 0; i--) {
      if (dayCounts[i] > 0) {
        current += 1;
      } else {
        break;
      }
    }

    // ---- per-period completion (Day / Week / Month / Year) ----
    final perPeriod = <TaskPeriod, _TaskCounts>{};
    for (final p in [
      TaskPeriod.day,
      TaskPeriod.week,
      TaskPeriod.month,
      TaskPeriod.year,
    ]) {
      perPeriod[p] = _TaskCounts();
    }
    for (final t in allTasks) {
      final c = perPeriod[t.period];
      if (c == null) continue;
      c.total += 1;
      if (t.completed) c.done += 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.local_fire_department_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              Text('Продуктивность',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              _StreakBadge(label: 'Серия', value: current),
              const SizedBox(width: 8),
              _StreakBadge(label: 'Лучшая', value: best),
            ]),
            const SizedBox(height: 8),
            Text('Выполнено по дням (30 дн.)',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceBetween,
                  minY: 0,
                  maxY: yMax,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      strokeWidth: 0.5,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: math.max(1, (yMax / 3).ceilToDouble()),
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || v != v.roundToDouble()) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(i.toString(),
                                style: const TextStyle(fontSize: 9)),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= 30) {
                            return const SizedBox.shrink();
                          }
                          // Show only every 7th label to avoid overlap
                          if (i % 7 != 0 && i != 29) {
                            return const SizedBox.shrink();
                          }
                          final d = today.subtract(Duration(days: 29 - i));
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(DateFormat('d/MM').format(d),
                                style: const TextStyle(fontSize: 8)),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: [
                    for (var i = 0; i < dayCounts.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: dayCounts[i].toDouble(),
                            color: i == dayCounts.length - 1
                                ? scheme.tertiary
                                : scheme.primary,
                            width: 6,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(2)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Выполнение по периодам',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            for (final entry in perPeriod.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        switch (entry.key) {
                          TaskPeriod.day => 'День',
                          TaskPeriod.week => 'Неделя',
                          TaskPeriod.month => 'Месяц',
                          TaskPeriod.year => 'Год',
                          TaskPeriod.history => 'История',
                        },
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: entry.value.total == 0
                              ? 0
                              : entry.value.done / entry.value.total,
                          minHeight: 8,
                          backgroundColor: scheme.surfaceContainerHighest,
                          color: const Color(0xFF22C55E),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${entry.value.done}/${entry.value.total}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskCounts {
  int done = 0;
  int total = 0;
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9, color: Color(0xFFB45309))),
          Text(
            '$value',
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
          ),
        ],
      ),
    );
  }
}

/// Animated donut chart used inside [_TasksStatsCard]. The arc sweeps from
/// 0 → percent over 900 ms whenever the underlying values change, and the
/// center number ticks up in lockstep.
class _TaskDonut extends StatelessWidget {
  const _TaskDonut({
    required this.done,
    required this.pending,
    required this.percent,
  });

  final int done;
  final int pending;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = (done + pending) == 0 ? 0.0 : done / (done + pending);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return CustomPaint(
          painter: _DonutPainter(
            progress: value,
            track: scheme.surfaceContainerHighest,
            color: const Color(0xFF22C55E),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(value * 100).round()}%',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  'выполнено',
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.progress,
    required this.track,
    required this.color,
  });

  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 12.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - stroke / 2,
    );
    final trackPaint = Paint()
      ..color = track
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);
    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      progress.clamp(0.0, 1.0) * 2 * math.pi,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// Tiny labelled row used in the stats card next to the donut.
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Eisenhower 2×2 infographic. Each quadrant shows the count of tasks
/// matching the priority assigned to that cell, plus a coloured corner
/// stripe for quick visual scanning.
class _EisenhowerMatrix extends StatelessWidget {
  const _EisenhowerMatrix({required this.counts});

  final Map<TaskPriority, int> counts;

  @override
  Widget build(BuildContext context) {
    Widget cell(TaskPriority p, String title) {
      final c = counts[p] ?? 0;
      final color = _priorityColor(p);
      return Expanded(
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            border: Border.all(color: color.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$c',
                style: TextStyle(
                  fontSize: 22,
                  color: color,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Матрица приоритетов',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        IntrinsicHeight(
          child: Row(
            children: [
              cell(TaskPriority.urgent_important, 'Срочно + важно'),
              cell(TaskPriority.important, 'Важно'),
            ],
          ),
        ),
        IntrinsicHeight(
          child: Row(
            children: [
              cell(TaskPriority.urgent, 'Срочно'),
              cell(TaskPriority.later, 'Потом'),
            ],
          ),
        ),
      ],
    );
  }
}
