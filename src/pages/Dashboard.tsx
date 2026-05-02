import React, { useState, useMemo, useEffect } from 'react';
import { useStore } from '../store/useStore';
import { format, subDays, addDays, isSameDay, isWithinInterval, parseISO, differenceInCalendarDays, startOfDay } from 'date-fns';
import { ru } from 'date-fns/locale';
import { CheckCircle2, Circle, XCircle, Target, Activity, ArrowRight, ChevronLeft, ChevronRight, MinusCircle, Plus, Minus, TrendingUp, ChevronDown, ChevronUp, X, Sun, Moon, Coffee, Home as HomeIcon, Calendar, Plane, Award, Dumbbell, Flame, Zap, GripVertical, Eye, EyeOff, LayoutGrid, Clock, ShoppingCart, Wallet, ListChecks } from 'lucide-react';
import { Link } from 'react-router-dom';
import { cn } from '../lib/utils';
import { motion, AnimatePresence } from 'motion/react';
import { WaterWidget } from '../components/WaterWidget';
import { PomodoroWidget } from '../components/PomodoroWidget';
import { InboxWidget } from '../components/InboxWidget';
import { SleepRecoveryWidget } from '../components/SleepRecoveryWidget';
import { NextWorkoutWidget } from '../components/NextWorkoutWidget';
import { DisciplineScoreWidget, StoicQuoteWidget } from '../components/MasculineWidgets';
import { DashboardWidget } from '../types';
import { useDashboardStats } from '../hooks/useDashboardStats';
import { SmartGreeting } from '../components/dashboard/SmartGreeting';
import { TasksHabitsWidget } from '../components/dashboard/TasksHabitsWidget';
import { GoalsWidget } from '../components/dashboard/GoalsWidget';
import { ActivityTrendsWidget } from '../components/dashboard/ActivityTrendsWidget';
import { ActivityCalendarWidget } from '../components/dashboard/ActivityCalendarWidget';
import { FinanceHubWidget } from '../components/dashboard/FinanceHubWidget';
import { MonthBudgetWidget } from '../components/dashboard/MonthBudgetWidget';
import { UpcomingDeadlinesWidget } from '../components/dashboard/UpcomingDeadlinesWidget';
import { HabitMatrixWidget } from '../components/dashboard/HabitMatrixWidget';
import { ShoppingListWidget } from '../components/dashboard/ShoppingListWidget';
import { EfficiencyWidget } from '../components/dashboard/EfficiencyWidget';
import { TrendsWidget } from '../components/dashboard/TrendsWidget';
import { StatsGridWidget } from '../components/dashboard/StatsGridWidget';
import { OverviewWidget } from '../components/dashboard/OverviewWidget';
import { SpheresHubWidget } from '../components/dashboard/SpheresHubWidget';
import { HabitStoriesWidget } from '../components/dashboard/HabitStoriesWidget';
import { SmartScheduleWidget } from '../components/dashboard/SmartScheduleWidget';
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  TouchSensor,
  useSensor,
  useSensors,
  DragEndEvent,
  rectIntersection,
} from '@dnd-kit/core';
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  rectSortingStrategy,
  useSortable,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import { Maximize2, Minimize2 } from 'lucide-react';

interface SortableWidgetProps {
  id: string;
  children: React.ReactNode;
  isEditMode: boolean;
  onToggleVisibility?: () => void;
  isVisible?: boolean;
  size?: 'small' | 'large';
  onToggleSize?: () => void;
}

const SortableWidget = ({ id, children, isEditMode, onToggleVisibility, isVisible = true, size = 'large', onToggleSize }: SortableWidgetProps) => {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    zIndex: isDragging ? 50 : 'auto',
    opacity: isVisible ? 1 : 0.4,
  };

  return (
    <div 
      ref={setNodeRef} 
      style={style} 
      className={cn(
        "relative group", 
        !isVisible && "hidden",
        size === 'large' ? "md:col-span-2" : "md:col-span-1"
      )}
    >
      {isEditMode && (
        <div className="absolute top-2 right-2 z-10 flex gap-2 bg-white/80 backdrop-blur-sm p-1 rounded-xl border border-stone-300 shadow-lg">
          <button
            onClick={onToggleSize}
            className="p-1.5 bg-stone-100 rounded-lg text-zinc-500 hover:text-zinc-900 transition-colors"
            title={size === 'large' ? "Уменьшить" : "Увеличить"}
          >
            {size === 'large' ? <Minimize2 className="w-3.5 h-3.5" /> : <Maximize2 className="w-3.5 h-3.5" />}
          </button>
          <button
            onClick={onToggleVisibility}
            className="p-1.5 bg-stone-100 rounded-lg text-zinc-500 hover:text-zinc-900 transition-colors"
            title={isVisible ? "Скрыть" : "Показать"}
          >
            {isVisible ? <Eye className="w-3.5 h-3.5" /> : <EyeOff className="w-3.5 h-3.5" />}
          </button>
          <div
            {...attributes}
            {...listeners}
            className="p-1.5 bg-stone-100 rounded-lg text-zinc-500 hover:text-zinc-900 cursor-grab active:cursor-grabbing transition-colors touch-none"
            title="Перетащить"
          >
            <GripVertical className="w-3.5 h-3.5" />
          </div>
        </div>
      )}
      {children}
    </div>
  );
};

export function Dashboard() {
  const { 
    tasks, habits, habitLogs, toggleTaskCompletion, toggleTaskFailure, logHabit, addTask, 
    spheres, goals, updateGoal, addGoalStep, updateGoalStep, deleteGoalStep, 
    workSchedule, exerciseLogs, workoutNodes, dashboardConfig, updateDashboardConfig, 
    reorderDashboardWidgets, bodyMeasurements, transactions, accounts, budgetLimits, shoppingItems, shoppingCategories, savingsGoals,
    reorderTasks, reorderHabits
  } = useStore();
  const [currentDate, setCurrentDate] = useState(new Date());
  const [direction, setDirection] = useState(0);

  const [isAddingTask, setIsAddingTask] = useState(false);
  const [newTaskTitle, setNewTaskTitle] = useState('');
  const [newTaskSphere, setNewTaskSphere] = useState('');
  const [expandedGoalId, setExpandedGoalId] = useState<string | null>(null);
  const [isEditMode, setIsEditMode] = useState(false);
  const [showMoreShopping, setShowMoreShopping] = useState(false);

  // Sync missing widgets into the dashboard configuration (for existing users)
  useEffect(() => {
    if (!dashboardConfig?.widgetsOrder || !dashboardConfig?.visibleWidgets) return;

    const ALL_WIDGETS: DashboardWidget[] = [
      'smart_schedule', 'efficiency', 'trends', 'stats_grid', 'overview', 
      'spheres_hub', 'goals', 'tasks_habits', 'water', 
      'activity_trends', 'habit_stories', 'activity_calendar', 'finance_hub', 'monthly_budget',
      'upcoming_deadlines', 'habit_matrix', 'pomodoro', 'inbox', 'next_workout', 'sleep_recovery',
      'discipline_score', 'stoic_quote', 'shopping_list'
    ];
    
    // Remove old widgets from config if they exist
    const oldWidgets = ['finance_summary', 'net_worth', 'piggy_bank', 'spheres_charts', 'spheres_progress', 'daily_efficiency'];
    let currentOrder = dashboardConfig.widgetsOrder.filter(id => !oldWidgets.includes(id));
    let currentVisible = dashboardConfig.visibleWidgets.filter(id => !oldWidgets.includes(id));

    const missingWidgets = ALL_WIDGETS.filter(id => !currentOrder.includes(id));
    if (missingWidgets.length > 0 || oldWidgets.some(id => dashboardConfig.widgetsOrder.includes(id as any))) {
      updateDashboardConfig({
        widgetsOrder: [...currentOrder, ...missingWidgets],
        visibleWidgets: [...currentVisible, ...missingWidgets]
      });
    }
  }, [dashboardConfig?.widgetsOrder, dashboardConfig?.visibleWidgets, updateDashboardConfig]);

  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        distance: 10,
      },
    }),
    useSensor(TouchSensor, {
      activationConstraint: {
        delay: 100,
        tolerance: 10,
      },
    }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  );

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;

    if (over && active.id !== over.id && dashboardConfig?.widgetsOrder) {
      const oldIndex = dashboardConfig.widgetsOrder.indexOf(active.id as any);
      const newIndex = dashboardConfig.widgetsOrder.indexOf(over.id as any);
      const newOrder = arrayMove(dashboardConfig.widgetsOrder, oldIndex, newIndex);
      reorderDashboardWidgets(newOrder);
    }
  };

  const toggleWidgetVisibility = (widgetId: any) => {
    if (!dashboardConfig?.visibleWidgets) return;
    const isVisible = dashboardConfig.visibleWidgets.includes(widgetId);
    let newVisibleWidgets;
    if (isVisible) {
      newVisibleWidgets = dashboardConfig.visibleWidgets.filter(w => w !== widgetId);
    } else {
      newVisibleWidgets = [...dashboardConfig.visibleWidgets, widgetId];
    }
    updateDashboardConfig({ visibleWidgets: newVisibleWidgets });
  };

  const toggleWidgetSize = (widgetId: string) => {
    if (!dashboardConfig) return;
    const currentSizes = dashboardConfig.widgetSizes || {};
    const currentSize = currentSizes[widgetId] || 'large';
    const newSize = currentSize === 'large' ? 'small' : 'large';
    
    updateDashboardConfig({
      widgetSizes: {
        ...currentSizes,
        [widgetId]: newSize
      }
    });
  };

  const [efficiencyTrendDays, setEfficiencyTrendDays] = useState<7 | 30>(7);

  const dateStr = format(currentDate, 'yyyy-MM-dd');
  const isToday = isSameDay(currentDate, new Date());

  const goodHabits = habits.filter(h => h.type === 'good');
  const badHabits = habits.filter(h => h.type === 'bad');

  const {
    last30Days,
    recentWorkout,
    habitStreaks,
    financeStats,
    upcomingDeadlines,
    habitMatrix,
    sphereBalance,
    efficiencyStats,
    tasksBySphere,
    tasksByStatus,
    currentShift,
    todaysTasks
  } = useDashboardStats(currentDate);

  const handlePrevDay = () => {
    setDirection(-1);
    setCurrentDate(prev => subDays(prev, 1));
  };

  const handleNextDay = () => {
    setDirection(1);
    setCurrentDate(prev => addDays(prev, 1));
  };

  const handleHabitLog = (habitId: string, status: 'done' | 'failed' | 'skipped') => {
    logHabit({
      habitId,
      date: dateStr,
      status,
      notes: '',
      feelings: ''
    });
  };

  const handleAddTask = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTaskTitle.trim()) return;
    
    addTask({
      title: newTaskTitle,
      period: 'day',
      date: dateStr,
      sphereId: newTaskSphere || undefined
    });
    
    setNewTaskTitle('');
    setNewTaskSphere('');
    setIsAddingTask(false);
  };

  const totalTasks = todaysTasks.length;
  const completedTasks = todaysTasks.filter(t => t.completed).length;
  const failedTasks = todaysTasks.filter(t => t.failed).length;
  const taskProgress = totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0;

  const totalGoodHabits = goodHabits.length;
  const doneGoodHabits = goodHabits.filter(h => {
    const log = habitLogs.find(l => l.habitId === h.id && l.date === dateStr);
    return log?.status === 'done';
  }).length;
  const goodHabitProgress = totalGoodHabits > 0 ? Math.round((doneGoodHabits / totalGoodHabits) * 100) : 0;

  const totalBadHabits = badHabits.length;
  const resistedBadHabits = badHabits.filter(h => {
    const log = habitLogs.find(l => l.habitId === h.id && l.date === dateStr);
    return log?.status === 'done'; // 'done' means resisted for bad habits
  }).length;
  const badHabitProgress = totalBadHabits > 0 ? Math.round((resistedBadHabits / totalBadHabits) * 100) : 0;

  let scoreComponents = 0;
  let totalScore = 0;
  if (totalTasks > 0) { totalScore += taskProgress; scoreComponents++; }
  if (totalGoodHabits > 0) { totalScore += goodHabitProgress; scoreComponents++; }
  if (totalBadHabits > 0) { totalScore += badHabitProgress; scoreComponents++; }
  const overallProgress = scoreComponents > 0 ? Math.round(totalScore / scoreComponents) : 0;

  const calculateProgress = (goal: any) => {
    if (goal.type === 'book' && goal.totalPages) {
      return Math.round(((goal.readPages || 0) / goal.totalPages) * 100);
    }
    if (goal.steps && goal.steps.length > 0) {
      const completed = goal.steps.filter((s: any) => s.completed).length;
      return Math.round((completed / goal.steps.length) * 100);
    }
    return goal.progress || 0;
  };

  const dashboardGoals = goals.filter(g => g.showOnDashboard && g.status !== 'completed');

  const { weeklyAvg: weeklyEfficiency, monthlyAvg: monthlyEfficiency, last7DaysEffData, last30DaysEffData } = efficiencyStats;
  const efficiencyTrend = efficiencyTrendDays === 7 ? last7DaysEffData : last30DaysEffData;

  const dailyEfficiency = overallProgress;

  const variants = {
    enter: (direction: number) => {
      return {
        x: direction > 0 ? 1000 : -1000,
        opacity: 0
      };
    },
    center: {
      zIndex: 1,
      x: 0,
      opacity: 1
    },
    exit: (direction: number) => {
      return {
        zIndex: 0,
        x: direction < 0 ? 1000 : -1000,
        opacity: 0
      };
    }
  };

  const renderWidget = (id: string) => {
    switch (id) {
      case 'smart_schedule':
        return <SmartScheduleWidget />;
      case 'efficiency':
        return (
          <EfficiencyWidget
            weeklyEfficiency={weeklyEfficiency}
            monthlyEfficiency={monthlyEfficiency}
          />
        );
      case 'trends':
        return (
          <TrendsWidget
            efficiencyTrend={efficiencyTrend}
            efficiencyTrendDays={efficiencyTrendDays}
            setEfficiencyTrendDays={setEfficiencyTrendDays}
          />
        );
      case 'stats_grid':
        return (
          <StatsGridWidget
            recentWorkout={recentWorkout}
            habitStreaks={habitStreaks}
            sphereBalance={sphereBalance}
          />
        );
      case 'overview':
        return (
          <OverviewWidget
            dailyEfficiency={dailyEfficiency}
            todaysTasks={todaysTasks}
            habitLogs={habitLogs}
            dateStr={dateStr}
            totalTasks={totalTasks}
            completedTasks={completedTasks}
            taskProgress={taskProgress}
            totalGoodHabits={totalGoodHabits}
            doneGoodHabits={doneGoodHabits}
            goodHabitProgress={goodHabitProgress}
            totalBadHabits={totalBadHabits}
            resistedBadHabits={resistedBadHabits}
            badHabitProgress={badHabitProgress}
          />
        );
      case 'spheres_hub':
        return (
          <SpheresHubWidget
            tasksBySphere={tasksBySphere}
            tasksByStatus={tasksByStatus}
            spheres={spheres}
            tasks={tasks}
          />
        );
      case 'goals':
        return (
          <GoalsWidget
            goals={goals}
            updateGoal={updateGoal}
            updateGoalStep={updateGoalStep}
            addGoalStep={addGoalStep}
          />
        );
      case 'activity_trends':
        return <ActivityTrendsWidget last30Days={last30Days} />;
      case 'tasks_habits':
        return (
          <TasksHabitsWidget
            todaysTasks={todaysTasks}
            totalTasks={totalTasks}
            completedTasks={completedTasks}
            taskProgress={taskProgress}
            goodHabits={goodHabits}
            badHabits={badHabits}
            habitLogs={habitLogs}
            spheres={spheres}
            dateStr={dateStr}
            toggleTaskCompletion={toggleTaskCompletion}
            toggleTaskFailure={toggleTaskFailure}
            reorderTasks={reorderTasks}
            reorderHabits={reorderHabits}
            logHabit={handleHabitLog}
            addTask={addTask}
          />
        );
      case 'habit_stories':
        return (
          <HabitStoriesWidget
            habits={habits}
            habitLogs={habitLogs}
            dateStr={dateStr}
            handleHabitLog={handleHabitLog}
          />
        );
      case 'activity_calendar':
        return <ActivityCalendarWidget last30Days={last30Days} />;
      case 'water':
        return <WaterWidget />;
      case 'finance_hub':
        return <FinanceHubWidget financeStats={financeStats} />;
      case 'monthly_budget':
        return <MonthBudgetWidget />;
      case 'upcoming_deadlines':
        return <UpcomingDeadlinesWidget upcomingDeadlines={upcomingDeadlines} />;
      case 'habit_matrix':
        return <HabitMatrixWidget habitMatrix={habitMatrix} />;
      case 'pomodoro':
        return <PomodoroWidget />;
      case 'inbox':
        return <InboxWidget />;
      case 'sleep_recovery':
        return <SleepRecoveryWidget />;
      case 'next_workout':
        return <NextWorkoutWidget />;
      case 'discipline_score':
        return <DisciplineScoreWidget />;
      case 'stoic_quote':
        return <StoicQuoteWidget />;
      case 'shopping_list':
        return <ShoppingListWidget shoppingItems={shoppingItems} shoppingCategories={shoppingCategories} />;
      default:
        return null;
    }
  };

  const SHIFT_INFO = {
    day: { label: 'День', icon: Sun, color: 'text-amber-500 bg-amber-500/10 border-amber-500/20' },
    night: { label: 'Ночь', icon: Moon, color: 'text-indigo-400 bg-indigo-500/10 border-indigo-500/20' },
    off: { label: 'Выходной', icon: HomeIcon, color: 'text-zinc-500 bg-stone-100/60 border-stone-300/50' },
    post_night: { label: 'Отсыпной', icon: Coffee, color: 'text-emerald-400 bg-emerald-500/10 border-emerald-500/20' },
    vacation: { label: 'Отпуск', icon: Plane, color: 'text-rose-400 bg-rose-500/10 border-rose-500/20' },
  };

  return (
    <div className="space-y-6">
      <SmartGreeting currentDate={currentDate} todaysTasks={todaysTasks} />

      {/* Quick Actions row — главные действия в один тап */}
      <div className="grid grid-cols-4 gap-2 sm:gap-3 -mt-2">
        {[
          { to: '/tasks', icon: ListChecks, label: 'Задача', color: 'from-emerald-500 to-emerald-600', shadow: 'shadow-emerald-500/30' },
          { to: '/finance', icon: Wallet, label: 'Расход', color: 'from-amber-500 to-orange-600', shadow: 'shadow-orange-500/30' },
          { to: '/workouts', icon: Dumbbell, label: 'Спорт', color: 'from-blue-500 to-indigo-600', shadow: 'shadow-blue-500/30' },
          { to: '/habits', icon: Flame, label: 'Навык', color: 'from-rose-500 to-pink-600', shadow: 'shadow-rose-500/30' },
        ].map(action => (
          <Link
            key={action.to}
            to={action.to}
            className={cn(
              'group flex flex-col items-center justify-center gap-1.5 px-2 py-3 sm:py-3.5 rounded-2xl text-white font-semibold text-[11px] sm:text-xs',
              'bg-gradient-to-br shadow-md transition-transform active:scale-95',
              action.color,
              action.shadow,
            )}
          >
            <action.icon className="w-5 h-5 sm:w-6 sm:h-6 shrink-0 transition-transform group-hover:scale-110" />
            <span className="leading-none">{action.label}</span>
          </Link>
        ))}
      </div>

      <div className="flex items-center justify-between">
        <div className="min-w-0">
          <h1 className="text-lg sm:text-xl font-extrabold tracking-tight text-zinc-900">
            С возвращением
          </h1>
          <p className="text-xs text-zinc-500 mt-0.5">
            Обзор на {format(new Date(), 'd MMMM', { locale: ru })}
          </p>
        </div>
        <button
          onClick={() => setIsEditMode(!isEditMode)}
          className={cn(
            "px-3 py-1.5 rounded-2xl text-xs font-semibold transition-all flex items-center gap-1.5 shrink-0",
            isEditMode ? "bg-emerald-600 text-white shadow-md shadow-emerald-500/30" : "bg-white text-zinc-600 border border-stone-200 hover:text-emerald-700 hover:border-emerald-300"
          )}
        >
          {isEditMode ? <CheckCircle2 className="w-4 h-4" /> : <LayoutGrid className="w-4 h-4" />}
          {isEditMode ? "Готово" : "Настроить"}
        </button>
      </div>

      <div className="flex items-center justify-between bg-white p-2.5 rounded-2xl border border-stone-200">
        <button 
          onClick={handlePrevDay}
          className="p-1.5 text-zinc-500 hover:text-zinc-900 hover:bg-stone-100 rounded-full transition-colors"
        >
          <ChevronLeft className="w-4 h-4" />
        </button>
        <div className="flex items-center gap-4">
          <div className="text-center">
            <h2 className="text-sm font-semibold text-zinc-900 capitalize">
              {format(currentDate, 'EEEE', { locale: ru })}
            </h2>
            <p className="text-[10px] text-zinc-500">
              {format(currentDate, 'd MMMM yyyy', { locale: ru })}
            </p>
          </div>
          {currentShift && (
            <Link 
              to="/work-schedule"
              className={cn(
                "flex items-center gap-2 px-3 py-1 rounded-full border text-[10px] font-bold uppercase tracking-wider transition-all hover:scale-105",
                SHIFT_INFO[currentShift].color
              )}
            >
              {React.createElement(SHIFT_INFO[currentShift].icon, { className: "w-3 h-3" })}
              {SHIFT_INFO[currentShift].label}
            </Link>
          )}
        </div>
        <button 
          onClick={handleNextDay}
          className="p-1.5 text-zinc-500 hover:text-zinc-900 hover:bg-stone-100 rounded-full transition-colors"
        >
          <ChevronRight className="w-4 h-4" />
        </button>
      </div>

      <DndContext
        sensors={sensors}
        collisionDetection={rectIntersection}
        onDragEnd={handleDragEnd}
        autoScroll={true}
      >
        <SortableContext
          items={dashboardConfig.widgetsOrder}
          strategy={rectSortingStrategy}
        >
          <AnimatePresence initial={false} custom={direction} mode="wait">
            <motion.div
              key={dateStr}
              custom={direction}
              variants={variants}
              initial="enter"
              animate="center"
              exit="exit"
              transition={{
                x: { type: "spring", stiffness: 300, damping: 30 },
                opacity: { duration: 0.2 }
              }}
              className="grid grid-cols-1 md:grid-cols-2 gap-4"
            >
              {dashboardConfig.widgetsOrder.map((id) => (
                <SortableWidget
                  key={id}
                  id={id}
                  isEditMode={isEditMode}
                  isVisible={dashboardConfig.visibleWidgets.includes(id)}
                  onToggleVisibility={() => toggleWidgetVisibility(id)}
                  size={dashboardConfig.widgetSizes?.[id] || 'large'}
                  onToggleSize={() => toggleWidgetSize(id)}
                >
                  {renderWidget(id)}
                </SortableWidget>
              ))}
            </motion.div>
          </AnimatePresence>
        </SortableContext>
      </DndContext>
    </div>
  );
}

