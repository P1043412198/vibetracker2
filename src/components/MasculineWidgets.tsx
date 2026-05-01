import React, { useMemo } from 'react';
import { useStore } from '../store/useStore';
import { useCurrencyConverter } from '../hooks/useCurrencyConverter';
import { Shield, Wallet, Quote, TrendingUp, TrendingDown, Target, Zap, Activity } from 'lucide-react';
import { cn } from '../lib/utils';
import { motion } from 'motion/react';
import { format, isSameDay, parseISO } from 'date-fns';

export function DisciplineScoreWidget() {
  const { habits = [], habitLogs = [], tasks = [], pomodoro, waterLogs = [], waterGoal = 2000 } = useStore();
  const today = format(new Date(), 'yyyy-MM-dd');

  const score = useMemo(() => {
    let totalPoints = 0;
    let maxPoints = 0;

    // Habits (40% of score)
    const activeHabits = habits; // All habits are considered active for now
    if (activeHabits.length > 0) {
      maxPoints += 40;
      const completedToday = activeHabits.filter(h => 
        (habitLogs || []).some(l => l.habitId === h.id && l.date === today && l.status === 'done')
      ).length;
      totalPoints += (completedToday / activeHabits.length) * 40;
    }

    // Tasks (30% of score)
    const todayTasks = (tasks || []).filter(t => t.date === today);
    if (todayTasks.length > 0) {
      maxPoints += 30;
      const completedToday = todayTasks.filter(t => t.completed).length;
      totalPoints += (completedToday / todayTasks.length) * 30;
    }

    // Pomodoro (20% of score)
    maxPoints += 20;
    const pomodoroPoints = Math.min(pomodoro.sessionsCompleted * 5, 20); // 5 points per session, max 20
    totalPoints += pomodoroPoints;

    // Water (10% of score)
    maxPoints += 10;
    const waterToday = waterLogs
      .filter(l => l.date === today)
      .reduce((sum, l) => sum + l.amount, 0);
    if (waterToday >= (waterGoal || 2000)) {
      totalPoints += 10;
    } else {
      totalPoints += (waterToday / (waterGoal || 2000)) * 10;
    }

    if (maxPoints === 0) return 0;
    return Math.round((totalPoints / maxPoints) * 100);
  }, [habits, habitLogs, tasks, pomodoro, waterLogs, waterGoal, today]);

  const getStatus = (s: number) => {
    if (s >= 90) return { label: 'Элита', color: 'text-emerald-500', bg: 'bg-emerald-500/10' };
    if (s >= 70) return { label: 'Дисциплинирован', color: 'text-indigo-500', bg: 'bg-indigo-500/10' };
    if (s >= 40) return { label: 'В процессе', color: 'text-amber-500', bg: 'bg-amber-500/10' };
    return { label: 'Нужна работа', color: 'text-rose-500', bg: 'bg-rose-500/10' };
  };

  const status = getStatus(score);

  return (
    <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-sm font-semibold text-white flex items-center gap-2">
          <Shield className="w-4 h-4 text-indigo-500" />
          Уровень Дисциплины
        </h2>
        <div className={cn("px-2 py-1 rounded-lg text-[10px] font-bold uppercase tracking-wider", status.bg, status.color)}>
          {status.label}
        </div>
      </div>

      <div className="flex flex-col items-center justify-center py-4">
        <div className="relative w-24 h-24 mb-4">
          <svg className="w-full h-full transform -rotate-90">
            <circle
              cx="48"
              cy="48"
              r="44"
              stroke="currentColor"
              strokeWidth="4"
              fill="transparent"
              className="text-zinc-800"
            />
            <motion.circle
              cx="48"
              cy="48"
              r="44"
              stroke="currentColor"
              strokeWidth="4"
              fill="transparent"
              strokeDasharray={276.46}
              initial={{ strokeDashoffset: 276.46 }}
              animate={{ strokeDashoffset: 276.46 * (1 - score / 100) }}
              className={cn("transition-all duration-1000", status.color)}
              strokeLinecap="round"
            />
          </svg>
          <div className="absolute inset-0 flex items-center justify-center">
            <span className="text-3xl font-bold text-white tabular-nums">{score}</span>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-2 w-full">
          <div className="bg-zinc-950 p-2 rounded-xl border border-zinc-800 flex items-center gap-2">
            <Zap className="w-3 h-3 text-amber-500" />
            <div className="flex flex-col">
              <span className="text-[10px] text-zinc-500">Фокус</span>
              <span className="text-xs font-bold text-white">{pomodoro.sessionsCompleted} сес.</span>
            </div>
          </div>
          <div className="bg-zinc-950 p-2 rounded-xl border border-zinc-800 flex items-center gap-2">
            <Activity className="w-3 h-3 text-emerald-500" />
            <div className="flex flex-col">
              <span className="text-[10px] text-zinc-500">Привычки</span>
              <span className="text-xs font-bold text-white">
                {(habits || []).filter(h => (habitLogs || []).some(l => l.habitId === h.id && l.date === today && l.status === 'done')).length}/{(habits || []).length}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export function NetWorthWidget() {
  const { accounts = [], loans = [], transactions = [], savingsGoals = [], rates = {}, baseCurrency = 'BYN' } = useStore();

  const convertCurrency = useCurrencyConverter();

  const { totalAssets, totalLiabilities, netWorth } = useMemo(() => {
    const accountAssets = (accounts || []).reduce((sum, acc) => {
      const accountTransactions = (transactions || []).filter(t => t.accountId === acc.id || t.toAccountId === acc.id);
      const balance = accountTransactions.reduce((accSum, t) => {
        if (t.type === 'income') return accSum + t.amount;
        if (t.type === 'expense') return accSum - t.amount;
        if (t.type === 'transfer') {
          if (t.accountId === acc.id) return accSum - t.amount;
          if (t.toAccountId === acc.id) return accSum + t.amount;
        }
        return accSum;
      }, acc.initialBalance);
      return sum + convertCurrency(balance, acc.currency || baseCurrency, baseCurrency);
    }, 0);

    const savingsAssets = (savingsGoals || []).reduce((sum, goal) => sum + convertCurrency(goal.currentAmount, goal.currency || baseCurrency, baseCurrency), 0);
    const assets = accountAssets + savingsAssets;

    const liabilities = (loans || []).reduce((sum, loan) => {
      const totalPaid = (loan.payments || [])
        .filter(p => p.type === 'payment')
        .reduce((s, p) => s + p.amount, 0);
      const totalWithdrawn = (loan.payments || [])
        .filter(p => p.type === 'withdrawal')
        .reduce((s, p) => s + p.amount, 0);
      const remaining = loan.totalPayment - (totalPaid - totalWithdrawn);
      return sum + convertCurrency(remaining, loan.currency || baseCurrency, baseCurrency);
    }, 0);

    return {
      totalAssets: assets,
      totalLiabilities: liabilities,
      netWorth: assets - liabilities
    };
  }, [accounts, loans, transactions, savingsGoals, rates, baseCurrency]);

  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('ru-RU', {
      style: 'currency',
      currency: baseCurrency,
      maximumFractionDigits: 0
    }).format(value);
  };

  return (
    <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-sm font-semibold text-white flex items-center gap-2">
          <Wallet className="w-4 h-4 text-emerald-500" />
          Чистый капитал
        </h2>
        <div className={cn(
          "px-2 py-1 rounded-lg text-[10px] font-bold uppercase",
          netWorth >= 0 ? "bg-emerald-500/10 text-emerald-500" : "bg-rose-500/10 text-rose-500"
        )}>
          {netWorth >= 0 ? 'В плюсе' : 'В долгах'}
        </div>
      </div>

      <div className="space-y-4">
        <div className="text-center">
          <div className="text-3xl font-bold text-white tracking-tight">
            {formatCurrency(netWorth)}
          </div>
          <div className="text-[10px] text-zinc-500 uppercase font-bold tracking-widest mt-1">
            Общий баланс
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div className="bg-zinc-950 p-3 rounded-2xl border border-zinc-800">
            <div className="flex items-center gap-2 mb-1">
              <TrendingUp className="w-3 h-3 text-emerald-500" />
              <span className="text-[10px] text-zinc-500 uppercase font-bold">Активы</span>
            </div>
            <div className="text-sm font-bold text-white">{formatCurrency(totalAssets)}</div>
          </div>
          <div className="bg-zinc-950 p-3 rounded-2xl border border-zinc-800">
            <div className="flex items-center gap-2 mb-1">
              <TrendingDown className="w-3 h-3 text-rose-500" />
              <span className="text-[10px] text-zinc-500 uppercase font-bold">Долги</span>
            </div>
            <div className="text-sm font-bold text-white">{formatCurrency(totalLiabilities)}</div>
          </div>
        </div>
      </div>
    </div>
  );
}

export function StoicQuoteWidget() {
  const quotes = [
    { text: "У тебя есть власть над своим разумом, а не над внешними событиями. Осознай это, и ты обретешь силу.", author: "Марк Аврелий" },
    { text: "Трудности укрепляют разум, как труд укрепляет тело.", author: "Сенека" },
    { text: "Счастье твоей жизни зависит от качества твоих мыслей.", author: "Марк Аврелий" },
    { text: "Не то, что с тобой происходит, а то, как ты на это реагируешь, имеет значение.", author: "Эпиктет" },
    { text: "Лучшая месть — не быть похожим на своего врага.", author: "Марк Аврелий" },
    { text: "Мы страдаем чаще в воображении, чем в реальности.", author: "Сенека" },
    { text: "Кто боится смерти, тот никогда не сделает ничего достойного живого человека.", author: "Сенека" },
    { text: "Если хочешь быть хозяином своей жизни, стань хозяином своих мыслей.", author: "Эпиктет" }
  ];

  const dailyQuote = useMemo(() => {
    const dayOfYear = Math.floor((new Date().getTime() - new Date(new Date().getFullYear(), 0, 0).getTime()) / 86400000);
    return quotes[dayOfYear % quotes.length];
  }, []);

  return (
    <div className="bg-zinc-900 p-5 rounded-3xl shadow-sm border border-zinc-800 flex flex-col justify-between min-h-[160px]">
      <div>
        <Quote className="w-6 h-6 text-zinc-700 mb-3" />
        <p className="text-sm text-zinc-300 leading-relaxed italic">
          "{dailyQuote.text}"
        </p>
      </div>
      <div className="mt-4 flex items-center justify-between border-t border-zinc-800 pt-3">
        <span className="text-[10px] text-zinc-500 uppercase font-bold tracking-widest">Стоицизм</span>
        <span className="text-xs font-semibold text-zinc-400">— {dailyQuote.author}</span>
      </div>
    </div>
  );
}
