import '../models/enums.dart';
import '../models/goal.dart';

/// Compute a 0..1 progress value following precedence:
/// book (readPages/totalPages) → numeric (currentValue/targetValue)
/// → manual (progress) → steps (% completed).
double computeGoalProgress(Goal goal) {
  if (goal.type == GoalType.book && (goal.totalPages ?? 0) > 0) {
    return ((goal.readPages ?? 0) / goal.totalPages!).clamp(0.0, 1.0);
  }
  if ((goal.targetValue ?? 0) > 0) {
    return ((goal.currentValue ?? 0) / goal.targetValue!)
        .toDouble()
        .clamp(0.0, 1.0);
  }
  if (goal.progress != null) {
    return (goal.progress! / 100).clamp(0.0, 1.0).toDouble();
  }
  if (goal.steps.isNotEmpty) {
    final done = goal.steps.where((s) => s.completed).length;
    return done / goal.steps.length;
  }
  return 0.0;
}

/// Human-readable summary of what drives the progress, e.g. "3 / 5 шагов".
String progressLabel(Goal goal) {
  if (goal.type == GoalType.book && (goal.totalPages ?? 0) > 0) {
    return '${goal.readPages ?? 0} / ${goal.totalPages} стр.';
  }
  if ((goal.targetValue ?? 0) > 0) {
    return '${goal.currentValue ?? 0} / ${goal.targetValue}';
  }
  if (goal.steps.isNotEmpty) {
    final done = goal.steps.where((s) => s.completed).length;
    return '$done / ${goal.steps.length} шагов';
  }
  if (goal.progress != null) {
    return '${goal.progress!.round()}% вручную';
  }
  return '';
}
