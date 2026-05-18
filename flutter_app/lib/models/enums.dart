// Mirrors the string-literal enums from `src/types.ts` (React).
//
// We keep them as enhanced enums so they round-trip through JSON without
// adapters: `MyEnum.values.byName(json)` for read, `value.name` for write.
//
// Names use snake_case to match the TypeScript source string-literals 1:1
// — Dart's analyzer is lint-only here, so we silence the cosmetic warnings.

// ignore_for_file: constant_identifier_names

enum GoalType { goal, skill, book, learning }

enum GoalStatus { not_started, in_progress, completed }

enum GoalStepStatus { todo, in_progress, done }

enum TaskPeriod { day, week, month, year, history }

enum TaskPriority { urgent_important, important, urgent, later }

enum HabitTypeKind { good, bad }

enum HabitFrequencyType { daily, specific_days, times_per_week }

enum HabitLogStatus { done, failed, skipped }

enum WorkShiftType { day, night, off, post_night, vacation }

enum MuscleGroup { chest, back, legs, shoulders, arms, core, cardio }

enum WorkoutMetric { weight, reps, distance, time, speed, calories }

enum WorkoutNodeType { folder, exercise }

enum PlannedWorkoutStatus { planned, completed, missed }

enum AccountType { card, cash, deposit, crypto, installment, other }

enum TransactionType { income, expense, transfer }

enum PaymentMethod { card, cash }

enum LoanPaymentType { payment, withdrawal }

enum WaterVisualization { glass, bottle }

enum AppModule {
  spheres,
  tasks,
  habits,
  workouts,
  passwords,
  finance,
  goals,
  schedule,
  household,
  water,
  analytics,
  pomodoro,
  inbox,
  sleep,
}

enum DashboardWidgetKind {
  efficiency,
  trends,
  stats_grid,
  overview,
  spheres_hub,
  goals,
  tasks_habits,
  water,
  activity_trends,
  habit_stories,
  activity_calendar,
  finance_hub,
  monthly_budget,
  upcoming_deadlines,
  habit_matrix,
  pomodoro,
  inbox,
  next_workout,
  sleep_recovery,
  discipline_score,
  stoic_quote,
  shopping_list,
  smart_schedule,
}

T enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
