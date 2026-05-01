import React, { useState } from 'react';
import { Target, Plus, ArrowRight, CheckCircle2, Circle, XCircle, Activity, MinusCircle, GripVertical } from 'lucide-react';
import { Link } from 'react-router-dom';
import { motion, AnimatePresence } from 'motion/react';
import { cn } from '../../lib/utils';
import { Task, Habit, HabitLog, Sphere } from '../../types';
import { useStore } from '../../store/useStore';
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
} from '@dnd-kit/core';
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  verticalListSortingStrategy,
  useSortable,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';

interface SortableTaskItemProps {
  task: Task;
  toggleTaskCompletion: (id: string) => void;
  toggleTaskFailure: (id: string) => void;
}

const SortableTaskItem: React.FC<SortableTaskItemProps> = ({ task, toggleTaskCompletion, toggleTaskFailure }) => {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: task.id });
  
  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  };

  return (
    <motion.div
      ref={setNodeRef}
      style={style}
      layout
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      exit={{ opacity: 0, scale: 0.95, transition: { duration: 0.2 } }}
      drag="x"
      dragConstraints={{ left: 0, right: 0 }}
      dragElastic={0.7}
      onDragEnd={(e, { offset }) => {
        if (offset.x > 100) {
          toggleTaskCompletion(task.id);
        } else if (offset.x < -100) {
          toggleTaskFailure(task.id);
        }
      }}
      className={cn(
        "p-3 rounded-2xl border flex items-center gap-3 cursor-grab active:cursor-grabbing relative overflow-hidden",
        task.completed ? "bg-zinc-900 border-zinc-800" : "bg-zinc-950 border-zinc-800"
      )}
    >
      <div {...attributes} {...listeners} className="cursor-grab text-zinc-600 hover:text-zinc-400">
        <GripVertical className="w-4 h-4" />
      </div>
      <div className="absolute inset-y-0 left-0 w-1 bg-white opacity-0 transition-opacity" />
      <div className="flex gap-1.5">
        <button
          onClick={() => toggleTaskCompletion(task.id)}
          className={cn(
            "transition-colors",
            task.completed ? "text-white" : "text-zinc-600 hover:text-white"
          )}
        >
          {task.completed ? <CheckCircle2 className="w-5 h-5" /> : <Circle className="w-5 h-5" />}
        </button>
        <button
          onClick={() => toggleTaskFailure(task.id)}
          className={cn(
            "transition-colors",
            task.failed ? "text-zinc-500" : "text-zinc-700 hover:text-zinc-500"
          )}
        >
          {task.failed ? <XCircle className="w-5 h-5" /> : <XCircle className="w-5 h-5 opacity-50" />}
        </button>
      </div>
      <div className="flex-1 min-w-0">
        <p className={cn(
          "text-xs font-medium text-zinc-200 truncate",
          task.completed && "text-zinc-500 line-through",
          task.failed && "text-zinc-700 line-through"
        )}>
          {task.title}
        </p>
        {task.subtasks && task.subtasks.length > 0 && (
          <div className="mt-1.5 space-y-1">
            <div className="flex justify-between text-[8px] uppercase tracking-tighter text-zinc-500">
              <span>Подзадачи</span>
              <span>{task.subtasks.filter(s => s.completed).length}/{task.subtasks.length}</span>
            </div>
            <div className="w-full bg-zinc-900 h-1 rounded-full overflow-hidden border border-zinc-800">
              <motion.div 
                initial={{ width: 0 }}
                animate={{ width: `${(task.subtasks.filter(s => s.completed).length / task.subtasks.length) * 100}%` }}
                className="bg-indigo-500 h-full rounded-full" 
              />
            </div>
          </div>
        )}
      </div>
    </motion.div>
  );
};

const SortableHabitItem: React.FC<{
  habit: Habit;
  log?: HabitLog;
  handleHabitLog: (habitId: string, status: 'done' | 'failed' | 'skipped') => void;
  type: 'good' | 'bad';
}> = ({ habit, log, handleHabitLog, type }) => {
  const { hideHabitNames } = useStore();
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: habit.id });
  
  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  };

  return (
    <div ref={setNodeRef} style={style} className="bg-zinc-950 p-2 rounded-xl border border-zinc-800 flex items-center justify-between">
      <div {...attributes} {...listeners} className="cursor-grab text-zinc-600 hover:text-zinc-400 mr-2">
        <GripVertical className="w-4 h-4" />
      </div>
      <span className="text-xs text-zinc-200 font-medium truncate pr-2 flex-1">{hideHabitNames ? '***' : habit.title}</span>
      <div className="flex gap-1">
        {type === 'good' ? (
          <>
            <button onClick={() => handleHabitLog(habit.id, 'done')} className={cn("p-1.5 rounded-lg transition-colors", log?.status === 'done' ? "bg-white text-black" : "text-zinc-600 hover:bg-zinc-800")}>
              <CheckCircle2 className="w-4 h-4" />
            </button>
            <button onClick={() => handleHabitLog(habit.id, 'skipped')} className={cn("p-1.5 rounded-lg transition-colors", log?.status === 'skipped' ? "bg-zinc-800 text-zinc-400" : "text-zinc-600 hover:bg-zinc-800")}>
              <MinusCircle className="w-4 h-4" />
            </button>
            <button onClick={() => handleHabitLog(habit.id, 'failed')} className={cn("p-1.5 rounded-lg transition-colors", log?.status === 'failed' ? "bg-zinc-800 text-zinc-500" : "text-zinc-600 hover:bg-zinc-800")}>
              <XCircle className="w-4 h-4" />
            </button>
          </>
        ) : (
          <>
            <button onClick={() => handleHabitLog(habit.id, 'done')} className={cn("p-1.5 rounded-lg transition-colors", log?.status === 'done' ? "bg-white text-black" : "text-zinc-600 hover:bg-zinc-800")} title="Сдержался">
              <CheckCircle2 className="w-4 h-4" />
            </button>
            <button onClick={() => handleHabitLog(habit.id, 'failed')} className={cn("p-1.5 rounded-lg transition-colors", log?.status === 'failed' ? "bg-zinc-800 text-zinc-500" : "text-zinc-600 hover:bg-zinc-800")} title="Сорвался">
              <XCircle className="w-4 h-4" />
            </button>
          </>
        )}
      </div>
    </div>
  );
};

interface TasksHabitsWidgetProps {
  todaysTasks: Task[];
  totalTasks: number;
  completedTasks: number;
  taskProgress: number;
  goodHabits: Habit[];
  badHabits: Habit[];
  habitLogs: HabitLog[];
  spheres: Sphere[];
  dateStr: string;
  toggleTaskCompletion: (id: string) => void;
  toggleTaskFailure: (id: string) => void;
  reorderTasks: (taskIds: string[]) => void;
  reorderHabits: (habitIds: string[]) => void;
  logHabit: (habitId: string, status: 'done' | 'failed' | 'skipped') => void;
  addTask: (task: Omit<Task, 'id' | 'createdAt' | 'completed' | 'failed'>) => void;
}

export const TasksHabitsWidget: React.FC<TasksHabitsWidgetProps> = ({
  todaysTasks,
  totalTasks,
  completedTasks,
  taskProgress,
  goodHabits,
  badHabits,
  habitLogs,
  spheres,
  dateStr,
  toggleTaskCompletion,
  toggleTaskFailure,
  reorderTasks,
  reorderHabits,
  logHabit,
  addTask
}) => {
  const [isAddingTask, setIsAddingTask] = useState(false);
  const [newTaskTitle, setNewTaskTitle] = useState('');
  const [newTaskSphere, setNewTaskSphere] = useState('');

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

  const handleHabitLog = (habitId: string, status: 'done' | 'failed' | 'skipped') => {
    logHabit(habitId, status);
  };

  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  );

  const handleDragEnd = (event: any) => {
    const { active, over } = event;
    if (over && active.id !== over.id) {
      if (todaysTasks.find(t => t.id === active.id)) {
        const oldIndex = todaysTasks.findIndex((t) => t.id === active.id);
        const newIndex = todaysTasks.findIndex((t) => t.id === over.id);
        reorderTasks(arrayMove(todaysTasks.map(t => t.id), oldIndex, newIndex));
      } else if (goodHabits.find(h => h.id === active.id)) {
        const oldIndex = goodHabits.findIndex((h) => h.id === active.id);
        const newIndex = goodHabits.findIndex((h) => h.id === over.id);
        reorderHabits(arrayMove(goodHabits.map(h => h.id), oldIndex, newIndex));
      } else if (badHabits.find(h => h.id === active.id)) {
        const oldIndex = badHabits.findIndex((h) => h.id === active.id);
        const newIndex = badHabits.findIndex((h) => h.id === over.id);
        reorderHabits(arrayMove(badHabits.map(h => h.id), oldIndex, newIndex));
      }
    }
  };

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
      <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
        <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800 flex flex-col">
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-sm font-semibold flex items-center gap-2 text-white">
              <Target className="w-4 h-4 text-white" />
              Задачи
            </h2>
            <div className="flex items-center gap-3">
              <button 
                onClick={() => setIsAddingTask(!isAddingTask)}
                className="text-xs text-zinc-300 hover:text-white font-medium flex items-center gap-1"
              >
                <Plus className="w-3.5 h-3.5" /> Добавить
              </button>
              <Link to="/tasks" className="text-xs text-zinc-500 hover:text-zinc-300 font-medium flex items-center gap-1">
                Все <ArrowRight className="w-3.5 h-3.5" />
              </Link>
            </div>
          </div>

          {todaysTasks.length > 0 && (
            <div className="mb-4 space-y-1.5">
              <div className="flex justify-between text-[10px] uppercase tracking-wider">
                <span className="text-zinc-500">Прогресс задач</span>
                <span className="text-white font-bold">{completedTasks}/{totalTasks}</span>
              </div>
              <div className="w-full bg-zinc-800 h-1.5 rounded-full overflow-hidden">
                <motion.div 
                  initial={{ width: 0 }}
                  animate={{ width: `${taskProgress}%` }}
                  className="bg-indigo-500 h-full rounded-full" 
                />
              </div>
            </div>
          )}

          {isAddingTask && (
            <form onSubmit={handleAddTask} className="mb-4 bg-zinc-950 p-3 rounded-2xl border border-zinc-800 space-y-3">
              <input
                type="text"
                value={newTaskTitle}
                onChange={(e) => setNewTaskTitle(e.target.value)}
                placeholder="Название задачи..."
                className="w-full px-3 py-2 text-sm bg-zinc-900 border border-zinc-800 text-white rounded-xl focus:ring-2 focus:ring-zinc-500"
                required
              />
              <div className="flex gap-2">
                <select
                  value={newTaskSphere}
                  onChange={(e) => setNewTaskSphere(e.target.value)}
                  className="flex-1 px-3 py-2 text-sm bg-zinc-900 border border-zinc-800 text-zinc-300 rounded-xl focus:ring-2 focus:ring-zinc-500"
                >
                  <option value="">Без сферы</option>
                  {spheres.map(s => (
                    <option key={s.id} value={s.id}>{s.title}</option>
                  ))}
                </select>
                <button type="submit" className="px-3 py-2 bg-white text-black text-sm rounded-xl hover:bg-zinc-200 font-medium">
                  Ок
                </button>
              </div>
            </form>
          )}
          
          <div className="flex-1">
            {todaysTasks.length === 0 ? (
              <div className="h-full flex flex-col items-center justify-center text-zinc-500 py-6">
                <Target className="w-10 h-10 mb-2 opacity-20" />
                <p className="text-sm">На этот день задач нет.</p>
              </div>
            ) : (
              <SortableContext items={todaysTasks.map(t => t.id)} strategy={verticalListSortingStrategy}>
                <div className="space-y-2">
                  <AnimatePresence mode="popLayout">
                    {todaysTasks.map((task) => (
                      <SortableTaskItem 
                        key={task.id} 
                        task={task} 
                        toggleTaskCompletion={toggleTaskCompletion} 
                        toggleTaskFailure={toggleTaskFailure} 
                      />
                    ))}
                  </AnimatePresence>
                </div>
              </SortableContext>
            )}
          </div>
          {todaysTasks.length > 0 && (
            <div className="text-center text-[10px] text-zinc-600 mt-3">
              Свайп вправо — выполнить, влево — провал. Перетаскивайте за иконку слева.
            </div>
          )}
        </div>

        <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800 flex flex-col">
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-sm font-semibold flex items-center gap-2 text-white">
              <Activity className="w-4 h-4 text-white" />
              Привычки
            </h2>
            <Link to="/habits" className="text-xs text-zinc-500 hover:text-zinc-300 font-medium flex items-center gap-1">
              Все <ArrowRight className="w-3.5 h-3.5" />
            </Link>
          </div>

          <div className="space-y-5 flex-1">
            <div>
              <h3 className="text-xs font-medium text-zinc-400 uppercase tracking-wider mb-2">Хорошие</h3>
              <SortableContext items={goodHabits.map(h => h.id)} strategy={verticalListSortingStrategy}>
                <div className="space-y-2">
                  {goodHabits.map(habit => {
                    const log = habitLogs.find(l => l.habitId === habit.id && l.date === dateStr);
                    return (
                      <SortableHabitItem key={habit.id} habit={habit} log={log} handleHabitLog={handleHabitLog} type="good" />
                    );
                  })}
                </div>
              </SortableContext>
              {goodHabits.length === 0 && <p className="text-xs text-zinc-600 italic">Нет хороших привычек.</p>}
            </div>

            <div>
              <h3 className="text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">Вредные</h3>
              <SortableContext items={badHabits.map(h => h.id)} strategy={verticalListSortingStrategy}>
                <div className="space-y-2">
                  {badHabits.map(habit => {
                    const log = habitLogs.find(l => l.habitId === habit.id && l.date === dateStr);
                    return (
                      <SortableHabitItem key={habit.id} habit={habit} log={log} handleHabitLog={handleHabitLog} type="bad" />
                    );
                  })}
                </div>
              </SortableContext>
              {badHabits.length === 0 && <p className="text-xs text-zinc-600 italic">Нет вредных привычек.</p>}
            </div>
          </div>
        </div>
      </DndContext>
    </div>
  );
};
