import React from 'react';
import { Activity, CheckCircle2 } from 'lucide-react';
import { format, subDays } from 'date-fns';
import { cn } from '../../lib/utils';
import { useStore } from '../../store/useStore';

interface HabitStoriesWidgetProps {
  habits: any[];
  habitLogs: any[];
  dateStr: string;
  handleHabitLog: (habitId: string, status: 'done' | 'skipped' | 'failed') => void;
}

export const HabitStoriesWidget: React.FC<HabitStoriesWidgetProps> = ({ 
  habits, 
  habitLogs, 
  dateStr, 
  handleHabitLog 
}) => {
  const { hideHabitNames } = useStore();
  
  return (
    <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800">
      <h2 className="text-[10px] text-zinc-500 font-semibold uppercase tracking-wider mb-4 flex items-center gap-2">
        <Activity className="w-3 h-3" />
        Привычки дня
      </h2>
      <div className="flex gap-4 overflow-x-auto pb-4 scrollbar-hide">
        {habits.map(habit => {
          const log = habitLogs.find(l => l.habitId === habit.id && l.date === dateStr);
          const isDone = log?.status === 'done';
          
          // Calculate last 7 days for this habit
          const history = Array.from({ length: 7 }).map((_, i) => {
            const d = subDays(new Date(), i);
            const dStr = format(d, 'yyyy-MM-dd');
            const l = habitLogs.find(log => log.habitId === habit.id && log.date === dStr);
            return { date: dStr, status: l?.status };
          }).reverse();

          return (
            <div key={habit.id} className="flex flex-col items-center gap-2 flex-shrink-0">
              <button 
                onClick={() => handleHabitLog(habit.id, isDone ? 'skipped' : 'done')}
                className="relative w-14 h-14 rounded-full p-1 transition-transform active:scale-95"
              >
                <div className={cn(
                  "absolute inset-0 rounded-full border-2 transition-colors",
                  isDone ? "border-emerald-500" : "border-zinc-800"
                )} />
                <div className={cn(
                  "w-full h-full rounded-full flex items-center justify-center text-xl transition-all",
                  isDone ? "bg-emerald-500/20" : "bg-zinc-950"
                )}>
                  {habit.icon || '✨'}
                </div>
                {isDone && (
                  <div className="absolute -bottom-1 -right-1 bg-emerald-500 rounded-full p-0.5 border-2 border-zinc-900">
                    <CheckCircle2 className="w-3 h-3 text-white" />
                  </div>
                )}
              </button>
              <div className="flex gap-0.5">
                {history.map((h, i) => (
                  <div 
                    key={i} 
                    className={cn(
                      "w-1.5 h-1.5 rounded-full",
                      h.status === 'done' ? "bg-emerald-500" : 
                      h.status === 'failed' ? "bg-rose-500" : 
                      h.status === 'skipped' ? "bg-zinc-700" : "bg-zinc-800"
                    )} 
                  />
                ))}
              </div>
              <span className="text-[9px] text-zinc-400 font-medium truncate w-16 text-center">
                {hideHabitNames ? '***' : habit.title}
              </span>
            </div>
          );
        })}
        {habits.length === 0 && (
          <p className="text-[10px] text-zinc-600 italic">Нет привычек</p>
        )}
      </div>
    </div>
  );
};
