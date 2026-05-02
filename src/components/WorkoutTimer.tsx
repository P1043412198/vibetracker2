import React, { useState, useEffect, useRef } from 'react';
import { Play, Pause, Square, RotateCcw, X, Timer as TimerIcon, Plus, Minus } from 'lucide-react';
import { cn } from '../lib/utils';
import { motion, AnimatePresence } from 'framer-motion';
import { useStore } from '../store/useStore';

export function WorkoutTimer() {
  const { timer, setTimer, stopTimer, resetTimer } = useStore();
  const { timeLeft, initialTime, isRunning, isOpen } = timer;
  
  const setIsOpen = (open: boolean) => setTimer({ isOpen: open });
  const setIsMinimized = (min: boolean) => setIsMinimizedState(min);
  const [isMinimized, setIsMinimizedState] = useState(false);

  useEffect(() => {
    let interval: NodeJS.Timeout;
    if (isRunning && timeLeft > 0) {
      interval = setInterval(() => {
        setTimer({ timeLeft: timeLeft - 1 });
      }, 1000);
    } else if (isRunning && timeLeft === 0) {
      stopTimer();
      if ('vibrate' in navigator) {
        navigator.vibrate([200, 100, 200, 100, 200]);
      }
    }
    return () => clearInterval(interval);
  }, [isRunning, timeLeft, setTimer, stopTimer]);

  const toggleTimer = () => setTimer({ isRunning: !isRunning });
  
  const adjustTime = (amount: number) => {
    const newTime = Math.max(10, initialTime + amount);
    setTimer({ initialTime: newTime, timeLeft: isRunning ? timeLeft : newTime });
  };

  const formatTime = (seconds: number) => {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  if (!isOpen) {
    return (
      <button
        onClick={() => setIsOpen(true)}
        className="fixed bottom-20 right-4 z-40 bg-emerald-600 text-zinc-900 p-3 rounded-full shadow-lg hover:bg-emerald-500 transition-colors flex items-center justify-center"
      >
        <TimerIcon className="w-6 h-6" />
      </button>
    );
  }

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0, y: 50, scale: 0.9 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        exit={{ opacity: 0, y: 50, scale: 0.9 }}
        className={cn(
          "fixed z-50 bg-white border border-stone-300 shadow-2xl rounded-2xl overflow-hidden transition-all duration-300",
          isMinimized 
            ? "bottom-20 right-4 w-auto" 
            : "bottom-20 right-4 left-4 md:left-auto md:w-80"
        )}
      >
        {isMinimized ? (
          <div 
            className="flex items-center gap-3 p-3 cursor-pointer"
            onClick={() => setIsMinimized(false)}
          >
            <div className={cn(
              "text-lg font-mono font-bold",
              timeLeft === 0 ? "text-red-500 animate-pulse" : "text-emerald-400"
            )}>
              {formatTime(timeLeft)}
            </div>
            <button 
              onClick={(e) => { e.stopPropagation(); toggleTimer(); }}
              className="p-1.5 bg-stone-100 rounded-full text-zinc-900 hover:bg-stone-200"
            >
              {isRunning ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4" />}
            </button>
            <button 
              onClick={(e) => { e.stopPropagation(); setIsOpen(false); }}
              className="p-1.5 text-zinc-500 hover:text-zinc-900"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        ) : (
          <div className="flex flex-col">
            <div className="flex justify-between items-center p-3 border-b border-stone-200 bg-stone-50">
              <div className="flex items-center gap-2 text-zinc-700 font-medium">
                <TimerIcon className="w-4 h-4 text-emerald-500" />
                Таймер отдыха
              </div>
              <div className="flex items-center gap-1">
                <button 
                  onClick={() => setIsMinimized(true)}
                  className="p-1.5 text-zinc-500 hover:text-zinc-900 hover:bg-stone-100 rounded-lg transition-colors text-xs font-medium"
                >
                  Свернуть
                </button>
                <button 
                  onClick={() => setIsOpen(false)}
                  className="p-1.5 text-zinc-500 hover:text-zinc-900 hover:bg-stone-100 rounded-lg transition-colors"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
            </div>

            <div className="p-6 flex flex-col items-center justify-center">
              <div className={cn(
                "text-6xl font-mono font-bold mb-6 tracking-tighter",
                timeLeft === 0 ? "text-red-500 animate-pulse" : "text-zinc-900"
              )}>
                {formatTime(timeLeft)}
              </div>

              {!isRunning && timeLeft === initialTime && (
                <div className="flex items-center gap-2 mb-6">
                  <button onClick={() => adjustTime(-10)} className="p-2 bg-stone-100 text-zinc-700 rounded-lg hover:bg-stone-200 hover:text-zinc-900">
                    -10с
                  </button>
                  <button onClick={() => adjustTime(-30)} className="p-2 bg-stone-100 text-zinc-700 rounded-lg hover:bg-stone-200 hover:text-zinc-900">
                    -30с
                  </button>
                  <button onClick={() => adjustTime(30)} className="p-2 bg-stone-100 text-zinc-700 rounded-lg hover:bg-stone-200 hover:text-zinc-900">
                    +30с
                  </button>
                  <button onClick={() => adjustTime(60)} className="p-2 bg-stone-100 text-zinc-700 rounded-lg hover:bg-stone-200 hover:text-zinc-900">
                    +1м
                  </button>
                </div>
              )}

              <div className="flex items-center gap-4">
                <button
                  onClick={resetTimer}
                  className="p-4 bg-stone-100 text-zinc-700 rounded-full hover:bg-stone-200 hover:text-zinc-900 transition-colors"
                >
                  <RotateCcw className="w-6 h-6" />
                </button>
                <button
                  onClick={toggleTimer}
                  className={cn(
                    "p-5 rounded-full text-zinc-900 transition-all transform hover:scale-105 active:scale-95 shadow-lg",
                    isRunning 
                      ? "bg-amber-500 hover:bg-amber-400 shadow-amber-500/20" 
                      : "bg-emerald-500 hover:bg-emerald-400 shadow-emerald-500/20"
                  )}
                >
                  {isRunning ? <Pause className="w-8 h-8" /> : <Play className="w-8 h-8 ml-1" />}
                </button>
              </div>
            </div>
          </div>
        )}
      </motion.div>
    </AnimatePresence>
  );
}
