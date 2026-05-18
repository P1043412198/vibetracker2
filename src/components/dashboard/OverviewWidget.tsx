import React from 'react';
import { Zap, Award } from 'lucide-react';
import { motion } from 'motion/react';

interface OverviewWidgetProps {
  dailyEfficiency: number;
  todaysTasks: any[];
  habitLogs: any[];
  dateStr: string;
  totalTasks: number;
  completedTasks: number;
  taskProgress: number;
  totalGoodHabits: number;
  doneGoodHabits: number;
  goodHabitProgress: number;
  totalBadHabits: number;
  resistedBadHabits: number;
  badHabitProgress: number;
}

export const OverviewWidget: React.FC<OverviewWidgetProps> = ({ 
  dailyEfficiency, 
  todaysTasks, 
  habitLogs, 
  dateStr,
  totalTasks,
  completedTasks,
  taskProgress,
  totalGoodHabits,
  doneGoodHabits,
  goodHabitProgress,
  totalBadHabits,
  resistedBadHabits,
  badHabitProgress
}) => {
  const doneHabits = habitLogs.filter(l => l.date === dateStr && l.status === 'done');
  return (
    <div className="bg-white p-6 rounded-3xl shadow-sm border border-stone-200 flex flex-col gap-6">
      <div className="flex flex-col md:flex-row items-center gap-6">
        <div className="relative w-24 h-24 flex-shrink-0">
          <svg className="w-full h-full transform -rotate-90">
            <circle cx="48" cy="48" r="40" stroke="currentColor" strokeWidth="8" fill="transparent" className="text-zinc-800" />
            <circle cx="48" cy="48" r="40" stroke="currentColor" strokeWidth="8" fill="transparent" strokeDasharray={251.2} strokeDashoffset={251.2 * (1 - dailyEfficiency / 100)} className="text-zinc-900 transition-all duration-1000" strokeLinecap="round" />
          </svg>
          <div className="absolute inset-0 flex items-center justify-center flex-col">
            <span className="text-xl font-bold text-zinc-900">{dailyEfficiency}%</span>
          </div>
        </div>
        <div className="flex-1 text-center md:text-left">
          <h2 className="text-lg font-bold text-zinc-900 mb-1">Обзор дня и Эффективность</h2>
          <p className="text-xs text-zinc-500 leading-relaxed max-w-md">
            {dailyEfficiency >= 80 ? 'Отличный результат! Вы сегодня на высоте.' : 
             dailyEfficiency >= 50 ? 'Хороший темп. Продолжайте в том же духе.' : 
             'День только начался или требует больше внимания.'}
          </p>
          <div className="flex justify-center md:justify-start gap-4 mt-3">
            <div className="flex items-center gap-1.5">
              <Zap className="w-3 h-3 text-amber-500" />
              <span className="text-[10px] font-bold text-zinc-900">{completedTasks} задач</span>
            </div>
            <div className="flex items-center gap-1.5">
              <Award className="w-3 h-3 text-emerald-500" />
              <span className="text-[10px] font-bold text-zinc-900">{doneHabits.length} привычек</span>
            </div>
          </div>
        </div>
      </div>

      <div className="space-y-4 pt-4 border-t border-stone-200/70">
        {totalTasks > 0 && (
          <div className="space-y-1.5">
            <div className="flex justify-between text-[10px] uppercase tracking-wider">
              <span className="text-zinc-500">Задачи</span>
              <span className="text-zinc-900 font-bold">{completedTasks}/{totalTasks}</span>
            </div>
            <div className="w-full bg-stone-100 h-1.5 rounded-full overflow-hidden">
              <motion.div 
                initial={{ width: 0 }}
                animate={{ width: `${taskProgress}%` }}
                className="bg-indigo-500 h-full rounded-full" 
              />
            </div>
          </div>
        )}
        
        {totalGoodHabits > 0 && (
          <div className="space-y-1.5">
            <div className="flex justify-between text-[10px] uppercase tracking-wider">
              <span className="text-zinc-500">Полезные привычки</span>
              <span className="text-zinc-900 font-bold">{doneGoodHabits}/{totalGoodHabits}</span>
            </div>
            <div className="w-full bg-stone-100 h-1.5 rounded-full overflow-hidden">
              <motion.div 
                initial={{ width: 0 }}
                animate={{ width: `${goodHabitProgress}%` }}
                className="bg-emerald-500 h-full rounded-full" 
              />
            </div>
          </div>
        )}
        
        {totalBadHabits > 0 && (
          <div className="space-y-1.5">
            <div className="flex justify-between text-[10px] uppercase tracking-wider">
              <span className="text-zinc-500">Вредные привычки (сдержался)</span>
              <span className="text-zinc-900 font-bold">{resistedBadHabits}/{totalBadHabits}</span>
            </div>
            <div className="w-full bg-stone-100 h-1.5 rounded-full overflow-hidden">
              <motion.div 
                initial={{ width: 0 }}
                animate={{ width: `${badHabitProgress}%` }}
                className="bg-blue-500 h-full rounded-full" 
              />
            </div>
          </div>
        )}
        
        {totalTasks === 0 && totalGoodHabits === 0 && totalBadHabits === 0 && (
          <div className="text-center py-2 text-zinc-500 text-xs">
            Нет данных для расчета эффективности
          </div>
        )}
      </div>
    </div>
  );
};
