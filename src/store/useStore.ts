import { create } from 'zustand';
import { persist, createJSONStorage, StateStorage } from 'zustand/middleware';
import { get, set, del } from 'idb-keyval';
import { v4 as uuidv4 } from 'uuid';
import { format, isSameMonth, parseISO } from 'date-fns';
import { Sphere, Task, Habit, HabitLog, TaskPeriod, HabitType, SphereNote, WorkoutNode, ExerciseLog, BodyMeasurement, PlannedWorkout, PlannedWorkoutStatus, PasswordEntry, Transaction, Loan, LoanPayment, FinancialGoal, BudgetLimit, RegularPayment, Envelope, Account, NotificationSettings, Goal, GoalStep, GoalLog, WorkSchedule, Vacation, WaterLog, DashboardConfig, DashboardWidget, AppModule, InboxItem, SleepLog, PomodoroState, PomodoroSettings, ShoppingItem, ShoppingCategory, SavingsGoal, ShoppingItemPrice, DailyActivity, Currency, MonthlyBudgetPlan } from '../types';

// Custom storage using IndexedDB to handle large data (like base64 images)
const storage: StateStorage = {
  getItem: async (name: string): Promise<string | null> => {
    const value = await get(name);
    if (value) return value;
    
    // Fallback and migrate from localStorage if it exists
    const localValue = localStorage.getItem(name);
    if (localValue) {
      await set(name, localValue);
      // Optional: localStorage.removeItem(name); // keep it for now as backup
      return localValue;
    }
    return null;
  },
  setItem: async (name: string, value: string): Promise<void> => {
    await set(name, value);
  },
  removeItem: async (name: string): Promise<void> => {
    await del(name);
  },
};

interface AppState {
  spheres: Sphere[];
  tasks: Task[];
  habits: Habit[];
  habitLogs: HabitLog[];
  workoutNodes: WorkoutNode[];
  exerciseLogs: ExerciseLog[];
  bodyMeasurements: BodyMeasurement[];
  plannedWorkouts: PlannedWorkout[];
  passwords: PasswordEntry[];
  transactions: Transaction[];
  accounts: Account[];
  loans: Loan[];
  financialGoals: FinancialGoal[];
  budgetLimits: BudgetLimit[];
  regularPayments: RegularPayment[];
  envelopes: Envelope[];
  goals: Goal[];
  goalLogs: GoalLog[];
  monthlyBudgetPlans: MonthlyBudgetPlan[];
  hideHabitNames: boolean;
  workSchedule: WorkSchedule | null;
  waterLogs: WaterLog[];
  waterGoal: number;
  waterIncrement: number;
  waterVisualization: 'glass' | 'bottle';
  dashboardConfig: DashboardConfig;
  enabledModules: Record<AppModule, boolean>;
  
  inboxItems: InboxItem[];
  sleepLogs: SleepLog[];
  pomodoro: PomodoroState;
  shoppingItems: ShoppingItem[];
  shoppingCategories: ShoppingCategory[];
  savingsGoals: SavingsGoal[];
  priceHistory: ShoppingItemPrice[];
  dailyActivities: DailyActivity[];
  
  // Currency
  rates: Record<string, number>;
  baseCurrency: Currency;
  fetchRates: () => Promise<void>;
  setBaseCurrency: (currency: Currency) => void;
  
  // AI Settings
  customGeminiKey: string | null;
  customOpenAIKey: string | null;
  preferredAiProvider: 'gemini' | 'openai';
  dailyTip: { date: string; text: string } | null;
  setDailyTip: (tip: { date: string; text: string } | null) => void;
  
  // Notification Settings
  notificationSettings: NotificationSettings;
  updateNotificationSettings: (settings: Partial<NotificationSettings>) => void;
  
  // Actions
  setCustomGeminiKey: (key: string | null) => void;
  setCustomOpenAIKey: (key: string | null) => void;
  setPreferredAiProvider: (provider: 'gemini' | 'openai') => void;

  addSphere: (sphere: Omit<Sphere, 'id' | 'createdAt'>) => string;
  updateSphere: (id: string, updates: Partial<Sphere>) => void;
  deleteSphere: (id: string) => void;
  reorderSpheres: (sphereIds: string[]) => void;
  addSphereNote: (sphereId: string, content: string, youtubeUrl?: string, isCheckbox?: boolean, photoUrl?: string) => void;
  updateSphereNote: (sphereId: string, noteId: string, updates: Partial<SphereNote>) => void;
  deleteSphereNote: (sphereId: string, noteId: string) => void;

  addTask: (task: Omit<Task, 'id' | 'createdAt' | 'completed' | 'failed'>) => void;
  updateTask: (id: string, updates: Partial<Task>) => void;
  deleteTask: (id: string) => void;
  toggleTaskCompletion: (id: string) => void;
  toggleTaskFailure: (id: string) => void;
  reorderTasks: (taskIds: string[]) => void;
  addSubtask: (taskId: string, title: string) => void;
  toggleSubtask: (taskId: string, subtaskId: string) => void;
  deleteSubtask: (taskId: string, subtaskId: string) => void;

  addHabit: (habit: Omit<Habit, 'id' | 'createdAt'>) => void;
  updateHabit: (id: string, updates: Partial<Habit>) => void;
  deleteHabit: (id: string) => void;
  reorderHabits: (habitIds: string[]) => void;

  logHabit: (log: Omit<HabitLog, 'id'>) => void;
  updateHabitLog: (id: string, updates: Partial<HabitLog>) => void;

  // Workouts
  addWorkoutNode: (node: Omit<WorkoutNode, 'id'>) => string;
  updateWorkoutNode: (id: string, updates: Partial<WorkoutNode>) => void;
  deleteWorkoutNode: (id: string) => void;
  moveWorkoutNode: (id: string, newParentId: string | null) => void;

  logExercise: (log: Omit<ExerciseLog, 'id'>) => void;
  updateExerciseLog: (id: string, updates: Partial<ExerciseLog>) => void;
  deleteExerciseLog: (id: string) => void;

  addBodyMeasurement: (measurement: Omit<BodyMeasurement, 'id'>) => void;
  updateBodyMeasurement: (id: string, updates: Partial<BodyMeasurement>) => void;
  deleteBodyMeasurement: (id: string) => void;

  togglePlannedWorkout: (date: string, status: PlannedWorkoutStatus | null) => void;
  updatePlannedWorkout: (date: string, updates: Partial<PlannedWorkout>) => void;

  // Passwords
  addPassword: (password: Omit<PasswordEntry, 'id' | 'createdAt' | 'updatedAt'>) => void;
  updatePassword: (id: string, updates: Partial<PasswordEntry>) => void;
  deletePassword: (id: string) => void;

  // Accounts
  addAccount: (account: Omit<Account, 'id' | 'createdAt'>) => void;
  updateAccount: (id: string, updates: Partial<Account>) => void;
  deleteAccount: (id: string) => void;

  // Transactions
  addTransaction: (transaction: Omit<Transaction, 'id'>) => void;
  updateTransaction: (id: string, updates: Partial<Transaction>) => void;
  deleteTransaction: (id: string) => void;

  // Loans
  addLoan: (loan: Omit<Loan, 'id' | 'createdAt'>) => void;
  updateLoan: (id: string, updates: Partial<Loan>) => void;
  deleteLoan: (id: string) => void;
  addLoanPayment: (loanId: string, payment: Omit<LoanPayment, 'id'>) => void;
  updateLoanPayment: (loanId: string, paymentId: string, updates: Partial<LoanPayment>) => void;
  deleteLoanPayment: (loanId: string, paymentId: string) => void;

  // Financial Goals
  addFinancialGoal: (goal: Omit<FinancialGoal, 'id' | 'createdAt'>) => void;
  updateFinancialGoal: (id: string, updates: Partial<FinancialGoal>) => void;
  deleteFinancialGoal: (id: string) => void;

  // Budget Limits
  addBudgetLimit: (limit: Omit<BudgetLimit, 'id'>) => void;
  updateBudgetLimit: (id: string, updates: Partial<BudgetLimit>) => void;
  deleteBudgetLimit: (id: string) => void;

  // Monthly Budget Plans (per-month plan vs fact)
  saveMonthlyBudgetPlan: (plan: Omit<MonthlyBudgetPlan, 'id' | 'createdAt' | 'updatedAt'> & { id?: string }) => void;
  deleteMonthlyBudgetPlan: (id: string) => void;
  getMonthlyBudgetPlan: (monthKey: string) => MonthlyBudgetPlan | undefined;

  // Regular Payments
  addRegularPayment: (payment: Omit<RegularPayment, 'id'>) => void;
  updateRegularPayment: (id: string, updates: Partial<RegularPayment>) => void;
  deleteRegularPayment: (id: string) => void;

  // Envelopes
  addEnvelope: (envelope: Omit<Envelope, 'id'>) => void;
  updateEnvelope: (id: string, updates: Partial<Envelope>) => void;
  deleteEnvelope: (id: string) => void;

  // Regular Payments
  processRegularPayment: (id: string, accountId: string) => void;
  checkRegularPayments: () => void;

  // Price History
  addPriceHistory: (item: Omit<ShoppingItemPrice, 'id'>) => void;
  deletePriceHistory: (id: string) => void;

  // Goals
  addGoal: (goal: Omit<Goal, 'id' | 'createdAt'>) => void;
  updateGoal: (id: string, updates: Partial<Goal>) => void;
  deleteGoal: (id: string) => void;
  addGoalStep: (goalId: string, step: Omit<GoalStep, 'id'>) => void;
  updateGoalStep: (goalId: string, stepId: string, updates: Partial<GoalStep>) => void;
  deleteGoalStep: (goalId: string, stepId: string) => void;
  addGoalLog: (log: Omit<GoalLog, 'id'>) => void;
  deleteGoalLog: (id: string) => void;
  updateWorkSchedule: (schedule: WorkSchedule | null) => void;
  addVacation: (vacation: Omit<Vacation, 'id'>) => void;
  deleteVacation: (id: string) => void;

  // Water
  logWater: (amount: number) => void;
  deleteWaterLog: (id: string) => void;
  setWaterGoal: (goal: number) => void;
  setWaterIncrement: (increment: number) => void;
  setWaterVisualization: (type: 'glass' | 'bottle') => void;

  // Inbox
  addInboxItem: (content: string) => void;
  deleteInboxItem: (id: string) => void;
  
  // Sleep
  logSleep: (log: Omit<SleepLog, 'id'>) => void;
  deleteSleepLog: (id: string) => void;
  
  // Pomodoro
  updatePomodoro: (updates: Partial<PomodoroState>) => void;
  updatePomodoroSettings: (settings: Partial<PomodoroSettings>) => void;
  startPomodoro: (type: 'work' | 'shortBreak' | 'longBreak') => void;
  tickPomodoro: () => void;
  resetPomodoro: () => void;

  resetSleepLogs?: () => void;
  
  // Shopping List
  addShoppingItem: (item: Omit<ShoppingItem, 'id' | 'createdAt' | 'completed'>) => void;
  updateShoppingItem: (id: string, updates: Partial<ShoppingItem>) => void;
  deleteShoppingItem: (id: string) => void;
  toggleShoppingItem: (id: string) => void;
  clearCompletedShoppingItems: () => void;
  addShoppingCategory: (category: Omit<ShoppingCategory, 'id'>) => void;
  updateShoppingCategory: (id: string, updates: Partial<ShoppingCategory>) => void;
  deleteShoppingCategory: (id: string) => void;

  // Savings Goals
  addSavingsGoal: (goal: Omit<SavingsGoal, 'id' | 'createdAt' | 'isCompleted'>) => void;
  updateSavingsGoal: (id: string, updates: Partial<SavingsGoal>) => void;
  deleteSavingsGoal: (id: string) => void;
  addSavingsContribution: (id: string, amount: number) => void;

  // Daily Activity
  logDailyActivity: (activity: Omit<DailyActivity, 'id'>) => void;
  deleteDailyActivity: (id: string) => void;

  // Habits
  toggleHideHabitNames: () => void;

  // Dashboard
  updateDashboardConfig: (config: Partial<DashboardConfig>) => void;
  reorderDashboardWidgets: (order: DashboardWidget[]) => void;
  updateModuleSettings: (settings: Partial<Record<AppModule, boolean>>) => void;

  // Timer
  timer: {
    timeLeft: number;
    initialTime: number;
    isRunning: boolean;
    isOpen: boolean;
  };
  setTimer: (timer: Partial<AppState['timer']>) => void;
  startTimer: (seconds: number) => void;
  stopTimer: () => void;
  resetTimer: () => void;

  // Wealth Tree
  wealthTreeTarget: number | null;
  setWealthTreeTarget: (target: number | null) => void;

  // Security
  pinCode: string | null;
  isLocked: boolean;
  setPinCode: (pin: string | null) => void;
  unlock: () => void;
  lock: () => void;

  // Password Generator
  customPasswordWord: string;
  scatterPasswordWord: boolean;
  setCustomPasswordWord: (word: string) => void;
  setScatterPasswordWord: (scatter: boolean) => void;
}

export const useStore = create<AppState>()(
  persist(
    (set, get) => ({
      spheres: [],
      tasks: [],
      habits: [],
      habitLogs: [],
      workoutNodes: [],
      exerciseLogs: [],
      bodyMeasurements: [],
      plannedWorkouts: [],
      passwords: [],
      transactions: [],
      accounts: [],
      loans: [],
      financialGoals: [],
      budgetLimits: [],
      regularPayments: [],
      envelopes: [],
      goals: [],
      goalLogs: [],
      monthlyBudgetPlans: [],
      workSchedule: null,
      waterLogs: [],
      waterGoal: 2000,
      waterIncrement: 250,
      waterVisualization: 'glass',
      wealthTreeTarget: null,
      dashboardConfig: {
        widgetsOrder: ['smart_schedule', 'efficiency', 'trends', 'stats_grid', 'overview', 'spheres_hub', 'goals', 'tasks_habits', 'water', 'activity_trends', 'habit_stories', 'activity_calendar', 'finance_hub', 'upcoming_deadlines', 'habit_matrix', 'pomodoro', 'inbox', 'next_workout', 'sleep_recovery', 'discipline_score', 'stoic_quote', 'shopping_list'],
        visibleWidgets: ['smart_schedule', 'efficiency', 'trends', 'stats_grid', 'overview', 'spheres_hub', 'goals', 'tasks_habits', 'water', 'activity_trends', 'habit_stories', 'activity_calendar', 'finance_hub', 'upcoming_deadlines', 'habit_matrix', 'pomodoro', 'inbox', 'next_workout', 'sleep_recovery', 'discipline_score', 'stoic_quote', 'shopping_list']
      },
      enabledModules: {
        spheres: true,
        tasks: true,
        habits: true,
        workouts: true,
        passwords: true,
        finance: true,
        goals: true,
        schedule: true,
        household: true,
        water: true,
        analytics: true,
        pomodoro: true,
        inbox: true,
        sleep: true
      },
      inboxItems: [],
      sleepLogs: [],
      shoppingItems: [],
      shoppingCategories: [
        { id: 'food', name: 'Продукты', color: '#10b981' },
        { id: 'household', name: 'Дом', color: '#3b82f6' },
        { id: 'clothes', name: 'Одежда', color: '#a855f7' },
        { id: 'electronics', name: 'Техника', color: '#eab308' },
        { id: 'other', name: 'Другое', color: '#71717a' }
      ],
      savingsGoals: [],
      priceHistory: [],
      dailyActivities: [],
      hideHabitNames: false,
      rates: {},
      baseCurrency: 'USD',
      pomodoro: {
        timeLeft: 25 * 60,
        totalTime: 25 * 60,
        isRunning: false,
        type: 'work',
        sessionsCompleted: 0,
        settings: {
          workTime: 25,
          shortBreakTime: 5,
          longBreakTime: 15,
          soundEnabled: true
        }
      },
      customGeminiKey: null,
      customOpenAIKey: null,
      preferredAiProvider: 'gemini',
      dailyTip: null,
      notificationSettings: {
        tasks: true,
        habits: true,
        payments: true,
      },
      pinCode: null,
      isLocked: true,
      customPasswordWord: '',
      scatterPasswordWord: false,

      setPinCode: (pin) => set({ pinCode: pin, isLocked: pin !== null }),
      unlock: () => set({ isLocked: false }),
      lock: () => set({ isLocked: true }),
      setCustomPasswordWord: (word) => set({ customPasswordWord: word }),
      setScatterPasswordWord: (scatter) => set({ scatterPasswordWord: scatter }),

      setBaseCurrency: (currency) => set({ baseCurrency: currency }),

      fetchRates: async () => {
        try {
          const response = await fetch('https://api.nbrb.by/exrates/rates?periodicity=0');
          if (!response.ok) throw new Error('Failed to fetch rates');
          const data = await response.json();
          
          const newRates: Record<string, number> = {};
          // NBRB returns rates relative to 1 or 100 units of foreign currency in BYN
          // We want to store how many BYN is 1 unit of foreign currency
          data.forEach((item: any) => {
            if (['USD', 'EUR', 'RUB', 'PLN'].includes(item.Cur_Abbreviation)) {
              newRates[item.Cur_Abbreviation] = item.Cur_OfficialRate / item.Cur_Scale;
            }
          });
          
          // Add BYN as 1 since it's the anchor for NBRB
          newRates['BYN'] = 1;
          
          set({ rates: newRates });
        } catch (error) {
          console.error('Error fetching NBRB rates:', error);
        }
      },

      updateNotificationSettings: (settings) => set((state) => ({
        notificationSettings: { ...state.notificationSettings, ...settings }
      })),

      setCustomGeminiKey: (key) => set({ customGeminiKey: key }),
      setCustomOpenAIKey: (key) => set({ customOpenAIKey: key }),
      setPreferredAiProvider: (provider) => set({ preferredAiProvider: provider }),
      setDailyTip: (tip) => set({ dailyTip: tip }),

      addSphere: (sphere) => {
        const id = uuidv4();
        set((state) => ({
          spheres: [...state.spheres, { ...sphere, id, createdAt: new Date().toISOString(), order: state.spheres.length }]
        }));
        return id;
      },
      updateSphere: (id, updates) => set((state) => ({
        spheres: state.spheres.map(s => s.id === id ? { ...s, ...updates } : s)
      })),
      deleteSphere: (id) => set((state) => ({
        spheres: state.spheres.filter(s => s.id !== id),
        tasks: state.tasks.map(t => t.sphereId === id ? { ...t, sphereId: undefined } : t)
      })),
      reorderSpheres: (sphereIds) => set((state) => {
        const newSpheres = [...state.spheres];
        sphereIds.forEach((id, index) => {
          const sphereIndex = newSpheres.findIndex(s => s.id === id);
          if (sphereIndex !== -1) {
            newSpheres[sphereIndex] = { ...newSpheres[sphereIndex], order: index };
          }
        });
        return { spheres: newSpheres };
      }),
      addSphereNote: (sphereId, content, youtubeUrl, isCheckbox, photoUrl) => set((state) => ({
        spheres: state.spheres.map(s => {
          if (s.id === sphereId) {
            const newNote = { id: uuidv4(), content, youtubeUrl, photoUrl, isCheckbox, isChecked: false, createdAt: new Date().toISOString() };
            return { ...s, notesList: [...(s.notesList || []), newNote] };
          }
          return s;
        })
      })),
      updateSphereNote: (sphereId, noteId, updates) => set((state) => ({
        spheres: state.spheres.map(s => {
          if (s.id === sphereId) {
            return {
              ...s,
              notesList: (s.notesList || []).map(n => n.id === noteId ? { ...n, ...updates } : n)
            };
          }
          return s;
        })
      })),
      deleteSphereNote: (sphereId, noteId) => set((state) => ({
        spheres: state.spheres.map(s => {
          if (s.id === sphereId) {
            return { ...s, notesList: (s.notesList || []).filter(n => n.id !== noteId) };
          }
          return s;
        })
      })),

      addTask: (task) => set((state) => ({
        tasks: [...state.tasks, { ...task, id: uuidv4(), completed: false, failed: false, createdAt: new Date().toISOString(), order: state.tasks.length }]
      })),
      updateTask: (id, updates) => set((state) => ({
        tasks: state.tasks.map(t => t.id === id ? { ...t, ...updates } : t)
      })),
      deleteTask: (id) => set((state) => ({
        tasks: state.tasks.filter(t => t.id !== id)
      })),
      toggleTaskCompletion: (id) => set((state) => ({
        tasks: state.tasks.map(t => {
          if (t.id === id) {
            return { ...t, completed: !t.completed, failed: false };
          }
          return t;
        })
      })),
      toggleTaskFailure: (id) => set((state) => ({
        tasks: state.tasks.map(t => {
          if (t.id === id) {
            return { ...t, failed: !t.failed, completed: false };
          }
          return t;
        })
      })),
      reorderTasks: (taskIds) => set((state) => {
        const newTasks = [...state.tasks];
        taskIds.forEach((id, index) => {
          const taskIndex = newTasks.findIndex(t => t.id === id);
          if (taskIndex !== -1) {
            newTasks[taskIndex] = { ...newTasks[taskIndex], order: index };
          }
        });
        return { tasks: newTasks };
      }),
      addSubtask: (taskId, title) => set((state) => ({
        tasks: state.tasks.map(t => {
          if (t.id === taskId) {
            const subtasks = t.subtasks || [];
            return { ...t, subtasks: [...subtasks, { id: uuidv4(), title, completed: false }] };
          }
          return t;
        })
      })),
      toggleSubtask: (taskId, subtaskId) => set((state) => ({
        tasks: state.tasks.map(t => {
          if (t.id === taskId && t.subtasks) {
            return {
              ...t,
              subtasks: t.subtasks.map(s => s.id === subtaskId ? { ...s, completed: !s.completed } : s)
            };
          }
          return t;
        })
      })),
      deleteSubtask: (taskId, subtaskId) => set((state) => ({
        tasks: state.tasks.map(t => {
          if (t.id === taskId && t.subtasks) {
            return {
              ...t,
              subtasks: t.subtasks.filter(s => s.id !== subtaskId)
            };
          }
          return t;
        })
      })),

      addHabit: (habit) => set((state) => ({
        habits: [...state.habits, { ...habit, id: uuidv4(), createdAt: new Date().toISOString(), order: state.habits.length }]
      })),
      updateHabit: (id, updates) => set((state) => ({
        habits: state.habits.map(h => h.id === id ? { ...h, ...updates } : h)
      })),
      deleteHabit: (id) => set((state) => ({
        habits: state.habits.filter(h => h.id !== id),
        habitLogs: state.habitLogs.filter(l => l.habitId !== id)
      })),
      reorderHabits: (habitIds) => set((state) => {
        const newHabits = [...state.habits];
        habitIds.forEach((id, index) => {
          const habitIndex = newHabits.findIndex(h => h.id === id);
          if (habitIndex !== -1) {
            newHabits[habitIndex] = { ...newHabits[habitIndex], order: index };
          }
        });
        return { habits: newHabits };
      }),

      logHabit: (log) => set((state) => {
        const existingLogIndex = state.habitLogs.findIndex(l => l.habitId === log.habitId && l.date === log.date);
        if (existingLogIndex >= 0) {
          const newLogs = [...state.habitLogs];
          newLogs[existingLogIndex] = { ...newLogs[existingLogIndex], ...log };
          return { habitLogs: newLogs };
        }
        return {
          habitLogs: [...state.habitLogs, { ...log, id: uuidv4() }]
        };
      }),
      updateHabitLog: (id, updates) => set((state) => ({
        habitLogs: state.habitLogs.map(l => l.id === id ? { ...l, ...updates } : l)
      })),

      addWorkoutNode: (node) => {
        const id = uuidv4();
        set((state) => ({
          workoutNodes: [...state.workoutNodes, { ...node, id }]
        }));
        return id;
      },
      updateWorkoutNode: (id, updates) => set((state) => ({
        workoutNodes: state.workoutNodes.map(n => n.id === id ? { ...n, ...updates } : n)
      })),
      deleteWorkoutNode: (id) => set((state) => {
        // Recursively delete children if it's a folder
        const getChildrenIds = (parentId: string): string[] => {
          const children = state.workoutNodes.filter(n => n.parentId === parentId);
          return [
            ...children.map(c => c.id),
            ...children.flatMap(c => getChildrenIds(c.id))
          ];
        };
        const idsToDelete = [id, ...getChildrenIds(id)];
        return {
          workoutNodes: state.workoutNodes.filter(n => !idsToDelete.includes(n.id)),
          exerciseLogs: state.exerciseLogs.filter(l => !idsToDelete.includes(l.exerciseId))
        };
      }),
      moveWorkoutNode: (id, newParentId) => set((state) => ({
        workoutNodes: state.workoutNodes.map(n => n.id === id ? { ...n, parentId: newParentId } : n)
      })),

      logExercise: (log) => set((state) => ({
        exerciseLogs: [...state.exerciseLogs, { ...log, id: uuidv4() }]
      })),
      updateExerciseLog: (id, updates) => set((state) => ({
        exerciseLogs: state.exerciseLogs.map(l => l.id === id ? { ...l, ...updates } : l)
      })),
      deleteExerciseLog: (id) => set((state) => ({
        exerciseLogs: state.exerciseLogs.filter(l => l.id !== id)
      })),

      addBodyMeasurement: (measurement) => set((state) => ({
        bodyMeasurements: [...state.bodyMeasurements, { ...measurement, id: uuidv4() }]
      })),
      updateBodyMeasurement: (id, updates) => set((state) => ({
        bodyMeasurements: state.bodyMeasurements.map(m => m.id === id ? { ...m, ...updates } : m)
      })),
      deleteBodyMeasurement: (id) => set((state) => ({
        bodyMeasurements: state.bodyMeasurements.filter(m => m.id !== id)
      })),

      togglePlannedWorkout: (date, status) => set((state) => {
        const existing = (state.plannedWorkouts || []).find(p => p.date === date);
        if (status === null) {
          return { plannedWorkouts: (state.plannedWorkouts || []).filter(p => p.date !== date) };
        }
        if (existing) {
          return {
            plannedWorkouts: state.plannedWorkouts.map(p => p.date === date ? { ...p, status } : p)
          };
        }
        return {
          plannedWorkouts: [...(state.plannedWorkouts || []), { id: uuidv4(), date, status }]
        };
      }),
      updatePlannedWorkout: (date, updates) => set((state) => {
        const existing = (state.plannedWorkouts || []).find(p => p.date === date);
        if (existing) {
          return {
            plannedWorkouts: state.plannedWorkouts.map(p => p.date === date ? { ...p, ...updates } : p)
          };
        }
        return state;
      }),

      addPassword: (password) => set((state) => ({
        passwords: [...(state.passwords || []), { 
          ...password, 
          id: uuidv4(), 
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString()
        }]
      })),
      updatePassword: (id, updates) => set((state) => ({
        passwords: (state.passwords || []).map(p => p.id === id ? { 
          ...p, 
          ...updates,
          updatedAt: new Date().toISOString()
        } : p)
      })),
      deletePassword: (id) => set((state) => ({
        passwords: (state.passwords || []).filter(p => p.id !== id)
      })),

      addAccount: (account) => set((state) => ({
        accounts: [...(state.accounts || []), { ...account, id: uuidv4(), createdAt: new Date().toISOString() }]
      })),
      updateAccount: (id, updates) => set((state) => ({
        accounts: (state.accounts || []).map(a => a.id === id ? { ...a, ...updates } : a)
      })),
      deleteAccount: (id) => set((state) => ({
        accounts: (state.accounts || []).filter(a => a.id !== id)
      })),

      addTransaction: (transaction) => set((state) => ({
        transactions: [{ ...transaction, id: uuidv4() }, ...(state.transactions || [])]
      })),
      updateTransaction: (id, updates) => set((state) => ({
        transactions: (state.transactions || []).map(t => t.id === id ? { ...t, ...updates } : t)
      })),
      deleteTransaction: (id) => set((state) => ({
        transactions: (state.transactions || []).filter(t => t.id !== id)
      })),

      addLoan: (loan) => set((state) => ({
        loans: [...(state.loans || []), { ...loan, id: uuidv4(), createdAt: new Date().toISOString(), payments: [] }]
      })),
      updateLoan: (id, updates) => set((state) => ({
        loans: (state.loans || []).map(l => l.id === id ? { ...l, ...updates } : l)
      })),
      deleteLoan: (id) => set((state) => ({
        loans: (state.loans || []).filter(l => l.id !== id)
      })),
      addLoanPayment: (loanId, payment) => set((state) => ({
        loans: (state.loans || []).map(l => {
          if (l.id === loanId) {
            return {
              ...l,
              payments: [...(l.payments || []), { ...payment, id: uuidv4() }]
            };
          }
          return l;
        })
      })),
      updateLoanPayment: (loanId, paymentId, updates) => set((state) => ({
        loans: (state.loans || []).map(l => {
          if (l.id === loanId) {
            return {
              ...l,
              payments: (l.payments || []).map(p => p.id === paymentId ? { ...p, ...updates } : p)
            };
          }
          return l;
        })
      })),
      deleteLoanPayment: (loanId, paymentId) => set((state) => ({
        loans: (state.loans || []).map(l => {
          if (l.id === loanId) {
            return {
              ...l,
              payments: (l.payments || []).filter(p => p.id !== paymentId)
            };
          }
          return l;
        })
      })),

      addFinancialGoal: (goal) => set((state) => ({
        financialGoals: [...(state.financialGoals || []), { ...goal, id: uuidv4(), createdAt: new Date().toISOString() }]
      })),
      updateFinancialGoal: (id, updates) => set((state) => ({
        financialGoals: (state.financialGoals || []).map(g => g.id === id ? { ...g, ...updates } : g)
      })),
      deleteFinancialGoal: (id) => set((state) => ({
        financialGoals: (state.financialGoals || []).filter(g => g.id !== id)
      })),

      addBudgetLimit: (limit) => set((state) => ({
        budgetLimits: [...(state.budgetLimits || []), { ...limit, id: uuidv4() }]
      })),
      updateBudgetLimit: (id, updates) => set((state) => ({
        budgetLimits: (state.budgetLimits || []).map(l => l.id === id ? { ...l, ...updates } : l)
      })),
      deleteBudgetLimit: (id) => set((state) => ({
        budgetLimits: (state.budgetLimits || []).filter(l => l.id !== id)
      })),

      // Monthly Budget Plans (per-month plan vs fact)
      saveMonthlyBudgetPlan: (plan) => set((state) => {
        const now = new Date().toISOString();
        const plans = state.monthlyBudgetPlans || [];
        // Identify existing plan by id or monthKey+currency
        const existing = plan.id
          ? plans.find(p => p.id === plan.id)
          : plans.find(p => p.monthKey === plan.monthKey);
        if (existing) {
          return {
            monthlyBudgetPlans: plans.map(p => p.id === existing.id
              ? { ...existing, ...plan, id: existing.id, createdAt: existing.createdAt, updatedAt: now }
              : p)
          };
        }
        return {
          monthlyBudgetPlans: [
            ...plans,
            {
              ...plan,
              id: uuidv4(),
              createdAt: now,
              updatedAt: now,
            } as MonthlyBudgetPlan,
          ]
        };
      }),
      deleteMonthlyBudgetPlan: (id) => set((state) => ({
        monthlyBudgetPlans: (state.monthlyBudgetPlans || []).filter(p => p.id !== id)
      })),
      getMonthlyBudgetPlan: (monthKey) => {
        const state = get();
        return (state.monthlyBudgetPlans || []).find(p => p.monthKey === monthKey);
      },

      addRegularPayment: (payment) => set((state) => ({
        regularPayments: [...(state.regularPayments || []), { ...payment, id: uuidv4() }]
      })),
      updateRegularPayment: (id, updates) => set((state) => ({
        regularPayments: (state.regularPayments || []).map(p => p.id === id ? { ...p, ...updates } : p)
      })),
      deleteRegularPayment: (id) => set((state) => ({
        regularPayments: (state.regularPayments || []).filter(p => p.id !== id)
      })),

      addEnvelope: (envelope) => set((state) => ({
        envelopes: [...(state.envelopes || []), { ...envelope, id: uuidv4() }]
      })),
      updateEnvelope: (id, updates) => set((state) => ({
        envelopes: (state.envelopes || []).map(e => e.id === id ? { ...e, ...updates } : e)
      })),
      deleteEnvelope: (id) => set((state) => ({
        envelopes: (state.envelopes || []).filter(e => e.id !== id)
      })),

      processRegularPayment: (id, accountId) => set((state) => {
        const payment = (state.regularPayments || []).find(p => p.id === id);
        const account = (state.accounts || []).find(a => a.id === accountId);
        if (!payment || !account) return state;

        let finalAmount = payment.amount;
        if (payment.currency && payment.currency !== account.currency) {
          const fromRate = state.rates[payment.currency] || 1;
          const toRate = state.rates[account.currency] || 1;
          finalAmount = (payment.amount * fromRate) / toRate;
        }

        const transaction: Transaction = {
          id: uuidv4(),
          type: 'expense',
          amount: finalAmount,
          category: payment.category,
          date: new Date().toISOString().split('T')[0],
          notes: `Автоплатеж: ${payment.name}`,
          accountId
        };

        return {
          transactions: [transaction, ...(state.transactions || [])]
        };
      }),

      checkRegularPayments: () => set((state) => {
        const today = new Date();
        const currentDay = today.getDate();
        const currentMonthTx = (state.transactions || []).filter(t => 
          isSameMonth(parseISO(t.date), today)
        );

        const newTransactions: Transaction[] = [];
        const defaultAccountId = state.accounts?.[0]?.id;
        const defaultAccount = state.accounts?.[0];

        if (!defaultAccountId || !defaultAccount) return state;

        (state.regularPayments || []).forEach(p => {
          if (!p.isActive) return;
          
          const isPaid = currentMonthTx.some(t => t.notes?.includes(`Автоплатеж: ${p.name}`));
          if (!isPaid && p.dueDate <= currentDay) {
            let finalAmount = p.amount;
            if (p.currency && p.currency !== defaultAccount.currency) {
              const fromRate = state.rates[p.currency] || 1;
              const toRate = state.rates[defaultAccount.currency] || 1;
              finalAmount = (p.amount * fromRate) / toRate;
            }

            newTransactions.push({
              id: uuidv4(),
              type: 'expense',
              amount: finalAmount,
              category: p.category,
              date: today.toISOString().split('T')[0],
              notes: `Автоплатеж: ${p.name}`,
              accountId: defaultAccountId
            });
          }
        });

        if (newTransactions.length === 0) return state;

        return {
          transactions: [...newTransactions, ...(state.transactions || [])]
        };
      }),

      addPriceHistory: (item) => set((state) => ({
        priceHistory: [...(state.priceHistory || []), { ...item, id: uuidv4() }]
      })),
      deletePriceHistory: (id) => set((state) => ({
        priceHistory: (state.priceHistory || []).filter(p => p.id !== id)
      })),

      addGoal: (goal) => set((state) => ({
        goals: [...(state.goals || []), { ...goal, id: uuidv4(), createdAt: new Date().toISOString() }]
      })),
      updateGoal: (id, updates) => set((state) => ({
        goals: (state.goals || []).map(g => g.id === id ? { ...g, ...updates } : g)
      })),
      deleteGoal: (id) => set((state) => ({
        goals: (state.goals || []).filter(g => g.id !== id)
      })),
      addGoalStep: (goalId, step) => set((state) => ({
        goals: (state.goals || []).map(g => {
          if (g.id === goalId) {
            return {
              ...g,
              steps: [...(g.steps || []), { ...step, id: uuidv4() }]
            };
          }
          return g;
        })
      })),
      updateGoalStep: (goalId, stepId, updates) => set((state) => ({
        goals: (state.goals || []).map(g => {
          if (g.id === goalId) {
            return {
              ...g,
              steps: (g.steps || []).map(s => s.id === stepId ? { ...s, ...updates } : s)
            };
          }
          return g;
        })
      })),
      deleteGoalStep: (goalId, stepId) => set((state) => ({
        goals: (state.goals || []).map(g => {
          if (g.id === goalId) {
            return {
              ...g,
              steps: (g.steps || []).filter(s => s.id !== stepId)
            };
          }
          return g;
        })
      })),
      addGoalLog: (log) => set((state) => ({
        goalLogs: [...(state.goalLogs || []), { ...log, id: uuidv4() }]
      })),
      deleteGoalLog: (id) => set((state) => ({
        goalLogs: (state.goalLogs || []).filter(l => l.id !== id)
      })),
      updateWorkSchedule: (schedule) => set({ workSchedule: schedule }),
      addVacation: (vacation) => set((state) => {
        if (!state.workSchedule) return state;
        return {
          workSchedule: {
            ...state.workSchedule,
            vacations: [...(state.workSchedule.vacations || []), { ...vacation, id: uuidv4() }]
          }
        };
      }),
      deleteVacation: (id) => set((state) => {
        if (!state.workSchedule) return state;
        return {
          workSchedule: {
            ...state.workSchedule,
            vacations: (state.workSchedule.vacations || []).filter(v => v.id !== id)
          }
        };
      }),

      logWater: (amount) => set((state) => {
        const now = new Date();
        const date = format(now, 'yyyy-MM-dd');
        const timestamp = now.toISOString();
        return {
          waterLogs: [...(state.waterLogs || []), { id: uuidv4(), date, timestamp, amount }]
        };
      }),
      deleteWaterLog: (id) => set((state) => ({
        waterLogs: (state.waterLogs || []).filter(l => l.id !== id)
      })),
      setWaterGoal: (goal) => set({ waterGoal: goal }),
      setWaterIncrement: (increment) => set({ waterIncrement: increment }),
      setWaterVisualization: (type) => set({ waterVisualization: type }),

      setWealthTreeTarget: (target) => set({ wealthTreeTarget: target }),

      addInboxItem: (content) => set((state) => ({
        inboxItems: [{ id: uuidv4(), content, createdAt: new Date().toISOString() }, ...(state.inboxItems || [])]
      })),
      deleteInboxItem: (id) => set((state) => ({
        inboxItems: (state.inboxItems || []).filter(item => item.id !== id)
      })),

      logSleep: (log) => set((state) => {
        const existing = (state.sleepLogs || []).find(l => l.date === log.date);
        if (existing) {
          return {
            sleepLogs: state.sleepLogs.map(l => l.date === log.date ? { ...l, ...log } : l)
          };
        }
        return {
          sleepLogs: [...(state.sleepLogs || []), { ...log, id: uuidv4() }]
        };
      }),
      deleteSleepLog: (id) => set((state) => ({
        sleepLogs: (state.sleepLogs || []).filter(l => l.id !== id)
      })),

      // Shopping List
      addShoppingItem: (item) => set((state) => ({
        shoppingItems: [...(state.shoppingItems || []), { 
          ...item, 
          id: uuidv4(), 
          createdAt: new Date().toISOString(),
          completed: false 
        }]
      })),
      updateShoppingItem: (id, updates) => set((state) => ({
        shoppingItems: (state.shoppingItems || []).map(item => item.id === id ? { ...item, ...updates } : item)
      })),
      deleteShoppingItem: (id) => set((state) => ({
        shoppingItems: (state.shoppingItems || []).filter(item => item.id !== id)
      })),
      toggleShoppingItem: (id) => set((state) => ({
        shoppingItems: (state.shoppingItems || []).map(item => {
          if (item.id === id) {
            const completed = !item.completed;
            return { 
              ...item, 
              completed,
              completedAt: completed ? new Date().toISOString() : undefined
            };
          }
          return item;
        })
      })),
      clearCompletedShoppingItems: () => set((state) => ({
        shoppingItems: (state.shoppingItems || []).filter(item => !item.completed)
      })),
      addShoppingCategory: (category) => set((state) => ({
        shoppingCategories: [...(state.shoppingCategories || []), { ...category, id: uuidv4() }]
      })),
      updateShoppingCategory: (id, updates) => set((state) => ({
        shoppingCategories: (state.shoppingCategories || []).map(c => c.id === id ? { ...c, ...updates } : c)
      })),
      deleteShoppingCategory: (id) => set((state) => ({
        shoppingCategories: (state.shoppingCategories || []).filter(c => c.id !== id),
        shoppingItems: (state.shoppingItems || []).map(item => item.category === id ? { ...item, category: 'other' } : item)
      })),

      addSavingsGoal: (goal) => set((state) => ({
        savingsGoals: [...(state.savingsGoals || []), { ...goal, id: uuidv4(), createdAt: new Date().toISOString(), isCompleted: false }]
      })),
      updateSavingsGoal: (id, updates) => set((state) => ({
        savingsGoals: (state.savingsGoals || []).map(g => g.id === id ? { ...g, ...updates } : g)
      })),
      deleteSavingsGoal: (id) => set((state) => ({
        savingsGoals: (state.savingsGoals || []).filter(g => g.id !== id)
      })),
      addSavingsContribution: (id, amount) => set((state) => ({
        savingsGoals: (state.savingsGoals || []).map(g => {
          if (g.id === id) {
            const newAmount = g.currentAmount + amount;
            return { ...g, currentAmount: newAmount, isCompleted: newAmount >= g.targetAmount };
          }
          return g;
        })
      })),

      logDailyActivity: (activity) => set((state) => {
        const existing = (state.dailyActivities || []).find(a => a.date === activity.date);
        if (existing) {
          return {
            dailyActivities: (state.dailyActivities || []).map(a => 
              a.date === activity.date ? { ...a, ...activity } : a
            )
          };
        }
        return {
          dailyActivities: [...(state.dailyActivities || []), { ...activity, id: uuidv4() }]
        };
      }),

      deleteDailyActivity: (id) => set((state) => ({
        dailyActivities: (state.dailyActivities || []).filter(a => a.id !== id)
      })),

      updatePomodoro: (updates) => set((state) => ({
        pomodoro: { ...state.pomodoro, ...updates }
      })),
      updatePomodoroSettings: (settings) => set((state) => {
        const currentSettings = state.pomodoro?.settings || {
          workTime: 25,
          shortBreakTime: 5,
          longBreakTime: 15,
          soundEnabled: true
        };
        return {
          pomodoro: {
            ...state.pomodoro,
            settings: { ...currentSettings, ...settings }
          }
        };
      }),
      startPomodoro: (type) => set((state) => {
        const settings = state.pomodoro?.settings || {
          workTime: 25,
          shortBreakTime: 5,
          longBreakTime: 15,
          soundEnabled: true
        };
        const times = {
          work: settings.workTime * 60,
          shortBreak: settings.shortBreakTime * 60,
          longBreak: settings.longBreakTime * 60
        };
        return {
          pomodoro: {
            ...state.pomodoro,
            type,
            timeLeft: times[type],
            totalTime: times[type],
            isRunning: true
          }
        };
      }),
      tickPomodoro: () => set((state) => {
        if (!state.pomodoro.isRunning || state.pomodoro.timeLeft <= 0) return state;
        const newTime = state.pomodoro.timeLeft - 1;
        if (newTime === 0) {
          return {
            pomodoro: {
              ...state.pomodoro,
              timeLeft: 0,
              isRunning: false,
              sessionsCompleted: state.pomodoro.type === 'work' 
                ? state.pomodoro.sessionsCompleted + 1 
                : state.pomodoro.sessionsCompleted
            }
          };
        }
        return {
          pomodoro: {
            ...state.pomodoro,
            timeLeft: newTime
          }
        };
      }),
      resetPomodoro: () => set((state) => ({
        pomodoro: {
          ...state.pomodoro,
          timeLeft: state.pomodoro.totalTime,
          isRunning: false
        }
      })),

      toggleHideHabitNames: () => set((state) => ({
        hideHabitNames: !state.hideHabitNames
      })),

      updateDashboardConfig: (config) => set((state) => ({
        dashboardConfig: { ...state.dashboardConfig, ...config }
      })),
      reorderDashboardWidgets: (order) => set((state) => ({
        dashboardConfig: { ...state.dashboardConfig, widgetsOrder: order }
      })),
      updateModuleSettings: (settings) => set((state) => ({
        enabledModules: { ...state.enabledModules, ...settings }
      })),

      // Timer
      timer: {
        timeLeft: 90,
        initialTime: 90,
        isRunning: false,
        isOpen: false,
      },
      setTimer: (timer) => set((state) => ({ timer: { ...state.timer, ...timer } })),
      startTimer: (seconds) => set((state) => ({ 
        timer: { 
          ...state.timer, 
          timeLeft: seconds, 
          initialTime: seconds, 
          isRunning: true, 
          isOpen: true 
        } 
      })),
      stopTimer: () => set((state) => ({ timer: { ...state.timer, isRunning: false } })),
      resetTimer: () => set((state) => ({ timer: { ...state.timer, timeLeft: state.timer.initialTime, isRunning: false } })),
    }),
    {
      name: 'vibesight-storage',
      storage: createJSONStorage(() => storage),
      partialize: (state) => {
        const { isLocked, ...rest } = state;
        return rest;
      },
    }
  )
);
