import React from 'react';
import { Dumbbell, Flame } from 'lucide-react';
import { ResponsiveContainer, RadarChart, PolarGrid, PolarAngleAxis, Radar } from 'recharts';
import { format } from 'date-fns';
import { ru } from 'date-fns/locale';

interface StatsGridWidgetProps {
  recentWorkout: any;
  habitStreaks: any[];
  sphereBalance: any[];
}

export const StatsGridWidget: React.FC<StatsGridWidgetProps> = ({ 
  recentWorkout, 
  habitStreaks, 
  sphereBalance 
}) => {
  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800">
        <p className="text-[8px] text-zinc-500 font-semibold uppercase tracking-wider mb-3">Последняя тренировка</p>
        {recentWorkout ? (
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-xl bg-blue-500/10 flex items-center justify-center">
              <Dumbbell className="w-4 h-4 text-blue-500" />
            </div>
            <div>
              <p className="text-[10px] font-bold text-white truncate max-w-[120px]">{recentWorkout.exerciseName}</p>
              <p className="text-[8px] text-zinc-500">{format(new Date(recentWorkout.date), 'd MMM', { locale: ru })}</p>
            </div>
          </div>
        ) : (
          <p className="text-[9px] text-zinc-600 italic">Нет записей</p>
        )}
      </div>
      <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800">
        <p className="text-[8px] text-zinc-500 font-semibold uppercase tracking-wider mb-3">Топ привычек</p>
        <div className="space-y-2">
          {habitStreaks.length > 0 ? habitStreaks.map(s => (
            <div key={s.id} className="flex items-center justify-between">
              <p className="text-[8px] text-zinc-300 truncate max-w-[100px]">{s.title}</p>
              <div className="flex items-center gap-1">
                <Flame className="w-2 h-2 text-orange-500" />
                <span className="text-[8px] font-bold text-white">{s.streak}</span>
              </div>
            </div>
          )) : (
            <p className="text-[9px] text-zinc-600 italic">Нет активных стриков</p>
          )}
        </div>
      </div>
      <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800">
        <p className="text-[8px] text-zinc-500 font-semibold uppercase tracking-wider mb-1">Радар баланса</p>
        <div className="h-20">
          <ResponsiveContainer width="100%" height="100%">
            <RadarChart cx="50%" cy="50%" outerRadius="80%" data={sphereBalance}>
              <PolarGrid stroke="#27272a" />
              <PolarAngleAxis dataKey="sphere" tick={{ fill: '#71717a', fontSize: 4 }} />
              <Radar name="Баланс" dataKey="score" stroke="#6366f1" fill="#6366f1" fillOpacity={0.6} />
            </RadarChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  );
};
