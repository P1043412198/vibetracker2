import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/habit.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import 'providers.dart';

/// Bridge between the reactive state and the [NotificationService]: every
/// time a habit / task list changes, recompute the desired schedule for any
/// entity that has a reminder configured.
///
/// Idempotent: scheduling helpers cancel existing alarms by the entity ID
/// before re-scheduling, so triggering this listener too often is safe.
final reminderSyncProvider = Provider<void>((ref) {
  // Habits — daily reminders gated by reminderTime + reminderDays.
  ref.listen<List<Habit>>(habitsProvider, (prev, next) async {
    final svc = NotificationService.instance;
    final prevById = {for (final h in prev ?? const <Habit>[]) h.id: h};
    final nextIds = next.map((h) => h.id).toSet();

    // Reschedule changed reminders.
    for (final h in next) {
      final before = prevById[h.id];
      if (before != null && _habitReminderEqual(before, h)) continue;
      await _applyHabit(svc, h);
    }
    // Cancel for habits removed from the list.
    for (final old in prev ?? const <Habit>[]) {
      if (!nextIds.contains(old.id)) {
        await svc.cancelHabit(old.id);
      }
    }
  }, fireImmediately: true);

  // Tasks — one-shot reminderAt; cancel when a task completes or vanishes.
  ref.listen<List<TaskItem>>(tasksProvider, (prev, next) async {
    final svc = NotificationService.instance;
    final prevById = {for (final t in prev ?? const <TaskItem>[]) t.id: t};
    final nextIds = next.map((t) => t.id).toSet();

    for (final t in next) {
      final before = prevById[t.id];
      if (before != null && _taskReminderEqual(before, t)) continue;
      await _applyTask(svc, t);
    }
    for (final old in prev ?? const <TaskItem>[]) {
      if (!nextIds.contains(old.id)) {
        await svc.cancelTask(old.id);
      }
    }
  }, fireImmediately: true);
});

bool _habitReminderEqual(Habit a, Habit b) {
  if (a.title != b.title) return false;
  if (a.reminderTime != b.reminderTime) return false;
  final ad = a.reminderDays ?? const <int>[];
  final bd = b.reminderDays ?? const <int>[];
  if (ad.length != bd.length) return false;
  final s = ad.toSet();
  for (final d in bd) {
    if (!s.contains(d)) return false;
  }
  return true;
}

bool _taskReminderEqual(TaskItem a, TaskItem b) {
  return a.title == b.title &&
      a.reminderAt == b.reminderAt &&
      a.completed == b.completed;
}

Future<void> _applyHabit(NotificationService svc, Habit h) async {
  final time = h.reminderTime;
  final days = h.reminderDays ?? const <int>[];
  if (time == null || time.isEmpty || days.isEmpty) {
    await svc.cancelHabit(h.id);
    return;
  }
  final parts = time.split(':');
  if (parts.length != 2) {
    await svc.cancelHabit(h.id);
    return;
  }
  final hour = int.tryParse(parts[0]) ?? 9;
  final minute = int.tryParse(parts[1]) ?? 0;
  await svc.scheduleHabitDaily(
    habitId: h.id,
    habitTitle: h.title,
    hour: hour,
    minute: minute,
    weekdays: days.where((d) => d >= 1 && d <= 7).toSet(),
  );
}

Future<void> _applyTask(NotificationService svc, TaskItem t) async {
  if (t.completed || t.reminderAt == null || t.reminderAt!.isEmpty) {
    await svc.cancelTask(t.id);
    return;
  }
  final when = DateTime.tryParse(t.reminderAt!);
  if (when == null) return;
  await svc.scheduleTaskOnce(
    taskId: t.id,
    taskTitle: t.title,
    when: when,
  );
}
