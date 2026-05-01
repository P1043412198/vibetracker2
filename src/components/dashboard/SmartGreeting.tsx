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

  const { greeting, Icon, color } = useMemo(() => {
    const hour = new Date().getHours();
    if (hour >= 5 && hour < 12) return { greeting: 'Доброе утро', Icon: Coffee, color: 'text-amber-400' };
    if (hour >= 12 && hour < 18) return { greeting: 'Добрый день', Icon: Sun, color: 'text-amber-500' };
    if (hour >= 18 && hour < 23) return { greeting: 'Добрый вечер', Icon: Sunset, color: 'text-orange-400' };
    return { greeting: 'Доброй ночи', Icon: Moon, color: 'text-indigo-400' };
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
    <div className="bg-zinc-900/50 p-6 rounded-3xl border border-zinc-800/50 mb-6 flex items-start sm:items-center gap-4">
      <div className={`p-3 rounded-2xl bg-zinc-800/50 ${color}`}>
        <Icon className="w-8 h-8" />
      </div>
      <div>
        <h1 className="text-2xl font-bold text-white mb-1">{greeting}!</h1>
        <p className="text-sm text-zinc-400">{summary}</p>
      </div>
    </div>
  );
};
