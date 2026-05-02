import React, { useEffect, useState } from 'react';
import { useStore } from '../store/useStore';
import { Play, Pause, RotateCcw, Coffee, Brain, Settings, Bell, BellOff } from 'lucide-react';
import { cn } from '../lib/utils';
import { motion, AnimatePresence } from 'motion/react';

export function PomodoroWidget() {
  const { pomodoro, tickPomodoro, updatePomodoro, startPomodoro, resetPomodoro, updatePomodoroSettings } = useStore();
  const [showSettings, setShowSettings] = useState(false);

  useEffect(() => {
    let interval: NodeJS.Timeout;
    if (pomodoro.isRunning && pomodoro.timeLeft > 0) {
      interval = setInterval(() => {
        tickPomodoro();
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [pomodoro.isRunning, pomodoro.timeLeft, tickPomodoro]);

  const playSound = () => {
    if (!pomodoro?.settings?.soundEnabled) return;
    try {
      const audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
      const oscillator = audioCtx.createOscillator();
      const gainNode = audioCtx.createGain();

      oscillator.connect(gainNode);
      gainNode.connect(audioCtx.destination);

      oscillator.type = 'sine';
      oscillator.frequency.setValueAtTime(523.25, audioCtx.currentTime); // C5
      oscillator.frequency.exponentialRampToValueAtTime(659.25, audioCtx.currentTime + 0.1); // E5
      oscillator.frequency.exponentialRampToValueAtTime(783.99, audioCtx.currentTime + 0.2); // G5

      gainNode.gain.setValueAtTime(0.1, audioCtx.currentTime);
      gainNode.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 0.5);

      oscillator.start();
      oscillator.stop(audioCtx.currentTime + 0.5);
    } catch (e) {
      console.error('Audio error:', e);
    }
  };

  useEffect(() => {
    if (pomodoro.timeLeft === 0 && !pomodoro.isRunning && pomodoro.totalTime > 0) {
      playSound();
    }
  }, [pomodoro.timeLeft, pomodoro.isRunning]);

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const progress = (pomodoro.timeLeft / pomodoro.totalTime) * 100;

  return (
    <div className="bg-white p-4 rounded-3xl shadow-sm border border-stone-200 relative overflow-hidden">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-sm font-semibold text-zinc-900 flex items-center gap-2">
          <Brain className="w-4 h-4 text-indigo-500" />
          Фокус (Pomodoro)
        </h2>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setShowSettings(!showSettings)}
            className={cn(
              "p-1.5 rounded-lg transition-colors",
              showSettings ? "bg-indigo-500 text-zinc-900" : "text-zinc-500 hover:text-zinc-700 hover:bg-stone-100"
            )}
          >
            <Settings className="w-4 h-4" />
          </button>
          <div className="flex items-center gap-1.5 bg-stone-50 p-1 rounded-xl border border-stone-200">
            <button
              onClick={() => startPomodoro('work')}
              className={cn(
                "px-2 py-1 text-[9px] font-bold rounded-lg transition-all",
                pomodoro.type === 'work' ? "bg-indigo-500 text-zinc-900" : "text-zinc-500 hover:text-zinc-700"
              )}
            >
              Работа
            </button>
            <button
              onClick={() => startPomodoro('shortBreak')}
              className={cn(
                "px-2 py-1 text-[9px] font-bold rounded-lg transition-all",
                pomodoro.type === 'shortBreak' ? "bg-emerald-500 text-zinc-900" : "text-zinc-500 hover:text-zinc-700"
              )}
            >
              Перерыв
            </button>
          </div>
        </div>
      </div>

      <AnimatePresence>
        {showSettings ? (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 10 }}
            className="absolute inset-x-0 bottom-0 top-[52px] bg-white z-10 p-4 flex flex-col gap-4"
          >
            <div className="grid grid-cols-3 gap-2">
              <div className="flex flex-col gap-1">
                <label className="text-[10px] text-zinc-500 uppercase font-bold">Работа</label>
                <input
                  type="number"
                  value={pomodoro?.settings?.workTime || 25}
                  onChange={(e) => updatePomodoroSettings({ workTime: parseInt(e.target.value) || 1 })}
                  className="bg-stone-50 border border-stone-200 rounded-lg px-2 py-1 text-xs text-zinc-900 focus:outline-none focus:border-indigo-500"
                />
              </div>
              <div className="flex flex-col gap-1">
                <label className="text-[10px] text-zinc-500 uppercase font-bold">Отдых</label>
                <input
                  type="number"
                  value={pomodoro?.settings?.shortBreakTime || 5}
                  onChange={(e) => updatePomodoroSettings({ shortBreakTime: parseInt(e.target.value) || 1 })}
                  className="bg-stone-50 border border-stone-200 rounded-lg px-2 py-1 text-xs text-zinc-900 focus:outline-none focus:border-emerald-500"
                />
              </div>
              <div className="flex flex-col gap-1">
                <label className="text-[10px] text-zinc-500 uppercase font-bold">Дл. Отдых</label>
                <input
                  type="number"
                  value={pomodoro?.settings?.longBreakTime || 15}
                  onChange={(e) => updatePomodoroSettings({ longBreakTime: parseInt(e.target.value) || 1 })}
                  className="bg-stone-50 border border-stone-200 rounded-lg px-2 py-1 text-xs text-zinc-900 focus:outline-none focus:border-emerald-500"
                />
              </div>
            </div>
            <div className="flex items-center justify-between">
              <button
                onClick={() => updatePomodoroSettings({ soundEnabled: !pomodoro?.settings?.soundEnabled })}
                className="flex items-center gap-2 text-xs text-zinc-500 hover:text-zinc-900 transition-colors"
              >
                {pomodoro?.settings?.soundEnabled ? <Bell className="w-4 h-4" /> : <BellOff className="w-4 h-4" />}
                Звуковой сигнал
              </button>
              <button
                onClick={() => setShowSettings(false)}
                className="px-3 py-1 bg-indigo-500 text-zinc-900 text-xs font-bold rounded-lg hover:bg-indigo-600 transition-colors"
              >
                Готово
              </button>
            </div>
          </motion.div>
        ) : null}
      </AnimatePresence>

      <div className="flex flex-col items-center justify-center py-2">
        <div className="relative w-32 h-32 mb-4">
          <svg className="w-full h-full transform -rotate-90">
            <circle
              cx="64"
              cy="64"
              r="58"
              stroke="currentColor"
              strokeWidth="6"
              fill="transparent"
              className="text-zinc-800"
            />
            <motion.circle
              cx="64"
              cy="64"
              r="58"
              stroke="currentColor"
              strokeWidth="6"
              fill="transparent"
              strokeDasharray={364.4}
              animate={{ strokeDashoffset: 364.4 * (1 - progress / 100) }}
              className={cn(
                "transition-all duration-1000",
                pomodoro.type === 'work' ? "text-indigo-500" : "text-emerald-500"
              )}
              strokeLinecap="round"
            />
          </svg>
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <span className="text-2xl font-bold text-zinc-900 tabular-nums">
              {formatTime(pomodoro.timeLeft)}
            </span>
            <span className="text-[10px] text-zinc-500 uppercase tracking-wider">
              {pomodoro.type === 'work' ? 'Фокус' : 'Отдых'}
            </span>
          </div>
        </div>

        <div className="flex items-center gap-4">
          <button
            onClick={resetPomodoro}
            className="p-2 bg-stone-100 text-zinc-500 rounded-xl hover:text-zinc-900 transition-colors"
          >
            <RotateCcw className="w-4 h-4" />
          </button>
          <button
            onClick={() => updatePomodoro({ isRunning: !pomodoro.isRunning })}
            className={cn(
              "w-12 h-12 flex items-center justify-center rounded-2xl transition-all active:scale-95 shadow-lg",
              pomodoro.isRunning 
                ? "bg-stone-100 text-zinc-900" 
                : "bg-white text-black hover:bg-zinc-200"
            )}
          >
            {pomodoro.isRunning ? <Pause className="w-6 h-6" /> : <Play className="w-6 h-6 fill-current" />}
          </button>
          <div className="w-8 flex flex-col items-center">
            <span className="text-xs font-bold text-zinc-900">{pomodoro.sessionsCompleted}</span>
            <span className="text-[8px] text-zinc-500 uppercase">Сессий</span>
          </div>
        </div>
      </div>
    </div>
  );
}
