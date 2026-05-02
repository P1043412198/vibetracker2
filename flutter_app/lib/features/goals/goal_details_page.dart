import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/goal.dart';
import '../../services/photo_storage.dart';
import '../../state/providers.dart';

/// Per-goal detail screen — header + type-specific progress block + steps
/// editor + photo notes + status switcher. Mirrors the editing surface of
/// `src/pages/Goals.tsx` minus the AI plan generator.
class GoalDetailsPage extends ConsumerWidget {
  const GoalDetailsPage({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final goal = goals.cast<Goal?>().firstWhere(
          (g) => g?.id == goalId,
          orElse: () => null,
        );
    if (goal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Цель')),
        body: const Center(child: Text('Цель не найдена')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(goal.title),
        actions: [
          IconButton(
            tooltip: goal.isPinned == true ? 'Открепить' : 'Закрепить',
            icon: Icon(goal.isPinned == true
                ? Icons.push_pin
                : Icons.push_pin_outlined),
            onPressed: () => ref.read(goalsProvider.notifier).update(
                goal.id,
                (g) => g.copyWith(isPinned: !(g.isPinned ?? false))),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editMeta(context, ref, goal),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await ref.read(goalsProvider.notifier).remove(goal.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _HeaderCard(goal: goal),
          const SizedBox(height: 16),
          _StatusCard(goal: goal),
          const SizedBox(height: 16),
          _ProgressCard(goal: goal),
          const SizedBox(height: 16),
          _StepsCard(goal: goal),
          const SizedBox(height: 16),
          _PhotosCard(goal: goal),
        ],
      ),
    );
  }

  Future<void> _editMeta(
      BuildContext context, WidgetRef ref, Goal goal) async {
    final title = TextEditingController(text: goal.title);
    final desc = TextEditingController(text: goal.description ?? '');
    final author = TextEditingController(text: goal.author ?? '');
    DateTime? deadline = goal.deadline != null
        ? DateTime.tryParse(goal.deadline!)
        : null;

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
                top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Изменить цель',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextField(
                      controller: title,
                      decoration:
                          const InputDecoration(labelText: 'Название')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: desc,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(labelText: 'Описание')),
                  if (goal.type == GoalType.book) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: author,
                      decoration: const InputDecoration(labelText: 'Автор'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(deadline == null
                        ? 'Дедлайн (не указан)'
                        : 'Дедлайн: ${DateFormat('d MMM y', 'ru').format(deadline!)}'),
                    trailing: deadline == null
                        ? const Icon(Icons.add)
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setState(() => deadline = null),
                          ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: deadline ?? DateTime.now(),
                        firstDate: DateTime.now()
                            .subtract(const Duration(days: 365)),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null) setState(() => deadline = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final t = title.text.trim();
                      if (t.isEmpty) return;
                      final descText = desc.text.trim();
                      final authorText = author.text.trim();
                      await ref.read(goalsProvider.notifier).update(
                            goal.id,
                            (g) => g.copyWith(
                              title: t,
                              description:
                                  descText.isEmpty ? null : descText,
                              clearDescription: descText.isEmpty,
                              author: authorText.isEmpty
                                  ? null
                                  : authorText,
                              deadline: deadline?.toIso8601String(),
                              clearDeadline: deadline == null,
                            ),
                          );
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
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.goal});
  final Goal goal;

  String _typeLabel(GoalType t) => switch (t) {
        GoalType.goal => 'Цель',
        GoalType.skill => 'Навык',
        GoalType.book => 'Книга',
        GoalType.learning => 'Обучение',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(goal.icon ?? '🎯',
                      style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_typeLabel(goal.type),
                          style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                      Text(goal.title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      if (goal.author != null && goal.author!.isNotEmpty)
                        Text('Автор: ${goal.author}',
                            style:
                                Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            if (goal.description != null && goal.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(goal.description!),
            ],
            if (goal.deadline != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.event, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'до ${DateFormat('d MMM y', 'ru').format(DateTime.parse(goal.deadline!))}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.goal});
  final Goal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Статус', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final s in GoalStatus.values)
                  ChoiceChip(
                    label: Text(_statusLabel(s)),
                    selected: goal.status == s,
                    onSelected: (v) {
                      if (!v) return;
                      ref.read(goalsProvider.notifier).update(
                          goal.id, (g) => g.copyWith(status: s));
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(GoalStatus s) => switch (s) {
        GoalStatus.completed => 'Готово',
        GoalStatus.in_progress => 'В работе',
        GoalStatus.not_started => 'Не начато',
      };
}

class _ProgressCard extends ConsumerStatefulWidget {
  const _ProgressCard({required this.goal});
  final Goal goal;

  @override
  ConsumerState<_ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends ConsumerState<_ProgressCard> {
  late final TextEditingController _totalPages;
  late final TextEditingController _readPages;
  late final TextEditingController _target;
  late final TextEditingController _current;
  double _manualPct = 0;

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    _totalPages =
        TextEditingController(text: (g.totalPages ?? '').toString());
    _readPages =
        TextEditingController(text: (g.readPages ?? '').toString());
    _target = TextEditingController(text: (g.targetValue ?? '').toString());
    _current =
        TextEditingController(text: (g.currentValue ?? '').toString());
    _manualPct = (g.progress ?? 0).toDouble().clamp(0, 100);
  }

  @override
  void didUpdateWidget(covariant _ProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goal != widget.goal) {
      final g = widget.goal;
      _totalPages.text = (g.totalPages ?? '').toString();
      _readPages.text = (g.readPages ?? '').toString();
      _target.text = (g.targetValue ?? '').toString();
      _current.text = (g.currentValue ?? '').toString();
      _manualPct = (g.progress ?? 0).toDouble().clamp(0, 100);
    }
  }

  @override
  void dispose() {
    _totalPages.dispose();
    _readPages.dispose();
    _target.dispose();
    _current.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Прогресс', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (goal.type == GoalType.book) _buildBook() else _buildNumeric(),
          ],
        ),
      ),
    );
  }

  Widget _buildBook() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _readPages,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Прочитано стр.'),
            onSubmitted: (_) => _saveBook(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _totalPages,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Всего стр.'),
            onSubmitted: (_) => _saveBook(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Сохранить',
          icon: const Icon(Icons.check_circle),
          onPressed: _saveBook,
        ),
      ],
    );
  }

  Widget _buildNumeric() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _current,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Текущее'),
                onSubmitted: (_) => _saveNumeric(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _target,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Цель'),
                onSubmitted: (_) => _saveNumeric(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Сохранить',
              icon: const Icon(Icons.check_circle),
              onPressed: _saveNumeric,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Или вручную: ${_manualPct.round()}%'),
        Slider(
          value: _manualPct,
          min: 0,
          max: 100,
          divisions: 20,
          label: '${_manualPct.round()}%',
          onChanged: (v) => setState(() => _manualPct = v),
          onChangeEnd: (v) => _saveManualProgress(v),
        ),
      ],
    );
  }

  void _saveBook() {
    final read = int.tryParse(_readPages.text.trim());
    final total = int.tryParse(_totalPages.text.trim());
    ref.read(goalsProvider.notifier).update(
          widget.goal.id,
          (g) => g.copyWith(readPages: read, totalPages: total),
        );
  }

  void _saveNumeric() {
    final cur = num.tryParse(_current.text.trim());
    final tgt = num.tryParse(_target.text.trim());
    ref.read(goalsProvider.notifier).update(
          widget.goal.id,
          (g) => g.copyWith(currentValue: cur, targetValue: tgt),
        );
  }

  void _saveManualProgress(double v) {
    ref.read(goalsProvider.notifier).update(
          widget.goal.id,
          (g) => g.copyWith(progress: v),
        );
  }
}

class _StepsCard extends ConsumerStatefulWidget {
  const _StepsCard({required this.goal});
  final Goal goal;

  @override
  ConsumerState<_StepsCard> createState() => _StepsCardState();
}

class _StepsCardState extends ConsumerState<_StepsCard> {
  final _newStep = TextEditingController();

  @override
  void dispose() {
    _newStep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Шаги',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (goal.steps.isNotEmpty)
                  Text(
                      '${goal.steps.where((s) => s.completed).length} / ${goal.steps.length}',
                      style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 8),
            if (goal.steps.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                    'Разбей цель на маленькие шаги — будет легче двигаться вперёд.'),
              ),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: true,
              onReorder: _onReorder,
              children: [
                for (var i = 0; i < goal.steps.length; i++)
                  _stepTile(context, i, goal.steps[i]),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newStep,
                    decoration: const InputDecoration(
                      labelText: 'Новый шаг',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addStep(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add),
                  onPressed: _addStep,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepTile(BuildContext context, int index, GoalStep step) {
    return Padding(
      key: ValueKey('step-${step.id}'),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Checkbox(
            value: step.completed,
            onChanged: (v) => _toggle(index, v ?? false),
          ),
          Expanded(
            child: Text(
              step.title,
              style: TextStyle(
                decoration:
                    step.completed ? TextDecoration.lineThrough : null,
                color: step.completed
                    ? Theme.of(context).disabledColor
                    : null,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => _delete(index),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.drag_handle, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _addStep() {
    final text = _newStep.text.trim();
    if (text.isEmpty) return;
    final step = GoalStep(
      id: const Uuid().v4(),
      title: text,
      completed: false,
    );
    ref.read(goalsProvider.notifier).update(
          widget.goal.id,
          (g) => g.copyWith(steps: [...g.steps, step]),
        );
    _newStep.clear();
  }

  void _toggle(int index, bool completed) {
    final steps = [...widget.goal.steps];
    final s = steps[index];
    steps[index] = GoalStep(
      id: s.id,
      title: s.title,
      completed: completed,
      status: s.status,
    );
    ref.read(goalsProvider.notifier).update(
          widget.goal.id,
          (g) => g.copyWith(steps: steps),
        );
  }

  void _delete(int index) {
    final steps = [...widget.goal.steps]..removeAt(index);
    ref.read(goalsProvider.notifier).update(
          widget.goal.id,
          (g) => g.copyWith(steps: steps),
        );
  }

  void _onReorder(int oldIndex, int newIndex) {
    final steps = [...widget.goal.steps];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = steps.removeAt(oldIndex);
    steps.insert(newIndex, item);
    ref.read(goalsProvider.notifier).update(
          widget.goal.id,
          (g) => g.copyWith(steps: steps),
        );
  }
}

class _PhotosCard extends ConsumerWidget {
  const _PhotosCard({required this.goal});
  final Goal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = goal.photoPaths ?? const <String>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Фото-заметки',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: 'Камера',
                  icon: const Icon(Icons.photo_camera_outlined),
                  onPressed: () => _add(ref, fromCamera: true),
                ),
                IconButton(
                  tooltip: 'Из галереи',
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  onPressed: () => _add(ref, fromCamera: false),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (photos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                    'Прикрепи скриншоты, фото книги, конспекты — всё, что помогает двигаться к цели.'),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: photos.length,
                itemBuilder: (context, i) =>
                    _PhotoTile(path: photos[i], goal: goal, index: i),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(WidgetRef ref, {required bool fromCamera}) async {
    final path = fromCamera
        ? await PhotoStorage.instance
            .captureAndStore(bucket: 'goal_photos', entityId: goal.id)
        : await PhotoStorage.instance
            .pickAndStore(bucket: 'goal_photos', entityId: goal.id);
    if (path == null) return;
    final next = [...?goal.photoPaths, path];
    await ref.read(goalsProvider.notifier).update(
          goal.id,
          (g) => g.copyWith(photoPaths: next),
        );
  }
}

class _PhotoTile extends ConsumerWidget {
  const _PhotoTile(
      {required this.path, required this.goal, required this.index});
  final String path;
  final Goal goal;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onLongPress: () => _confirmDelete(context, ref),
      onTap: () => _showFull(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined, size: 28),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить фото?'),
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
    final next = [...?goal.photoPaths]..removeAt(index);
    await PhotoStorage.instance.delete(path);
    await ref.read(goalsProvider.notifier).update(
          goal.id,
          (g) => g.copyWith(
            photoPaths: next.isEmpty ? null : next,
          ),
        );
  }

  void _showFull(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: InteractiveViewer(
            child: Image.file(File(path)),
          ),
        ),
      ),
    );
  }
}
