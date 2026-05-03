import React, { useState } from 'react';
import { Droplets, Plus, Minus, Trash2, Settings } from 'lucide-react';
import { useStore } from '../store/useStore';
import { format } from 'date-fns';
import { cn } from '../lib/utils';
import { motion, AnimatePresence } from 'framer-motion';

export const WaterWidget: React.FC = () => {
  const { 
    waterLogs, logWater, deleteWaterLog, 
    waterGoal, setWaterGoal, 
    waterIncrement, setWaterIncrement,
    waterVisualization, setWaterVisualization
  } = useStore();
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const today = format(new Date(), 'yyyy-MM-dd');
  
  const todaysLogs = waterLogs.filter(log => log.date === today);
  const totalAmount = todaysLogs.reduce((sum, log) => sum + log.amount, 0);
  const progress = Math.min((totalAmount / waterGoal) * 100, 100);

  const handleAdd = () => {
    logWater(waterIncrement);
  };

  return (
    <div className="bg-white p-4 rounded-3xl shadow-sm border border-stone-200 flex flex-col h-full">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-sm font-semibold flex items-center gap-2 text-zinc-900">
          <Droplets className="w-4 h-4 text-blue-400" />
          Водный баланс
        </h2>
        <div className="flex items-center gap-2">
          <span className="text-xs font-medium text-zinc-500">
            {totalAmount} / {waterGoal} мл
          </span>
          <button 
            onClick={() => setIsSettingsOpen(!isSettingsOpen)}
            className="p-1 text-zinc-500 hover:text-zinc-900 transition-colors"
          >
            <Settings className="w-3 h-3" />
          </button>
        </div>
      </div>

      <div className="flex-1 flex flex-col gap-4">
        <AnimatePresence mode="wait">
          {isSettingsOpen ? (
            <motion.div 
              key="settings"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              className="space-y-4"
            >
              <div className="space-y-4">
                <div className="space-y-2">
                  <label className="text-[10px] uppercase tracking-wider text-zinc-500 font-bold">Цель на день (мл)</label>
                  <input 
                    type="number"
                    value={waterGoal}
                    onChange={(e) => setWaterGoal(Number(e.target.value))}
                    className="w-full bg-stone-50 border border-stone-200 rounded-xl px-3 py-2 text-sm text-zinc-900 focus:outline-none focus:border-blue-500"
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-[10px] uppercase tracking-wider text-zinc-500 font-bold">Шаг добавления (мл)</label>
                  <input 
                    type="number"
                    value={waterIncrement}
                    onChange={(e) => setWaterIncrement(Number(e.target.value))}
                    className="w-full bg-stone-50 border border-stone-200 rounded-xl px-3 py-2 text-sm text-zinc-900 focus:outline-none focus:border-blue-500"
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-[10px] uppercase tracking-wider text-zinc-500 font-bold">Визуализация</label>
                  <div className="flex gap-2">
                    <button 
                      onClick={() => setWaterVisualization('glass')}
                      className={cn(
                        "flex-1 py-2 rounded-xl text-xs font-medium transition-all border",
                        waterVisualization === 'glass' 
                          ? "bg-blue-600 border-blue-500 text-zinc-900" 
                          : "bg-stone-50 border-stone-200 text-zinc-500 hover:border-stone-300"
                      )}
                    >
                      Стакан
                    </button>
                    <button 
                      onClick={() => setWaterVisualization('bottle')}
                      className={cn(
                        "flex-1 py-2 rounded-xl text-xs font-medium transition-all border",
                        waterVisualization === 'bottle' 
                          ? "bg-blue-600 border-blue-500 text-zinc-900" 
                          : "bg-stone-50 border-stone-200 text-zinc-500 hover:border-stone-300"
                      )}
                    >
                      Бутылка
                    </button>
                  </div>
                </div>
              </div>
              <button 
                onClick={() => setIsSettingsOpen(false)}
                className="w-full bg-stone-100 hover:bg-stone-200 text-zinc-900 text-xs py-2 rounded-xl transition-colors"
              >
                Готово
              </button>
            </motion.div>
          ) : (
            <motion.div 
              key="main"
              initial={{ opacity: 0, y: -10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 10 }}
              className="flex flex-col gap-4"
            >
              {/* Visualization */}
              <div className="flex justify-center py-4">
                <div className={cn(
                  "relative overflow-hidden bg-stone-50/50 transition-all duration-500",
                  waterVisualization === 'glass' 
                    ? "w-24 h-32 border-x-2 border-b-2 border-stone-300 rounded-b-2xl" 
                    : "w-20 h-40 border-2 border-stone-300 rounded-t-lg rounded-b-2xl"
                )}>
                  {/* Bottle Neck */}
                  {waterVisualization === 'bottle' && (
                    <div className="absolute top-0 left-1/2 -translate-x-1/2 w-8 h-4 border-x-2 border-stone-300 bg-stone-50/50 -mt-4 rounded-t-sm" />
                  )}

                  {/* Water Level */}
                  <motion.div 
                    initial={{ height: 0 }}
                    animate={{ height: `${progress}%` }}
                    transition={{ type: 'spring', damping: 20, stiffness: 100 }}
                    className="absolute bottom-0 left-0 right-0 bg-blue-500/80 backdrop-blur-sm"
                  >
                    {/* Wave Effect */}
                    <motion.div 
                      animate={{ 
                        x: [0, -100, 0],
                      }}
                      transition={{ 
                        duration: 4, 
                        repeat: Infinity, 
                        ease: "linear" 
                      }}
                      className="absolute -top-4 left-0 w-[200%] h-8 opacity-50"
                      style={{
                        background: 'radial-gradient(circle at 50% 100%, transparent 20%, #3b82f6 21%, #3b82f6 34%, transparent 35%)',
                        backgroundSize: '40px 40px'
                      }}
                    />
                    
                    {/* Bubbles */}
                    {[...Array(5)].map((_, i) => (
                      <motion.div
                        key={i}
                        initial={{ bottom: -10, left: `${Math.random() * 100}%`, opacity: 0 }}
                        animate={{ 
                          bottom: '100%', 
                          opacity: [0, 1, 0],
                          x: [0, (Math.random() - 0.5) * 20, 0]
                        }}
                        transition={{ 
                          duration: 2 + Math.random() * 2, 
                          repeat: Infinity, 
                          delay: Math.random() * 2 
                        }}
                        className="absolute w-1 h-1 bg-white/40 rounded-full"
                      />
                    ))}
                  </motion.div>

                  {/* Shine Effects */}
                  <div className="absolute top-0 right-2 w-1 h-full bg-white/5 rounded-full" />
                  <div className="absolute top-4 left-2 w-0.5 h-12 bg-white/5 rounded-full" />
                </div>
              </div>

              {/* Progress Bar */}
              <div className="relative h-2 bg-stone-50 rounded-full overflow-hidden border border-stone-200">
                <motion.div 
                  initial={{ width: 0 }}
                  animate={{ width: `${progress}%` }}
                  className="absolute inset-y-0 left-0 bg-blue-500 rounded-full"
                />
              </div>

              {/* Controls */}
              <div className="flex items-center gap-2">
                <div className="flex-1 flex items-center bg-stone-50 rounded-2xl border border-stone-200 p-1">
                  <button 
                    onClick={() => setWaterIncrement(Math.max(50, waterIncrement - 50))}
                    className="p-2 text-zinc-500 hover:text-zinc-900 transition-colors"
                  >
                    <Minus className="w-4 h-4" />
                  </button>
                  <div className="flex-1 text-center text-sm font-medium text-zinc-900">
                    {waterIncrement} мл
                  </div>
                  <button 
                    onClick={() => setWaterIncrement(waterIncrement + 50)}
                    className="p-2 text-zinc-500 hover:text-zinc-900 transition-colors"
                  >
                    <Plus className="w-4 h-4" />
                  </button>
                </div>
                <button 
                  onClick={handleAdd}
                  className="bg-blue-600 hover:bg-blue-500 text-zinc-900 p-3 rounded-2xl transition-colors shadow-lg shadow-blue-900/20"
                >
                  <Plus className="w-5 h-5" />
                </button>
              </div>

              {/* Recent Logs */}
              <div className="space-y-2 max-h-32 overflow-y-auto pr-1 custom-scrollbar">
                <AnimatePresence mode="popLayout">
                  {todaysLogs.slice().reverse().map((log) => (
                    <motion.div 
                      key={log.id}
                      initial={{ opacity: 0, x: -10 }}
                      animate={{ opacity: 1, x: 0 }}
                      exit={{ opacity: 0, x: 10 }}
                      className="flex items-center justify-between p-2 bg-stone-50 rounded-xl border border-stone-200/70 group"
                    >
                      <div className="flex items-center gap-2">
                        <div className="w-1.5 h-1.5 rounded-full bg-blue-500" />
                        <span className="text-xs text-zinc-700">{log.amount} мл</span>
                        <span className="text-[10px] text-zinc-500">{log.timestamp.split('T')[1].slice(0, 5)}</span>
                      </div>
                      <button 
                        onClick={() => deleteWaterLog(log.id)}
                        className="opacity-0 group-hover:opacity-100 p-1 text-zinc-600 hover:text-red-400 transition-all"
                      >
                        <Trash2 className="w-3 h-3" />
                      </button>
                    </motion.div>
                  ))}
                </AnimatePresence>
                {todaysLogs.length === 0 && (
                  <div className="text-center py-4 text-zinc-600 text-[10px] italic">
                    Логи воды отсутствуют
                  </div>
                )}
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
};
