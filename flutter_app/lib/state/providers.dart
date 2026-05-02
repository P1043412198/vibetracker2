import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/finance.dart';
import '../models/goal.dart';
import '../models/habit.dart';
import '../models/misc.dart';
import '../models/sphere.dart';
import '../models/task.dart';
import '../services/storage.dart';
import 'json_list_controller.dart';

/// One controller per entity type. The storage keys mirror the React Zustand
/// store fields so the data shape is recognisable to future migrations.

class SpheresController extends JsonListController<Sphere> {
  SpheresController()
      : super(
          storageKey: 'spheres',
          fromJson: Sphere.fromJson,
          toJson: (s) => s.toJson(),
        );

  @override
  String idOf(Sphere item) => item.id;
}

final spheresProvider =
    StateNotifierProvider<SpheresController, List<Sphere>>((ref) {
  return SpheresController();
});

class TasksController extends JsonListController<TaskItem> {
  TasksController()
      : super(
          storageKey: 'tasks',
          fromJson: TaskItem.fromJson,
          toJson: (t) => t.toJson(),
        );

  @override
  String idOf(TaskItem item) => item.id;

  Future<void> toggleCompleted(String id) async {
    final next = state.map((t) {
      if (t.id != id) return t;
      return t.copyWith(completed: !t.completed);
    }).toList(growable: false);
    state = next;
    await replaceAll(next);
  }
}

final tasksProvider =
    StateNotifierProvider<TasksController, List<TaskItem>>((ref) {
  return TasksController();
});

class HabitsController extends JsonListController<Habit> {
  HabitsController()
      : super(
          storageKey: 'habits',
          fromJson: Habit.fromJson,
          toJson: (h) => h.toJson(),
        );

  @override
  String idOf(Habit item) => item.id;
}

final habitsProvider =
    StateNotifierProvider<HabitsController, List<Habit>>((ref) {
  return HabitsController();
});

class HabitLogsController extends JsonListController<HabitLog> {
  HabitLogsController()
      : super(
          storageKey: 'habitLogs',
          fromJson: HabitLog.fromJson,
          toJson: (h) => h.toJson(),
        );

  @override
  String idOf(HabitLog item) => item.id;
}

final habitLogsProvider =
    StateNotifierProvider<HabitLogsController, List<HabitLog>>((ref) {
  return HabitLogsController();
});

class GoalsController extends JsonListController<Goal> {
  GoalsController()
      : super(
          storageKey: 'goals',
          fromJson: Goal.fromJson,
          toJson: (g) => g.toJson(),
        );

  @override
  String idOf(Goal item) => item.id;
}

final goalsProvider =
    StateNotifierProvider<GoalsController, List<Goal>>((ref) {
  return GoalsController();
});

class TransactionsController extends JsonListController<Transaction> {
  TransactionsController()
      : super(
          storageKey: 'transactions',
          fromJson: Transaction.fromJson,
          toJson: (t) => t.toJson(),
        );

  @override
  String idOf(Transaction item) => item.id;
}

final transactionsProvider =
    StateNotifierProvider<TransactionsController, List<Transaction>>((ref) {
  return TransactionsController();
});

class AccountsController extends JsonListController<Account> {
  AccountsController()
      : super(
          storageKey: 'accounts',
          fromJson: Account.fromJson,
          toJson: (a) => a.toJson(),
        );

  @override
  String idOf(Account item) => item.id;
}

final accountsProvider =
    StateNotifierProvider<AccountsController, List<Account>>((ref) {
  return AccountsController();
});

class BudgetLimitsController extends JsonListController<BudgetLimit> {
  BudgetLimitsController()
      : super(
          storageKey: 'budgetLimits',
          fromJson: BudgetLimit.fromJson,
          toJson: (b) => b.toJson(),
        );

  @override
  String idOf(BudgetLimit item) => item.id;
}

final budgetLimitsProvider =
    StateNotifierProvider<BudgetLimitsController, List<BudgetLimit>>((ref) {
  return BudgetLimitsController();
});

class MonthlyBudgetPlansController extends JsonListController<MonthlyBudgetPlan> {
  MonthlyBudgetPlansController()
      : super(
          storageKey: 'monthlyBudgetPlans',
          fromJson: MonthlyBudgetPlan.fromJson,
          toJson: (p) => p.toJson(),
        );

  @override
  String idOf(MonthlyBudgetPlan item) => item.id;
}

final monthlyBudgetPlansProvider = StateNotifierProvider<
    MonthlyBudgetPlansController, List<MonthlyBudgetPlan>>((ref) {
  return MonthlyBudgetPlansController();
});

class WaterLogsController extends JsonListController<WaterLog> {
  WaterLogsController()
      : super(
          storageKey: 'waterLogs',
          fromJson: WaterLog.fromJson,
          toJson: (w) => w.toJson(),
        );

  @override
  String idOf(WaterLog item) => item.id;
}

final waterLogsProvider =
    StateNotifierProvider<WaterLogsController, List<WaterLog>>((ref) {
  return WaterLogsController();
});

class InboxController extends JsonListController<InboxItem> {
  InboxController()
      : super(
          storageKey: 'inboxItems',
          fromJson: InboxItem.fromJson,
          toJson: (i) => i.toJson(),
        );

  @override
  String idOf(InboxItem item) => item.id;
}

final inboxProvider =
    StateNotifierProvider<InboxController, List<InboxItem>>((ref) {
  return InboxController();
});

class SleepLogsController extends JsonListController<SleepLog> {
  SleepLogsController()
      : super(
          storageKey: 'sleepLogs',
          fromJson: SleepLog.fromJson,
          toJson: (s) => s.toJson(),
        );

  @override
  String idOf(SleepLog item) => item.id;
}

final sleepLogsProvider =
    StateNotifierProvider<SleepLogsController, List<SleepLog>>((ref) {
  return SleepLogsController();
});

class ShoppingListController extends JsonListController<ShoppingItem> {
  ShoppingListController()
      : super(
          storageKey: 'shoppingItems',
          fromJson: ShoppingItem.fromJson,
          toJson: (s) => s.toJson(),
        );

  @override
  String idOf(ShoppingItem item) => item.id;
}

final shoppingListProvider =
    StateNotifierProvider<ShoppingListController, List<ShoppingItem>>((ref) {
  return ShoppingListController();
});

class PasswordsController extends JsonListController<PasswordEntry> {
  PasswordsController()
      : super(
          storageKey: 'passwords',
          fromJson: PasswordEntry.fromJson,
          toJson: (p) => p.toJson(),
        );

  @override
  String idOf(PasswordEntry item) => item.id;
}

final passwordsProvider =
    StateNotifierProvider<PasswordsController, List<PasswordEntry>>((ref) {
  return PasswordsController();
});

class WorkoutNodesController extends JsonListController<WorkoutNode> {
  WorkoutNodesController()
      : super(
          storageKey: 'workoutNodes',
          fromJson: WorkoutNode.fromJson,
          toJson: (w) => w.toJson(),
        );

  @override
  String idOf(WorkoutNode item) => item.id;
}

final workoutNodesProvider =
    StateNotifierProvider<WorkoutNodesController, List<WorkoutNode>>((ref) {
  return WorkoutNodesController();
});

class ExerciseLogsController extends JsonListController<ExerciseLog> {
  ExerciseLogsController()
      : super(
          storageKey: 'exerciseLogs',
          fromJson: ExerciseLog.fromJson,
          toJson: (l) => l.toJson(),
        );

  @override
  String idOf(ExerciseLog item) => item.id;
}

final exerciseLogsProvider =
    StateNotifierProvider<ExerciseLogsController, List<ExerciseLog>>((ref) {
  return ExerciseLogsController();
});

class BodyMeasurementsController extends JsonListController<BodyMeasurement> {
  BodyMeasurementsController()
      : super(
          storageKey: 'bodyMeasurements',
          fromJson: BodyMeasurement.fromJson,
          toJson: (m) => m.toJson(),
        );

  @override
  String idOf(BodyMeasurement item) => item.id;
}

final bodyMeasurementsProvider = StateNotifierProvider<
    BodyMeasurementsController, List<BodyMeasurement>>((ref) {
  return BodyMeasurementsController();
});

class PlannedWorkoutsController extends JsonListController<PlannedWorkout> {
  PlannedWorkoutsController()
      : super(
          storageKey: 'plannedWorkouts',
          fromJson: PlannedWorkout.fromJson,
          toJson: (p) => p.toJson(),
        );

  @override
  String idOf(PlannedWorkout item) => item.id;
}

final plannedWorkoutsProvider = StateNotifierProvider<
    PlannedWorkoutsController, List<PlannedWorkout>>((ref) {
  return PlannedWorkoutsController();
});

/// Pomodoro state — persisted as a single JSON map (not a list).
class PomodoroController extends StateNotifier<PomodoroState> {
  PomodoroController()
      : super(PomodoroState(timeLeft: 25 * 60, totalTime: 25 * 60)) {
    _load();
  }

  static const _key = 'pomodoro';

  void _load() {
    final map = AppStorage.readMap(_key);
    if (map != null) {
      final loaded = PomodoroState.fromJson(map);
      state = loaded.copyWith(isRunning: false);
    }
  }

  Future<void> _persist() async {
    await AppStorage.writeMap(_key, state.toJson());
  }

  void tick() {
    if (!state.isRunning || state.timeLeft <= 0) return;
    final newTime = state.timeLeft - 1;
    if (newTime <= 0) {
      state = state.copyWith(
        timeLeft: 0,
        isRunning: false,
        sessionsCompleted: state.type == 'work'
            ? state.sessionsCompleted + 1
            : state.sessionsCompleted,
      );
    } else {
      state = state.copyWith(timeLeft: newTime);
    }
    _persist();
  }

  void toggleRunning() {
    state = state.copyWith(isRunning: !state.isRunning);
    _persist();
  }

  void startType(String type) {
    final settings = state.settings;
    int time;
    switch (type) {
      case 'shortBreak':
        time = settings.shortBreakTime * 60;
        break;
      case 'longBreak':
        time = settings.longBreakTime * 60;
        break;
      default:
        time = settings.workTime * 60;
    }
    state = state.copyWith(
      type: type,
      timeLeft: time,
      totalTime: time,
      isRunning: false,
    );
    _persist();
  }

  void reset() {
    final settings = state.settings;
    int time;
    switch (state.type) {
      case 'shortBreak':
        time = settings.shortBreakTime * 60;
        break;
      case 'longBreak':
        time = settings.longBreakTime * 60;
        break;
      default:
        time = settings.workTime * 60;
    }
    state = state.copyWith(
      timeLeft: time,
      totalTime: time,
      isRunning: false,
    );
    _persist();
  }

  Future<void> updateSettings(PomodoroSettings settings) async {
    state = state.copyWith(settings: settings);
    await _persist();
  }
}

final pomodoroProvider =
    StateNotifierProvider<PomodoroController, PomodoroState>((ref) {
  return PomodoroController();
});
