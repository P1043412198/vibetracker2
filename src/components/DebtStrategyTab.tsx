import React, { useMemo, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useStore } from '../store/useStore';
import { 
  ShieldAlert, TrendingDown, Zap, Target, 
  ChevronRight, Info, Calculator, Calendar,
  ArrowDownRight, HelpCircle, Sparkles,
  Flame, Snowflake, AlertCircle, CheckCircle2
} from 'lucide-react';
import { 
  AreaChart, Area, XAxis, YAxis, CartesianGrid, 
  Tooltip, ResponsiveContainer, Legend, BarChart, Bar, Cell
} from 'recharts';
import { format, addMonths, parseISO } from 'date-fns';
import { ru } from 'date-fns/locale';
import { cn } from '../lib/utils';

export function DebtStrategyTab() {
  const { loans = [] } = useStore();
  const [extraPayment, setExtraPayment] = useState<number>(0);
  const [strategy, setStrategy] = useState<'avalanche' | 'snowball'>('avalanche');

  const totalDebt = useMemo(() => {
    return loans.reduce((sum, loan) => {
      const totalPaid = (loan.payments || [])
        .filter(p => p.type === 'payment')
        .reduce((s, p) => s + p.amount, 0);
      const totalWithdrawn = (loan.payments || [])
        .filter(p => p.type === 'withdrawal')
        .reduce((s, p) => s + p.amount, 0);
      return sum + (loan.totalPayment - (totalPaid - totalWithdrawn));
    }, 0);
  }, [loans]);

  const monthlyMinimums = useMemo(() => {
    return loans.reduce((sum, l) => sum + l.monthlyPayment, 0);
  }, [loans]);

  // Strategy Simulation
  const simulation = useMemo(() => {
    if (loans.length === 0) return null;

    // Sort loans based on strategy
    const sortedLoans = [...loans].map(l => {
      const totalPaid = (l.payments || [])
        .filter(p => p.type === 'payment')
        .reduce((s, p) => s + p.amount, 0);
      const totalWithdrawn = (l.payments || [])
        .filter(p => p.type === 'withdrawal')
        .reduce((s, p) => s + p.amount, 0);
      const currentBalance = l.totalPayment - (totalPaid - totalWithdrawn);
      return { ...l, currentBalance };
    }).filter(l => l.currentBalance > 0);

    if (strategy === 'avalanche') {
      sortedLoans.sort((a, b) => b.rate - a.rate);
    } else {
      sortedLoans.sort((a, b) => a.currentBalance - b.currentBalance);
    }

    const data = [];
    let currentTotalDebt = totalDebt;
    let month = 0;
    let totalInterestSaved = 0;
    const today = new Date();

    // Baseline (no extra payment)
    let baselineMonths = 0;
    if (loans.length > 0) {
        baselineMonths = Math.max(...loans.map(l => {
            const paid = (l.payments || []).filter(p => p.type === 'payment').reduce((s, p) => s + p.amount, 0);
            const remaining = l.totalPayment - paid;
            return Math.ceil(remaining / l.monthlyPayment);
        }));
    }

    // Simulation with extra payment
    const activeLoans = sortedLoans.map(l => ({ ...l }));
    
    while (currentTotalDebt > 0 && month < 360) { // Max 30 years
      let monthlyExtra = extraPayment;
      let monthlyTotalPaid = 0;
      
      // 1. Pay minimums first
      activeLoans.forEach(l => {
        if (l.currentBalance > 0) {
          const payment = Math.min(l.currentBalance, l.monthlyPayment);
          l.currentBalance -= payment;
          monthlyTotalPaid += payment;
        }
      });

      // 2. Apply extra payment to the target loan
      for (const l of activeLoans) {
        if (l.currentBalance > 0 && monthlyExtra > 0) {
          const extra = Math.min(l.currentBalance, monthlyExtra);
          l.currentBalance -= extra;
          monthlyExtra -= extra;
          monthlyTotalPaid += extra;
          // Simplified interest saving calculation
          // In a real app, we'd recalculate the whole schedule
          totalInterestSaved += (extra * (l.rate / 100 / 12)); 
        }
      }

      currentTotalDebt = activeLoans.reduce((sum, l) => sum + l.currentBalance, 0);
      
      if (month % 3 === 0 || currentTotalDebt === 0) {
        data.push({
          month: format(addMonths(today, month), 'MMM yy', { locale: ru }),
          debt: Math.round(currentTotalDebt),
          monthIndex: month
        });
      }
      month++;
    }

    return {
      data,
      monthsToFreedom: month,
      totalInterestSaved,
      timeSaved: baselineMonths - month,
      baselineMonths
    };
  }, [loans, extraPayment, strategy, totalDebt]);

  if (loans.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-20 text-center space-y-4">
        <div className="w-20 h-20 bg-zinc-900 rounded-full flex items-center justify-center border border-zinc-800">
          <ShieldAlert className="w-10 h-10 text-zinc-700" />
        </div>
        <div>
          <h3 className="text-xl font-bold text-white">Долгов не обнаружено</h3>
          <p className="text-zinc-500 max-w-xs mx-auto mt-2">
            Добавьте ваши кредиты или займы во вкладке "Кредиты", чтобы составить стратегию их погашения.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8 pb-20">
      
      {/* Header Summary */}
      <section className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-zinc-900/50 border border-zinc-800 p-6 rounded-3xl relative overflow-hidden">
          <div className="absolute top-0 right-0 p-4 opacity-10">
            <TrendingDown className="w-12 h-12 text-red-500" />
          </div>
          <p className="text-xs text-zinc-500 uppercase font-bold tracking-wider mb-1">Общий долг</p>
          <p className="text-2xl font-black text-white">{totalDebt.toLocaleString()} <span className="text-sm font-normal text-zinc-500">BYN</span></p>
        </div>
        <div className="bg-zinc-900/50 border border-zinc-800 p-6 rounded-3xl">
          <p className="text-xs text-zinc-500 uppercase font-bold tracking-wider mb-1">Обязательный платеж</p>
          <p className="text-2xl font-black text-white">{monthlyMinimums.toLocaleString()} <span className="text-sm font-normal text-zinc-500">BYN/мес</span></p>
        </div>
        <div className="bg-zinc-900/50 border border-zinc-800 p-6 rounded-3xl relative overflow-hidden">
          <div className="absolute top-0 right-0 p-4 opacity-10">
            <Target className="w-12 h-12 text-emerald-500" />
          </div>
          <p className="text-xs text-zinc-500 uppercase font-bold tracking-wider mb-1">Свобода через</p>
          <p className="text-2xl font-black text-emerald-400">
            {simulation?.monthsToFreedom} <span className="text-sm font-normal text-zinc-500">мес.</span>
          </p>
        </div>
      </section>

      {/* Strategy Controls */}
      <section className="bg-zinc-900/50 border border-zinc-800 rounded-3xl p-6 space-y-8">
        <div className="flex flex-col md:flex-row gap-8">
          <div className="flex-1 space-y-6">
            <div>
              <h3 className="text-lg font-bold text-white mb-2 flex items-center gap-2">
                <Zap className="w-5 h-5 text-amber-400" />
                Ускоритель погашения
              </h3>
              <p className="text-sm text-zinc-400">Сколько вы готовы платить сверх минимума?</p>
            </div>
            
            <div className="space-y-4">
              <div className="flex justify-between items-end">
                <span className="text-sm text-zinc-500">Доп. платеж</span>
                <span className="text-2xl font-black text-white">{extraPayment.toLocaleString()} BYN</span>
              </div>
              <input 
                type="range" min="0" max="5000" step="50"
                value={extraPayment}
                onChange={(e) => setExtraPayment(Number(e.target.value))}
                className="w-full accent-emerald-500"
              />
              <div className="flex justify-between text-[10px] text-zinc-600 font-bold uppercase">
                <span>0</span>
                <span>5000+</span>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <button 
                onClick={() => setStrategy('avalanche')}
                className={cn(
                  "p-4 rounded-2xl border transition-all text-left relative overflow-hidden group",
                  strategy === 'avalanche' ? "bg-emerald-500/10 border-emerald-500/50" : "bg-zinc-950 border-zinc-800 hover:border-zinc-700"
                )}
              >
                <Flame className={cn("w-5 h-5 mb-2", strategy === 'avalanche' ? "text-emerald-400" : "text-zinc-500")} />
                <p className="text-sm font-bold text-white">Лавина</p>
                <p className="text-[10px] text-zinc-500 mt-1">Сначала самые дорогие (высокий %)</p>
                {strategy === 'avalanche' && <div className="absolute top-2 right-2"><CheckCircle2 className="w-4 h-4 text-emerald-500" /></div>}
              </button>
              <button 
                onClick={() => setStrategy('snowball')}
                className={cn(
                  "p-4 rounded-2xl border transition-all text-left relative overflow-hidden group",
                  strategy === 'snowball' ? "bg-blue-500/10 border-blue-500/50" : "bg-zinc-950 border-zinc-800 hover:border-zinc-700"
                )}
              >
                <Snowflake className={cn("w-5 h-5 mb-2", strategy === 'snowball' ? "text-blue-400" : "text-zinc-500")} />
                <p className="text-sm font-bold text-white">Снежный ком</p>
                <p className="text-[10px] text-zinc-500 mt-1">Сначала самые мелкие (психология)</p>
                {strategy === 'snowball' && <div className="absolute top-2 right-2"><CheckCircle2 className="w-4 h-4 text-blue-500" /></div>}
              </button>
            </div>
          </div>

          <div className="flex-1 bg-zinc-950/50 border border-zinc-800/50 rounded-2xl p-6 flex flex-col justify-center space-y-6">
            <div className="flex items-center gap-4">
              <div className="p-3 bg-emerald-500/10 rounded-xl">
                <Sparkles className="w-6 h-6 text-emerald-400" />
              </div>
              <div>
                <p className="text-sm text-white font-bold">Ваша выгода</p>
                <p className="text-xs text-zinc-400">При текущем плане ускорения</p>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1">
                <p className="text-[10px] text-zinc-500 uppercase font-bold">Сэкономите на %</p>
                <p className="text-xl font-black text-emerald-400">~{Math.round(simulation?.totalInterestSaved || 0).toLocaleString()} BYN</p>
              </div>
              <div className="space-y-1">
                <p className="text-[10px] text-zinc-500 uppercase font-bold">Выйдете раньше на</p>
                <p className="text-xl font-black text-blue-400">
                  {simulation?.timeSaved && simulation.timeSaved > 0 ? `${simulation.timeSaved} мес.` : '0 мес.'}
                </p>
              </div>
            </div>

            <div className="p-3 bg-amber-500/5 border border-amber-500/10 rounded-xl flex items-start gap-3">
              <AlertCircle className="w-4 h-4 text-amber-500 mt-0.5" />
              <p className="text-[10px] text-zinc-400 leading-relaxed">
                {strategy === 'avalanche' 
                  ? "Метод Лавины математически выгоден — вы платите меньше процентов банку." 
                  : "Метод Снежного кома помогает не бросить начатое, так как вы быстрее видите закрытые счета."}
              </p>
            </div>
          </div>
        </div>

        {/* Debt Chart */}
        <div className="h-[300px] w-full pt-4">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={simulation?.data}>
              <defs>
                <linearGradient id="colorDebt" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#ef4444" stopOpacity={0.3}/>
                  <stop offset="95%" stopColor="#ef4444" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
              <XAxis dataKey="month" stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
              <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} tickFormatter={(v) => `${v/1000}k`} />
              <Tooltip 
                contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', borderRadius: '16px' }}
                itemStyle={{ color: '#fff' }}
              />
              <Area 
                name="Остаток долга" 
                type="monotone" 
                dataKey="debt" 
                stroke="#ef4444" 
                strokeWidth={3} 
                fillOpacity={1} 
                fill="url(#colorDebt)" 
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </section>

      {/* Step-by-Step Plan */}
      <section className="space-y-4">
        <h3 className="text-lg font-bold text-white px-1 flex items-center gap-2">
          <Calculator className="w-5 h-5 text-zinc-400" />
          Пошаговый план выхода
        </h3>
        <div className="space-y-3">
          <div className="bg-zinc-900/50 border border-zinc-800 p-5 rounded-3xl flex items-start gap-4">
            <div className="w-8 h-8 rounded-full bg-emerald-500/20 text-emerald-400 flex items-center justify-center font-black text-sm shrink-0">1</div>
            <div>
              <p className="text-sm font-bold text-white">Зафиксируйте обязательные платежи</p>
              <p className="text-xs text-zinc-400 mt-1">Ваш минимум: {monthlyMinimums.toLocaleString()} BYN. Никогда не платите меньше этой суммы, чтобы избежать штрафов.</p>
            </div>
          </div>
          <div className="bg-zinc-900/50 border border-zinc-800 p-5 rounded-3xl flex items-start gap-4">
            <div className="w-8 h-8 rounded-full bg-blue-500/20 text-blue-400 flex items-center justify-center font-black text-sm shrink-0">2</div>
            <div>
              <p className="text-sm font-bold text-white">Направьте доп. платеж на цель</p>
              <p className="text-xs text-zinc-400 mt-1">
                {strategy === 'avalanche' 
                  ? "Все свободные средства ({extraPayment} BYN) направляйте на кредит с самой высокой ставкой."
                  : "Все свободные средства ({extraPayment} BYN) направляйте на самый маленький по сумме кредит."}
              </p>
            </div>
          </div>
          <div className="bg-zinc-900/50 border border-zinc-800 p-5 rounded-3xl flex items-start gap-4">
            <div className="w-8 h-8 rounded-full bg-purple-500/20 text-purple-400 flex items-center justify-center font-black text-sm shrink-0">3</div>
            <div>
              <p className="text-sm font-bold text-white">Эффект снежного кома</p>
              <p className="text-xs text-zinc-400 mt-1">Когда закроете первый кредит, не тратьте освободившиеся деньги. Добавьте их к платежу по следующему кредиту.</p>
            </div>
          </div>
        </div>
      </section>

      {/* Educational Tips */}
      <section className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="bg-zinc-900/30 border border-zinc-800 p-6 rounded-3xl space-y-3">
          <div className="flex items-center gap-2 text-amber-400">
            <Info className="w-4 h-4" />
            <span className="text-xs font-bold uppercase tracking-wider">Важно знать</span>
          </div>
          <h4 className="text-sm font-bold text-white">Досрочное погашение: Срок или Платеж?</h4>
          <p className="text-xs text-zinc-500 leading-relaxed">
            Математически выгоднее сокращать <strong>срок</strong> кредита. Это уменьшает общую переплату по процентам. Сокращение платежа полезно только если вам нужно снизить ежемесячную нагрузку для психологического комфорта.
          </p>
        </div>
        <div className="bg-zinc-900/30 border border-zinc-800 p-6 rounded-3xl space-y-3">
          <div className="flex items-center gap-2 text-blue-400">
            <HelpCircle className="w-4 h-4" />
            <span className="text-xs font-bold uppercase tracking-wider">Совет</span>
          </div>
          <h4 className="text-sm font-bold text-white">Кредитные карты</h4>
          <p className="text-xs text-zinc-500 leading-relaxed">
            У кредиток самые высокие ставки. Всегда закрывайте их в первую очередь по методу Лавины. Если возможно, переведите долг по кредитке на обычный потребительский кредит под меньший процент.
          </p>
        </div>
      </section>

    </div>
  );
}
