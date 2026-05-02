import React from 'react';
import { Calendar } from 'lucide-react';

interface ActivityCalendarWidgetProps {
  last30Days: any[];
}

export const ActivityCalendarWidget: React.FC<ActivityCalendarWidgetProps> = ({ last30Days }) => {
  return (
    <div className="bg-white p-4 rounded-3xl shadow-sm border border-stone-200">
      <h2 className="text-[10px] text-zinc-500 font-semibold uppercase tracking-wider mb-4 flex items-center gap-2">
        <Calendar className="w-3 h-3" />
        Календарь активности
      </h2>
      <div className="grid grid-cols-5 sm:grid-cols-10 gap-1.5">
        {last30Days.map((day) => {
          const intensity = Math.min(day.totalActivity / 5, 1); // 5 activities = 100% intensity
          return (
            <div 
              key={day.fullDate}
              className="aspect-square rounded-lg relative group flex flex-col items-center justify-center overflow-hidden"
              style={{ 
                backgroundColor: intensity > 0 
                  ? `rgba(99, 102, 241, ${0.1 + intensity * 0.9})` 
                  : '#18181b' 
              }}
            >
              {day.weight && (
                <span className="text-[7px] text-zinc-900/90 font-medium leading-none mb-0.5">
                  {day.weight}
                </span>
              )}
              <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 px-2 py-1 bg-stone-100 text-zinc-900 text-[8px] rounded opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap z-10">
                {day.date}: {day.totalActivity} акт. {day.weight ? `| ${day.weight} кг` : ''}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
