import React, { useState, useEffect } from 'react';
import { motion } from 'motion/react';
import { Lock, Delete } from 'lucide-react';
import { useStore } from '../store/useStore';

export function PinLockScreen() {
  const { pinCode, isLocked, unlock } = useStore();
  const [input, setInput] = useState('');
  const [error, setError] = useState(false);

  useEffect(() => {
    if (input.length === 4) {
      if (input === pinCode) {
        unlock();
        setInput('');
      } else {
        setError(true);
        setTimeout(() => {
          setInput('');
          setError(false);
        }, 500);
      }
    }
  }, [input, pinCode, unlock]);

  useEffect(() => {
    const handleVisibilityChange = () => {
      if (document.visibilityState === 'hidden' && pinCode) {
        useStore.getState().lock();
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, [pinCode]);

  if (!pinCode || !isLocked) return null;

  const handleNumberClick = (num: number) => {
    if (input.length < 4) {
      setInput(prev => prev + num);
      setError(false);
    }
  };

  const handleDelete = () => {
    setInput(prev => prev.slice(0, -1));
    setError(false);
  };

  return (
    <div className="fixed inset-0 z-[100] bg-white flex flex-col items-center justify-center">
      <div className="flex flex-col items-center max-w-xs w-full px-6">
        <div className="w-16 h-16 bg-indigo-500/20 rounded-full flex items-center justify-center mb-6">
          <Lock className="w-8 h-8 text-indigo-500" />
        </div>
        
        <h2 className="text-2xl font-bold text-zinc-900 mb-2">Введите PIN-код</h2>
        <p className="text-zinc-500 text-sm mb-8 text-center">
          Приложение заблокировано для защиты ваших данных
        </p>

        <div className="flex gap-4 mb-12">
          {[0, 1, 2, 3].map(i => (
            <div 
              key={i}
              className={`w-4 h-4 rounded-full transition-all duration-300 ${
                input.length > i ? 'bg-indigo-500' : 'bg-stone-100'
              } ${error ? 'bg-red-500' : ''}`}
            />
          ))}
        </div>

        <div className="grid grid-cols-3 gap-4 w-full">
          {[1, 2, 3, 4, 5, 6, 7, 8, 9].map(num => (
            <button
              key={num}
              onClick={() => handleNumberClick(num)}
              className="h-16 rounded-2xl bg-white hover:bg-stone-100 text-2xl font-medium text-zinc-900 transition-colors flex items-center justify-center"
            >
              {num}
            </button>
          ))}
          <div />
          <button
            onClick={() => handleNumberClick(0)}
            className="h-16 rounded-2xl bg-white hover:bg-stone-100 text-2xl font-medium text-zinc-900 transition-colors flex items-center justify-center"
          >
            0
          </button>
          <button
            onClick={handleDelete}
            className="h-16 rounded-2xl bg-white hover:bg-stone-100 text-zinc-900 transition-colors flex items-center justify-center"
          >
            <Delete className="w-6 h-6" />
          </button>
        </div>
      </div>
    </div>
  );
}
