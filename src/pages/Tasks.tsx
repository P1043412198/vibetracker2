import React, { useState } from 'react';
import { useStore } from '../store/useStore';
import { Plus, CheckCircle2, XCircle, Circle, Trash2, X, Edit2, ChevronLeft, ChevronRight, GripVertical, ChevronDown, ChevronUp, Pin, PinOff, History, LayoutGrid, List, AlertTriangle, Clock, Coffee, Tag, Hash } from 'lucide-react';
import { TaskPeriod, Task, TaskPriority } from '../types';
import { cn } from '../lib/utils';
import { format, subDays, addDays, startOfWeek, endOfWeek, startOfMonth, endOfMonth, startOfYear, endOfYear, isWithinInterval, subWeeks, addWeeks, subMonths, addMonths, subYears, addYears } from 'date-fns';
import { ru } from 'date-fns/locale';
import { motion, AnimatePresence } from 'framer-motion';
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

export const PRIORITY_LABELS: Record<TaskPriority, string> = {
  urgent_important: 'Срочно + важно',
  important: 'Важно',
  urgent: 'Срочно',
  later: 'Не срочно',
};

export const PRIORITY_HINTS: Record<TaskPriority, string> = {
  urgent_important: 'Сделать сейчас',
  important: 'Запланировать',
  urgent: 'Делегировать или сделать быстро',
  later: 'Удалить или отложить',
};

export const PRIORITY_COLORS: Record<TaskPriority, { bg: string; text: string; border: string; ring: string }> = {
  urgent_important: { bg: 'bg-rose-50', text: 'text-rose-700', border: 'border-rose-200', ring: 'ring-rose-300' },
  important: { bg: 'bg-blue-50', text: 'text-blue-700', border: 'border-blue-200', ring: 'ring-blue-300' },
  urgent: { bg: 'bg-amber-50', text: 'text-amber-700', border: 'border-amber-200', ring: 'ring-amber-300' },
  later: { bg: 'bg-stone-50', text: 'text-zinc-600', border: 'border-stone-200', ring: 'ring-stone-300' },
};

const DEFAULT_CONTEXTS = ['@дом', '@работа', '@звонки', '@магазин', '@улица', '@компьютер'];

interface SortableTaskProps {
  task: Task;
  sphere: any;
  isExpanded: boolean;
  completedSubtasks: number;
  totalSubtasks: number;
  onToggleCompletion: (id: string) => void;
  onToggleFailure: (id: string) => void;
  onTogglePin: (id: string, isPinned: boolean) => void;
  onToggleExpand: (id: string) => void;
  onEdit: (task: any) => void;
  onDelete: (id: string) => void;
  onToggleSubtask: (taskId: string, subtaskId: string) => void;
  onDeleteSubtask: (taskId: string, subtaskId: string) => void;
  onAddSubtask: (e: React.FormEvent, taskId: string) => void;
  newSubtaskTitle: string;
  onNewSubtaskTitleChange: (taskId: string, title: string) => void;
}

function SortableTask({
  task,
  sphere,
  isExpanded,
  completedSubtasks,
  totalSubtasks,
  onToggleCompletion,
  onToggleFailure,
  onTogglePin,
  onToggleExpand,
  onEdit,
  onDelete,
  onToggleSubtask,
  onDeleteSubtask,
  onAddSubtask,
  newSubtaskTitle,
  onNewSubtaskTitleChange,
}: SortableTaskProps) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: task.id });

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
        "bg-white rounded-3xl border border-stone-200 flex flex-col hover:bg-stone-100/70 transition-colors relative overflow-hidden",
        isDragging && "shadow-2xl shadow-black/50 border-stone-300 z-50"
      )}
    >
      <div className="p-4 sm:p-5 flex flex-col sm:flex-row sm:items-center gap-3">
        <div className="absolute inset-y-0 left-0 w-1 bg-white opacity-0 transition-opacity" />
        <div className="flex items-start sm:items-center gap-3 flex-1">
          <div 
            {...attributes} 
            {...listeners}
            className="cursor-grab active:cursor-grabbing p-1 text-zinc-600 hover:text-zinc-500 transition-colors"
          >
            <GripVertical className="w-4 h-4" />
          </div>
          <div className="flex gap-1.5 mt-0.5 sm:mt-0">
            <button
              onClick={() => onToggleCompletion(task.id)}
              className={cn(
                "transition-colors",
                task.completed ? "text-zinc-900" : "text-zinc-600 hover:text-zinc-900"
              )}
            >
              {task.completed ? <CheckCircle2 className="w-5 h-5" /> : <Circle className="w-5 h-5" />}
            </button>
            <button
              onClick={() => onToggleFailure(task.id)}
              className={cn(
                "transition-colors",
                task.failed ? "text-zinc-500" : "text-zinc-700 hover:text-zinc-500"
              )}
            >
              {task.failed ? <XCircle className="w-5 h-5" /> : <XCircle className="w-5 h-5 opacity-50" />}
            </button>
          </div>
          
          <div className="flex-1">
            <div className="flex items-center gap-2">
              <p className={cn(
                "text-sm font-medium text-zinc-800",
                task.completed && "text-zinc-500 line-through",
                task.failed && "text-zinc-700 line-through"
              )}>
                {task.title}
                {task.isPinned && <Pin className="w-3 h-3 text-emerald-500 fill-emerald-500 inline ml-2" />}
              </p>
              {totalSubtasks > 0 && (
                <span className="text-[10px] font-medium px-1.5 py-0.5 rounded-md bg-stone-100 text-zinc-500">
                  {completedSubtasks}/{totalSubtasks}
                </span>
              )}
            </div>
            <div className="flex flex-wrap items-center gap-2 mt-1.5 text-[10px] text-zinc-500">
              <span>{format(new Date(task.date), 'd MMM yyyy', { locale: ru })}</span>
              {sphere && (
                <span className="bg-stone-100 text-zinc-700 px-1.5 py-0.5 rounded-md font-medium">
                  {sphere.title}
                </span>
              )}
              {task.priority && (
                <span className={cn(
                  "px-1.5 py-0.5 rounded-md font-medium border",
                  task.priority === 'urgent_important' && "bg-rose-50 text-rose-700 border-rose-200",
                  task.priority === 'important' && "bg-blue-50 text-blue-700 border-blue-200",
                  task.priority === 'urgent' && "bg-amber-50 text-amber-700 border-amber-200",
                  task.priority === 'later' && "bg-stone-50 text-zinc-600 border-stone-200"
                )}>
                  {PRIORITY_LABELS[task.priority]}
                </span>
              )}
              {task.context && (
                <span className="bg-indigo-50 text-indigo-700 border border-indigo-200 px-1.5 py-0.5 rounded-md font-medium">
                  {task.context}
                </span>
              )}
            </div>
          </div>
        </div>

        <div className="flex gap-1 sm:self-center self-end">
          <button
            onClick={() => onTogglePin(task.id, !!task.isPinned)}
            className={cn(
              "transition-colors p-1.5 rounded-xl",
              task.isPinned ? "text-emerald-500 bg-emerald-500/10" : "text-zinc-600 hover:text-zinc-900"
            )}
          >
            {task.isPinned ? <PinOff className="w-4 h-4" /> : <Pin className="w-4 h-4" />}
          </button>
          <button
            onClick={() => onToggleExpand(task.id)}
            className="text-zinc-600 hover:text-zinc-900 p-1.5 transition-colors"
          >
            {isExpanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
          </button>
          <button
            onClick={() => onEdit(task)}
            className="text-zinc-600 hover:text-zinc-900 p-1.5 transition-colors"
          >
            <Edit2 className="w-4 h-4" />
          </button>
          <button
            onClick={() => onDelete(task.id)}
            className="text-zinc-600 hover:text-zinc-500 p-1.5 transition-colors"
          >
            <Trash2 className="w-4 h-4" />
          </button>
        </div>
      </div>

      <AnimatePresence>
        {isExpanded && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            className="border-t border-stone-200/70 bg-white/30"
          >
            <div className="p-4 pl-12 space-y-2">
              {task.subtasks?.map(subtask => (
                <div key={subtask.id} className="flex items-center gap-3 group">
                  <button
                    onClick={() => onToggleSubtask(task.id, subtask.id)}
                    className={cn(
                      "transition-colors",
                      subtask.completed ? "text-blue-500" : "text-zinc-600 hover:text-blue-400"
                    )}
                  >
                    {subtask.completed ? <CheckCircle2 className="w-4 h-4" /> : <Circle className="w-4 h-4" />}
                  </button>
                  <span className={cn(
                    "flex-1 text-sm transition-colors",
                    subtask.completed ? "text-zinc-500 line-through" : "text-zinc-700"
                  )}>
                    {subtask.title}
                  </span>
                  <button
                    onClick={() => onDeleteSubtask(task.id, subtask.id)}
                    className="opacity-0 group-hover:opacity-100 p-1 text-zinc-600 hover:text-red-400 transition-all"
                  >
                    <X className="w-3 h-3" />
                  </button>
                </div>
              ))}
              
              <form onSubmit={(e) => onAddSubtask(e, task.id)} className="flex items-center gap-2 mt-3">
                <Plus className="w-4 h-4 text-zinc-600" />
                <input
                  type="text"
                  value={newSubtaskTitle || ''}
                  onChange={(e) => onNewSubtaskTitleChange(task.id, e.target.value)}
                  placeholder="Добавить подзадачу..."
                  className="flex-1 bg-transparent border-none text-sm text-zinc-700 focus:outline-none focus:ring-0 placeholder:text-zinc-400"
                />
              </form>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

export function Tasks() {
  const { tasks, spheres, addTask, updateTask, toggleTaskCompletion, toggleTaskFailure, deleteTask, reorderTasks, addSubtask, toggleSubtask, deleteSubtask } = useStore();
  const [activePeriod, setActivePeriod] = useState<TaskPeriod>('day');
  const [isAdding, setIsAdding] = useState(false);
  const [editingTaskId, setEditingTaskId] = useState<string | null>(null);
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [expandedTasks, setExpandedTasks] = useState<Record<string, boolean>>({});
  const [newSubtaskTitle, setNewSubtaskTitle] = useState<Record<string, string>>({});
  const [historyFilter, setHistoryFilter] = useState<{ sphereId: string; status: 'all' | 'completed' | 'failed' }>({ sphereId: '', status: 'all' });
  
  const [title, setTitle] = useState('');
  const [sphereId, setSphereId] = useState('');
  const [date, setDate] = useState(format(new Date(), 'yyyy-MM-dd'));
  const [priority, setPriority] = useState<TaskPriority | ''>('');
  const [context, setContext] = useState<string>('');
  const [viewMode, setViewMode] = useState<'list' | 'matrix' | 'context'>('list');

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

  const selectedDateStr = format(selectedDate, 'yyyy-MM-dd');

  const filteredTasks = tasks.filter(t => {
    if (activePeriod === 'history') {
      const isStatusMatch = historyFilter.status === 'all' || 
                           (historyFilter.status === 'completed' && t.completed) ||
                           (historyFilter.status === 'failed' && t.failed);
      const isSphereMatch = !historyFilter.sphereId || t.sphereId === historyFilter.sphereId;
      return (t.completed || t.failed) && isStatusMatch && isSphereMatch;
    }

    if (t.period !== activePeriod) return false;
    const taskDate = new Date(t.date);
    
    if (activePeriod === 'day') {
      return t.date.startsWith(selectedDateStr);
    } else if (activePeriod === 'week') {
      return isWithinInterval(taskDate, { start: startOfWeek(selectedDate, { weekStartsOn: 1 }), end: endOfWeek(selectedDate, { weekStartsOn: 1 }) });
    } else if (activePeriod === 'month') {
      return isWithinInterval(taskDate, { start: startOfMonth(selectedDate), end: endOfMonth(selectedDate) });
    } else if (activePeriod === 'year') {
      return isWithinInterval(taskDate, { start: startOfYear(selectedDate), end: endOfYear(selectedDate) });
    }
    return true;
  });

  const sortedTasks = [...filteredTasks].sort((a, b) => {
    if (activePeriod === 'history') {
      return new Date(b.date).getTime() - new Date(a.date).getTime();
    }
    if (a.isPinned && !b.isPinned) return -1;
    if (!a.isPinned && b.isPinned) return 1;
    return (a.order || 0) - (b.order || 0);
  });

  const handleDragEnd = (event: DragEndEvent) => {
    if (activePeriod === 'history') return;
    const { active, over } = event;

    if (over && active.id !== over.id) {
      const oldIndex = sortedTasks.findIndex(t => t.id === active.id);
      const newIndex = sortedTasks.findIndex(t => t.id === over.id);
      const newOrder = arrayMove(sortedTasks, oldIndex, newIndex);
      reorderTasks(newOrder.map(t => t.id));
    }
  };

  const togglePin = (id: string, isPinned: boolean) => {
    updateTask(id, { isPinned: !isPinned });
  };

  const toggleExpand = (taskId: string) => {
    setExpandedTasks(prev => ({ ...prev, [taskId]: !prev[taskId] }));
  };

  const handleAddSubtask = (e: React.FormEvent, taskId: string) => {
    e.preventDefault();
    const title = newSubtaskTitle[taskId];
    if (!title?.trim()) return;
    addSubtask(taskId, title.trim());
    setNewSubtaskTitle(prev => ({ ...prev, [taskId]: '' }));
  };

  const handlePrev = () => {
    if (activePeriod === 'day') setSelectedDate(prev => subDays(prev, 1));
    else if (activePeriod === 'week') setSelectedDate(prev => subWeeks(prev, 1));
    else if (activePeriod === 'month') setSelectedDate(prev => subMonths(prev, 1));
    else if (activePeriod === 'year') setSelectedDate(prev => subYears(prev, 1));
  };

  const handleNext = () => {
    if (activePeriod === 'day') setSelectedDate(prev => addDays(prev, 1));
    else if (activePeriod === 'week') setSelectedDate(prev => addWeeks(prev, 1));
    else if (activePeriod === 'month') setSelectedDate(prev => addMonths(prev, 1));
    else if (activePeriod === 'year') setSelectedDate(prev => addYears(prev, 1));
  };

  const getPeriodLabel = () => {
    if (activePeriod === 'history') return 'Завершенные и проваленные';
    if (activePeriod === 'day') return format(selectedDate, 'd MMMM yyyy', { locale: ru });
    if (activePeriod === 'week') {
      const start = startOfWeek(selectedDate, { weekStartsOn: 1 });
      const end = endOfWeek(selectedDate, { weekStartsOn: 1 });
      return `${format(start, 'd MMM', { locale: ru })} - ${format(end, 'd MMM yyyy', { locale: ru })}`;
    }
    if (activePeriod === 'month') return format(selectedDate, 'LLLL yyyy', { locale: ru });
    if (activePeriod === 'year') return format(selectedDate, 'yyyy', { locale: ru });
    return '';
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    const period = activePeriod === 'history' ? 'day' : activePeriod;

    if (editingTaskId) {
      updateTask(editingTaskId, {
        title,
        sphereId: sphereId || undefined,
        period,
        date: new Date(date).toISOString(),
        priority: priority || undefined,
        context: context.trim() || undefined,
      });
    } else {
      addTask({
        title,
        sphereId: sphereId || undefined,
        period,
        date: new Date(date).toISOString(),
        priority: priority || undefined,
        context: context.trim() || undefined,
      });
    }

    setIsAdding(false);
    setEditingTaskId(null);
    setTitle('');
    setSphereId('');
    setPriority('');
    setContext('');
  };

  const handleEdit = (task: any) => {
    setEditingTaskId(task.id);
    setTitle(task.title);
    setSphereId(task.sphereId || '');
    setDate(format(new Date(task.date), 'yyyy-MM-dd'));
    setPriority(task.priority || '');
    setContext(task.context || '');
    setIsAdding(true);
  };

  const handleCancel = () => {
    setIsAdding(false);
    setEditingTaskId(null);
    setTitle('');
    setSphereId('');
    setPriority('');
    setContext('');
  };

  const periods: { value: TaskPeriod; label: string }[] = [
    { value: 'day', label: 'День' },
    { value: 'week', label: 'Неделя' },
    { value: 'month', label: 'Месяц' },
    { value: 'year', label: 'Год' },
  ];

  const periodLabels: Record<TaskPeriod, string> = {
    day: 'на день',
    week: 'на неделю',
    month: 'на месяц',
    year: 'на год',
    history: 'история'
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold tracking-tight text-zinc-900">Задачи</h1>
          <p className="text-sm text-zinc-500 mt-1">Управляйте своими целями на разных временных отрезках.</p>
        </div>
        <div className="flex items-center gap-2">
          <div className="flex bg-white border border-stone-200 rounded-xl p-0.5">
            <button
              onClick={() => setViewMode('list')}
              className={cn(
                "flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-medium transition-all",
                viewMode === 'list' ? 'bg-stone-100 text-zinc-900' : 'text-zinc-500 hover:text-zinc-800'
              )}
              title="Список"
            >
              <List className="w-3.5 h-3.5" />
            </button>
            <button
              onClick={() => setViewMode('matrix')}
              className={cn(
                "flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-medium transition-all",
                viewMode === 'matrix' ? 'bg-stone-100 text-zinc-900' : 'text-zinc-500 hover:text-zinc-800'
              )}
              title="Матрица Эйзенхауэра"
            >
              <LayoutGrid className="w-3.5 h-3.5" />
            </button>
            <button
              onClick={() => setViewMode('context')}
              className={cn(
                "flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-medium transition-all",
                viewMode === 'context' ? 'bg-stone-100 text-zinc-900' : 'text-zinc-500 hover:text-zinc-800'
              )}
              title="По контекстам"
            >
              <Hash className="w-3.5 h-3.5" />
            </button>
          </div>
          <button
            onClick={() => setActivePeriod(activePeriod === 'history' ? 'day' : 'history')}
            className={cn(
              "flex items-center gap-2 px-3 py-1.5 rounded-xl transition-all text-sm font-medium border",
              activePeriod === 'history'
                ? "bg-stone-100 text-zinc-900 border-stone-300 shadow-lg"
                : "bg-white text-zinc-500 border-stone-200 hover:text-zinc-800 hover:bg-stone-100"
            )}
          >
            <History className="w-4 h-4" />
            <span className="hidden sm:inline">История</span>
          </button>
          <button
            onClick={() => {
              setEditingTaskId(null);
              setTitle('');
              setSphereId('');
              setDate(format(selectedDate, 'yyyy-MM-dd'));
              setIsAdding(true);
            }}
            disabled={activePeriod === 'history'}
            className={cn(
              "flex items-center gap-2 px-3 py-1.5 rounded-xl transition-colors text-sm font-medium",
              activePeriod === 'history' 
                ? "bg-stone-100 text-zinc-600 cursor-not-allowed" 
                : "bg-white text-black hover:bg-zinc-200"
            )}
          >
            <Plus className="w-4 h-4" />
            <span className="hidden sm:inline">Добавить задачу</span>
          </button>
        </div>
      </div>

        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div className="flex flex-wrap gap-1 bg-white/60 p-1 rounded-2xl w-full sm:w-fit border border-stone-200">
            {periods.map((period) => (
              <button
                key={period.value}
                onClick={() => setActivePeriod(period.value)}
                className={cn(
                  'flex-1 sm:flex-none px-2.5 py-1.5 rounded-xl text-[11px] font-medium transition-all whitespace-nowrap text-center',
                  activePeriod === period.value
                    ? 'bg-stone-100 text-zinc-900 shadow-sm'
                    : 'text-zinc-500 hover:text-zinc-800 hover:bg-stone-100/60'
                )}
              >
                {period.label}
              </button>
            ))}
          </div>

          {activePeriod !== 'history' && (
            <div className="flex items-center gap-3 bg-white p-1.5 rounded-2xl border border-stone-200 w-fit">
              <button 
                onClick={handlePrev}
                className="p-1.5 text-zinc-500 hover:text-zinc-900 hover:bg-stone-100 rounded-xl transition-colors"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>
              <div className="text-sm font-medium text-zinc-900 min-w-[120px] text-center capitalize">
                {getPeriodLabel()}
              </div>
              <button 
                onClick={handleNext}
                className="p-1.5 text-zinc-500 hover:text-zinc-900 hover:bg-stone-100 rounded-xl transition-colors"
              >
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          )}
        </div>

        {activePeriod === 'history' && (
          <div className="flex flex-wrap items-center gap-3 bg-white/30 p-3 rounded-2xl border border-stone-200/70">
            <div className="flex items-center gap-2">
              <span className="text-xs text-zinc-500">Сфера:</span>
              <select
                value={historyFilter.sphereId}
                onChange={(e) => setHistoryFilter(prev => ({ ...prev, sphereId: e.target.value }))}
                className="bg-stone-50 border border-stone-200 text-xs text-zinc-700 rounded-lg px-2 py-1 focus:outline-none focus:ring-1 focus:ring-stone-300"
              >
                <option value="">Все</option>
                {spheres.map(s => (
                  <option key={s.id} value={s.id}>{s.title}</option>
                ))}
              </select>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-xs text-zinc-500">Статус:</span>
              <div className="flex bg-stone-50 rounded-lg p-0.5 border border-stone-200">
                {(['all', 'completed', 'failed'] as const).map((s) => (
                  <button
                    key={s}
                    onClick={() => setHistoryFilter(prev => ({ ...prev, status: s }))}
                    className={cn(
                      "px-2 py-1 rounded-md text-[10px] font-medium transition-all",
                      historyFilter.status === s
                        ? "bg-stone-100 text-zinc-900"
                        : "text-zinc-500 hover:text-zinc-700"
                    )}
                  >
                    {s === 'all' ? 'Все' : s === 'completed' ? 'Выполнено' : 'Провалено'}
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}

      {isAdding && (
        <div className="bg-white p-5 rounded-3xl shadow-sm border border-stone-200">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-base font-semibold text-zinc-900">
              {editingTaskId ? 'Редактировать задачу' : `Новая задача ${periodLabels[activePeriod]}`}
            </h2>
            <button onClick={handleCancel} className="text-zinc-500 hover:text-zinc-700">
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
                placeholder="Что нужно сделать?"
                required
              />
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-medium text-zinc-700 mb-1">Сфера (необязательно)</label>
                <select
                  value={sphereId}
                  onChange={(e) => setSphereId(e.target.value)}
                  className="w-full px-3 py-2 text-sm bg-stone-50 border border-stone-200 text-zinc-900 rounded-xl focus:ring-2 focus:ring-zinc-500 focus:border-zinc-500"
                >
                  <option value="">Нет</option>
                  {spheres.map(s => (
                    <option key={s.id} value={s.id}>{s.title}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-xs font-medium text-zinc-700 mb-1">Дата</label>
                <input
                  type="date"
                  value={date}
                  onChange={(e) => setDate(e.target.value)}
                  className="w-full px-3 py-2 text-sm bg-stone-50 border border-stone-200 text-zinc-900 rounded-xl focus:ring-2 focus:ring-zinc-500 focus:border-zinc-500"
                  required
                />
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-medium text-zinc-700 mb-1">Приоритет (Eisenhower)</label>
                <div className="grid grid-cols-2 gap-1.5">
                  {(['urgent_important', 'important', 'urgent', 'later'] as TaskPriority[]).map((p) => {
                    const active = priority === p;
                    const colors = PRIORITY_COLORS[p];
                    return (
                      <button
                        type="button"
                        key={p}
                        onClick={() => setPriority(active ? '' : p)}
                        className={cn(
                          "px-2 py-2 rounded-xl text-[11px] font-medium border transition-all text-left",
                          active
                            ? `${colors.bg} ${colors.text} ${colors.border} ring-2 ${colors.ring}`
                            : "bg-stone-50 text-zinc-600 border-stone-200 hover:bg-stone-100"
                        )}
                      >
                        <div className="flex items-center gap-1">
                          {p === 'urgent_important' && <AlertTriangle className="w-3 h-3" />}
                          {p === 'important' && <Tag className="w-3 h-3" />}
                          {p === 'urgent' && <Clock className="w-3 h-3" />}
                          {p === 'later' && <Coffee className="w-3 h-3" />}
                          {PRIORITY_LABELS[p]}
                        </div>
                        <div className="text-[10px] opacity-70 mt-0.5">{PRIORITY_HINTS[p]}</div>
                      </button>
                    );
                  })}
                </div>
              </div>
              <div>
                <label className="block text-xs font-medium text-zinc-700 mb-1">Контекст (GTD)</label>
                <input
                  type="text"
                  value={context}
                  onChange={(e) => setContext(e.target.value)}
                  className="w-full px-3 py-2 text-sm bg-stone-50 border border-stone-200 text-zinc-900 rounded-xl focus:ring-2 focus:ring-zinc-500 focus:border-zinc-500"
                  placeholder="@дом, @работа, @звонки..."
                />
                <div className="flex flex-wrap gap-1.5 mt-1.5">
                  {DEFAULT_CONTEXTS.map((c) => (
                    <button
                      type="button"
                      key={c}
                      onClick={() => setContext(c)}
                      className={cn(
                        "px-2 py-0.5 rounded-md text-[10px] font-medium border transition-all",
                        context === c
                          ? "bg-indigo-50 text-indigo-700 border-indigo-200"
                          : "bg-stone-50 text-zinc-600 border-stone-200 hover:bg-stone-100"
                      )}
                    >
                      {c}
                    </button>
                  ))}
                </div>
              </div>
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={handleCancel}
                className="px-3 py-1.5 text-xs text-zinc-500 hover:bg-stone-100 rounded-xl font-medium transition-colors"
              >
                Отмена
              </button>
              <button
                type="submit"
                className="px-3 py-1.5 text-xs bg-white text-black rounded-xl hover:bg-zinc-200 font-medium transition-colors"
              >
                {editingTaskId ? 'Сохранить изменения' : 'Сохранить задачу'}
              </button>
            </div>
          </form>
        </div>
      )}

      <div>
        {sortedTasks.length === 0 ? (
          <div className="bg-white rounded-3xl border border-stone-200 p-10 text-center text-zinc-500">
            <CheckCircle2 className="w-10 h-10 mx-auto text-zinc-700 mb-3" />
            <p className="text-base font-medium text-zinc-700">Задачи не найдены</p>
            <p className="text-sm mt-1">Добавьте задачу на этот период, чтобы начать.</p>
          </div>
        ) : viewMode === 'matrix' ? (
          <EisenhowerMatrix
            tasks={sortedTasks}
            updateTaskPriority={(id, p) => updateTask(id, { priority: p })}
            onToggleCompletion={toggleTaskCompletion}
            onEdit={handleEdit}
          />
        ) : viewMode === 'context' ? (
          <ContextGroupedView
            tasks={sortedTasks}
            spheres={spheres}
            updateTaskContext={(id, c) => updateTask(id, { context: c })}
            onToggleCompletion={toggleTaskCompletion}
            onEdit={handleEdit}
            onDelete={deleteTask}
          />
        ) : (
          <div className="space-y-3">
            <DndContext
              sensors={sensors}
              collisionDetection={closestCenter}
              onDragEnd={handleDragEnd}
            >
              <SortableContext
                items={sortedTasks.map(t => t.id)}
                strategy={verticalListSortingStrategy}
              >
                <div className="space-y-3">
                  {sortedTasks.map((task) => {
                    const sphere = spheres.find(s => s.id === task.sphereId);
                    const isExpanded = expandedTasks[task.id];
                    const completedSubtasks = task.subtasks?.filter(s => s.completed).length || 0;
                    const totalSubtasks = task.subtasks?.length || 0;
                    
                    return (
                      <SortableTask
                        key={task.id}
                        task={task}
                        sphere={sphere}
                        isExpanded={isExpanded}
                        completedSubtasks={completedSubtasks}
                        totalSubtasks={totalSubtasks}
                        onToggleCompletion={toggleTaskCompletion}
                        onToggleFailure={toggleTaskFailure}
                        onTogglePin={togglePin}
                        onToggleExpand={toggleExpand}
                        onEdit={handleEdit}
                        onDelete={deleteTask}
                        onToggleSubtask={toggleSubtask}
                        onDeleteSubtask={deleteSubtask}
                        onAddSubtask={handleAddSubtask}
                        newSubtaskTitle={newSubtaskTitle[task.id]}
                        onNewSubtaskTitleChange={(taskId, title) => setNewSubtaskTitle(prev => ({ ...prev, [taskId]: title }))}
                      />
                    );
                  })}
                </div>
              </SortableContext>
            </DndContext>
          </div>
        )}
      </div>
      {viewMode === 'list' && (
        <div className="text-center text-xs text-zinc-600 mt-4">
          Перетаскивайте задачи за иконку слева, чтобы изменить порядок
        </div>
      )}
    </div>
  );
}

interface QuadrantProps {
  priority: TaskPriority;
  tasks: Task[];
  onAssign: (taskId: string, p: TaskPriority) => void;
  onToggleCompletion: (id: string) => void;
  onEdit: (task: Task) => void;
}

function EisenhowerQuadrant({ priority, tasks, onAssign, onToggleCompletion, onEdit }: QuadrantProps) {
  const colors = PRIORITY_COLORS[priority];
  const Icon = priority === 'urgent_important' ? AlertTriangle
    : priority === 'important' ? Tag
    : priority === 'urgent' ? Clock
    : Coffee;

  return (
    <div
      onDragOver={(e) => e.preventDefault()}
      onDrop={(e) => {
        const id = e.dataTransfer.getData('text/plain');
        if (id) onAssign(id, priority);
      }}
      className={cn(
        'rounded-3xl border-2 p-3 sm:p-4 min-h-[180px] flex flex-col gap-2',
        colors.bg, colors.border
      )}
    >
      <div className={cn('flex items-center gap-2 font-semibold text-sm', colors.text)}>
        <Icon className="w-4 h-4" />
        <span>{PRIORITY_LABELS[priority]}</span>
        <span className="ml-auto text-[10px] font-medium opacity-60">{tasks.length}</span>
      </div>
      <p className="text-[10px] opacity-70 -mt-1">{PRIORITY_HINTS[priority]}</p>
      <div className="flex-1 space-y-1.5">
        {tasks.length === 0 ? (
          <p className="text-[11px] opacity-50 text-center py-4">
            Перетащите задачу сюда
          </p>
        ) : (
          tasks.map((t) => (
            <div
              key={t.id}
              draggable
              onDragStart={(e) => e.dataTransfer.setData('text/plain', t.id)}
              className="bg-white/80 border border-stone-200 rounded-xl p-2 text-xs flex items-start gap-2 cursor-grab active:cursor-grabbing"
            >
              <button
                onClick={() => onToggleCompletion(t.id)}
                className={cn('mt-0.5 transition-colors', t.completed ? 'text-zinc-900' : 'text-zinc-500 hover:text-zinc-900')}
              >
                {t.completed ? <CheckCircle2 className="w-3.5 h-3.5" /> : <Circle className="w-3.5 h-3.5" />}
              </button>
              <button
                onClick={() => onEdit(t)}
                className={cn(
                  'flex-1 text-left',
                  t.completed && 'line-through text-zinc-500'
                )}
              >
                {t.title}
                {t.context && <span className="ml-1 text-[10px] text-indigo-600">{t.context}</span>}
              </button>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

function EisenhowerMatrix({
  tasks,
  updateTaskPriority,
  onToggleCompletion,
  onEdit,
}: {
  tasks: Task[];
  updateTaskPriority: (id: string, p: TaskPriority) => void;
  onToggleCompletion: (id: string) => void;
  onEdit: (task: Task) => void;
}) {
  const grouped = (p: TaskPriority) => tasks.filter(t => (t.priority || 'later') === p && !t.completed && !t.failed);
  const completed = tasks.filter(t => t.completed);
  const unassigned = tasks.filter(t => !t.priority && !t.completed && !t.failed);

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-4">
        <EisenhowerQuadrant priority="urgent_important" tasks={grouped('urgent_important')}
          onAssign={updateTaskPriority} onToggleCompletion={onToggleCompletion} onEdit={onEdit} />
        <EisenhowerQuadrant priority="important" tasks={grouped('important')}
          onAssign={updateTaskPriority} onToggleCompletion={onToggleCompletion} onEdit={onEdit} />
        <EisenhowerQuadrant priority="urgent" tasks={grouped('urgent')}
          onAssign={updateTaskPriority} onToggleCompletion={onToggleCompletion} onEdit={onEdit} />
        <EisenhowerQuadrant priority="later" tasks={grouped('later').filter(t => unassigned.indexOf(t) === -1)}
          onAssign={updateTaskPriority} onToggleCompletion={onToggleCompletion} onEdit={onEdit} />
      </div>

      {unassigned.length > 0 && (
        <div className="bg-white rounded-3xl border border-stone-200 p-4">
          <div className="flex items-center gap-2 mb-2 text-zinc-700 font-medium text-sm">
            <Hash className="w-4 h-4" />
            <span>Без приоритета</span>
            <span className="ml-auto text-[10px] font-normal text-zinc-500">{unassigned.length}</span>
          </div>
          <p className="text-[11px] text-zinc-500 mb-3">Перетащите эти задачи в один из квадрантов выше или нажмите и выберите.</p>
          <div className="flex flex-wrap gap-1.5">
            {unassigned.map((t) => (
              <div
                key={t.id}
                draggable
                onDragStart={(e) => e.dataTransfer.setData('text/plain', t.id)}
                className="bg-stone-50 border border-stone-200 rounded-xl px-2.5 py-1.5 text-xs cursor-grab active:cursor-grabbing flex items-center gap-1.5"
              >
                <span>{t.title}</span>
                <select
                  value=""
                  onChange={(e) => updateTaskPriority(t.id, e.target.value as TaskPriority)}
                  className="bg-transparent text-[10px] text-zinc-500 border-0 outline-0 cursor-pointer"
                >
                  <option value="">→</option>
                  <option value="urgent_important">Срочно+важно</option>
                  <option value="important">Важно</option>
                  <option value="urgent">Срочно</option>
                  <option value="later">Не срочно</option>
                </select>
              </div>
            ))}
          </div>
        </div>
      )}

      {completed.length > 0 && (
        <details className="bg-white rounded-3xl border border-stone-200 p-4">
          <summary className="cursor-pointer text-sm font-medium text-zinc-700">
            Выполненные ({completed.length})
          </summary>
          <div className="mt-2 space-y-1 text-xs text-zinc-500">
            {completed.map((t) => (
              <div key={t.id} className="line-through">{t.title}</div>
            ))}
          </div>
        </details>
      )}
    </div>
  );
}

function ContextGroupedView({
  tasks,
  spheres,
  updateTaskContext,
  onToggleCompletion,
  onEdit,
  onDelete,
}: {
  tasks: Task[];
  spheres: any[];
  updateTaskContext: (id: string, c: string) => void;
  onToggleCompletion: (id: string) => void;
  onEdit: (task: Task) => void;
  onDelete: (id: string) => void;
}) {
  const groups = new Map<string, Task[]>();
  tasks.forEach(t => {
    const key = t.context || '— Без контекста';
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key)!.push(t);
  });

  const sorted = [...groups.entries()].sort((a, b) => a[0].localeCompare(b[0], 'ru'));

  return (
    <div className="space-y-4">
      {sorted.map(([context, items]) => (
        <div key={context} className="bg-white rounded-3xl border border-stone-200 p-4">
          <div className="flex items-center gap-2 text-zinc-700 font-medium text-sm mb-3">
            <Hash className="w-4 h-4 text-indigo-600" />
            <span>{context}</span>
            <span className="ml-auto text-[10px] font-normal text-zinc-500">{items.length}</span>
          </div>
          <div className="space-y-1.5">
            {items.map((t) => {
              const sphere = spheres.find((s: any) => s.id === t.sphereId);
              return (
                <div key={t.id} className="bg-stone-50 border border-stone-200 rounded-xl p-2.5 flex items-center gap-2 text-xs">
                  <button
                    onClick={() => onToggleCompletion(t.id)}
                    className={cn('transition-colors', t.completed ? 'text-zinc-900' : 'text-zinc-500 hover:text-zinc-900')}
                  >
                    {t.completed ? <CheckCircle2 className="w-4 h-4" /> : <Circle className="w-4 h-4" />}
                  </button>
                  <button onClick={() => onEdit(t)} className={cn('flex-1 text-left', t.completed && 'line-through text-zinc-500')}>
                    {t.title}
                  </button>
                  {t.priority && (
                    <span className={cn('px-1.5 py-0.5 rounded-md text-[10px] font-medium border',
                      PRIORITY_COLORS[t.priority].bg, PRIORITY_COLORS[t.priority].text, PRIORITY_COLORS[t.priority].border
                    )}>
                      {PRIORITY_LABELS[t.priority]}
                    </span>
                  )}
                  {sphere && <span className="text-[10px] text-zinc-500">{sphere.title}</span>}
                  <button onClick={() => onDelete(t.id)} className="text-zinc-400 hover:text-rose-500">
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                  {context === '— Без контекста' && (
                    <select
                      value=""
                      onChange={(e) => updateTaskContext(t.id, e.target.value)}
                      className="text-[10px] bg-transparent border-0 text-indigo-600 cursor-pointer"
                    >
                      <option value="">+ контекст</option>
                      {DEFAULT_CONTEXTS.map(c => <option key={c} value={c}>{c}</option>)}
                    </select>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}
