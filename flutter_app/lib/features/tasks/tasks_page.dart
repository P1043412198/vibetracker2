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
  });

  final TaskPeriod period;
  final String date;
  final List<TaskItem> tasks;

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
      return Center(
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
