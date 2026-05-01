import React, { Dispatch, SetStateAction } from 'react';
import { Activity } from 'lucide-react';
import { ResponsiveContainer, BarChart, Bar, CartesianGrid, XAxis, YAxis, Tooltip } from 'recharts';
import { cn } from '../../lib/utils';

interface TrendsWidgetProps {
  efficiencyTrend: any[];
  efficiencyTrendDays: 7 | 30;
  setEfficiencyTrendDays: Dispatch<SetStateAction<7 | 30>>;
}

export const TrendsWidget: React.FC<TrendsWidgetProps> = ({ 
  efficiencyTrend, 
  efficiencyTrendDays, 
  setEfficiencyTrendDays 
}) => {
  return (
    <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-sm font-semibold text-white flex items-center gap-2">
          <Activity className="w-4 h-4" />
          Тренд эффективности
        </h2>
        <div className="flex bg-zinc-950 p-1 rounded-xl border border-zinc-800">
          <button 
            onClick={() => setEfficiencyTrendDays(7)}
            className={cn("px-2 py-1 text-[10px] font-medium rounded-lg transition-all", efficiencyTrendDays === 7 ? "bg-zinc-800 text-white shadow-sm" : "text-zinc-500 hover:text-zinc-300")}
          >
            7д
          </button>
          <button 
            onClick={() => setEfficiencyTrendDays(30)}
            className={cn("px-2 py-1 text-[10px] font-medium rounded-lg transition-all", efficiencyTrendDays === 30 ? "bg-zinc-800 text-white shadow-sm" : "text-zinc-500 hover:text-zinc-300")}
          >
            30д
          </button>
        </div>
      </div>
      <div className="h-48">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={efficiencyTrend} margin={{ top: 5, right: 0, left: -25, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#27272a" />
            <XAxis dataKey="date" axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 9 }} />
            <YAxis axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 9 }} />
            <Tooltip 
              cursor={{ fill: '#27272a', opacity: 0.4 }}
              contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', color: '#fff', borderRadius: '12px', fontSize: '10px', padding: '4px 8px' }}
              itemStyle={{ color: '#fff' }}
            />
            <Bar dataKey="efficiency" fill="#6366f1" radius={[4, 4, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
};
