import React, { useMemo, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useStore } from '../store/useStore';
import { useCurrencyConverter } from '../hooks/useCurrencyConverter';
import { Coins, TreeDeciduous, TrendingUp, Sparkles, Edit2, Check } from 'lucide-react';
import { cn } from '../lib/utils';

export function WealthTree() {
  const { 
    accounts = [], 
    savingsGoals = [], 
    transactions = [], 
    loans = [],
    rates = {},
    baseCurrency = 'BYN',
    wealthTreeTarget,
    setWealthTreeTarget
  } = useStore();

  const [isEditingTarget, setIsEditingTarget] = useState(false);
  const [tempTarget, setTempTarget] = useState((wealthTreeTarget || 100000).toString());

  const convertCurrency = useCurrencyConverter();

  const totalSavings = useMemo(() => {
    const accountAssets = accounts.reduce((sum, acc) => {
      const accountTransactions = transactions.filter(t => t.accountId === acc.id || t.toAccountId === acc.id);
      const balance = accountTransactions.reduce((s, t) => {
        if (t.type === 'income' && t.accountId === acc.id) return s + t.amount;
        if (t.type === 'expense' && t.accountId === acc.id) return s - t.amount;
        if (t.type === 'transfer') {
          if (t.accountId === acc.id) return s - t.amount;
          if (t.toAccountId === acc.id) {
            const fromAccount = accounts.find(a => a.id === t.accountId);
            if (fromAccount && fromAccount.currency !== acc.currency) {
              const amountInAnchor = t.amount * (rates[fromAccount.currency] || 1);
              const amountInTarget = amountInAnchor / (rates[acc.currency] || 1);
              return s + amountInTarget;
            }
            return s + t.amount;
          }
        }
        return s;
      }, acc.initialBalance);
      return sum + convertCurrency(balance, acc.currency || baseCurrency, baseCurrency);
    }, 0);
    const goalAssets = savingsGoals.reduce((sum, g) => sum + convertCurrency(g.currentAmount, g.currency || baseCurrency, baseCurrency), 0);
    return accountAssets + goalAssets;
  }, [accounts, savingsGoals, transactions, rates, baseCurrency]);

  const totalDebt = useMemo(() => {
    return loans.reduce((sum, loan) => {
      const totalPaid = (loan.payments || [])
        .filter(p => p.type === 'payment')
        .reduce((s, p) => s + p.amount, 0);
      const totalWithdrawn = (loan.payments || [])
        .filter(p => p.type === 'withdrawal')
        .reduce((s, p) => s + p.amount, 0);
      const remainingDebt = loan.totalPayment - (totalPaid - totalWithdrawn);
      return sum + convertCurrency(remainingDebt, loan.currency || baseCurrency, baseCurrency);
    }, 0);
  }, [loans, rates, baseCurrency]);

  const netWorth = totalSavings - totalDebt;

  const targetAmount = wealthTreeTarget || 100000;

  // Growth stages based on netWorth and targetAmount
  // 0: Debt
  // 1: < 1% of target
  // 2: < 5% of target
  // 3: < 20% of target
  // 4: < 100% of target
  // 5: >= 100% of target
  const growthLevel = useMemo(() => {
    if (netWorth <= 0) return 0;
    if (netWorth < targetAmount * 0.01) return 1;
    if (netWorth < targetAmount * 0.05) return 2;
    if (netWorth < targetAmount * 0.2) return 3;
    if (netWorth < targetAmount) return 4;
    return 5;
  }, [netWorth, targetAmount]);

  const getStageName = (level: number) => {
    switch(level) {
      case 0: return 'Почва (Долги)';
      case 1: return 'Росток';
      case 2: return 'Молодое дерево';
      case 3: return 'Крепкое дерево';
      case 4: return 'Плодоносное дерево';
      case 5: return 'Золотой дуб';
      default: return 'Росток';
    }
  };

  return (
    <div className="bg-white/60 border border-stone-200 rounded-3xl p-8 relative overflow-hidden flex flex-col items-center text-center">
      <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-emerald-500/0 via-emerald-500/50 to-emerald-500/0" />
      
      <div className="mb-6 w-full flex flex-col items-center">
        <h3 className="text-lg font-bold text-zinc-900 flex items-center justify-center gap-2">
          <TreeDeciduous className="w-5 h-5 text-emerald-500" />
          Дерево богатства
        </h3>
        <p className="text-xs text-zinc-500 mt-1 uppercase tracking-widest font-bold">
          Стадия: <span className="text-emerald-400">{getStageName(growthLevel)}</span>
        </p>
        
        <div className="mt-4 flex items-center gap-2 bg-stone-50 px-3 py-1.5 rounded-xl border border-stone-200">
          <span className="text-xs text-zinc-500 font-medium">Цель:</span>
          {isEditingTarget ? (
            <div className="flex items-center gap-2">
              <input
                type="number"
                value={tempTarget}
                onChange={(e) => setTempTarget(e.target.value)}
                className="w-24 bg-white text-zinc-900 text-sm px-2 py-1 rounded-lg border border-stone-300 outline-none focus:border-emerald-500"
                autoFocus
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    setWealthTreeTarget(Number(tempTarget));
                    setIsEditingTarget(false);
                  }
                }}
              />
              <button
                onClick={() => {
                  setWealthTreeTarget(Number(tempTarget));
                  setIsEditingTarget(false);
                }}
                className="p-1 hover:bg-stone-100 rounded-lg text-emerald-500"
              >
                <Check className="w-4 h-4" />
              </button>
            </div>
          ) : (
            <div className="flex items-center gap-2 group cursor-pointer" onClick={() => setIsEditingTarget(true)}>
              <span className="text-sm font-bold text-emerald-400">{targetAmount.toLocaleString()} {baseCurrency}</span>
              <Edit2 className="w-3 h-3 text-zinc-500 opacity-0 group-hover:opacity-100 transition-opacity" />
            </div>
          )}
        </div>
      </div>

      {/* Tree Visualization */}
      <div className="relative w-64 h-64 flex items-end justify-center mb-8">
        {/* Ground */}
        <div className="absolute bottom-0 w-48 h-2 bg-stone-100 rounded-full" />
        
        {/* The Tree (SVG) */}
        <svg viewBox="0 0 100 100" className="w-full h-full">
          {/* Trunk */}
          <motion.path
            d="M50 95 L50 70"
            stroke="#3f3f46"
            strokeWidth={growthLevel > 0 ? 4 : 2}
            strokeLinecap="round"
            initial={{ pathLength: 0 }}
            animate={{ pathLength: 1 }}
            transition={{ duration: 1 }}
          />
          
          {/* Branches - Level 2+ */}
          {growthLevel >= 2 && (
            <>
              <motion.path
                d="M50 80 L35 65"
                stroke="#3f3f46"
                strokeWidth="3"
                strokeLinecap="round"
                initial={{ pathLength: 0 }}
                animate={{ pathLength: 1 }}
                transition={{ duration: 1, delay: 0.2 }}
              />
              <motion.path
                d="M50 75 L65 60"
                stroke="#3f3f46"
                strokeWidth="3"
                strokeLinecap="round"
                initial={{ pathLength: 0 }}
                animate={{ pathLength: 1 }}
                transition={{ duration: 1, delay: 0.3 }}
              />
            </>
          )}

          {/* Leaves/Crown - Level 1+ */}
          <AnimatePresence>
            {growthLevel >= 1 && (
              <motion.circle
                cx="50" cy="65" r={growthLevel * 6}
                fill={growthLevel >= 5 ? "#fbbf24" : "#10b981"}
                fillOpacity="0.2"
                stroke={growthLevel >= 5 ? "#fbbf24" : "#10b981"}
                strokeWidth="1"
                initial={{ scale: 0 }}
                animate={{ scale: 1 }}
                exit={{ scale: 0 }}
                className="transition-all duration-1000"
              />
            )}
            
            {/* Level 3+ extra foliage */}
            {growthLevel >= 3 && (
              <>
                <motion.circle
                  cx="35" cy="60" r={growthLevel * 3}
                  fill="#10b981" fillOpacity="0.15"
                  initial={{ scale: 0 }}
                  animate={{ scale: 1 }}
                  transition={{ delay: 0.5 }}
                />
                <motion.circle
                  cx="65" cy="55" r={growthLevel * 3}
                  fill="#10b981" fillOpacity="0.15"
                  initial={{ scale: 0 }}
                  animate={{ scale: 1 }}
                  transition={{ delay: 0.6 }}
                />
              </>
            )}

            {/* Level 5 - Golden Fruits */}
            {growthLevel >= 5 && (
              <>
                {[...Array(5)].map((_, i) => (
                  <motion.circle
                    key={i}
                    cx={40 + Math.sin(i) * 20}
                    cy={50 + Math.cos(i) * 15}
                    r="3"
                    fill="#fbbf24"
                    initial={{ scale: 0 }}
                    animate={{ scale: [0, 1.2, 1] }}
                    transition={{ delay: 1 + i * 0.1 }}
                  />
                ))}
              </>
            )}
          </AnimatePresence>

          {/* Sparkles for high levels */}
          {growthLevel >= 4 && (
            <motion.g
              animate={{ opacity: [0.4, 1, 0.4] }}
              transition={{ duration: 2, repeat: Infinity }}
            >
              <circle cx="30" cy="40" r="1" fill="white" />
              <circle cx="70" cy="30" r="1" fill="white" />
              <circle cx="50" cy="20" r="1" fill="white" />
            </motion.g>
          )}
        </svg>

        {/* Floating Stats */}
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 pointer-events-none">
          <div className="bg-stone-50/80 backdrop-blur-sm border border-stone-200 px-4 py-2 rounded-2xl shadow-2xl">
            <p className="text-[10px] text-zinc-500 uppercase font-bold tracking-widest">Чистый капитал</p>
            <p className="text-lg font-black text-zinc-900">{netWorth.toLocaleString()} {baseCurrency}</p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 w-full">
        <div className="bg-stone-50 p-4 rounded-2xl border border-stone-200 flex flex-col items-center">
          <Coins className="w-4 h-4 text-amber-500 mb-1" />
          <span className="text-[10px] text-zinc-500 uppercase font-bold">Активы</span>
          <span className="text-sm font-bold text-zinc-900">{totalSavings.toLocaleString()} {baseCurrency}</span>
        </div>
        <div className="bg-stone-50 p-4 rounded-2xl border border-stone-200 flex flex-col items-center">
          <TrendingUp className="w-4 h-4 text-emerald-500 mb-1" />
          <span className="text-[10px] text-zinc-500 uppercase font-bold">До цели</span>
          <span className="text-sm font-bold text-zinc-900">
            {growthLevel < 5 ? (targetAmount - netWorth).toLocaleString() : 'MAX'} {growthLevel < 5 ? baseCurrency : ''}
          </span>
        </div>
      </div>

      <p className="text-[10px] text-zinc-500 mt-6 leading-relaxed max-w-xs">
        Ваше дерево растет вместе с вашим капиталом. Каждая сэкономленная копейка — это вода для его корней.
      </p>
    </div>
  );
}
