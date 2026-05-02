import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/task.dart';
import '../../state/providers.dart';

/// Counterpart of `src/pages/Tasks.tsx`. Lists tasks grouped by period
/// (today / week / month / year). Supports add and toggle-complete.
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
        onPressed: () => _addTask(context),
        icon: const Icon(Icons.add),
        label: const Text('Задача'),
      ),
    );
  }

  Future<void> _addTask(BuildContext context) async {
    final controller = TextEditingController();
    final period = _periods[_tabController.index];
    final date = _bucketKey(period);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Новая задача — ${_labels[_tabController.index]}',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Что сделать?'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final title = controller.text.trim();
                  if (title.isEmpty) return;
                  final task = TaskItem(
                    id: const Uuid().v4(),
                    title: title,
                    period: period,
                    date: date,
                    completed: false,
                    failed: false,
                    createdAt: DateTime.now().toIso8601String(),
                  );
                  await ref.read(tasksProvider.notifier).add(task);
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
                child: const Text('Добавить'),
              ),
            ],
          ),
        );
      },
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
    final pending = tasks.where((t) => !t.completed).toList();
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        value: task.completed,
        onChanged: (_) =>
            ref.read(tasksProvider.notifier).toggleCompleted(task.id),
        title: Text(
          task.title,
          style: TextStyle(
            decoration:
                task.completed ? TextDecoration.lineThrough : null,
          ),
        ),
        secondary: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => ref.read(tasksProvider.notifier).remove(task.id),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
