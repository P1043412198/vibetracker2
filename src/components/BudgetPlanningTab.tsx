import React, { useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import { useStore } from '../store/useStore';
import { useCurrencyConverter } from '../hooks/useCurrencyConverter';
import { 
  format, subMonths, startOfMonth, endOfMonth, 
  isWithinInterval, parseISO, addMonths, isSameMonth 
} from 'date-fns';
import { ru } from 'date-fns/locale';
import { cn } from '../lib/utils';
import { 
  CalendarRange, TrendingUp, TrendingDown, 
  ArrowRightLeft, Info, AlertCircle, 
  CheckCircle2, Calculator, ArrowRight,
  ChevronRight, ChevronLeft, BarChart3
} from 'lucide-react';
import { 
  BarChart, Bar, XAxis, YAxis, CartesianGrid, 
  Tooltip, ResponsiveContainer, Legend, Cell 
} from 'recharts';

export function BudgetPlanningTab() {
  const { 
    transactions = [], 
    regularPayments = [], 
    budgetLimits = [], 
    accounts = [],
    rates = {},
    baseCurrency = 'BYN'
  } = useStore();

  const convertCurrency = useCurrencyConverter();
  
  const now = new Date();
  const currentMonthStart = startOfMonth(now);
  const prevMonthStart = subMonths(currentMonthStart, 1);
  const nextMonthStart = addMonths(currentMonthStart, 1);

  // --- 1. Calculate Actuals for Current and Previous Months ---
  const getMonthStats = (date: Date) => {
    const start = startOfMonth(date);
    const end = endOfMonth(date);
    
    const monthTx = transactions.filter(t => 
      isWithinInterval(parseISO(t.date), { start, end })
    );

    const income = monthTx.filter(t => t.type === 'income').reduce((sum, t) => {
      const account = accounts.find(a => a.id === t.accountId);
      const currency = account?.currency || baseCurrency;
      return sum + convertCurrency(t.amount, currency, baseCurrency);
    }, 0);

    const expense = monthTx.filter(t => t.type === 'expense').reduce((sum, t) => {
      const account = accounts.find(a => a.id === t.accountId);
      const currency = account?.currency || baseCurrency;
      return sum + convertCurrency(t.amount, currency, baseCurrency);
    }, 0);
    
    return { income, expense, balance: income - expense };
  };

  const currentActuals = useMemo(() => getMonthStats(now), [transactions, now]);
  const prevActuals = useMemo(() => getMonthStats(prevMonthStart), [transactions, prevMonthStart]);

  // --- 2. Calculate Next Month Plan ---
  // We estimate income as the average of the last 2 months if available, otherwise current
  const estimatedIncome = useMemo(() => {
    if (prevActuals.income > 0 && currentActuals.income > 0) {
      return (prevActuals.income + currentActuals.income) / 2;
    }
    return currentActuals.income || prevActuals.income || 0;
  }, [currentActuals.income, prevActuals.income]);

  const nextMonthPlan = useMemo(() => {
    const fixedExpenses = regularPayments
      .filter(p => p.isActive)
      .reduce((sum, p) => sum + convertCurrency(p.amount, p.currency || baseCurrency, baseCurrency), 0);
    
    const variableExpenses = budgetLimits.reduce((sum, l) => sum + convertCurrency(l.amount, l.currency || baseCurrency, baseCurrency), 0);
    
    const totalExpense = fixedExpenses + variableExpenses;
    
    return {
      income: estimatedIncome,
      fixedExpense: fixedExpenses,
      variableExpense: variableExpenses,
      totalExpense,
      balance: estimatedIncome - totalExpense
    };
  }, [regularPayments, budgetLimits, estimatedIncome]);

  // --- 3. Comparison Data for Chart ---
  const chartData = [
    {
      name: 'Прошлый мес.',
      Доход: prevActuals.income,
      Расход: prevActuals.expense,
    },
    {
      name: 'Текущий мес.',
      Доход: currentActuals.income,
      Расход: currentActuals.expense,
    },
    {
      name: 'План (След.)',
      Доход: nextMonthPlan.income,
      Расход: nextMonthPlan.totalExpense,
    }
  ];

  return (
    <div className="space-y-8 pb-20 animate-in fade-in duration-700">
      
      {/* Header Section */}
      <section className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <h2 className="text-xl font-bold text-zinc-900 flex items-center gap-2">
            <CalendarRange className="w-6 h-6 text-emerald-400" />
            Планирование: {format(nextMonthStart, 'LLLL yyyy', { locale: ru })}
          </h2>
          <p className="text-sm text-zinc-500">Прогноз на основе ваших регулярных платежей и лимитов</p>
        </div>
        <div className="flex items-center gap-2 bg-white/60 p-1 rounded-xl border border-stone-200">
          <div className="px-3 py-1.5 text-xs font-bold text-zinc-500 uppercase">Сравнение</div>
          <div className="flex gap-1">
            <div className="w-3 h-3 bg-emerald-500 rounded-full" title="Доход" />
            <div className="w-3 h-3 bg-red-500 rounded-full" title="Расход" />
          </div>
        </div>
      </section>

      {/* Main Comparison Chart */}
      <section className="bg-white/60 border border-stone-200 rounded-3xl p-6">
        <div className="h-[300px] w-full">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={chartData} margin={{ top: 20, right: 30, left: 0, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
              <XAxis dataKey="name" stroke="#71717a" fontSize={12} tickLine={false} axisLine={false} />
              <YAxis stroke="#71717a" fontSize={12} tickLine={false} axisLine={false} />
              <Tooltip 
                contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', borderRadius: '16px', color: '#fff' }}
                cursor={{ fill: '#27272a', opacity: 0.4 }}
              />
              <Legend verticalAlign="top" align="right" iconType="circle" wrapperStyle={{ paddingBottom: '20px', fontSize: '12px' }} />
              <Bar name="Доход" dataKey="Доход" fill="#10b981" radius={[6, 6, 0, 0]} />
              <Bar name="Расход" dataKey="Расход" fill="#ef4444" radius={[6, 6, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </section>

      {/* Detailed Plan Breakdown */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        
        {/* Next Month Forecast */}
        <section className="bg-white/60 border border-stone-200 rounded-3xl p-6 space-y-6">
          <h3 className="text-lg font-bold text-zinc-900 flex items-center gap-2">
            <TrendingUp className="w-5 h-5 text-emerald-400" />
            Прогноз на следующий месяц
          </h3>
          
          <div className="space-y-4">
            <div className="flex justify-between items-center p-4 bg-stone-50 rounded-2xl border border-stone-200/70">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-emerald-500/10 rounded-lg">
                  <TrendingUp className="w-4 h-4 text-emerald-500" />
                </div>
                <span className="text-sm text-zinc-500">Ожидаемый доход</span>
              </div>
              <span className="text-lg font-bold text-zinc-900">{nextMonthPlan.income.toLocaleString()} {baseCurrency}</span>
            </div>

            <div className="flex justify-between items-center p-4 bg-stone-50 rounded-2xl border border-stone-200/70">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-red-500/10 rounded-lg">
                  <TrendingDown className="w-4 h-4 text-red-500" />
                </div>
                <span className="text-sm text-zinc-500">Ожидаемый расход</span>
              </div>
              <span className="text-lg font-bold text-zinc-900">{nextMonthPlan.totalExpense.toLocaleString()} {baseCurrency}</span>
            </div>

            <div className="p-4 bg-stone-50 rounded-2xl border border-stone-200/70 space-y-3">
              <div className="flex justify-between text-xs text-zinc-500 uppercase font-bold">
                <span>Детализация расходов</span>
              </div>
              <div className="space-y-2">
                <div className="flex justify-between items-center">
                  <span className="text-xs text-zinc-500">Фиксированные (Подписки/Кредиты)</span>
                  <span className="text-xs font-bold text-zinc-700">{nextMonthPlan.fixedExpense.toLocaleString()} {baseCurrency}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-xs text-zinc-500">Переменные (Лимиты категорий)</span>
                  <span className="text-xs font-bold text-zinc-700">{nextMonthPlan.variableExpense.toLocaleString()} {baseCurrency}</span>
                </div>
              </div>
            </div>

            <div className={cn(
              "p-6 rounded-2xl border flex flex-col items-center text-center space-y-2",
              nextMonthPlan.balance >= 0 ? "bg-emerald-500/5 border-emerald-500/20" : "bg-red-500/5 border-red-500/20"
            )}>
              <p className="text-xs text-zinc-500 uppercase font-bold">Прогноз остатка</p>
              <p className={cn(
                "text-3xl font-black",
                nextMonthPlan.balance >= 0 ? "text-emerald-400" : "text-red-400"
              )}>
                {nextMonthPlan.balance.toLocaleString()} {baseCurrency}
              </p>
              <p className="text-[10px] text-zinc-500 max-w-[200px]">
                {nextMonthPlan.balance >= 0 
                  ? "Отлично! У вас останутся свободные средства для накоплений." 
                  : "Внимание! Расходы превышают доходы. Нужно пересмотреть лимиты."}
              </p>
            </div>
          </div>
        </section>

        {/* Comparison with Current/Past */}
        <section className="space-y-6">
          <div className="bg-white/60 border border-stone-200 rounded-3xl p-6 space-y-6">
            <h3 className="text-lg font-bold text-zinc-900 flex items-center gap-2">
              <ArrowRightLeft className="w-5 h-5 text-emerald-400" />
              Сравнение с фактом
            </h3>

            <div className="space-y-6">
              {/* vs Current Month */}
              <div className="space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-sm font-bold text-zinc-900">План vs Текущий месяц</span>
                  <span className={cn(
                    "text-xs px-2 py-1 rounded-lg font-bold",
                    nextMonthPlan.totalExpense <= currentActuals.expense ? "bg-emerald-500/10 text-emerald-400" : "bg-red-500/10 text-red-400"
                  )}>
                    {nextMonthPlan.totalExpense <= currentActuals.expense ? 'Экономия' : 'Рост трат'}
                  </span>
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div className="bg-stone-50 p-3 rounded-xl border border-stone-200/70">
                    <p className="text-[10px] text-zinc-500 uppercase font-bold mb-1">Разница в расходах</p>
                    <p className="text-sm font-bold text-zinc-900">
                      {Math.abs(nextMonthPlan.totalExpense - currentActuals.expense).toLocaleString()} {baseCurrency}
                    </p>
                  </div>
                  <div className="bg-stone-50 p-3 rounded-xl border border-stone-200/70">
                    <p className="text-[10px] text-zinc-500 uppercase font-bold mb-1">% изменения</p>
                    <p className="text-sm font-bold text-zinc-900">
                      {currentActuals.expense > 0 ? Math.round((Math.abs(nextMonthPlan.totalExpense - currentActuals.expense) / currentActuals.expense) * 100) : 0}%
                    </p>
                  </div>
                </div>
              </div>

              {/* vs Previous Month */}
              <div className="space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-sm font-bold text-zinc-900">План vs Прошлый месяц</span>
                  <span className={cn(
                    "text-xs px-2 py-1 rounded-lg font-bold",
                    nextMonthPlan.totalExpense <= prevActuals.expense ? "bg-emerald-500/10 text-emerald-400" : "bg-red-500/10 text-red-400"
                  )}>
                    {nextMonthPlan.totalExpense <= prevActuals.expense ? 'Экономия' : 'Рост трат'}
                  </span>
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div className="bg-stone-50 p-3 rounded-xl border border-stone-200/70">
                    <p className="text-[10px] text-zinc-500 uppercase font-bold mb-1">Разница в расходах</p>
                    <p className="text-sm font-bold text-zinc-900">
                      {Math.abs(nextMonthPlan.totalExpense - prevActuals.expense).toLocaleString()} {baseCurrency}
                    </p>
                  </div>
                  <div className="bg-stone-50 p-3 rounded-xl border border-stone-200/70">
                    <p className="text-[10px] text-zinc-500 uppercase font-bold mb-1">% изменения</p>
                    <p className="text-sm font-bold text-zinc-900">
                      {prevActuals.expense > 0 ? Math.round((Math.abs(nextMonthPlan.totalExpense - prevActuals.expense) / prevActuals.expense) * 100) : 0}%
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Actionable Insights */}
          <div className="bg-emerald-500/5 border border-emerald-500/20 rounded-3xl p-6 space-y-4">
            <div className="flex items-center gap-3 text-emerald-400">
              <Info className="w-5 h-5" />
              <h4 className="text-sm font-bold uppercase tracking-wider">Анализ плана</h4>
            </div>
            <ul className="space-y-3">
              <li className="flex items-start gap-3">
                <div className="w-1.5 h-1.5 rounded-full bg-emerald-400 mt-1.5 shrink-0" />
                <p className="text-xs text-zinc-500 leading-relaxed">
                  Ваши фиксированные расходы составляют <strong>{Math.round((nextMonthPlan.fixedExpense / nextMonthPlan.totalExpense) * 100)}%</strong> от общего бюджета. Чем ниже этот процент, тем более гибкий ваш бюджет.
                </p>
              </li>
              <li className="flex items-start gap-3">
                <div className="w-1.5 h-1.5 rounded-full bg-emerald-400 mt-1.5 shrink-0" />
                <p className="text-xs text-zinc-500 leading-relaxed">
                  {nextMonthPlan.totalExpense > currentActuals.expense 
                    ? "Запланированные расходы выше текущих. Проверьте, не слишком ли оптимистичны ваши лимиты в категориях."
                    : "Вы планируете потратить меньше, чем в этом месяце. Это отличная стратегия для накопления капитала."}
                </p>
              </li>
            </ul>
          </div>
        </section>
      </div>

      {/* Planning Tips */}
      <section className="bg-white/30 border border-stone-200 p-6 rounded-3xl">
        <div className="flex items-center gap-3 mb-4">
          <Calculator className="w-5 h-5 text-zinc-500" />
          <h3 className="text-sm font-bold text-zinc-900">Как улучшить точность планирования?</h3>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="space-y-2">
            <p className="text-xs font-bold text-zinc-700">1. Регулярные платежи</p>
            <p className="text-[10px] text-zinc-500 leading-relaxed">Убедитесь, что все подписки, кредиты и коммунальные услуги добавлены во вкладку "Контроль".</p>
          </div>
          <div className="space-y-2">
            <p className="text-xs font-bold text-zinc-700">2. Реалистичные лимиты</p>
            <p className="text-[10px] text-zinc-500 leading-relaxed">Устанавливайте лимиты на категории (еда, транспорт) исходя из средних трат за прошлые месяцы.</p>
          </div>
          <div className="space-y-2">
            <p className="text-xs font-bold text-zinc-700">3. Резервный фонд</p>
            <p className="text-[10px] text-zinc-500 leading-relaxed">Всегда закладывайте 5-10% на непредвиденные расходы, которые не входят в основные категории.</p>
          </div>
        </div>
      </section>

    </div>
  );
}
