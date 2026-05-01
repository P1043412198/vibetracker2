import React from 'react';
import { ResponsiveContainer, PieChart, Pie, Cell, Tooltip, BarChart, Bar, XAxis, YAxis } from 'recharts';

interface SpheresChartsWidgetProps {
  tasksBySphere: any[];
  tasksByStatus: any[];
}

export const SpheresChartsWidget: React.FC<SpheresChartsWidgetProps> = ({ 
  tasksBySphere, 
  tasksByStatus 
}) => {
  return (
    <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800 grid grid-cols-2 gap-4">
      <div className="h-32">
        <p className="text-[8px] text-zinc-500 font-semibold uppercase tracking-wider mb-2">Аналитика сфер</p>
        {tasksBySphere.length > 0 ? (
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie data={tasksBySphere} cx="50%" cy="50%" innerRadius={15} outerRadius={30} paddingAngle={5} dataKey="value">
                {tasksBySphere.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={entry.color} />
                ))}
              </Pie>
              <Tooltip 
                contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', color: '#fff', borderRadius: '12px', fontSize: '8px', padding: '4px 8px' }}
                itemStyle={{ color: '#fff' }}
              />
            </PieChart>
          </ResponsiveContainer>
        ) : (
          <div className="h-full flex items-center justify-center">
            <p className="text-[9px] text-zinc-600 italic">Нет данных</p>
          </div>
        )}
      </div>
      <div className="h-32 flex flex-col">
        <p className="text-[8px] text-zinc-500 font-semibold uppercase tracking-wider mb-2">Статус задач</p>
        {tasksByStatus.some(t => t.value > 0) ? (
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={tasksByStatus} layout="vertical" margin={{ top: 0, right: 10, left: -30, bottom: 0 }}>
              <XAxis type="number" hide />
              <YAxis dataKey="name" type="category" axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 6 }} />
              <Bar dataKey="value" radius={[0, 4, 4, 0]}>
                {tasksByStatus.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={entry.color} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        ) : (
          <div className="flex-1 flex items-center justify-center">
            <p className="text-[9px] text-zinc-600 italic">Нет задач</p>
          </div>
        )}
      </div>
    </div>
  );
};
