export type GoalType = 'goal' | 'skill' | 'book' | 'learning';
export type GoalStatus = 'not_started' | 'in_progress' | 'completed';

export type GoalStepStatus = 'todo' | 'in_progress' | 'done';

export type GoalStep = {
  id: string;
  title: string;
  completed: boolean;
  status?: GoalStepStatus;
};

export type Goal = {
  id: string;
  title: string;
  description?: string;
  type: GoalType;
  status: GoalStatus;
  steps: GoalStep[];
  createdAt: string;
  deadline?: string;
  coverUrl?: string;
  icon?: string; // Emoji or icon name
  author?: string; // For books
  totalPages?: number; // For books
  readPages?: number; // For books
  progressHistory?: { id: string; date: string; value: number; note?: string }[]; // For tracking book reading history
  targetValue?: number; // For general numeric goals
  currentValue?: number; // For general numeric goals
  progress?: number; // Manual progress 0-100 if no steps
  showOnDashboard?: boolean;
  isPinned?: boolean;
};

export type NotificationSettings = {
  tasks: boolean;
  habits: boolean;
  payments: boolean;
};

/**
 * Произвольное удержание из зарплаты, сохраняемое как пресет пользователя.
 * Используется в калькуляторе «Зарплата на руки».
 */
export type SalaryDeductionPreset = {
  id: string;
  label: string;
  kind: 'percent' | 'fixed';
  /** Процент 0..100 либо фиксированная сумма в BYN. */
  value: number;
  /** Уменьшает ли налогооблагаемую базу. */
  taxable?: boolean;
  /** Активно ли (по умолчанию учитывается в расчёте). */
  enabled: boolean;
};

export type NoteComment = {
  id: string;
  content: string;
  createdAt: string;
};

export type SphereNote = {
  id: string;
  title?: string;
  content: string;
  updatedAt?: string;
  youtubeUrl?: string;
  photoUrl?: string;
  isCheckbox?: boolean;
  isChecked?: boolean;
  createdAt: string;
  comments?: NoteComment[];
  isPinned?: boolean;
};

export type Sphere = {
  id: string;
  title: string;
  description?: string;
  deadline?: string; // ISO date string
  notes: string;
  notesList?: SphereNote[];
  createdAt: string;
  color?: string; // Hex color
  icon?: string; // Emoji or icon name
  isPinned?: boolean;
  order?: number;
};

export type TaskPeriod = 'day' | 'week' | 'month' | 'year' | 'history';

export type Subtask = {
  id: string;
  title: string;
  completed: boolean;
};

export type TaskPriority = 'urgent_important' | 'important' | 'urgent' | 'later';

export type Task = {
  id: string;
  title: string;
  sphereId?: string;
  period: TaskPeriod;
  date: string; // ISO date string for the specific period it belongs to
  completed: boolean;
  failed: boolean;
  createdAt: string;
  subtasks?: Subtask[];
  order?: number;
  isPinned?: boolean;
  /** Eisenhower-квадрант: urgent_important = «Срочно+Важно», important = «Важно, не срочно»,
   *  urgent = «Срочно, не важно», later = «Не срочно, не важно». */
  priority?: TaskPriority;
  /** GTD-контекст: @home, @work, @errands и т.д. */
  context?: string;
};

export type HabitType = 'good' | 'bad';

export type HabitFrequency = {
  type: 'daily' | 'specific_days' | 'times_per_week';
  days?: number[]; // 0-6 (0 = Sunday)
  count?: number; // for times_per_week
};

export type Habit = {
  id: string;
  title: string;
  type: HabitType;
  description?: string;
  createdAt: string;
  frequency?: HabitFrequency;
  targetValue?: number; // For quantitative habits
  unit?: string; // e.g., 'ml', 'pages', 'min'
  icon?: string; // Emoji
  isPinned?: boolean;
  order?: number;
};

export type HabitLog = {
  id: string;
  habitId: string;
  date: string; // ISO date string (YYYY-MM-DD)
  status: 'done' | 'failed' | 'skipped'; // for good: done/skipped, for bad: failed(did it)/done(resisted)
  notes: string;
  feelings: string;
  value?: number; // For quantitative habits
};

export type WorkShiftType = 'day' | 'night' | 'off' | 'post_night' | 'vacation';

export type Vacation = {
  id: string;
  startDate: string; // ISO date string
  endDate: string; // ISO date string
  title: string;
};

export type WorkSchedule = {
  anchorDate: string; // ISO date string for the start of the cycle
  cycle: WorkShiftType[];
  vacations?: Vacation[];
};

export type MuscleGroup = 'chest' | 'back' | 'legs' | 'shoulders' | 'arms' | 'core' | 'cardio';

export type WorkoutMetric = 'weight' | 'reps' | 'distance' | 'time' | 'speed' | 'calories';

export type WorkoutNode = {
  id: string;
  parentId: string | null;
  name: string;
  type: 'folder' | 'exercise';
  notes?: string;
  videoUrl?: string;
  metrics?: WorkoutMetric[];
  restTime?: number; // in seconds
  muscleGroup?: MuscleGroup;
  isTemplate?: boolean;
};

export type ExerciseLog = {
  id: string;
  exerciseId: string;
  date: string; // YYYY-MM-DD
  metrics: Partial<Record<WorkoutMetric, number>>;
  notes?: string;
  restTime?: number; // in seconds
  sessionId?: string; // links the set to a WorkoutSession (legacy logs have none)
};

export type WorkoutSessionStatus = 'active' | 'completed';

export type WorkoutSession = {
  id: string;
  date: string; // YYYY-MM-DD (local day the session started)
  startedAt: string; // ISO timestamp
  endedAt?: string; // ISO timestamp
  durationSec?: number; // explicit elapsed seconds
  programId?: string; // workout node (folder/program) used
  label?: string; // e.g. "День ног"
  notes?: string;
  status: WorkoutSessionStatus;
};

export type BodyMeasurement = {
  id: string;
  date: string; // YYYY-MM-DD
  weight?: number;
  height?: number;
  neck?: number;
  gender?: 'male' | 'female';
  measurements?: Record<string, number>; // e.g., { chest: 100, waist: 80, hip: 90 }
  photos?: string[]; // Array of base64 strings or URLs
};

export type PlannedWorkoutStatus = 'planned' | 'completed' | 'missed';

export type PlannedWorkout = {
  id: string;
  date: string; // YYYY-MM-DD
  status: PlannedWorkoutStatus;
  programId?: string; // ID of the folder/program
  label?: string; // Custom label, e.g. "Leg Day"
};

export type PasswordEntry = {
  id: string;
  title: string;
  username?: string;
  password?: string;
  url?: string;
  totpSecret?: string;
  notes?: string;
  category?: string;
  createdAt: string;
  updatedAt: string;
  isPinned?: boolean;
};

export type Currency = 'BYN' | 'USD' | 'EUR' | 'RUB' | 'PLN' | 'USDT' | string;
export type AccountType =
  | 'card'
  | 'cash'
  | 'deposit'
  | 'crypto'
  | 'installment' // карты рассрочки (Халва, Магнит, Карта покупок)
  | 'other';

export type Account = {
  id: string;
  name: string;
  type: AccountType;
  currency: Currency;
  initialBalance: number;
  color: string;
  createdAt: string;
};

export type TransactionType = 'income' | 'expense' | 'transfer';
export type PaymentMethod = 'card' | 'cash'; // Keeping for backward compatibility

export type Transaction = {
  id: string;
  type: TransactionType;
  amount: number;
  category: string;
  date: string; // YYYY-MM-DD
  notes?: string;
  photoUrl?: string;
  paymentMethod?: PaymentMethod;
  cashGiven?: number; // How much cash was given (to calculate change)
  accountId?: string; // Account ID for income/expense, or source account for transfer
  toAccountId?: string; // Destination account ID for transfers
  tags?: string[]; // Array of tags like ['#food', '#restaurant']
  source?: string; // Source of income
  recurringRef?: string; // "<ruleId>:<periodKey>" — marks a posted recurring occurrence
};

export type LoanPaymentType = 'payment' | 'withdrawal';

export type LoanPayment = {
  id: string;
  date: string;
  amount: number;
  type: LoanPaymentType;
  notes?: string;
};

export type Loan = {
  id: string;
  name: string;
  amount: number; // Total loan amount
  currency?: Currency;
  rate: number; // Annual interest rate (%)
  termMonths: number; // Term in months
  monthlyPayment: number; // Calculated monthly payment
  totalPayment: number; // Total amount to pay
  overpayment: number; // Total interest paid
  createdAt: string;
  payments?: LoanPayment[];
  /** Day of month (1-31) the monthly payment is due. Defaults to 5. */
  paymentDay?: number;
};

export type FinancialGoalStep = {
  id: string;
  title: string;
  description?: string;
  completed: boolean;
};

export type FinancialGoal = {
  id: string;
  title: string;
  targetAmount: number;
  currentAmount: number;
  deadline?: string; // YYYY-MM-DD
  notes?: string;
  createdAt: string;
  aiPlan?: {
    steps: FinancialGoalStep[];
    generatedAt: string;
  };
};

export type BudgetLimit = {
  id: string;
  category: string;
  amount: number;
  currency?: Currency;
  period: 'month';
};

/**
 * User-defined budget plan for a specific month.
 * `monthKey` is `YYYY-MM`. `categoryPlans` is the planned spend per expense
 * category. `freeFundsTarget` is optional amount the user wants to keep free
 * (savings/buffer) — when omitted, free = plannedIncome - sum(categoryPlans).
 */
export type MonthlyBudgetPlan = {
  id: string;
  monthKey: string; // YYYY-MM
  plannedIncome: number;
  currency?: Currency;
  categoryPlans: { category: string; planned: number }[];
  freeFundsTarget?: number;
  /**
   * When true, the unspent remainder of each category limit (planned - actual)
   * from the previous month rolls into this month's effective limit.
   */
  rollover?: boolean;
  notes?: string;
  createdAt: string;
  updatedAt: string;
};

export type RecurringFrequency = 'weekly' | 'biweekly' | 'monthly' | 'yearly';

export type RegularPayment = {
  id: string;
  name: string;
  type?: TransactionType; // 'income' | 'expense' (default 'expense'); transfers out of scope
  amount: number;
  currency?: Currency;
  dueDate: number; // Day of the month (1-31), used for monthly/yearly
  frequency?: RecurringFrequency; // default 'monthly'
  weekday?: number; // 0 (Sun) - 6 (Sat), used for weekly/biweekly
  month?: number; // 1-12, used for yearly
  anchorDate?: string; // YYYY-MM-DD anchor for biweekly cadence / start
  category: string;
  accountId?: string; // Preferred account to post to
  autoConfirm?: boolean; // true = post silently when due; default false = review queue
  isActive: boolean;
};

// Records a recurring occurrence the user explicitly skipped (won't be re-suggested).
export type RecurringSkip = {
  ruleId: string;
  periodKey: string;
};

export type Envelope = {
  id: string;
  name: string;
  targetAmount?: number;
  currentAmount: number;
  color: string;
};

export type WaterLog = {
  id: string;
  date: string; // YYYY-MM-DD
  timestamp: string; // ISO string
  amount: number; // in ml
};

export type InboxItem = {
  id: string;
  content: string;
  createdAt: string;
};

export type SleepLog = {
  id: string;
  date: string; // YYYY-MM-DD
  hours: number;
  quality: 1 | 2 | 3 | 4 | 5; // 1-5 scale
  notes?: string;
  bedtime?: string; // HH:mm
  wakeTime?: string; // HH:mm
};

export type PomodoroSettings = {
  workTime: number;
  shortBreakTime: number;
  longBreakTime: number;
  soundEnabled: boolean;
};

export type PomodoroState = {
  timeLeft: number;
  totalTime: number;
  isRunning: boolean;
  type: 'work' | 'shortBreak' | 'longBreak';
  sessionsCompleted: number;
  settings: PomodoroSettings;
};

export type DashboardWidget = 'efficiency' | 'trends' | 'stats_grid' | 'overview' | 'spheres_hub' | 'goals' | 'tasks_habits' | 'water' | 'activity_trends' | 'habit_stories' | 'activity_calendar' | 'finance_hub' | 'monthly_budget' | 'upcoming_deadlines' | 'habit_matrix' | 'pomodoro' | 'inbox' | 'next_workout' | 'sleep_recovery' | 'discipline_score' | 'stoic_quote' | 'shopping_list' | 'smart_schedule';

export type DashboardConfig = {
  widgetsOrder: DashboardWidget[];
  visibleWidgets: DashboardWidget[];
  widgetSizes?: Record<string, 'small' | 'large'>;
};

export type ShoppingCategory = {
  id: string;
  name: string;
  color: string;
};

export type ShoppingItem = {
  id: string;
  text: string;
  completed: boolean;
  price?: number;
  category?: string;
  hashtags?: string[];
  photo?: string; // base64
  createdAt: string;
  completedAt?: string;
};

export type SavingsGoal = {
  id: string;
  title: string;
  targetAmount: number;
  currentAmount: number;
  currency?: Currency;
  color: string;
  createdAt: string;
  isCompleted: boolean;
};

export type DailyActivity = {
  id: string;
  date: string; // YYYY-MM-DD
  steps: number;
  calories: number;
};

export type AppModule = 'spheres' | 'tasks' | 'habits' | 'workouts' | 'passwords' | 'finance' | 'goals' | 'schedule' | 'household' | 'water' | 'analytics' | 'pomodoro' | 'inbox' | 'sleep';

export type ModuleSettings = Record<AppModule, boolean>;

export type ShoppingItemPrice = {
  id: string;
  itemName: string;
  price: number;
  date: string;
  store?: string;
};

export type GoalLog = {
  id: string;
  goalId: string;
  date: string; // ISO date string
  content: string;
};

// ── Budget Planner (План Доходов / Расходов / Факт) ──

export type IncomeSourceType = 'salary' | 'advance' | 'additional';

export type IncomeSource = {
  id: string;
  name: string;
  type: IncomeSourceType;
  amount: number;
  currency?: Currency;
  /** Day of month (1-31). For salary/advance, auto-adjusted for weekends/holidays. */
  dayOfMonth?: number;
  /** If true, adjust to last working day when date falls on weekend/holiday. */
  adjustForHolidays?: boolean;
  isActive: boolean;
  createdAt: string;
};

export type PlannedExpense = {
  id: string;
  name: string;
  amount: number;
  currency?: Currency;
  /** Start day of payment window (1-31). */
  dayFrom: number;
  /** End day of payment window (1-31). */
  dayTo: number;
  category?: string;
  /**
   * How often the expense recurs. 'monthly' (default) repeats every month on
   * the [dayFrom..dayTo] window; 'once' applies only in [startMonth].
   */
  recurrence?: 'monthly' | 'once';
  /**
   * First month the expense applies, as `YYYY-MM`. For 'monthly' it suppresses
   * occurrences before this month; for 'once' it is the only month. Undefined
   * means "from now / every month" (legacy behaviour).
   */
  startMonth?: string;
  /** Whether this expense has been paid in the current cycle. */
  isPaid: boolean;
  /** Date when it was actually paid (ISO string). */
  paidDate?: string;
  /** Actual amount paid (may differ from planned). */
  paidAmount?: number;
  isActive: boolean;
  createdAt: string;
};

export type ActualExpense = {
  id: string;
  plannedExpenseId?: string;
  name: string;
  amount: number;
  currency?: Currency;
  date: string; // YYYY-MM-DD
  category?: string;
};

export type BudgetPlanConfig = {
  incomeSources: IncomeSource[];
  plannedExpenses: PlannedExpense[];
  actualExpenses: ActualExpense[];
};

export type AppState = {
  spheres: Sphere[];
  tasks: Task[];
  habits: Habit[];
  habitLogs: HabitLog[];
  workoutNodes?: WorkoutNode[];
  exerciseLogs?: ExerciseLog[];
  workoutSessions?: WorkoutSession[];
  bodyMeasurements?: BodyMeasurement[];
  plannedWorkouts?: PlannedWorkout[];
  passwords?: PasswordEntry[];
  transactions?: Transaction[];
  accounts?: Account[];
  loans?: Loan[];
  financialGoals?: FinancialGoal[];
  budgetLimits?: BudgetLimit[];
  monthlyBudgetPlans?: MonthlyBudgetPlan[];
  regularPayments?: RegularPayment[];
  envelopes?: Envelope[];
  goals?: Goal[];
  goalLogs?: GoalLog[];
  waterLogs?: WaterLog[];
  waterGoal?: number;
  waterIncrement?: number;
  dashboardConfig?: DashboardConfig;
  inboxItems?: InboxItem[];
  sleepLogs?: SleepLog[];
  pomodoro?: PomodoroState;
  shoppingItems?: ShoppingItem[];
  shoppingCategories?: ShoppingCategory[];
  savingsGoals?: SavingsGoal[];
  priceHistory?: ShoppingItemPrice[];
  dailyActivities?: DailyActivity[];
  hideHabitNames?: boolean;
  incomeSources?: IncomeSource[];
  plannedExpenses?: PlannedExpense[];
  actualExpenses?: ActualExpense[];
};
