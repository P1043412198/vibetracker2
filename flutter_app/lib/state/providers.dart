import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/finance.dart';
import '../models/financial_plan_month.dart';
import '../models/goal.dart';
import '../models/habit.dart';
import '../models/misc.dart';
import '../models/savings_goal.dart';
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

class RegularPaymentsController extends JsonListController<RegularPayment> {
  RegularPaymentsController()
      : super(
          storageKey: 'regularPayments',
          fromJson: RegularPayment.fromJson,
          toJson: (p) => p.toJson(),
        );

  @override
  String idOf(RegularPayment item) => item.id;
}

final regularPaymentsProvider =
    StateNotifierProvider<RegularPaymentsController, List<RegularPayment>>(
        (ref) => RegularPaymentsController());

class RecurringSkipsController extends JsonListController<RecurringSkip> {
  RecurringSkipsController()
      : super(
          storageKey: 'recurringSkips',
          fromJson: RecurringSkip.fromJson,
          toJson: (s) => s.toJson(),
        );

  @override
  String idOf(RecurringSkip item) => item.id;
}

final recurringSkipsProvider =
    StateNotifierProvider<RecurringSkipsController, List<RecurringSkip>>(
        (ref) => RecurringSkipsController());

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

class FinancialPlanMonthsController
    extends JsonListController<FinancialPlanMonth> {
  FinancialPlanMonthsController()
      : super(
          storageKey: 'financialPlanMonths',
          fromJson: FinancialPlanMonth.fromJson,
          toJson: (p) => p.toJson(),
        );

  @override
  String idOf(FinancialPlanMonth item) => item.id;
}

final financialPlanMonthsProvider = StateNotifierProvider<
    FinancialPlanMonthsController, List<FinancialPlanMonth>>(
  (ref) => FinancialPlanMonthsController(),
);

class SavingsGoalsController extends JsonListController<SavingsGoal> {
  SavingsGoalsController()
      : super(
          storageKey: 'savingsGoals',
          fromJson: SavingsGoal.fromJson,
          toJson: (g) => g.toJson(),
        );

  @override
  String idOf(SavingsGoal item) => item.id;
}

final savingsGoalsProvider =
    StateNotifierProvider<SavingsGoalsController, List<SavingsGoal>>(
        (ref) => SavingsGoalsController());

class LoansController extends JsonListController<Loan> {
  LoansController()
      : super(
          storageKey: 'loans',
          fromJson: Loan.fromJson,
          toJson: (l) => l.toJson(),
        );

  @override
  String idOf(Loan item) => item.id;
}

final loansProvider =
    StateNotifierProvider<LoansController, List<Loan>>((ref) {
  return LoansController();
});

class LoanPaymentsController extends JsonListController<LoanPayment> {
  LoanPaymentsController()
      : super(
          storageKey: 'loanPayments',
          fromJson: LoanPayment.fromJson,
          toJson: (p) => p.toJson(),
        );

  @override
  String idOf(LoanPayment item) => item.id;
}

final loanPaymentsProvider =
    StateNotifierProvider<LoanPaymentsController, List<LoanPayment>>((ref) {
  return LoanPaymentsController();
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

class HouseholdNotesController extends JsonListController<HouseholdNote> {
  HouseholdNotesController()
      : super(
          storageKey: 'householdNotes',
          fromJson: HouseholdNote.fromJson,
          toJson: (n) => n.toJson(),
        );

  @override
  String idOf(HouseholdNote item) => item.id;
}

final householdNotesProvider =
    StateNotifierProvider<HouseholdNotesController, List<HouseholdNote>>(
        (ref) => HouseholdNotesController());

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

class WorkoutSessionsController extends JsonListController<WorkoutSession> {
  WorkoutSessionsController()
      : super(
          storageKey: 'workoutSessions',
          fromJson: WorkoutSession.fromJson,
          toJson: (s) => s.toJson(),
        );

  @override
  String idOf(WorkoutSession item) => item.id;
}

final workoutSessionsProvider = StateNotifierProvider<
    WorkoutSessionsController, List<WorkoutSession>>((ref) {
  return WorkoutSessionsController();
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

class RunSessionsController extends JsonListController<RunSession> {
  RunSessionsController()
      : super(
          storageKey: 'runSessions',
          fromJson: RunSession.fromJson,
          toJson: (r) => r.toJson(),
        );

  @override
  String idOf(RunSession item) => item.id;
}

final runSessionsProvider =
    StateNotifierProvider<RunSessionsController, List<RunSession>>((ref) {
  return RunSessionsController();
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

class ShoppingCategoriesController
    extends JsonListController<ShoppingCategory> {
  ShoppingCategoriesController()
      : super(
          storageKey: 'shoppingCategories',
          fromJson: ShoppingCategory.fromJson,
          toJson: (c) => c.toJson(),
        );

  @override
  String idOf(ShoppingCategory item) => item.id;
}

final shoppingCategoriesProvider = StateNotifierProvider<
    ShoppingCategoriesController, List<ShoppingCategory>>((ref) {
  return ShoppingCategoriesController();
});

class PriceHistoryController extends JsonListController<PriceHistoryEntry> {
  PriceHistoryController()
      : super(
          storageKey: 'priceHistory',
          fromJson: PriceHistoryEntry.fromJson,
          toJson: (p) => p.toJson(),
        );

  @override
  String idOf(PriceHistoryEntry item) => item.id;
}

final priceHistoryProvider =
    StateNotifierProvider<PriceHistoryController, List<PriceHistoryEntry>>(
        (ref) {
  return PriceHistoryController();
});

class WorkScheduleController extends StateNotifier<WorkScheduleData?> {
  WorkScheduleController() : super(null) {
    _load();
  }

  static const _key = 'workSchedule';

  void _load() {
    final map = AppStorage.readMap(_key);
    if (map != null) state = WorkScheduleData.fromJson(map);
  }

  Future<void> _persist() async {
    if (state != null) {
      await AppStorage.writeMap(_key, state!.toJson());
    }
  }

  Future<void> save(WorkScheduleData data) async {
    state = data;
    await _persist();
  }

  Future<void> addVacation(Vacation v) async {
    if (state == null) return;
    state = state!.copyWith(vacations: [...state!.vacations, v]);
    await _persist();
  }

  Future<void> deleteVacation(String id) async {
    if (state == null) return;
    state = state!.copyWith(
      vacations: state!.vacations.where((v) => v.id != id).toList(),
    );
    await _persist();
  }
}

final workScheduleProvider =
    StateNotifierProvider<WorkScheduleController, WorkScheduleData?>((ref) {
  return WorkScheduleController();
});

class ChallengesController extends JsonListController<Challenge> {
  ChallengesController()
      : super(
          storageKey: 'challenges',
          fromJson: Challenge.fromJson,
          toJson: (c) => c.toJson(),
        );

  @override
  String idOf(Challenge item) => item.id;
}

final challengesProvider =
    StateNotifierProvider<ChallengesController, List<Challenge>>(
        (ref) => ChallengesController());

class ChallengeCheckInsController
    extends JsonListController<ChallengeCheckIn> {
  ChallengeCheckInsController()
      : super(
          storageKey: 'challengeCheckIns',
          fromJson: ChallengeCheckIn.fromJson,
          toJson: (c) => c.toJson(),
        );

  @override
  String idOf(ChallengeCheckIn item) => item.id;
}

final challengeCheckInsProvider = StateNotifierProvider<
    ChallengeCheckInsController, List<ChallengeCheckIn>>(
        (ref) => ChallengeCheckInsController());

class BodyPhotosController extends JsonListController<BodyPhoto> {
  BodyPhotosController()
      : super(
          storageKey: 'bodyPhotos',
          fromJson: BodyPhoto.fromJson,
          toJson: (p) => p.toJson(),
        );

  @override
  String idOf(BodyPhoto item) => item.id;
}

final bodyPhotosProvider =
    StateNotifierProvider<BodyPhotosController, List<BodyPhoto>>(
        (ref) => BodyPhotosController());
