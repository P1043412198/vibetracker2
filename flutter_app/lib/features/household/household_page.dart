import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/task.dart';
import '../../state/providers.dart';

const _categories = [
  _HCat('clean', 'Чистота', Icons.auto_awesome, Colors.blue),
  _HCat('repair', 'Ремонт', Icons.build, Colors.orange),
  _HCat('water', 'Вода', Icons.water_drop, Colors.cyan),
  _HCat('light', 'Свет', Icons.bolt, Colors.amber),
];

class _HCat {
  const _HCat(this.id, this.label, this.icon, this.color);
  final String id;
  final String label;
  final IconData icon;
  final MaterialColor color;
}

class HouseholdPage extends ConsumerStatefulWidget {
  const HouseholdPage({super.key});

  @override
  ConsumerState<HouseholdPage> createState() => _HouseholdPageState();
}

class _HouseholdPageState extends ConsumerState<HouseholdPage> {
  DateTime _selectedDate = DateTime.now();
  String? _addingCategory;
  final _titleCtrl = TextEditingController();

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final daily = tasks
        .where((t) =>
            (t.sphereId?.startsWith('household_') ?? false) &&
            t.date.startsWith(_dateStr))
        .toList();

    final cs = Theme.of(context).colorScheme;
    final dayFmt = DateFormat('EEEE', 'ru');
    final dateFmt = DateFormat('d MMMM yyyy', 'ru');

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.home_outlined, size: 22),
            SizedBox(width: 8),
            Text('Быт и Дом'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date nav
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _selectedDate =
                      _selectedDate.subtract(const Duration(days: 1))),
                ),
                Column(children: [
                  Text(dayFmt.format(_selectedDate),
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(dateFmt.format(_selectedDate),
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _selectedDate =
                      _selectedDate.add(const Duration(days: 1))),
                ),
              ],
            ),
          ),

          // Category buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _categories.map((cat) {
                final sel = _addingCategory == cat.id;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() =>
                          _addingCategory = sel ? null : cat.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: sel
                              ? cat.color.withAlpha(30)
                              : cs.surfaceContainerHighest.withAlpha(40),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color:
                                  sel ? cat.color : Colors.grey.withAlpha(30)),
                        ),
                        child: Column(
                          children: [
                            Icon(cat.icon, size: 22, color: cat.color),
                            const SizedBox(height: 4),
                            Text(cat.label,
                                style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Add form
          if (_addingCategory != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _titleCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Что нужно сделать?',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                      ),
                      onSubmitted: (_) => _addTask(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addTask,
                    icon: const Icon(Icons.add, size: 20),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Tasks list
          Expanded(
            child: daily.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.home_outlined,
                            size: 48, color: Colors.grey.withAlpha(60)),
                        const SizedBox(height: 8),
                        const Text('На этот день нет задач по дому',
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const Text('Выберите категорию выше, чтобы добавить',
                            style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: daily.length,
                    itemBuilder: (_, i) {
                      final task = daily[i];
                      final catId =
                          task.sphereId?.replaceFirst('household_', '') ?? '';
                      final cat = _categories.firstWhere(
                          (c) => c.id == catId,
                          orElse: () => _categories.first);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          leading: IconButton(
                            icon: Icon(
                              task.completed
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: task.completed
                                  ? cat.color
                                  : Colors.grey,
                            ),
                            onPressed: () => ref
                                .read(tasksProvider.notifier)
                                .toggleCompleted(task.id),
                          ),
                          title: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 14,
                              decoration: task.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.completed
                                  ? Colors.grey
                                  : null,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: cat.color.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(cat.icon,
                                    size: 14, color: cat.color),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red[300]),
                                onPressed: () => ref
                                    .read(tasksProvider.notifier)
                                    .remove(task.id),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _addTask() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _addingCategory == null) return;
    ref.read(tasksProvider.notifier).add(TaskItem(
          id: const Uuid().v4(),
          title: title,
          completed: false,
          failed: false,
          createdAt: DateTime.now().toIso8601String(),
          date: DateTime.parse(_dateStr).toIso8601String(),
          period: TaskPeriod.day,
          sphereId: 'household_$_addingCategory',
        ));
    _titleCtrl.clear();
    setState(() => _addingCategory = null);
  }
}
