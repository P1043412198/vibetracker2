import React, { useMemo } from 'react';
import { useStore } from '../../store/useStore';
import { format } from 'date-fns';
import { Sun, Moon, Coffee, Sunset } from 'lucide-react';

interface SmartGreetingProps {
  currentDate: Date;
  todaysTasks: any[];
}

export const SmartGreeting: React.FC<SmartGreetingProps> = ({ currentDate, todaysTasks }) => {
  const { habits, habitLogs, exerciseLogs } = useStore();
  const dateStr = format(currentDate, 'yyyy-MM-dd');

  const { greeting, Icon, gradient, iconColor } = useMemo(() => {
    const hour = new Date().getHours();
    if (hour >= 5 && hour < 12)
      return { greeting: 'Доброе утро', Icon: Coffee, gradient: 'from-amber-100 via-orange-50 to-rose-50', iconColor: 'bg-amber-200/70 text-amber-700' };
    if (hour >= 12 && hour < 18)
      return { greeting: 'Добрый день', Icon: Sun, gradient: 'from-emerald-100 via-teal-50 to-sky-50', iconColor: 'bg-amber-200/70 text-amber-700' };
    if (hour >= 18 && hour < 23)
      return { greeting: 'Добрый вечер', Icon: Sunset, gradient: 'from-orange-100 via-rose-50 to-purple-50', iconColor: 'bg-orange-200/70 text-orange-700' };
    return { greeting: 'Доброй ночи', Icon: Moon, gradient: 'from-indigo-100 via-purple-50 to-slate-50', iconColor: 'bg-indigo-200/70 text-indigo-700' };
  }, []);

  const summary = useMemo(() => {
    const pendingTasks = todaysTasks.filter(t => !t.completed && !t.failed).length;
    const hasWorkout = (exerciseLogs || []).some(l => l.date === dateStr);
    const waterHabit = habits.find(h => h.title.toLowerCase().includes('вод') || h.title.toLowerCase().includes('water'));
    const waterDone = waterHabit ? habitLogs.some(l => l.habitId === waterHabit.id && l.date === dateStr && l.status === 'done') : true;

    let text = '';
    if (pendingTasks > 0) {
      text += `У вас сегодня ${pendingTasks} ${pendingTasks === 1 ? 'важная задача' : pendingTasks < 5 ? 'важные задачи' : 'важных задач'}. `;
    } else {
      text += 'Все задачи на сегодня выполнены! 🎉 ';
    }

    if (hasWorkout) {
      text += 'Отличная работа, тренировка уже записана! 💪 ';
    }

    if (!waterDone) {
      text += 'Не забудьте выпить воды. 💧';
    }

    return text.trim();
  }, [todaysTasks, exerciseLogs, habits, habitLogs, dateStr]);

  return (
    <div className={`relative overflow-hidden bg-gradient-to-br ${gradient} p-5 sm:p-6 rounded-3xl border border-white shadow-md mb-6 flex items-start sm:items-center gap-4`}>
      <div className="absolute -top-8 -right-8 w-32 h-32 bg-white/40 rounded-full blur-2xl pointer-events-none" />
      <div className={`p-3 rounded-2xl shadow-sm ${iconColor} shrink-0 relative`}>
        <Icon className="w-7 h-7 sm:w-8 sm:h-8" />
      </div>
      <div className="relative min-w-0 flex-1">
        <h1 className="text-xl sm:text-2xl font-extrabold text-zinc-900 mb-0.5 truncate">{greeting}!</h1>
        <p className="text-xs sm:text-sm text-zinc-700/90">{summary}</p>
      </div>
    </div>
  );
};
