import React from 'react';
import { TrendingUp, Award } from 'lucide-react';

interface EfficiencyWidgetProps {
  weeklyEfficiency: number;
  monthlyEfficiency: number;
}

export const EfficiencyWidget: React.FC<EfficiencyWidgetProps> = ({ weeklyEfficiency, monthlyEfficiency }) => {
  return (
    <div className="grid grid-cols-2 gap-4">
      <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800">
        <div className="flex items-center gap-2 mb-2">
          <div className="w-8 h-8 rounded-xl bg-emerald-500/10 flex items-center justify-center">
            <TrendingUp className="w-4 h-4 text-emerald-500" />
          </div>
          <div>
            <p className="text-[10px] text-zinc-500 font-medium uppercase tracking-wider">Неделя</p>
            <p className="text-lg font-bold text-white">{weeklyEfficiency}%</p>
          </div>
        </div>
        <div className="w-full bg-zinc-800 h-1 rounded-full overflow-hidden">
          <div className="bg-emerald-500 h-full rounded-full" style={{ width: `${weeklyEfficiency}%` }} />
        </div>
      </div>
      <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800">
        <div className="flex items-center gap-2 mb-2">
          <div className="w-8 h-8 rounded-xl bg-blue-500/10 flex items-center justify-center">
            <Award className="w-4 h-4 text-blue-500" />
          </div>
          <div>
            <p className="text-[10px] text-zinc-500 font-medium uppercase tracking-wider">Месяц</p>
            <p className="text-lg font-bold text-white">{monthlyEfficiency}%</p>
          </div>
        </div>
        <div className="w-full bg-zinc-800 h-1 rounded-full overflow-hidden">
          <div className="bg-blue-500 h-full rounded-full" style={{ width: `${monthlyEfficiency}%` }} />
        </div>
      </div>
    </div>
  );
};
