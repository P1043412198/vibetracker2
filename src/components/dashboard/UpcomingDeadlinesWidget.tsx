import React from 'react';
import { Clock } from 'lucide-react';
import { format } from 'date-fns';
import { ru } from 'date-fns/locale';
import { cn } from '../../lib/utils';

interface UpcomingDeadlinesWidgetProps {
  upcomingDeadlines: any[];
}

export const UpcomingDeadlinesWidget: React.FC<UpcomingDeadlinesWidgetProps> = ({ upcomingDeadlines }) => {
  return (
    <div className="bg-white p-4 rounded-3xl shadow-sm border border-stone-200">
      <h2 className="text-sm font-semibold text-zinc-900 flex items-center gap-2 mb-4">
        <Clock className="w-4 h-4 text-amber-500" />
        Ближайшие сроки
      </h2>
      <div className="space-y-2">
        {upcomingDeadlines.length > 0 ? upcomingDeadlines.slice(0, 4).map(item => (
          <div key={item.id} className="flex items-center justify-between p-2 bg-stone-50 rounded-xl border border-stone-200">
            <div className="flex items-center gap-2 overflow-hidden">
              <div className={cn(
                "w-1.5 h-1.5 rounded-full shrink-0",
                item.type === 'goal' ? "bg-indigo-500" : "bg-amber-500"
              )} />
              <p className="text-[10px] text-zinc-900 truncate">{item.title}</p>
            </div>
            <p className="text-[9px] text-zinc-500 whitespace-nowrap ml-2">
              {format(new Date(item.date), 'd MMM', { locale: ru })}
            </p>
          </div>
        )) : (
          <p className="text-[10px] text-zinc-600 italic text-center py-2">Срочных задач нет</p>
        )}
      </div>
    </div>
  );
};
