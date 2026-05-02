import React, { useState } from 'react';
import { useStore } from '../store/useStore';
import { Plus, Trash2, X, Activity, AlertCircle, CheckCircle2, XCircle, MinusCircle, History, Target, Flame, Zap, Pin, PinOff, GripVertical, Eye, EyeOff, BookOpen, Grid as GridIcon } from 'lucide-react';
import { HabitType, HabitFrequency, Habit } from '../types';
import { HABIT_TEMPLATES } from '../data/habitTemplates';
import { cn } from '../lib/utils';
import { format, getDay, subDays, isSameDay, parseISO, startOfWeek as dfStartOfWeek, addDays as dfAddDays, addWeeks as dfAddWeeks, differenceInCalendarDays } from 'date-fns';
import { ru } from 'date-fns/locale';
import { motion, AnimatePresence } from 'framer-motion';
import {
  LineChart as RechartsLineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer
} from 'recharts';
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  DragEndEvent,
} from '@dnd-kit/core';
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  verticalListSortingStrategy,
  useSortable,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';

interface SortableHabitProps {
  habit: Habit;
  selectedDate: string;
  log: any;
  streak: { current: number; max: number };
  onTogglePin: (id: string, isPinned: boolean) => void;
  onDelete: (id: string) => void;
  onLog: (log: any) => void;
  onToggleHistory: (id: string) => void;
  isHistoryExpanded: boolean;
  habitLogs: any[];
}

function SortableHabit({ 
  habit, 
  selectedDate, 
  log, 
  streak, 
  onTogglePin, 
  onDelete, 
  onLog, 
  onToggleHistory, 
  isHistoryExpanded,
  habitLogs 
}: SortableHabitProps) {
  const { hideHabitNames } = useStore();
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: habit.id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    zIndex: isDragging ? 50 : 'auto',
  };

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={cn(
        "bg-white rounded-3xl border border-stone-200 overflow-hidden relative group transition-shadow",
        isDragging && "shadow-2xl shadow-black/50 border-stone-300"
      )}
    >
      <div className="p-5">
        <div className="flex items-start justify-between mb-4">
          <div className="flex items-start gap-3 flex-1">
            <div 
              {...attributes} 
              {...listeners}
              className="cursor-grab active:cursor-grabbing p-1 text-zinc-600 hover:text-zinc-500 transition-colors mt-1"
            >
              <GripVertical className="w-4 h-4" />
            </div>
            <div className="flex-1">
              <div className="flex items-center gap-2 mb-1">
                <h3 className="text-lg font-bold text-zinc-900 flex items-center gap-2">
                  {hideHabitNames ? '***' : habit.title}
                  {habit.isPinned && <Pin className="w-3 h-3 text-emerald-500 fill-emerald-500" />}
                </h3>
                <div className="flex items-center gap-1 px-2 py-0.5 bg-orange-500/10 text-orange-400 rounded-full text-[10px] font-bold uppercase tracking-wider">
                  <Flame className="w-3 h-3 fill-current" />
                  {streak.current}
                </div>
              </div>
              {habit.description && (
                <p className="text-sm text-zinc-500">
                  {hideHabitNames ? '***' : habit.description}
                </p>
              )}
            </div>
          </div>
          <div className="flex items-center gap-1">
            <button
              onClick={() => onTogglePin(habit.id, !!habit.isPinned)}
              className={cn(
                "transition-colors p-2 rounded-xl",
                habit.isPinned ? "text-emerald-500 bg-emerald-500/10" : "text-zinc-500 hover:text-zinc-700"
              )}
            >
              {habit.isPinned ? <PinOff className="w-4 h-4" /> : <Pin className="w-4 h-4" />}
            </button>
            <button
              onClick={() => onDelete(habit.id)}
              className="p-2 text-zinc-500 hover:text-rose-400 transition-colors"
            >
              <Trash2 className="w-4 h-4" />
            </button>
          </div>
        </div>

        <div className="flex gap-2 mb-4">
          <button
            onClick={() => onLog({ habitId: habit.id, date: selectedDate, status: 'done', notes: log?.notes || '', feelings: log?.feelings || '' })}
            className={cn(
              "flex-1 flex flex-col items-center justify-center gap-1 py-2 rounded-2xl border transition-colors",
              log?.status === 'done' ? "bg-emerald-500 border-emerald-400 text-zinc-900" : "bg-stone-50 border-stone-200 text-zinc-500 hover:bg-stone-100"
            )}
          >
            <CheckCircle2 className="w-5 h-5" />
            <span className="text-[10px] font-medium uppercase tracking-wider">
              {habit.type === 'good' ? 'Готово' : 'Сдержался'}
            </span>
          </button>
          <button
            onClick={() => onLog({ habitId: habit.id, date: selectedDate, status: 'failed', notes: log?.notes || '', feelings: log?.feelings || '' })}
            className={cn(
              "flex-1 flex flex-col items-center justify-center gap-1 py-2 rounded-2xl border transition-colors",
              log?.status === 'failed' ? "bg-rose-500 border-rose-400 text-zinc-900" : "bg-stone-50 border-stone-200 text-zinc-500 hover:bg-stone-100"
            )}
          >
            <XCircle className="w-5 h-5" />
            <span className="text-[10px] font-medium uppercase tracking-wider">
              {habit.type === 'good' ? 'Провал' : 'Сорвался'}
            </span>
          </button>
        </div>

        <div className="space-y-2">
          <input
            type="text"
            placeholder="Чувства / Ощущения..."
            value={log?.feelings || ''}
            onChange={(e) => onLog({ habitId: habit.id, date: selectedDate, status: log?.status || 'skipped', feelings: e.target.value, notes: log?.notes || '' })}
            className="w-full px-3 py-2 text-xs border border-stone-200 rounded-xl focus:ring-2 focus:ring-zinc-500 focus:border-zinc-500 bg-stone-50 text-zinc-900"
          />
          <textarea
            placeholder="Заметки..."
            value={log?.notes || ''}
            onChange={(e) => onLog({ habitId: habit.id, date: selectedDate, status: log?.status || 'skipped', notes: e.target.value, feelings: log?.feelings || '' })}
            className="w-full px-3 py-2 text-xs border border-stone-200 rounded-xl focus:ring-2 focus:ring-zinc-500 focus:border-zinc-500 bg-stone-50 text-zinc-900 h-16 resize-none"
          />
        </div>
        
        <div className="mt-4 pt-4 border-t border-stone-200">
          <h4 className="text-[10px] font-semibold text-zinc-500 uppercase tracking-wider mb-2">Активность за 30 дней</h4>
          <div className="h-24 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <RechartsLineChart data={Array.from({ length: 30 }).map((_, i) => {
                const d = new Date();
                d.setDate(d.getDate() - (29 - i));
                const dateStr = format(d, 'yyyy-MM-dd');
                const logEntry = habitLogs.find(l => l.habitId === habit.id && l.date === dateStr);
                let value = 0;
                if (logEntry) {
                  if (logEntry.status === 'done') value = 1;
                  else if (logEntry.status === 'failed') value = -1;
                }
                return {
                  date: format(d, 'dd MMM', { locale: ru }),
                  value
                };
              })}>
                <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                <XAxis dataKey="date" hide />
                <YAxis domain={[-1.5, 1.5]} hide />
                <Tooltip 
                  contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '8px', fontSize: '12px' }}
                  labelStyle={{ color: '#a1a1aa', marginBottom: '4px' }}
                  formatter={(value: number) => {
                    if (value === 1) return [habit.type === 'good' ? 'Выполнено' : 'Сдержался', 'Статус'];
                    if (value === -1) return [habit.type === 'good' ? 'Провал' : 'Сорвался', 'Статус'];
                    return ['Пропущено', 'Статус'];
                  }}
                />
                <Line 
                  type="stepAfter" 
                  dataKey="value" 
                  stroke={habit.type === 'good' ? '#10b981' : '#f43f5e'} 
                  strokeWidth={2} 
                  dot={false}
                  activeDot={{ r: 4, fill: habit.type === 'good' ? '#10b981' : '#f43f5e' }}
                />
              </RechartsLineChart>
            </ResponsiveContainer>
          </div>
        </div>
        
        <div className="pt-4 mt-2 border-t border-stone-200">
          <button
            onClick={() => onToggleHistory(habit.id)}
            className="flex items-center gap-2 text-xs text-zinc-500 hover:text-zinc-900 transition-colors w-full"
          >
            <History className="w-3.5 h-3.5" />
            {isHistoryExpanded ? 'Скрыть историю' : 'История записей'}
          </button>
          
          <AnimatePresence>
            {isHistoryExpanded && (
              <motion.div 
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                className="mt-3 space-y-3 overflow-hidden"
              >
                {habitLogs
                  .filter(l => l.habitId === habit.id && (l.notes || l.feelings))
                  .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())
                  .map(historyLog => (
                    <div key={historyLog.id} className="bg-stone-50 p-3 rounded-xl border border-stone-200">
                      <div className="flex justify-between items-start mb-2">
                        <span className="text-xs font-medium text-zinc-700">
                          {format(new Date(historyLog.date), 'd MMM yyyy', { locale: ru })}
                        </span>
                        <span className={cn(
                          "text-[10px] px-2 py-0.5 rounded-full font-medium uppercase tracking-wider",
                          historyLog.status === 'done' ? "bg-emerald-500/10 text-emerald-400" :
                          historyLog.status === 'failed' ? "bg-red-500/10 text-red-400" :
                          "bg-stone-100 text-zinc-500"
                        )}>
                          {historyLog.status === 'done' ? (habit.type === 'good' ? 'Готово' : 'Сдержался') :
                           historyLog.status === 'failed' ? (habit.type === 'good' ? 'Провал' : 'Сорвался') :
                           'Пропуск'}
                        </span>
                      </div>
                      {historyLog.feelings && (
                        <div className="mb-1.5">
                          <span className="text-[10px] text-zinc-500 uppercase tracking-wider block mb-0.5">Чувства:</span>
                          <p className="text-xs text-zinc-700">{historyLog.feelings}</p>
                        </div>
                      )}
                      {historyLog.notes && (
                        <div>
                          <span className="text-[10px] text-zinc-500 uppercase tracking-wider block mb-0.5">Заметки:</span>
                          <p className="text-xs text-zinc-700 whitespace-pre-wrap">{historyLog.notes}</p>
                        </div>
                      )}
                    </div>
                  ))}
                {habitLogs.filter(l => l.habitId === habit.id && (l.notes || l.feelings)).length === 0 && (
                  <p className="text-xs text-zinc-500 text-center py-2">Нет записей с заметками или чувствами.</p>
                )}
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </div>
    </div>
  );
}

interface HabitYearHeatmapProps {
  habit: Habit;
  logs: ReturnType<typeof Object.values>;
}

function HabitYearHeatmap({ habit, logs }: { habit: Habit; logs: { date: string; status: string }[] }) {
  const today = new Date();
  // Start = 52 weeks ago, aligned to Monday
  const start = dfStartOfWeek(dfAddWeeks(today, -52), { weekStartsOn: 1 });
  const totalDays = differenceInCalendarDays(today, start) + 1;
  const weeks = Math.ceil(totalDays / 7);

  const dateStatus = new Map<string, string>();
  logs.forEach((l) => dateStatus.set(l.date, l.status));

  // Build columns (weeks) x rows (Mon..Sun)
  const cells: { date: string; status?: string; future: boolean }[][] = [];
  for (let w = 0; w < weeks; w++) {
    const col: { date: string; status?: string; future: boolean }[] = [];
    for (let d = 0; d < 7; d++) {
      const date = dfAddDays(start, w * 7 + d);
      const dateStr = format(date, 'yyyy-MM-dd');
      const future = date > today;
      col.push({
        date: dateStr,
        status: dateStatus.get(dateStr),
        future,
      });
    }
    cells.push(col);
  }

  const totalDone = logs.filter(l => l.status === 'done').length;
  const totalFailed = logs.filter(l => l.status === 'failed').length;

  return (
    <div className="bg-white p-4 rounded-3xl border border-stone-200">
      <div className="flex items-center justify-between mb-3 gap-2 flex-wrap">
        <div className="flex items-center gap-2">
          <GridIcon className="w-4 h-4 text-zinc-700" />
          <span className="text-sm font-medium text-zinc-900">{habit.title}</span>
          <span className={cn(
            "text-[10px] px-2 py-0.5 rounded-full font-medium",
            habit.type === 'good' ? "bg-emerald-50 text-emerald-700" : "bg-rose-50 text-rose-700"
          )}>
            {habit.type === 'good' ? '+' : '−'}
          </span>
        </div>
        <div className="flex items-center gap-3 text-[10px] text-zinc-500">
          <span><strong className="text-emerald-600">{totalDone}</strong> {habit.type === 'good' ? 'выполнено' : 'удержано'}</span>
          <span><strong className="text-rose-600">{totalFailed}</strong> {habit.type === 'good' ? 'провалено' : 'сорвался'}</span>
        </div>
      </div>
      <div className="overflow-x-auto pb-1">
        <div className="flex gap-[3px]">
          {cells.map((col, ci) => (
            <div key={ci} className="flex flex-col gap-[3px]">
              {col.map((cell) => {
                let bg = 'bg-stone-100';
                if (cell.future) bg = 'bg-stone-50';
                else if (cell.status === 'done') bg = habit.type === 'good' ? 'bg-emerald-500' : 'bg-emerald-400';
                else if (cell.status === 'failed') bg = 'bg-rose-400';
                else if (cell.status === 'skipped') bg = 'bg-stone-200';
                return (
                  <div
                    key={cell.date}
                    title={`${format(parseISO(cell.date), 'd MMM yyyy', { locale: ru })}: ${cell.status || 'нет данных'}`}
                    className={cn('w-[10px] h-[10px] rounded-[2px]', bg)}
                  />
                );
              })}
            </div>
          ))}
        </div>
      </div>
      <div className="flex items-center gap-2 mt-2 text-[10px] text-zinc-500">
        <span>Меньше</span>
        <div className="flex gap-[3px]">
          <div className="w-[10px] h-[10px] rounded-[2px] bg-stone-100" />
          <div className="w-[10px] h-[10px] rounded-[2px] bg-emerald-200" />
          <div className="w-[10px] h-[10px] rounded-[2px] bg-emerald-400" />
          <div className="w-[10px] h-[10px] rounded-[2px] bg-emerald-500" />
        </div>
        <span>Больше</span>
      </div>
    </div>
  );
}

function StreakAndRateMetrics({ habit, logs }: { habit: Habit; logs: { date: string; status: string }[] }) {
  // Calculate current/best streak
  const today = new Date();
  const todayStr = format(today, 'yyyy-MM-dd');
  const doneSet = new Set(logs.filter(l => l.status === 'done').map(l => l.date));

  let current = 0;
  let cursor = doneSet.has(todayStr) ? today : subDays(today, 1);
  while (doneSet.has(format(cursor, 'yyyy-MM-dd'))) {
    current++;
    cursor = subDays(cursor, 1);
  }
  if (!doneSet.has(format(today, 'yyyy-MM-dd')) && !doneSet.has(format(subDays(today, 1), 'yyyy-MM-dd'))) {
    current = 0;
  }

  let max = 0;
  const sortedDates = [...doneSet].sort();
  let streak = 0;
  let prev: Date | null = null;
  for (const dStr of sortedDates) {
    const d = parseISO(dStr);
    if (prev && differenceInCalendarDays(d, prev) === 1) {
      streak++;
    } else {
      streak = 1;
    }
    max = Math.max(max, streak);
    prev = d;
  }

  // Completion rates
  const calcRate = (days: number) => {
    let done = 0;
    for (let i = 0; i < days; i++) {
      const dStr = format(subDays(today, i), 'yyyy-MM-dd');
      if (doneSet.has(dStr)) done++;
    }
    return Math.round((done / days) * 100);
  };

  return (
    <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 mt-2">
      <div className="bg-emerald-50 border border-emerald-200 rounded-xl p-2 text-center">
        <div className="text-lg font-bold text-emerald-700 flex items-center justify-center gap-1">
          <Flame className="w-4 h-4" />
          {current}
        </div>
        <div className="text-[10px] text-emerald-600 uppercase tracking-wider">Текущая</div>
      </div>
      <div className="bg-amber-50 border border-amber-200 rounded-xl p-2 text-center">
        <div className="text-lg font-bold text-amber-700 flex items-center justify-center gap-1">
          <Zap className="w-4 h-4" />
          {max}
        </div>
        <div className="text-[10px] text-amber-600 uppercase tracking-wider">Лучшая</div>
      </div>
      <div className="bg-blue-50 border border-blue-200 rounded-xl p-2 text-center">
        <div className="text-lg font-bold text-blue-700">{calcRate(30)}%</div>
        <div className="text-[10px] text-blue-600 uppercase tracking-wider">30 дней</div>
      </div>
      <div className="bg-indigo-50 border border-indigo-200 rounded-xl p-2 text-center">
        <div className="text-lg font-bold text-indigo-700">{calcRate(90)}%</div>
        <div className="text-[10px] text-indigo-600 uppercase tracking-wider">90 дней</div>
      </div>
    </div>
  );
}

function HabitHistoryView() {
  const { habits, habitLogs, hideHabitNames } = useStore();
  
  const today = new Date();
  const last30Days = Array.from({ length: 30 }).map((_, i) => {
    const d = new Date(today);
    d.setDate(d.getDate() - (29 - i));
    return format(d, 'yyyy-MM-dd');
  });
  
  const thirtyDaysAgo = new Date(today);
  thirtyDaysAgo.setDate(today.getDate() - 30);
  
  const stats = habits.map(habit => {
    const logs = habitLogs.filter(l => l.habitId === habit.id && new Date(l.date) >= thirtyDaysAgo);
    const doneCount = logs.filter(l => l.status === 'done').length;
    const failedCount = logs.filter(l => l.status === 'failed').length;
    const totalLogs = logs.length;
    const completionRate = totalLogs > 0 ? Math.round((doneCount / totalLogs) * 100) : 0;
    
    return {
      ...habit,
      doneCount,
      failedCount,
      totalLogs,
      completionRate
    };
  });

  return (
    <div className="space-y-4">
      {stats.map(habit => (
        <div key={habit.id} className="space-y-3">
          <HabitYearHeatmap habit={habit} logs={habitLogs.filter(l => l.habitId === habit.id) as any} />
          <StreakAndRateMetrics habit={habit} logs={habitLogs.filter(l => l.habitId === habit.id) as any} />
          <div className="bg-white p-5 rounded-3xl border border-stone-200">
          <div className="flex justify-between items-start mb-4">
            <div>
              <div className="flex items-center gap-2 mb-1">
                <h3 className="text-lg font-bold text-zinc-900">{hideHabitNames ? '***' : habit.title}</h3>
                <span className={cn(
                  "text-[10px] px-2 py-0.5 rounded-full font-medium uppercase tracking-wider",
                  habit.type === 'good' ? "bg-emerald-500/10 text-emerald-400" : "bg-rose-500/10 text-rose-400"
                )}>
                  {habit.type === 'good' ? 'Хорошая' : 'Вредная'}
                </span>
              </div>
              <p className="text-sm text-zinc-500">{hideHabitNames ? '***' : (habit.description || 'Нет описания')}</p>
            </div>
            <div className="text-right">
              <div className="text-2xl font-bold text-zinc-900">{habit.completionRate}%</div>
              <div className="text-[10px] text-zinc-500 uppercase tracking-wider">Успешность (30 дн.)</div>
            </div>
          </div>
          
          <div className="grid grid-cols-3 gap-4 pt-4 border-t border-stone-200">
            <div className="text-center">
              <div className="text-emerald-500 font-bold">{habit.doneCount}</div>
              <div className="text-[10px] text-zinc-500 uppercase tracking-wider">
                {habit.type === 'good' ? 'Выполнено' : 'Сдержался'}
              </div>
            </div>
            <div className="text-center">
              <div className="text-rose-500 font-bold">{habit.failedCount}</div>
              <div className="text-[10px] text-zinc-500 uppercase tracking-wider">
                {habit.type === 'good' ? 'Провалено' : 'Сорвался'}
              </div>
            </div>
            <div className="text-center">
              <div className="text-zinc-500 font-bold">{habit.totalLogs}</div>
              <div className="text-[10px] text-zinc-500 uppercase tracking-wider">Дней с записями</div>
            </div>
          </div>

          <div className="mt-6 pt-4 border-t border-stone-200">
            <h4 className="text-xs font-medium text-zinc-500 mb-3">Активность за 30 дней (прогресс)</h4>
            <div className="flex flex-wrap gap-1.5 mt-3">
              {last30Days.map(day => {
                const log = habitLogs.find(l => l.habitId === habit.id && l.date === day);
                let colorClass = "bg-stone-100/60 border border-stone-200"; // default/skipped
                if (log?.status === 'done') {
                  colorClass = "bg-emerald-500 border-emerald-600"; // done is good/resisted
                } else if (log?.status === 'failed') {
                  colorClass = "bg-rose-500 border-rose-600"; // failed is bad/gave in
                }
                
                return (
                  <div 
                    key={day} 
                    className={cn("w-4 h-4 rounded-sm transition-colors", colorClass)}
                    title={`${format(new Date(day), 'd MMM', { locale: ru })}: ${log?.status === 'done' ? (habit.type === 'good' ? 'Готово' : 'Сдержался') : log?.status === 'failed' ? (habit.type === 'good' ? 'Провал' : 'Сорвался') : 'Нет данных'}`}
                  />
                );
              })}
            </div>
          </div>
          </div>
        </div>
      ))}
      {stats.length === 0 && (
        <div className="text-center py-12 bg-white/60 rounded-3xl border border-stone-200 border-dashed">
          <p className="text-zinc-500">Нет привычек для отображения статистики</p>
        </div>
      )}
    </div>
  );
}

export function Habits() {
  const { habits, habitLogs, addHabit, deleteHabit, logHabit, updateHabit, reorderHabits, hideHabitNames, toggleHideHabitNames } = useStore();
  const [activeTab, setActiveTab] = useState<'daily' | 'history'>('daily');
  const [isAdding, setIsAdding] = useState(false);
  const [activeType, setActiveType] = useState<HabitType>('good');
  const [selectedDate, setSelectedDate] = useState(format(new Date(), 'yyyy-MM-dd'));
  
  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        distance: 8,
      },
    }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  );

  const calculateStreak = (habit: Habit) => {
    const logs = habitLogs
      .filter(l => l.habitId === habit.id && l.status === 'done')
      .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

    if (logs.length === 0) return { current: 0, max: 0 };

    let current = 0;
    let max = 0;
    
    // Calculate Max Streak
    const sortedLogs = [...logs].sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
    if (sortedLogs.length > 0) {
      let streak = 1;
      max = 1;
      for (let i = 1; i < sortedLogs.length; i++) {
        const prev = parseISO(sortedLogs[i-1].date);
        const curr = parseISO(sortedLogs[i].date);
        const diff = Math.round((curr.getTime() - prev.getTime()) / (1000 * 60 * 60 * 24));
        
        if (diff === 1) {
          streak++;
        } else if (diff > 1) {
          streak = 1;
        }
        max = Math.max(max, streak);
      }
    }

    // Calculate Current Streak
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    let checkDate = today;
    
    const doneToday = logs.some(l => l.date === format(today, 'yyyy-MM-dd'));
    const doneYesterday = logs.some(l => l.date === format(subDays(today, 1), 'yyyy-MM-dd'));
    
    if (!doneToday && !doneYesterday) {
      current = 0;
    } else {
      if (!doneToday) checkDate = subDays(today, 1);
      
      while (true) {
        const dateStr = format(checkDate, 'yyyy-MM-dd');
        const hasLog = logs.some(l => l.date === dateStr);
        if (hasLog) {
          current++;
          checkDate = subDays(checkDate, 1);
        } else {
          break;
        }
      }
    }

    return { current, max };
  };

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [frequencyType, setFrequencyType] = useState<'daily' | 'specific_days' | 'times_per_week'>('daily');
  const [specificDays, setSpecificDays] = useState<number[]>([]);
  const [timesPerWeek, setTimesPerWeek] = useState<number>(3);
  const [isQuantitative, setIsQuantitative] = useState(false);
  const [targetValue, setTargetValue] = useState<number>(1);
  const [unit, setUnit] = useState<string>('');
  
  const [expandedHistory, setExpandedHistory] = useState<Record<string, boolean>>({});
  const [showTemplates, setShowTemplates] = useState(false);

  const toggleHistory = (habitId: string) => {
    setExpandedHistory(prev => ({ ...prev, [habitId]: !prev[habitId] }));
  };

  const handleAddTemplate = (tpl: { title: string; type: HabitType; icon?: string; targetValue?: number; unit?: string; frequency?: HabitFrequency }) => {
    addHabit({
      title: tpl.title,
      type: tpl.type,
      icon: tpl.icon,
      targetValue: tpl.targetValue,
      unit: tpl.unit,
      frequency: tpl.frequency || { type: 'daily' },
    });
  };

  const filteredHabits = habits.filter(h => {
    if (h.type !== activeType) return false;
    
    if (h.frequency?.type === 'specific_days' && h.frequency.days) {
      const dayOfWeek = getDay(new Date(selectedDate));
      if (!h.frequency.days.includes(dayOfWeek)) {
        return false;
      }
    }
    return true;
  });

  const sortedHabits = [...filteredHabits].sort((a, b) => {
    if (a.isPinned && !b.isPinned) return -1;
    if (!a.isPinned && b.isPinned) return 1;
    return (a.order ?? 0) - (b.order ?? 0);
  });

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;

    if (over && active.id !== over.id) {
      const oldIndex = sortedHabits.findIndex(h => h.id === active.id);
      const newIndex = sortedHabits.findIndex(h => h.id === over.id);
      const newOrder = arrayMove(sortedHabits, oldIndex, newIndex);
      reorderHabits(newOrder.map(h => h.id));
    }
  };

  const togglePin = (id: string, isPinned: boolean) => {
    updateHabit(id, { isPinned: !isPinned });
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    addHabit({
      title,
      description,
      type: activeType,
      frequency: {
        type: frequencyType,
        days: frequencyType === 'specific_days' ? specificDays : undefined,
        count: frequencyType === 'times_per_week' ? timesPerWeek : undefined,
      },
      targetValue: isQuantitative ? targetValue : undefined,
      unit: isQuantitative ? unit : undefined,
    });

    setTitle('');
    setDescription('');
    setIsAdding(false);
  };

  const daysOfWeek = [
    { id: 1, label: 'Пн' },
    { id: 2, label: 'Вт' },
    { id: 3, label: 'Ср' },
    { id: 4, label: 'Чт' },
    { id: 5, label: 'Пт' },
    { id: 6, label: 'Сб' },
    { id: 0, label: 'Вс' },
  ];

  return (
    <div className="space-y-6 pb-24">
      <header className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-zinc-900 mb-2">Привычки</h1>
          <p className="text-zinc-500">Формируй полезные и избавляйся от вредных</p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={toggleHideHabitNames}
            className="p-3 bg-white text-zinc-500 rounded-2xl hover:bg-stone-100 hover:text-zinc-700 transition-colors border border-stone-200"
            title={hideHabitNames ? "Показать названия" : "Скрыть названия"}
          >
            {hideHabitNames ? <EyeOff className="w-6 h-6" /> : <Eye className="w-6 h-6" />}
          </button>
          <button
            onClick={() => setShowTemplates(true)}
            className="p-3 bg-white text-emerald-600 rounded-2xl hover:bg-emerald-50 transition-colors border border-emerald-200"
            title="Шаблоны привычек"
          >
            <BookOpen className="w-6 h-6" />
          </button>
          <button
            onClick={() => setIsAdding(true)}
            className="p-3 bg-emerald-500 text-zinc-900 rounded-2xl hover:bg-emerald-600 transition-colors shadow-lg shadow-emerald-500/20"
          >
            <Plus className="w-6 h-6" />
          </button>
        </div>
      </header>

      <AnimatePresence>
        {showTemplates && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 bg-black/40 backdrop-blur-sm flex items-end sm:items-center justify-center p-0 sm:p-4"
            onClick={() => setShowTemplates(false)}
          >
            <motion.div
              initial={{ y: 40, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              exit={{ y: 40, opacity: 0 }}
              className="bg-white rounded-t-3xl sm:rounded-3xl border border-stone-200 max-w-2xl w-full max-h-[85vh] overflow-y-auto"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="sticky top-0 bg-white border-b border-stone-200 p-4 flex items-center justify-between rounded-t-3xl z-10">
                <h3 className="font-semibold text-zinc-900 flex items-center gap-2">
                  <BookOpen className="w-4 h-4 text-emerald-600" />
                  Шаблоны привычек
                </h3>
                <button onClick={() => setShowTemplates(false)} className="text-zinc-500 hover:text-zinc-900">
                  <X className="w-4 h-4" />
                </button>
              </div>
              <div className="p-4 space-y-4">
                <p className="text-xs text-zinc-500">
                  Готовые «атомные» привычки по областям жизни. Тапни — и привычка появится в твоём списке.
                </p>
                {HABIT_TEMPLATES.map((cat) => (
                  <div key={cat.id} className="space-y-2">
                    <div className="flex items-center gap-2">
                      <span className="text-2xl">{cat.emoji}</span>
                      <div>
                        <h4 className="font-semibold text-zinc-900 text-sm">{cat.title}</h4>
                        <p className="text-[11px] text-zinc-500">{cat.blurb}</p>
                      </div>
                    </div>
                    <div className="flex flex-wrap gap-1.5">
                      {cat.templates.map((tpl, i) => (
                        <button
                          key={i}
                          onClick={() => handleAddTemplate(tpl)}
                          className={cn(
                            "px-2.5 py-1.5 rounded-xl text-xs font-medium border transition-all flex items-center gap-1.5",
                            tpl.type === 'good'
                              ? "bg-emerald-50 text-emerald-800 border-emerald-200 hover:bg-emerald-100"
                              : "bg-rose-50 text-rose-800 border-rose-200 hover:bg-rose-100"
                          )}
                        >
                          <span>{tpl.icon}</span>
                          <span>{tpl.title}</span>
                          <Plus className="w-3 h-3 opacity-60" />
                        </button>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Main Tabs */}
      <div className="flex bg-white p-1 rounded-xl">
        <button
          onClick={() => setActiveTab('daily')}
          className={cn(
            "flex-1 py-2 text-sm font-medium rounded-lg transition-all",
            activeTab === 'daily' ? "bg-stone-100 text-zinc-900 shadow-sm" : "text-zinc-500 hover:text-zinc-700"
          )}
        >
          Сегодня
        </button>
        <button
          onClick={() => setActiveTab('history')}
          className={cn(
            "flex-1 py-2 text-sm font-medium rounded-lg transition-all",
            activeTab === 'history' ? "bg-stone-100 text-zinc-900 shadow-sm" : "text-zinc-500 hover:text-zinc-700"
          )}
        >
          История
        </button>
      </div>

      {activeTab === 'daily' ? (
        <>
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between bg-white p-3 rounded-2xl shadow-sm border border-stone-200 gap-3">
            <div className="flex space-x-1 bg-stone-50 p-1 rounded-xl w-full sm:w-auto">
              <button
                onClick={() => setActiveType('good')}
                className={cn(
                  'flex-1 sm:flex-none px-3 py-1.5 rounded-lg text-xs font-medium transition-all',
                  activeType === 'good'
                    ? 'bg-emerald-500 text-zinc-900 shadow-sm'
                    : 'text-zinc-500 hover:text-zinc-800'
                )}
              >
                Хорошие
              </button>
              <button
                onClick={() => setActiveType('bad')}
                className={cn(
                  'flex-1 sm:flex-none px-3 py-1.5 rounded-lg text-xs font-medium transition-all',
                  activeType === 'bad'
                    ? 'bg-rose-500 text-zinc-900 shadow-sm'
                    : 'text-zinc-500 hover:text-zinc-800'
                )}
              >
                Вредные
              </button>
            </div>
            
            <div className="flex items-center gap-2 w-full sm:w-auto">
              <label className="text-xs font-medium text-zinc-500">Дата:</label>
              <input
                type="date"
                value={selectedDate}
                onChange={(e) => setSelectedDate(e.target.value)}
                className="flex-1 sm:flex-none px-2 py-1.5 bg-stone-50 border border-stone-200 text-zinc-900 rounded-xl focus:ring-2 focus:ring-zinc-500 focus:border-zinc-500 text-xs"
              />
            </div>
          </div>

          {isAdding && (
            <div className="bg-white p-5 rounded-3xl shadow-sm border border-stone-200">
              <div className="flex justify-between items-center mb-4">
                <h2 className="text-base font-semibold text-zinc-900">Новая {activeType === 'good' ? 'хорошая' : 'вредная'} привычка</h2>
                <button onClick={() => setIsAdding(false)} className="text-zinc-500 hover:text-zinc-700">
                  <X className="w-4 h-4" />
                </button>
              </div>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label className="block text-xs font-medium text-zinc-700 mb-1">Название</label>
                  <input
                    type="text"
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    className="w-full px-3 py-2 text-sm bg-stone-50 border border-stone-200 text-zinc-900 rounded-xl focus:ring-2 focus:ring-zinc-500 focus:border-zinc-500"
                    placeholder={activeType === 'good' ? "напр., Читать 10 страниц" : "напр., Курение"}
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-zinc-700 mb-1">Описание (необязательно)</label>
                  <input
                    type="text"
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    className="w-full px-3 py-2 text-sm bg-stone-50 border border-stone-200 text-zinc-900 rounded-xl focus:ring-2 focus:ring-zinc-500 focus:border-zinc-500"
                  />
                </div>

                {activeType === 'good' && (
                  <>
                    <div className="space-y-3 pt-2 border-t border-stone-200">
                      <label className="block text-xs font-medium text-zinc-700">Расписание</label>
                      <div className="flex flex-wrap gap-2">
                        <button
                          type="button"
                          onClick={() => setFrequencyType('daily')}
                          className={cn(
                            "px-3 py-1.5 rounded-lg text-xs font-medium transition-all",
                            frequencyType === 'daily' ? "bg-zinc-100 text-zinc-900" : "bg-stone-50 text-zinc-500 border border-stone-200"
                          )}
                        >
                          Ежедневно
                        </button>
                        <button
                          type="button"
                          onClick={() => setFrequencyType('specific_days')}
                          className={cn(
                            "px-3 py-1.5 rounded-lg text-xs font-medium transition-all",
                            frequencyType === 'specific_days' ? "bg-zinc-100 text-zinc-900" : "bg-stone-50 text-zinc-500 border border-stone-200"
                          )}
                        >
                          По дням
                        </button>
                      </div>

                      {frequencyType === 'specific_days' && (
                        <div className="flex gap-1">
                          {daysOfWeek.map(day => (
                            <button
                              key={day.id}
                              type="button"
                              onClick={() => {
                                setSpecificDays(prev => 
                                  prev.includes(day.id) 
                                    ? prev.filter(d => d !== day.id)
                                    : [...prev, day.id]
                                );
                              }}
                              className={cn(
                                "w-8 h-8 rounded-lg text-[10px] font-bold transition-all",
                                specificDays.includes(day.id) ? "bg-emerald-500 text-zinc-900" : "bg-stone-50 text-zinc-500 border border-stone-200"
                              )}
                            >
                              {day.label}
                            </button>
                          ))}
                        </div>
                      )}
                    </div>
                  </>
                )}

                <button
                  type="submit"
                  className="w-full py-3 bg-white text-black rounded-2xl font-bold text-sm hover:bg-zinc-200 transition-colors"
                >
                  Создать привычку
                </button>
              </form>
            </div>
          )}

          <DndContext
            sensors={sensors}
            collisionDetection={closestCenter}
            onDragEnd={handleDragEnd}
          >
            <SortableContext
              items={sortedHabits.map(h => h.id)}
              strategy={verticalListSortingStrategy}
            >
              <div className="space-y-4">
                {sortedHabits.length === 0 ? (
                  <div className="text-center py-12 bg-white/60 rounded-3xl border border-stone-200 border-dashed">
                    <p className="text-zinc-500">Нет привычек на этот день</p>
                  </div>
                ) : (
                  sortedHabits.map(habit => {
                    const log = habitLogs.find(l => l.habitId === habit.id && l.date === selectedDate);
                    const streak = calculateStreak(habit);
                    
                    return (
                      <SortableHabit
                        key={habit.id}
                        habit={habit}
                        selectedDate={selectedDate}
                        log={log}
                        streak={streak}
                        onTogglePin={togglePin}
                        onDelete={deleteHabit}
                        onLog={logHabit}
                        onToggleHistory={toggleHistory}
                        isHistoryExpanded={!!expandedHistory[habit.id]}
                        habitLogs={habitLogs}
                      />
                    );
                  })
                )}
              </div>
            </SortableContext>
          </DndContext>
        </>
      ) : (
        <HabitHistoryView />
      )}
    </div>
  );
}
