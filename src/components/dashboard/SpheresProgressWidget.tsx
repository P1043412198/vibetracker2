import React from 'react';
import { LayoutGrid, ArrowRight } from 'lucide-react';
import { Link } from 'react-router-dom';
import { motion } from 'motion/react';

interface SpheresProgressWidgetProps {
  spheres: any[];
  tasks: any[];
}

export const SpheresProgressWidget: React.FC<SpheresProgressWidgetProps> = ({ 
  spheres, 
  tasks 
}) => {
  return (
    <div className="bg-white p-4 rounded-3xl shadow-sm border border-stone-200">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-sm font-semibold text-zinc-900 flex items-center gap-2">
          <LayoutGrid className="w-4 h-4" />
          Прогресс по сферам
        </h2>
        <Link to="/spheres" className="text-xs text-zinc-500 hover:text-zinc-700 font-medium flex items-center gap-1">
          Все сферы <ArrowRight className="w-3.5 h-3.5" />
        </Link>
      </div>
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        {spheres.map(sphere => {
          const sphereTasks = tasks.filter(t => t.sphereId === sphere.id);
          const completed = sphereTasks.filter(t => t.completed).length;
          const progress = sphereTasks.length > 0 ? (completed / sphereTasks.length) * 100 : 0;
          
          return (
            <div key={sphere.id} className="bg-stone-50 p-3 rounded-2xl border border-stone-200">
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <div className="w-6 h-6 rounded-lg bg-white flex items-center justify-center text-xs">
                    {sphere.icon || '🌐'}
                  </div>
                  <span className="text-[10px] font-bold text-zinc-900 truncate max-w-[80px]">{sphere.title}</span>
                </div>
                <span className="text-[9px] font-bold text-zinc-500">{Math.round(progress)}%</span>
              </div>
              <div className="w-full bg-white h-1 rounded-full overflow-hidden">
                <motion.div 
                  initial={{ width: 0 }}
                  animate={{ width: `${progress}%` }}
                  className="h-full rounded-full"
                  style={{ backgroundColor: sphere.color || '#6366f1' }}
                />
              </div>
              <p className="text-[8px] text-zinc-600 mt-1.5">
                {completed} из {sphereTasks.length} задач
              </p>
            </div>
          );
        })}
        {spheres.length === 0 && (
          <div className="col-span-full text-center py-4 text-zinc-600">
            <p className="text-[10px]">Сферы не созданы</p>
          </div>
        )}
      </div>
    </div>
  );
};
