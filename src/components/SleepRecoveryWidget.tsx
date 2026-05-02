import React, { useState } from 'react';
import { useStore } from '../store/useStore';
import { Moon, Plus, Trash2, Star, TrendingUp, AlertCircle } from 'lucide-react';
import { format, subDays, isSameDay, parseISO } from 'date-fns';
import { ru } from 'date-fns/locale';
import { motion, AnimatePresence } from 'motion/react';
import { cn } from '../lib/utils';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

export function SleepRecoveryWidget() {
  const { sleepLogs, logSleep, deleteSleepLog } = useStore();
  const [isLogging, setIsLogging] = useState(false);
  const [newLog, setNewLog] = useState({
    hours: 7.5,
    quality: 3,
    notes: ''
  });

  const last7Days = Array.from({ length: 7 }, (_, i) => {
    const date = subDays(new Date(), i);
    const log = sleepLogs.find(l => isSameDay(parseISO(l.date), date));
    return {
      date: format(date, 'dd.MM', { locale: ru }),
      hours: log?.hours || 0,
      quality: log?.quality || 0,
      fullDate: format(date, 'yyyy-MM-dd')
    };
  }).reverse();

  const averageHours = sleepLogs.length > 0 
    ? sleepLogs.reduce((acc, curr) => acc + curr.hours, 0) / sleepLogs.length 
    : 0;

  const readinessScore = Math.min(100, Math.round((averageHours / 8) * 70 + (newLog.quality / 5) * 30));

  const handleLog = () => {
    logSleep({
      date: format(new Date(), 'yyyy-MM-dd'),
      hours: newLog.hours,
      quality: newLog.quality as 1 | 2 | 3 | 4 | 5,
      notes: newLog.notes
    });
    setIsLogging(false);
  };

  return (
    <div className="bg-white p-4 rounded-3xl shadow-sm border border-stone-200">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-sm font-semibold text-zinc-900 flex items-center gap-2">
          <Moon className="w-4 h-4 text-indigo-500" />
          Сон и Восстановление
        </h2>
        <button
          onClick={() => setIsLogging(!isLogging)}
          className="p-1.5 bg-stone-100 text-zinc-500 rounded-xl hover:text-zinc-900 transition-colors"
        >
          <Plus className="w-4 h-4" />
        </button>
      </div>

      <AnimatePresence mode="wait">
        {isLogging ? (
          <motion.div
            key="logging"
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.95 }}
            className="bg-stone-50 p-4 rounded-2xl border border-stone-200 space-y-4"
          >
            <div>
              <label className="text-[10px] text-zinc-500 uppercase font-bold mb-2 block">
                Часов сна: {newLog.hours}ч
              </label>
              <input
                type="range"
                min="0"
                max="12"
                step="0.5"
                value={newLog.hours}
                onChange={(e) => setNewLog({ ...newLog, hours: parseFloat(e.target.value) })}
                className="w-full h-1.5 bg-stone-100 rounded-lg appearance-none cursor-pointer accent-emerald-500"
              />
            </div>
            <div>
              <label className="text-[10px] text-zinc-500 uppercase font-bold mb-2 block">
                Качество (1-5): {newLog.quality}
              </label>
              <div className="flex gap-2">
                {[1, 2, 3, 4, 5].map(q => (
                  <button
                    key={q}
                    onClick={() => setNewLog({ ...newLog, quality: q })}
                    className={cn(
                      "flex-1 py-1.5 rounded-xl border border-stone-200 transition-all",
                      newLog.quality === q ? "bg-indigo-500 text-zinc-900 border-indigo-500" : "bg-stone-50 text-zinc-500 hover:text-zinc-700"
                    )}
                  >
                    {q}
                  </button>
                ))}
              </div>
            </div>
            <div className="flex gap-2">
              <button
                onClick={() => setIsLogging(false)}
                className="flex-1 py-2 text-xs font-bold text-zinc-500 hover:text-zinc-700"
              >
                Отмена
              </button>
              <button
                onClick={handleLog}
                className="flex-1 py-2 text-xs font-bold bg-white text-black rounded-xl hover:bg-zinc-200"
              >
                Сохранить
              </button>
            </div>
          </motion.div>
        ) : (
          <motion.div
            key="stats"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="space-y-4"
          >
            <div className="grid grid-cols-2 gap-3">
              <div className="bg-stone-50 p-3 rounded-2xl border border-stone-200">
                <div className="flex items-center gap-2 mb-1">
                  <TrendingUp className="w-3 h-3 text-emerald-500" />
                  <span className="text-[10px] text-zinc-500 uppercase font-bold">Готовность</span>
                </div>
                <div className="flex items-end gap-2">
                  <span className="text-xl font-bold text-zinc-900">{readinessScore}%</span>
                  <span className={cn(
                    "text-[9px] mb-1 font-bold",
                    readinessScore > 80 ? "text-emerald-500" : readinessScore > 60 ? "text-amber-500" : "text-rose-500"
                  )}>
                    {readinessScore > 80 ? 'Высокая' : readinessScore > 60 ? 'Средняя' : 'Низкая'}
                  </span>
                </div>
              </div>
              <div className="bg-stone-50 p-3 rounded-2xl border border-stone-200">
                <div className="flex items-center gap-2 mb-1">
                  <Star className="w-3 h-3 text-amber-500" />
                  <span className="text-[10px] text-zinc-500 uppercase font-bold">Средний сон</span>
                </div>
                <div className="flex items-end gap-2">
                  <span className="text-xl font-bold text-zinc-900">{averageHours.toFixed(1)}ч</span>
                  <span className="text-[9px] mb-1 text-zinc-500">в сутки</span>
                </div>
              </div>
            </div>

            <div className="h-24 w-full">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={last7Days}>
                  <defs>
                    <linearGradient id="colorHours" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#6366f1" stopOpacity={0.3}/>
                      <stop offset="95%" stopColor="#6366f1" stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <Area
                    type="monotone"
                    dataKey="hours"
                    stroke="#6366f1"
                    fillOpacity={1}
                    fill="url(#colorHours)"
                    strokeWidth={2}
                  />
                  <XAxis 
                    dataKey="date" 
                    axisLine={false} 
                    tickLine={false} 
                    tick={{ fontSize: 8, fill: '#52525b' }}
                  />
                  <YAxis hide domain={[0, 12]} />
                  <Tooltip 
                    contentStyle={{ backgroundColor: '#09090b', border: '1px solid #27272a', borderRadius: '12px', fontSize: '10px' }}
                    itemStyle={{ color: '#fff' }}
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>

            {readinessScore < 60 && (
              <div className="flex items-start gap-2 p-2 bg-rose-500/10 rounded-xl border border-rose-500/20">
                <AlertCircle className="w-4 h-4 text-rose-500 shrink-0 mt-0.5" />
                <p className="text-[10px] text-rose-200 leading-tight">
                  Низкий уровень восстановления. Рекомендуется снизить интенсивность тренировок сегодня.
                </p>
              </div>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
