import React, { useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Home, Sparkles, Wrench, Droplets, Zap, ChevronLeft, ChevronRight, CheckCircle2, Circle, Trash2, Plus } from 'lucide-react';
import { HouseholdAssistant } from '../components/HouseholdAssistant';
import { format, addDays, subDays } from 'date-fns';
import { ru } from 'date-fns/locale';
import { useStore } from '../store/useStore';
import { cn } from '../lib/utils';

const CATEGORIES = [
  { id: 'clean', label: 'Чистота', icon: Sparkles, color: 'text-blue-400', bg: 'bg-blue-500/10' },
  { id: 'repair', label: 'Ремонт', icon: Wrench, color: 'text-orange-400', bg: 'bg-orange-500/10' },
  { id: 'water', label: 'Вода', icon: Droplets, color: 'text-cyan-400', bg: 'bg-cyan-500/10' },
  { id: 'light', label: 'Свет', icon: Zap, color: 'text-yellow-400', bg: 'bg-yellow-500/10' },
];

const swipeConfidenceThreshold = 10000;
const swipePower = (offset: number, velocity: number) => {
  return Math.abs(offset) * velocity;
};

export function Household() {
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [direction, setDirection] = useState(0);
  const { tasks, addTask, toggleTaskCompletion, deleteTask } = useStore();
  const [isAdding, setIsAdding] = useState<string | null>(null); // category id
  const [newTaskTitle, setNewTaskTitle] = useState('');

  const handlePrevDay = () => {
    setDirection(-1);
    setSelectedDate(prev => subDays(prev, 1));
  };

  const handleNextDay = () => {
    setDirection(1);
    setSelectedDate(prev => addDays(prev, 1));
  };

  const selectedDateStr = format(selectedDate, 'yyyy-MM-dd');
  const dailyTasks = tasks.filter(t => t.sphereId?.startsWith('household_') && t.date.startsWith(selectedDateStr));

  const handleAddTask = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTaskTitle.trim() || !isAdding) return;
    
    addTask({
      title: newTaskTitle.trim(),
      sphereId: `household_${isAdding}`,
      period: 'day',
      date: new Date(selectedDateStr).toISOString(),
    });
    setNewTaskTitle('');
    setIsAdding(null);
  };

  const variants = {
    enter: (direction: number) => ({
      x: direction > 0 ? 100 : -100,
      opacity: 0
    }),
    center: {
      x: 0,
      opacity: 1
    },
    exit: (direction: number) => ({
      x: direction < 0 ? 100 : -100,
      opacity: 0
    })
  };

  return (
    <div className="space-y-6 pb-24">
      <header>
        <h1 className="text-xl font-bold text-zinc-900 mb-1.5 flex items-center gap-2">
          <Home className="w-6 h-6 text-blue-400" />
          Быт и Дом
        </h1>
        <p className="text-sm text-zinc-500">Управление домашним хозяйством, уборка, ремонт и советы</p>
      </header>

      <div className="relative overflow-hidden rounded-3xl bg-white/60 border border-stone-200 flex flex-col">
        <div className="flex items-center justify-between p-4 border-b border-stone-200/70 bg-white/80 z-10">
          <button onClick={handlePrevDay} className="p-2 text-zinc-500 hover:text-zinc-900 rounded-xl hover:bg-stone-100 transition-colors">
            <ChevronLeft className="w-5 h-5" />
          </button>
          <div className="text-center">
            <h2 className="text-lg font-bold text-zinc-900 capitalize">
              {format(selectedDate, 'EEEE', { locale: ru })}
            </h2>
            <p className="text-sm text-zinc-500">
              {format(selectedDate, 'd MMMM yyyy', { locale: ru })}
            </p>
          </div>
          <button onClick={handleNextDay} className="p-2 text-zinc-500 hover:text-zinc-900 rounded-xl hover:bg-stone-100 transition-colors">
            <ChevronRight className="w-5 h-5" />
          </button>
        </div>

        <div className="relative h-[400px] overflow-hidden">
          <AnimatePresence initial={false} custom={direction} mode="wait">
            <motion.div
              key={selectedDate.toISOString()}
              custom={direction}
              variants={variants}
              initial="enter"
              animate="center"
              exit="exit"
              transition={{ type: "spring", stiffness: 300, damping: 30 }}
              drag="x"
              dragConstraints={{ left: 0, right: 0 }}
              dragElastic={1}
              onDragEnd={(e, { offset, velocity }) => {
                const swipe = swipePower(offset.x, velocity.x);
                if (swipe < -swipeConfidenceThreshold) {
                  handleNextDay();
                } else if (swipe > swipeConfidenceThreshold) {
                  handlePrevDay();
                }
              }}
              className="absolute inset-0 p-4 overflow-y-auto hide-scrollbar"
            >
              <div className="grid grid-cols-4 gap-2 mb-6">
                {CATEGORIES.map(cat => (
                  <button
                    key={cat.id}
                    onClick={() => setIsAdding(isAdding === cat.id ? null : cat.id)}
                    className={cn(
                      "flex flex-col items-center justify-center text-center gap-1.5 p-3 rounded-2xl border transition-colors",
                      isAdding === cat.id 
                        ? "bg-stone-100 border-stone-300" 
                        : "bg-white/60 border-stone-200/70 hover:bg-stone-100/60"
                    )}
                  >
                    <div className={cn("w-8 h-8 rounded-full flex items-center justify-center", cat.bg)}>
                      <cat.icon className={cn("w-4 h-4", cat.color)} />
                    </div>
                    <span className="text-[10px] font-medium text-zinc-700">{cat.label}</span>
                  </button>
                ))}
              </div>

              <AnimatePresence>
                {isAdding && (
                  <motion.form 
                    initial={{ opacity: 0, height: 0 }}
                    animate={{ opacity: 1, height: 'auto' }}
                    exit={{ opacity: 0, height: 0 }}
                    onSubmit={handleAddTask} 
                    className="mb-6 flex gap-2 overflow-hidden"
                  >
                    <input
                      type="text"
                      value={newTaskTitle}
                      onChange={(e) => setNewTaskTitle(e.target.value)}
                      placeholder="Что нужно сделать?"
                      className="flex-1 bg-stone-50 border border-stone-200 rounded-xl px-3 py-2 text-sm text-zinc-900 focus:outline-none focus:border-blue-500"
                      autoFocus
                    />
                    <button
                      type="submit"
                      disabled={!newTaskTitle.trim()}
                      className="px-4 py-2 bg-blue-600 text-zinc-900 rounded-xl text-sm font-medium hover:bg-blue-500 transition-colors disabled:opacity-50"
                    >
                      <Plus className="w-5 h-5" />
                    </button>
                  </motion.form>
                )}
              </AnimatePresence>

              <div className="space-y-2">
                {dailyTasks.length === 0 ? (
                  <div className="flex flex-col items-center justify-center py-8 text-zinc-500">
                    <Home className="w-8 h-8 mb-2 opacity-20" />
                    <p className="text-sm">На этот день нет задач по дому</p>
                    <p className="text-xs mt-1">Выберите категорию выше, чтобы добавить</p>
                  </div>
                ) : (
                  dailyTasks.map(task => {
                    const categoryId = task.sphereId?.replace('household_', '');
                    const category = CATEGORIES.find(c => c.id === categoryId) || CATEGORIES[0];
                    const Icon = category.icon;
                    return (
                      <div
                        key={task.id}
                        className={cn(
                          "flex items-center gap-3 p-3 rounded-2xl border transition-colors",
                          task.completed 
                            ? "bg-white/30 border-stone-200/30 opacity-50" 
                            : "bg-white/60 border-stone-200"
                        )}
                      >
                        <button
                          onClick={() => toggleTaskCompletion(task.id)}
                          className={cn(
                            "flex-shrink-0 transition-colors",
                            task.completed ? "text-blue-500" : "text-zinc-500 hover:text-blue-400"
                          )}
                        >
                          {task.completed ? <CheckCircle2 className="w-5 h-5" /> : <Circle className="w-5 h-5" />}
                        </button>
                        
                        <div className={cn("w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0", category.bg)}>
                          <Icon className={cn("w-4 h-4", category.color)} />
                        </div>

                        <span className={cn(
                          "flex-1 text-sm transition-all",
                          task.completed ? "text-zinc-500 line-through" : "text-zinc-800"
                        )}>
                          {task.title}
                        </span>

                        <button
                          onClick={() => deleteTask(task.id)}
                          className="p-2 text-zinc-500 hover:text-red-400 rounded-lg hover:bg-stone-100 transition-colors"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    );
                  })
                )}
              </div>
            </motion.div>
          </AnimatePresence>
        </div>
      </div>

      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.2 }}
      >
        <HouseholdAssistant />
      </motion.div>
    </div>
  );
}
