import React from 'react';
import { Activity } from 'lucide-react';
import { format, subDays } from 'date-fns';
import { ru } from 'date-fns/locale';
import { cn } from '../../lib/utils';
import { useStore } from '../../store/useStore';

interface HabitMatrixWidgetProps {
  habitMatrix: any[];
}

export const HabitMatrixWidget: React.FC<HabitMatrixWidgetProps> = ({ habitMatrix }) => {
  const { hideHabitNames } = useStore();
  
  return (
    <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800">
      <h2 className="text-sm font-semibold text-white flex items-center gap-2 mb-4">
        <Activity className="w-4 h-4 text-indigo-500" />
        Матрица привычек
      </h2>
      <div className="overflow-x-auto pb-2">
        <div className="min-w-[280px]">
          <div className="grid grid-cols-[1fr_repeat(7,24px)] gap-2 mb-2">
            <div />
            {Array.from({ length: 7 }).map((_, i) => (
              <div key={i} className="text-[8px] text-zinc-500 text-center uppercase">
                {format(subDays(new Date(), 6 - i), 'EE', { locale: ru })}
              </div>
            ))}
          </div>
          <div className="space-y-2">
            {habitMatrix.length > 0 ? habitMatrix.slice(0, 5).map(habit => (
              <div key={habit.id} className="grid grid-cols-[1fr_repeat(7,24px)] gap-2 items-center">
                <div className="flex items-center gap-1.5 overflow-hidden">
                  <span className="text-[10px] shrink-0">{habit.icon || '✨'}</span>
                  <p className="text-[9px] text-zinc-300 truncate">{hideHabitNames ? '***' : habit.title}</p>
                </div>
                {habit.logs.map((log: any, i: number) => (
                  <div 
                    key={i}
                    className={cn(
                      "w-6 h-6 rounded-md border transition-all",
                      log.status === 'done' ? "bg-emerald-500/20 border-emerald-500/30" : 
                      log.status === 'failed' ? "bg-rose-500/20 border-rose-500/30" :
                      "bg-zinc-950 border-zinc-800"
                    )}
                  />
                ))}
              </div>
            )) : (
              <p className="text-[10px] text-zinc-600 italic text-center py-4">Нет активных привычек</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
