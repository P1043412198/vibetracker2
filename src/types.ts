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

export type NoteComment = {
  id: string;
  content: string;
  createdAt: string;
};

export type SphereNote = {
  id: string;
  content: string;
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
export type AccountType = 'card' | 'cash' | 'deposit' | 'crypto' | 'other';

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
  notes?: string;
  createdAt: string;
  updatedAt: string;
};

export type RegularPayment = {
  id: string;
  name: string;
  amount: number;
  currency?: Currency;
  dueDate: number; // Day of the month (1-31)
  category: string;
  isActive: boolean;
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

export type DashboardWidget = 'efficiency' | 'trends' | 'stats_grid' | 'overview' | 'spheres_hub' | 'goals' | 'tasks_habits' | 'water' | 'activity_trends' | 'habit_stories' | 'activity_calendar' | 'finance_hub' | 'upcoming_deadlines' | 'habit_matrix' | 'pomodoro' | 'inbox' | 'next_workout' | 'sleep_recovery' | 'discipline_score' | 'stoic_quote' | 'shopping_list' | 'smart_schedule';

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

export type AppState = {
  spheres: Sphere[];
  tasks: Task[];
  habits: Habit[];
  habitLogs: HabitLog[];
  workoutNodes?: WorkoutNode[];
  exerciseLogs?: ExerciseLog[];
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
};
