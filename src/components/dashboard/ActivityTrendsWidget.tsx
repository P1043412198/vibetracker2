import React from 'react';
import { ResponsiveContainer, AreaChart, Area, CartesianGrid, XAxis, YAxis, Tooltip, BarChart, Bar } from 'recharts';

interface ActivityTrendsWidgetProps {
  last30Days: any[];
}

export const ActivityTrendsWidget: React.FC<ActivityTrendsWidgetProps> = ({ last30Days }) => {
  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800">
        <div className="mb-3">
          <h2 className="text-sm font-semibold text-white flex items-center gap-2">
            <div className="w-2 h-2 rounded-full bg-indigo-500"></div>
            Задачи (30 дней)
          </h2>
        </div>
        <div className="h-32">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={last30Days} margin={{ top: 5, right: 0, left: -25, bottom: 0 }}>
              <defs>
                <linearGradient id="colorTasksDash" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#6366f1" stopOpacity={0.4}/>
                  <stop offset="95%" stopColor="#6366f1" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#27272a" />
              <XAxis dataKey="date" axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 9 }} minTickGap={20} />
              <YAxis axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 9 }} />
              <Tooltip 
                contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', color: '#fff', borderRadius: '12px', fontSize: '10px', padding: '4px 8px' }}
                itemStyle={{ color: '#fff' }}
              />
              <Area type="monotone" dataKey="tasks" name="Задачи" stroke="#6366f1" strokeWidth={2} fillOpacity={1} fill="url(#colorTasksDash)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800">
        <div className="mb-3">
          <h2 className="text-sm font-semibold text-white flex items-center gap-2">
            <div className="w-2 h-2 rounded-full bg-emerald-500"></div>
            Привычки (30 дней)
          </h2>
        </div>
        <div className="h-32">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={last30Days} margin={{ top: 5, right: 0, left: -25, bottom: 0 }}>
              <defs>
                <linearGradient id="colorHabitsDash" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#10b981" stopOpacity={0.4}/>
                  <stop offset="95%" stopColor="#10b981" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#27272a" />
              <XAxis dataKey="date" axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 9 }} minTickGap={20} />
              <YAxis axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 9 }} />
              <Tooltip 
                contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', color: '#fff', borderRadius: '12px', fontSize: '10px', padding: '4px 8px' }}
                itemStyle={{ color: '#fff' }}
              />
              <Area type="monotone" dataKey="habits" name="Привычки" stroke="#10b981" strokeWidth={2} fillOpacity={1} fill="url(#colorHabitsDash)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800">
        <div className="mb-3">
          <h2 className="text-sm font-semibold text-white flex items-center gap-2">
            <div className="w-2 h-2 rounded-full bg-blue-500"></div>
            Тренировки (30 дней)
          </h2>
        </div>
        <div className="h-32">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={last30Days} margin={{ top: 5, right: 0, left: -25, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#27272a" />
              <XAxis dataKey="date" axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 9 }} minTickGap={20} />
              <YAxis axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 9 }} allowDecimals={false} />
              <Tooltip 
                contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', color: '#fff', borderRadius: '12px', fontSize: '10px', padding: '4px 8px' }}
                itemStyle={{ color: '#fff' }}
              />
              <Bar dataKey="workouts" name="Подходы" fill="#3b82f6" radius={[2, 2, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  );
};
