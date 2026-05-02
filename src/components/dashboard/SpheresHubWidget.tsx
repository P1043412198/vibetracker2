import React from 'react';
import { ResponsiveContainer, PieChart, Pie, Cell, Tooltip, BarChart, Bar, XAxis, YAxis } from 'recharts';
import { motion } from 'motion/react';
import { Target } from 'lucide-react';

interface SpheresHubWidgetProps {
  tasksBySphere: any[];
  tasksByStatus: any[];
  spheres: any[];
  tasks: any[];
}

export const SpheresHubWidget: React.FC<SpheresHubWidgetProps> = ({ 
  tasksBySphere, 
  tasksByStatus,
  spheres,
  tasks
}) => {
  return (
    <div className="bg-white p-4 rounded-3xl shadow-sm border border-stone-200 flex flex-col h-full">
      <div className="flex items-center gap-2 mb-4">
        <Target className="w-4 h-4 text-indigo-500" />
        <h2 className="text-sm font-semibold text-zinc-900">Сферы жизни</h2>
      </div>

      <div className="grid grid-cols-2 gap-4 mb-6">
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
            <div className="h-full flex items-center justify-center">
              <p className="text-[9px] text-zinc-600 italic">Нет задач</p>
            </div>
          )}
        </div>
      </div>

      <div className="flex-1">
        <p className="text-[8px] text-zinc-500 font-semibold uppercase tracking-wider mb-3">Прогресс по сферам</p>
        <div className="space-y-3">
          {spheres.map(sphere => {
            const sphereTasks = tasks.filter(t => t.sphereId === sphere.id);
            const completed = sphereTasks.filter(t => t.completed).length;
            const total = sphereTasks.length;
            const progress = total > 0 ? (completed / total) * 100 : 0;

            return (
              <div key={sphere.id}>
                <div className="flex justify-between items-center mb-1.5">
                  <div className="flex items-center gap-1.5">
                    <span className="text-[10px] font-medium text-zinc-900">{sphere.name}</span>
                  </div>
                  <span className="text-[9px] font-bold text-zinc-500">{Math.round(progress)}%</span>
                </div>
                <div className="w-full bg-stone-50 h-1.5 rounded-full overflow-hidden border border-stone-200">
                  <motion.div 
                    initial={{ width: 0 }}
                    animate={{ width: `${progress}%` }}
                    className="h-full rounded-full"
                    style={{ backgroundColor: sphere.color }}
                  />
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};
