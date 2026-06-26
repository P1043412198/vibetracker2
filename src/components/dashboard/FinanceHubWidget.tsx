import React, { useState } from 'react';
import { Zap, QrCode, TrendingUp, PiggyBank, Target, ChevronRight } from 'lucide-react';
import { Link } from 'react-router-dom';
import { motion } from 'motion/react';
import { cn } from '../../lib/utils';
import { ReceiptScanner } from '../ReceiptScanner';
import { useStore } from '../../store/useStore';
import { SafeToSpendMini } from './SafeToSpendMini';

interface FinanceHubWidgetProps {
  financeStats: {
    totalBalance: number;
    monthExpenses: number;
    budgetProgress: number;
    budgetTotal: number;
  };
}

export const FinanceHubWidget: React.FC<FinanceHubWidgetProps> = ({ financeStats }) => {
  const [isScannerOpen, setIsScannerOpen] = useState(false);
  const { savingsGoals = [], addSavingsContribution, baseCurrency } = useStore();
  const [selectedGoalId, setSelectedGoalId] = useState<string | null>(savingsGoals[0]?.id || null);
  const [amount, setAmount] = useState('');
  const [isWithdraw, setIsWithdraw] = useState(false);

  const selectedGoal = savingsGoals.find(g => g.id === selectedGoalId) || savingsGoals[0];

  const handleContribute = (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedGoal || !amount) return;
    const finalAmount = parseFloat(amount) * (isWithdraw ? -1 : 1);
    addSavingsContribution(selectedGoal.id, finalAmount);
    setAmount('');
  };

  const progress = selectedGoal ? Math.min((selectedGoal.currentAmount / selectedGoal.targetAmount) * 100, 100) : 0;
  const isFull = progress >= 100;

  return (
    <div className="bg-white p-4 rounded-3xl shadow-sm border border-stone-200 flex flex-col h-full">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-sm font-semibold text-zinc-900 flex items-center gap-2">
          <Zap className="w-4 h-4 text-emerald-500" />
          Финансовый центр
        </h2>
        <div className="flex items-center gap-2">
          <button 
            onClick={() => setIsScannerOpen(true)}
            className="p-1.5 bg-stone-100 hover:bg-stone-200 rounded-lg text-zinc-500 hover:text-zinc-900 transition-colors"
            title="Сканировать чек"
          >
            <QrCode className="w-4 h-4" />
          </button>
          <Link to="/finance" className="text-[10px] text-zinc-500 hover:text-zinc-900 transition-colors">Подробнее</Link>
        </div>
      </div>

      <div className="mb-4">
        <SafeToSpendMini compact />
      </div>

      <div className="grid grid-cols-2 gap-4 mb-4">
        <div className="bg-stone-50 p-3 rounded-2xl border border-stone-200">
          <p className="text-[8px] text-zinc-500 uppercase tracking-wider mb-1">Баланс</p>
          <p className="text-sm font-bold text-zinc-900">{financeStats.totalBalance.toLocaleString()} <span className="text-[10px] font-normal text-zinc-500">{baseCurrency}</span></p>
        </div>
        <div className="bg-stone-50 p-3 rounded-2xl border border-stone-200">
          <p className="text-[8px] text-zinc-500 uppercase tracking-wider mb-1">Расход (мес)</p>
          <p className="text-sm font-bold text-rose-400">-{financeStats.monthExpenses.toLocaleString()} <span className="text-[10px] font-normal text-zinc-500">{baseCurrency}</span></p>
        </div>
      </div>

      {financeStats.budgetTotal > 0 && (
        <div className="mb-6">
          <div className="flex items-center justify-between mb-1.5">
            <p className="text-[8px] text-zinc-500 uppercase tracking-wider">Бюджет</p>
            <p className="text-[9px] font-bold text-zinc-900">{Math.round(financeStats.budgetProgress)}%</p>
          </div>
          <div className="w-full bg-stone-50 h-1.5 rounded-full overflow-hidden border border-stone-200">
            <motion.div 
              initial={{ width: 0 }}
              animate={{ width: `${Math.min(financeStats.budgetProgress, 100)}%` }}
              className={cn(
                "h-full rounded-full",
                financeStats.budgetProgress > 90 ? "bg-rose-500" : financeStats.budgetProgress > 70 ? "bg-amber-500" : "bg-emerald-500"
              )}
            />
          </div>
        </div>
      )}

      {selectedGoal && (
        <div className="flex-1 flex flex-col pt-4 border-t border-stone-200">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2">
              <div className={cn("p-1.5 rounded-lg", isFull ? "bg-amber-500/10" : "bg-pink-500/10")}>
                <PiggyBank className={cn("w-3.5 h-3.5", isFull ? "text-amber-500" : "text-pink-500")} />
              </div>
              <span className="text-xs font-bold text-zinc-900">Копилка: {selectedGoal.title}</span>
            </div>
            <div className={cn("text-[10px] font-bold uppercase tracking-wider", isFull ? "text-amber-500" : "text-zinc-500")}>
              {progress.toFixed(0)}%
            </div>
          </div>

          <div className="flex items-center gap-4 mb-4">
            <div className="relative w-16 h-16 flex-shrink-0 flex items-center justify-center">
              <svg viewBox="0 0 24 24" className={cn(
                "w-12 h-12 fill-none stroke-1 transition-colors duration-500",
                isFull ? "stroke-amber-500" : "stroke-zinc-800"
              )}>
                <path d="M19 5c-1.5 0-2.8 1.4-3 2-3.5-1.5-11-.3-11 5 0 1.8 0 3 2 4.5V20h4v-2h3v2h4v-4c2-1.5 2-2.7 2-4.5 0-5.3-7.5-6.5-11-5" />
                <circle cx="7" cy="12" r="0.5" fill="currentColor" />
              </svg>
              <div 
                className="absolute bottom-2 left-2 right-2 overflow-hidden transition-all duration-1000 ease-out pointer-events-none"
                style={{ height: `${progress * 0.8}%`, maxHeight: '80%' }}
              >
                <div className={cn(
                  "w-full h-16 blur-sm rounded-full transition-colors duration-500",
                  isFull ? "bg-amber-500/40" : "bg-pink-500/40"
                )} />
                <div className={cn(
                  "absolute inset-0 opacity-60 transition-colors duration-500",
                  isFull ? "bg-amber-500" : "bg-pink-500"
                )} />
              </div>
            </div>
            <div className="flex-1">
              <div className="flex justify-between items-end mb-1">
                <span className={cn("text-sm font-black", isFull ? "text-amber-500" : "text-zinc-900")}>
                  {selectedGoal.currentAmount.toLocaleString()}
                </span>
                <span className="text-[10px] text-zinc-500 uppercase font-bold">из {selectedGoal.targetAmount.toLocaleString()}</span>
              </div>
              <div className="w-full bg-stone-50 h-1.5 rounded-full overflow-hidden border border-stone-200">
                <motion.div 
                  initial={{ width: 0 }}
                  animate={{ width: `${progress}%` }}
                  className={cn(
                    "h-full rounded-full",
                    isFull ? "bg-amber-500" : "bg-pink-500"
                  )}
                />
              </div>
            </div>
          </div>

          <form onSubmit={handleContribute} className="flex gap-2 mt-auto">
            <button
              type="button"
              onClick={() => setIsWithdraw(!isWithdraw)}
              className={cn(
                "p-2 rounded-xl border transition-colors flex items-center justify-center",
                isWithdraw 
                  ? "bg-rose-500/10 border-rose-500/20 text-rose-500" 
                  : "bg-emerald-500/10 border-emerald-500/20 text-emerald-500"
              )}
            >
              {isWithdraw ? <TrendingUp className="w-4 h-4 rotate-180" /> : <TrendingUp className="w-4 h-4" />}
            </button>
            <input
              type="number"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder={isWithdraw ? "Снять..." : "Пополнить..."}
              className="flex-1 bg-stone-50 border border-stone-200 rounded-xl px-3 py-2 text-sm text-zinc-900 focus:outline-none focus:border-stone-300"
              min="0"
              step="0.01"
            />
            <button
              type="submit"
              disabled={!amount}
              className="p-2 bg-stone-100 text-zinc-900 rounded-xl hover:bg-stone-200 transition-colors disabled:opacity-50"
            >
              <ChevronRight className="w-4 h-4" />
            </button>
          </form>
        </div>
      )}

      {isScannerOpen && (
        <ReceiptScanner onClose={() => setIsScannerOpen(false)} />
      )}
    </div>
  );
};
