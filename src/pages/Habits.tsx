import React, { useState } from 'react';
import { useStore } from '../store/useStore';
import { Plus, Trash2, X, Activity, AlertCircle, CheckCircle2, XCircle, MinusCircle, History, Target, Flame, Zap, Pin, PinOff, GripVertical, Eye, EyeOff } from 'lucide-react';
import { HabitType, HabitFrequency, Habit } from '../types';
import { cn } from '../lib/utils';
import { format, getDay, subDays, isSameDay, parseISO } from 'date-fns';
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
        "bg-zinc-900 rounded-3xl border border-zinc-800 overflow-hidden relative group transition-shadow",
        isDragging && "shadow-2xl shadow-black/50 border-zinc-700"
      )}
    >
      <div className="p-5">
        <div className="flex items-start justify-between mb-4">
          <div className="flex items-start gap-3 flex-1">
            <div 
              {...attributes} 
              {...listeners}
              className="cursor-grab active:cursor-grabbing p-1 text-zinc-600 hover:text-zinc-400 transition-colors mt-1"
            >
              <GripVertical className="w-4 h-4" />
            </div>
            <div className="flex-1">
              <div className="flex items-center gap-2 mb-1">
                <h3 className="text-lg font-bold text-white flex items-center gap-2">
                  {hideHabitNames ? '***' : habit.title}
                  {habit.isPinned && <Pin className="w-3 h-3 text-emerald-500 fill-emerald-500" />}
                </h3>
                <div className="flex items-center gap-1 px-2 py-0.5 bg-orange-500/10 text-orange-400 rounded-full text-[10px] font-bold uppercase tracking-wider">
                  <Flame className="w-3 h-3 fill-current" />
                  {streak.current}
                </div>
              </div>
              {habit.description && (
                <p className="text-sm text-zinc-400">
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
                habit.isPinned ? "text-emerald-500 bg-emerald-500/10" : "text-zinc-500 hover:text-zinc-300"
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
              log?.status === 'done' ? "bg-emerald-500 border-emerald-400 text-white" : "bg-zinc-950 border-zinc-800 text-zinc-400 hover:bg-zinc-800"
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
              log?.status === 'failed' ? "bg-rose-500 border-rose-400 text-white" : "bg-zinc-950 border-zinc-800 text-zinc-400 hover:bg-zinc-800"
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
            className="w-full px-3 py-2 text-xs border border-zinc-800 rounded-xl focus:ring-2 focus:ring-zinc-500 focus:border-zinc-500 bg-zinc-950 text-white"
          />
          <textarea
            placeholder="Заметки..."
            value={log?.notes || ''}
            onChange={(e) => onLog({ habitId: habit.id, date: selectedDate, status: log?.status || 'skipped', notes: e.target.value, feelings: log?.feelings || '' })}
            className="w-full px-3 py-2 text-xs border border-zinc-800 rounded-xl focus:ring-2 focus:ring-zinc-500 focus:border-zinc-500 bg-zinc-950 text-white h-16 resize-none"
          />
        </div>
        
        <div className="mt-4 pt-4 border-t border-zinc-800">
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
        
        <div className="pt-4 mt-2 border-t border-zinc-800">
          <button
            onClick={() => onToggleHistory(habit.id)}
            className="flex items-center gap-2 text-xs text-zinc-400 hover:text-white transition-colors w-full"
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
                    <div key={historyLog.id} className="bg-zinc-950 p-3 rounded-xl border border-zinc-800">
                      <div className="flex justify-between items-start mb-2">
                        <span className="text-xs font-medium text-zinc-300">
                          {format(new Date(historyLog.date), 'd MMM yyyy', { locale: ru })}
                        </span>
                        <span className={cn(
                          "text-[10px] px-2 py-0.5 rounded-full font-medium uppercase tracking-wider",
                          historyLog.status === 'done' ? "bg-emerald-500/10 text-emerald-400" :
                          historyLog.status === 'failed' ? "bg-red-500/10 text-red-400" :
                          "bg-zinc-800 text-zinc-400"
                        )}>
                          {historyLog.status === 'done' ? (habit.type === 'good' ? 'Готово' : 'Сдержался') :
                           historyLog.status === 'failed' ? (habit.type === 'good' ? 'Провал' : 'Сорвался') :
                           'Пропуск'}
                        </span>
                      </div>
                      {historyLog.feelings && (
                        <div className="mb-1.5">
                          <span className="text-[10px] text-zinc-500 uppercase tracking-wider block mb-0.5">Чувства:</span>
                          <p className="text-xs text-zinc-300">{historyLog.feelings}</p>
                        </div>
                      )}
                      {historyLog.notes && (
                        <div>
                          <span className="text-[10px] text-zinc-500 uppercase tracking-wider block mb-0.5">Заметки:</span>
                          <p className="text-xs text-zinc-300 whitespace-pre-wrap">{historyLog.notes}</p>
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
        <div key={habit.id} className="bg-zinc-900 p-5 rounded-3xl border border-zinc-800">
          <div className="flex justify-between items-start mb-4">
            <div>
              <div className="flex items-center gap-2 mb-1">
                <h3 className="text-lg font-bold text-white">{hideHabitNames ? '***' : habit.title}</h3>
                <span className={cn(
                  "text-[10px] px-2 py-0.5 rounded-full font-medium uppercase tracking-wider",
                  habit.type === 'good' ? "bg-emerald-500/10 text-emerald-400" : "bg-rose-500/10 text-rose-400"
                )}>
                  {habit.type === 'good' ? 'Хорошая' : 'Вредная'}
                </span>
              </div>
              <p className="text-sm text-zinc-400">{hideHabitNames ? '***' : (habit.description || 'Нет описания')}</p>
            </div>
            <div className="text-right">
              <div className="text-2xl font-bold text-white">{habit.completionRate}%</div>
              <div className="text-[10px] text-zinc-500 uppercase tracking-wider">Успешность (30 дн.)</div>
            </div>
          </div>
          
          <div className="grid grid-cols-3 gap-4 pt-4 border-t border-zinc-800">
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
              <div className="text-zinc-400 font-bold">{habit.totalLogs}</div>
              <div className="text-[10px] text-zinc-500 uppercase tracking-wider">Дней с записями</div>
            </div>
          </div>

          <div className="mt-6 pt-4 border-t border-zinc-800">
            <h4 className="text-xs font-medium text-zinc-400 mb-3">Активность за 30 дней (прогресс)</h4>
            <div className="flex flex-wrap gap-1.5 mt-3">
              {last30Days.map(day => {
                const log = habitLogs.find(l => l.habitId === habit.id && l.date === day);
                let colorClass = "bg-zinc-800/50 border border-zinc-800"; // default/skipped
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
      ))}
      {stats.length === 0 && (
        <div className="text-center py-12 bg-zinc-900/50 rounded-3xl border border-zinc-800 border-dashed">
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

  const toggleHistory = (habitId: string) => {
    setExpandedHistory(prev => ({ ...prev, [habitId]: !prev[habitId] }));
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
          <h1 className="text-xl font-bold text-white mb-2">Привычки</h1>
          <p className="text-zinc-400">Формируй полезные и избавляйся от вредных</p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={toggleHideHabitNames}
            className="p-3 bg-zinc-900 text-zinc-400 rounded-2xl hover:bg-zinc-800 hover:text-zinc-300 transition-colors border border-zinc-800"
            title={hideHabitNames ? "Показать названия" : "Скрыть названия"}
          >
            {hideHabitNames ? <EyeOff className="w-6 h-6" /> : <Eye className="w-6 h-6" />}
          </button>
          <button
            onClick={() => setIsAdding(true)}
            className="p-3 bg-emerald-500 text-white rounded-2xl hover:bg-emerald-600 transition-colors shadow-lg shadow-emerald-500/20"
          >
            <Plus className="w-6 h-6" />
          </button>
        </div>
      </header>

      {/* Main Tabs */}
      <div className="flex bg-zinc-900 p-1 rounded-xl">
        <button
          onClick={() => setActiveTab('daily')}
          className={cn(
            "flex-1 py-2 text-sm font-medium rounded-lg transition-all",
            activeTab === 'daily' ? "bg-zinc-800 text-white shadow-sm" : "text-zinc-500 hover:text-zinc-300"
          )}
        >
          Сегодня
        </button>
        <button
          onClick={() => setActiveTab('history')}
          className={cn(
            "flex-1 py-2 text-sm font-medium rounded-lg transition-all",
            activeTab === 'history' ? "bg-zinc-800 text-white shadow-sm" : "text-zinc-500 hover:text-zinc-300"
          )}
        >
          История
        </button>
      </div>

      {activeTab === 'daily' ? (
        <>
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between bg-zinc-900 p-3 rounded-2xl shadow-sm border border-zinc-800 gap-3">
            <div className="flex space-x-1 bg-zinc-950 p-1 rounded-xl w-full sm:w-auto">
              <button
                onClick={() => setActiveType('good')}
                className={cn(
                  'flex-1 sm:flex-none px-3 py-1.5 rounded-lg text-xs font-medium transition-all',
                  activeType === 'good'
                    ? 'bg-emerald-500 text-white shadow-sm'
                    : 'text-zinc-400 hover:text-zinc-200'
                )}
              >
                Хорошие
              </button>
              <button
                onClick={() => setActiveType('bad')}
                className={cn(
                  'flex-1 sm:flex-none px-3 py-1.5 rounded-lg text-xs font-medium transition-all',
                  activeType === 'bad'
                    ? 'bg-rose-500 text-white shadow-sm'
                    : 'text-zinc-400 hover:text-zinc-200'
                )}
              >
                Вредные
              </button>
            </div>
            
            <div className="flex items-center gap-2 w-full sm:w-auto">
              <label className="text-xs font-medium text-zinc-400">Дата:</label>
              <input
                type="date"
                value={selectedDate}
                onChange={(e) => setSelectedDate(e.target.value)}
                className="flex-1 sm:flex-none px-2 py-1.5 bg-zinc-950 border border-zinc-800 text-white rounded-xl focus:ring-2 focus:ring-zinc-500 focus:border-zinc-500 text-xs"
              />
            </div>
          </div>

          {isAdding && (
            <div className="bg-zinc-900 p-5 rounded-3xl shadow-sm border border-zinc-800">
              <div className="flex justify-between items-center mb-4">
                <h2 className="text-base font-semibold text-white">Новая {activeType === 'good' ? 'хорошая' : 'вредная'} привычка</h2>
                <button onClick={() => setIsAdding(false)} className="text-zinc-500 hover:text-zinc-300">
                  <X className="w-4 h-4" />
                </button>
              </div>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label className="block text-xs font-medium text-zinc-300 mb-1">Название</label>
                  <input
                    type="text"
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    className="w-full px-3 py-2 text-sm bg-zinc-950 border border-zinc-800 text-white rounded-xl focus:ring-2 focus:ring-zinc-500 focus:border-zinc-500"
                    placeholder={activeType === 'good' ? "напр., Читать 10 страниц" : "напр., Курение"}
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-zinc-300 mb-1">Описание (необязательно)</label>
                  <input
                    type="text"
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    className="w-full px-3 py-2 text-sm bg-zinc-950 border border-zinc-800 text-white rounded-xl focus:ring-2 focus:ring-zinc-500 focus:border-zinc-500"
                  />
                </div>

                {activeType === 'good' && (
                  <>
                    <div className="space-y-3 pt-2 border-t border-zinc-800">
                      <label className="block text-xs font-medium text-zinc-300">Расписание</label>
                      <div className="flex flex-wrap gap-2">
                        <button
                          type="button"
                          onClick={() => setFrequencyType('daily')}
                          className={cn(
                            "px-3 py-1.5 rounded-lg text-xs font-medium transition-all",
                            frequencyType === 'daily' ? "bg-zinc-100 text-zinc-900" : "bg-zinc-950 text-zinc-400 border border-zinc-800"
                          )}
                        >
                          Ежедневно
                        </button>
                        <button
                          type="button"
                          onClick={() => setFrequencyType('specific_days')}
                          className={cn(
                            "px-3 py-1.5 rounded-lg text-xs font-medium transition-all",
                            frequencyType === 'specific_days' ? "bg-zinc-100 text-zinc-900" : "bg-zinc-950 text-zinc-400 border border-zinc-800"
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
                                specificDays.includes(day.id) ? "bg-emerald-500 text-white" : "bg-zinc-950 text-zinc-500 border border-zinc-800"
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
                  <div className="text-center py-12 bg-zinc-900/50 rounded-3xl border border-zinc-800 border-dashed">
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
