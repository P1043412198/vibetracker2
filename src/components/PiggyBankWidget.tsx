import React, { useState } from 'react';
import { motion } from 'motion/react';
import { PiggyBank, Plus, TrendingUp, Target, ChevronRight } from 'lucide-react';
import { useStore } from '../store/useStore';
import { cn } from '../lib/utils';

export function PiggyBankWidget() {
  const { savingsGoals = [], addSavingsContribution } = useStore();
  const [selectedGoalId, setSelectedGoalId] = useState<string | null>(savingsGoals[0]?.id || null);
  const [amount, setAmount] = useState('');

  const selectedGoal = savingsGoals.find(g => g.id === selectedGoalId) || savingsGoals[0];

  const [isWithdraw, setIsWithdraw] = useState(false);

  const handleContribute = (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedGoal || !amount) return;
    const finalAmount = parseFloat(amount) * (isWithdraw ? -1 : 1);
    addSavingsContribution(selectedGoal.id, finalAmount);
    setAmount('');
  };

  if (savingsGoals.length === 0) {
    return (
      <div className="h-full flex flex-col items-center justify-center text-center p-6 bg-white rounded-3xl border border-stone-200">
        <div className="w-12 h-12 bg-stone-100 rounded-full flex items-center justify-center mb-3">
          <PiggyBank className="w-6 h-6 text-zinc-500" />
        </div>
        <h3 className="text-sm font-medium text-zinc-900 mb-1">Копилка пуста</h3>
        <p className="text-xs text-zinc-500 mb-4">Установите цель в разделе Финансы</p>
      </div>
    );
  }

  const progress = Math.min((selectedGoal.currentAmount / selectedGoal.targetAmount) * 100, 100);
  const isFull = progress >= 100;

  return (
    <div className={cn(
      "h-full flex flex-col bg-white rounded-3xl border transition-all duration-500 p-5",
      isFull ? "border-amber-500/50 shadow-[0_0_20px_rgba(245,158,11,0.1)]" : "border-stone-200"
    )}>
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className={cn("p-2 rounded-lg", isFull ? "bg-amber-500/10" : "bg-pink-500/10")}>
            <PiggyBank className={cn("w-4 h-4", isFull ? "text-amber-500" : "text-pink-500")} />
          </div>
          <span className="text-sm font-bold text-zinc-900">Копилка</span>
        </div>
        <div className={cn("text-[10px] font-bold uppercase tracking-wider", isFull ? "text-amber-500" : "text-zinc-500")}>
          {progress.toFixed(0)}%
        </div>
      </div>

      <div className="flex-1 flex flex-col justify-center items-center mb-6">
        <div className="relative w-32 h-32 flex items-center justify-center">
          {/* Piggy Bank SVG with fill animation */}
          <svg viewBox="0 0 24 24" className={cn(
            "w-24 h-24 fill-none stroke-1 transition-colors duration-500",
            isFull ? "stroke-amber-500" : "stroke-zinc-800"
          )}>
            <path d="M19 5c-1.5 0-2.8 1.4-3 2-3.5-1.5-11-.3-11 5 0 1.8 0 3 2 4.5V20h4v-2h3v2h4v-4c2-1.5 2-2.7 2-4.5 0-5.3-7.5-6.5-11-5" />
            <circle cx="7" cy="12" r="0.5" fill="currentColor" />
          </svg>
          
          {/* Fill Mask */}
          <div 
            className="absolute bottom-4 left-4 right-4 overflow-hidden transition-all duration-1000 ease-out pointer-events-none"
            style={{ height: `${progress * 0.8}%`, maxHeight: '80%' }}
          >
            <div className={cn(
              "w-full h-32 blur-sm rounded-full transition-colors duration-500",
              isFull ? "bg-amber-500/40" : "bg-pink-500/40"
            )} />
            <div className={cn(
              "absolute inset-0 opacity-60 transition-colors duration-500",
              isFull ? "bg-amber-500" : "bg-pink-500"
            )} />
          </div>

          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <span className={cn("text-lg font-black", isFull ? "text-amber-500" : "text-zinc-900")}>
              {selectedGoal.currentAmount.toLocaleString()}
            </span>
            <span className="text-[8px] text-zinc-500 uppercase font-bold">из {selectedGoal.targetAmount.toLocaleString()}</span>
          </div>
        </div>
        <h4 className="text-xs font-medium text-zinc-700 mt-2">{selectedGoal.title}</h4>
      </div>

      <div className="space-y-2">
        <div className="flex gap-1 p-1 bg-stone-50 rounded-xl border border-stone-200/70">
          <button
            onClick={() => setIsWithdraw(false)}
            className={cn(
              "flex-1 py-1 text-[10px] font-bold rounded-lg transition-all",
              !isWithdraw ? "bg-stone-100 text-zinc-900" : "text-zinc-500"
            )}
          >
            ВНОС
          </button>
          <button
            onClick={() => setIsWithdraw(true)}
            className={cn(
              "flex-1 py-1 text-[10px] font-bold rounded-lg transition-all",
              isWithdraw ? "bg-stone-100 text-zinc-900" : "text-zinc-500"
            )}
          >
            СНЯТИЕ
          </button>
        </div>
        <form onSubmit={handleContribute} className="flex gap-2">
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder={isWithdraw ? "Снять..." : "Пополнить..."}
            className="flex-1 bg-stone-50 border border-stone-200 rounded-xl px-3 py-2 text-xs text-zinc-900 focus:outline-none focus:border-stone-300"
          />
          <button
            type="submit"
            disabled={!amount}
            className={cn(
              "p-2 rounded-xl text-zinc-900 transition-colors disabled:opacity-50",
              isWithdraw ? "bg-red-500 hover:bg-red-600" : "bg-pink-500 hover:bg-pink-600"
            )}
          >
            {isWithdraw ? <TrendingUp className="w-4 h-4 rotate-180" /> : <Plus className="w-4 h-4" />}
          </button>
        </form>
      </div>
    </div>
  );
}
