import React, { useMemo, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useStore } from '../store/useStore';
import { useCurrencyConverter } from '../hooks/useCurrencyConverter';
import { 
  TrendingUp, TrendingDown, Target, Zap, Info, 
  ChevronRight, ArrowUpRight, ArrowDownRight, 
  Activity, PieChart as PieIcon, Calendar,
  Wallet, Landmark, PiggyBank, BarChart3,
  HelpCircle, RefreshCw, ChevronDown, ChevronUp
} from 'lucide-react';
import { 
  LineChart, Line, AreaChart, Area, BarChart, Bar, 
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, 
  Cell, PieChart, Pie, RadarChart, PolarGrid, 
  PolarAngleAxis, PolarRadiusAxis, Radar, Legend
} from 'recharts';
import { format, subMonths, startOfMonth, endOfMonth, isWithinInterval, parseISO, eachMonthOfInterval, isSameMonth } from 'date-fns';
import { ru } from 'date-fns/locale';
import { cn } from '../lib/utils';

export function ProAnalyticsTab() {
  const { 
    transactions = [], 
    accounts = [], 
    loans = [], 
    savingsGoals = [],
    budgetLimits = [],
    rates = {},
    baseCurrency = 'BYN'
  } = useStore();

  const convertCurrency = useCurrencyConverter();

  const [hoveredMonth, setHoveredMonth] = useState<string | null>(null);
  const [showDetails, setShowDetails] = useState<string | null>(null);

  // --- 1. Net Worth Calculation ---
  const netWorthData = useMemo(() => {
    const months = eachMonthOfInterval({
      start: subMonths(new Date(), 5),
      end: new Date()
    });

    return months.map(month => {
      const monthStr = format(month, 'MMM', { locale: ru });
      const monthEnd = endOfMonth(month);

      // Assets: Accounts + Savings
      const accountAssets = accounts.reduce((sum, acc) => {
        const txsBefore = transactions.filter(t => parseISO(t.date) <= monthEnd && (t.accountId === acc.id || t.toAccountId === acc.id));
        const balance = txsBefore.reduce((s, t) => {
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
        }, acc.initialBalance || 0);
        return sum + convertCurrency(balance, acc.currency || baseCurrency, baseCurrency);
      }, 0);

      const savingsAssets = savingsGoals.reduce((sum, g) => sum + convertCurrency(g.currentAmount, g.currency || baseCurrency, baseCurrency), 0);
      
      // Liabilities: Loans
      const loanLiabilities = loans.reduce((sum, l) => {
        const paid = (l.payments || [])
          .filter(p => parseISO(p.date) <= monthEnd && p.type === 'payment')
          .reduce((s, p) => s + p.amount, 0);
        const withdrawn = (l.payments || [])
          .filter(p => parseISO(p.date) <= monthEnd && p.type === 'withdrawal')
          .reduce((s, p) => s + p.amount, 0);
        const netPaid = paid - withdrawn;
        const remaining = l.totalPayment - netPaid;
        return sum + convertCurrency(remaining, l.currency || baseCurrency, baseCurrency);
      }, 0);

      const totalAssets = accountAssets + savingsAssets;
      const netWorth = totalAssets - loanLiabilities;

      return {
        month: monthStr,
        assets: totalAssets,
        liabilities: loanLiabilities,
        netWorth: netWorth
      };
    });
  }, [accounts, transactions, loans, savingsGoals]);

  // --- 2. Financial Health Radar ---
  const healthMetrics = useMemo(() => {
    const last30Days = transactions.filter(t => 
      parseISO(t.date) >= subMonths(new Date(), 1)
    );
    
    const income = last30Days.filter(t => t.type === 'income').reduce((sum, t) => {
      const account = accounts.find(a => a.id === t.accountId);
      return sum + convertCurrency(t.amount, account?.currency || baseCurrency, baseCurrency);
    }, 0);
    const expense = last30Days.filter(t => t.type === 'expense').reduce((sum, t) => {
      const account = accounts.find(a => a.id === t.accountId);
      return sum + convertCurrency(t.amount, account?.currency || baseCurrency, baseCurrency);
    }, 0);
    
    // 1. Savings Rate (Target: 20%+)
    const savingsRate = income > 0 ? Math.min(((income - expense) / income) * 100, 100) : 0;
    const savingsScore = Math.max(0, (savingsRate / 20) * 100);

    // 2. Debt Load (Target: < 30% of income)
    const monthlyLoanPayments = loans.reduce((sum, l) => sum + convertCurrency(l.monthlyPayment, l.currency || baseCurrency, baseCurrency), 0);
    const debtRatio = income > 0 ? (monthlyLoanPayments / income) * 100 : 0;
    const debtScore = Math.max(0, 100 - (debtRatio / 30) * 100);

    // 3. Budget Control (Target: 100% adherence)
    const budgetAdherence = budgetLimits.length > 0 ? budgetLimits.reduce((sum, limit) => {
      const spent = last30Days.filter(t => t.category === limit.category).reduce((s, t) => {
        const account = accounts.find(a => a.id === t.accountId);
        return s + convertCurrency(t.amount, account?.currency || baseCurrency, limit.currency || baseCurrency);
      }, 0);
      return sum + (spent <= limit.amount ? 100 : Math.max(0, 100 - ((spent - limit.amount) / limit.amount) * 100));
    }, 0) / budgetLimits.length : 100;

    // 4. Diversification (Number of accounts/income sources)
    const incomeSources = new Set(last30Days.filter(t => t.type === 'income').map(t => t.category)).size;
    const divScore = Math.min((incomeSources / 3) * 100, 100);

    // 5. Activity (Days with transactions)
    const activeDays = new Set(last30Days.map(t => t.date)).size;
    const activityScore = (activeDays / 30) * 100;

    return [
      { subject: 'Сбережения', A: savingsScore, fullMark: 100 },
      { subject: 'Долги', A: debtScore, fullMark: 100 },
      { subject: 'Бюджет', A: budgetAdherence, fullMark: 100 },
      { subject: 'Доходы', A: divScore, fullMark: 100 },
      { subject: 'Активность', A: activityScore, fullMark: 100 },
    ];
  }, [transactions, loans, budgetLimits, accounts, rates, baseCurrency]);

  // --- 3. 50/30/20 Rule Analysis ---
  const budgetRuleData = useMemo(() => {
    const lastMonth = transactions.filter(t => 
      isSameMonth(parseISO(t.date), new Date())
    );
    
    const income = lastMonth.filter(t => t.type === 'income').reduce((sum, t) => {
      const account = accounts.find(a => a.id === t.accountId);
      return sum + convertCurrency(t.amount, account?.currency || baseCurrency, baseCurrency);
    }, 0);
    
    const categories = {
      needs: ['Жилье', 'Продукты', 'Транспорт', 'Связь', 'Здоровье'],
      wants: ['Развлечения', 'Рестораны', 'Одежда', 'Подарки'],
    };

    const spentNeeds = lastMonth.filter(t => categories.needs.includes(t.category)).reduce((sum, t) => {
      const account = accounts.find(a => a.id === t.accountId);
      return sum + convertCurrency(t.amount, account?.currency || baseCurrency, baseCurrency);
    }, 0);
    const spentWants = lastMonth.filter(t => categories.wants.includes(t.category)).reduce((sum, t) => {
      const account = accounts.find(a => a.id === t.accountId);
      return sum + convertCurrency(t.amount, account?.currency || baseCurrency, baseCurrency);
    }, 0);
    const savings = income - (spentNeeds + spentWants);

    const actual = [
      { name: 'Нужды (50%)', value: spentNeeds, percent: income > 0 ? (spentNeeds / income) * 100 : 0, target: 50 },
      { name: 'Хотелки (30%)', value: spentWants, percent: income > 0 ? (spentWants / income) * 100 : 0, target: 30 },
      { name: 'Сбережения (20%)', value: Math.max(0, savings), percent: income > 0 ? (Math.max(0, savings) / income) * 100 : 0, target: 20 },
    ];

    return actual;
  }, [transactions, accounts, rates, baseCurrency]);

  // --- 4. Lifestyle Creep Analysis ---
  const creepData = useMemo(() => {
    const months = eachMonthOfInterval({
      start: subMonths(new Date(), 5),
      end: new Date()
    });

    return months.map(month => {
      const monthTxs = transactions.filter(t => isSameMonth(parseISO(t.date), month));
      const income = monthTxs.filter(t => t.type === 'income').reduce((sum, t) => {
        const account = accounts.find(a => a.id === t.accountId);
        return sum + convertCurrency(t.amount, account?.currency || baseCurrency, baseCurrency);
      }, 0);
      const expense = monthTxs.filter(t => t.type === 'expense').reduce((sum, t) => {
        const account = accounts.find(a => a.id === t.accountId);
        return sum + convertCurrency(t.amount, account?.currency || baseCurrency, baseCurrency);
      }, 0);
      
      return {
        name: format(month, 'MMM', { locale: ru }),
        income,
        expense,
        ratio: income > 0 ? (expense / income) * 100 : 0
      };
    });
  }, [transactions, accounts, rates, baseCurrency]);

  // --- 5. Spending Heatmap (Last 90 days) ---
  const heatmapData = useMemo(() => {
    const days = [];
    const today = new Date();
    for (let i = 89; i >= 0; i--) {
      const date = format(subMonths(today, 0).setDate(today.getDate() - i), 'yyyy-MM-dd');
      const amount = transactions
        .filter(t => t.date === date && t.type === 'expense')
        .reduce((sum, t) => {
          const account = accounts.find(a => a.id === t.accountId);
          return sum + convertCurrency(t.amount, account?.currency || baseCurrency, baseCurrency);
        }, 0);
      days.push({ date, amount });
    }
    return days;
  }, [transactions, accounts, rates, baseCurrency]);

  // --- 6. "What If?" Scenario Modeling ---
  const [scenario, setScenario] = useState({
    monthly: 500,
    rate: 8,
    years: 10,
    inflation: 4
  });

  const scenarioData = useMemo(() => {
    const data = [];
    let capital = 0;
    let realCapital = 0;
    const monthlyRate = scenario.rate / 100 / 12;
    const monthlyInflation = scenario.inflation / 100 / 12;

    for (let i = 0; i <= scenario.years * 12; i++) {
      if (i % 12 === 0) {
        data.push({
          year: i / 12,
          capital: Math.round(capital),
          realCapital: Math.round(realCapital)
        });
      }
      capital = (capital + scenario.monthly) * (1 + monthlyRate);
      realCapital = (realCapital + scenario.monthly) * (1 + monthlyRate - monthlyInflation);
    }
    return data;
  }, [scenario]);

  return (
    <div className="space-y-8 pb-20">
      
      {/* 1. Net Worth Overview */}
      <section className="space-y-4">
        <div className="flex items-center justify-between px-1">
          <div>
            <h2 className="text-xl font-bold text-white flex items-center gap-2">
              <Landmark className="w-5 h-5 text-blue-400" />
              Чистый капитал
            </h2>
            <p className="text-sm text-zinc-400">Динамика ваших активов и обязательств</p>
          </div>
          <div className="text-right">
            <p className="text-xs text-zinc-500 uppercase tracking-wider">Текущий Net Worth</p>
            <p className="text-2xl font-black text-white">
              {netWorthData[netWorthData.length - 1].netWorth.toLocaleString()} <span className="text-sm font-normal text-zinc-500">{baseCurrency}</span>
            </p>
          </div>
        </div>

        <div className="bg-zinc-900/50 border border-zinc-800 rounded-3xl p-6 backdrop-blur-sm">
          <div className="h-[300px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={netWorthData}>
                <defs>
                  <linearGradient id="colorNetWorth" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                <XAxis dataKey="month" stroke="#71717a" fontSize={12} tickLine={false} axisLine={false} />
                <YAxis stroke="#71717a" fontSize={12} tickLine={false} axisLine={false} tickFormatter={(value) => `${value/1000}k`} />
                <Tooltip 
                  contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', borderRadius: '16px', border: '1px solid #3f3f46' }}
                  itemStyle={{ color: '#fff' }}
                />
                <Area type="monotone" dataKey="netWorth" stroke="#3b82f6" strokeWidth={3} fillOpacity={1} fill="url(#colorNetWorth)" />
                <Line type="monotone" dataKey="assets" stroke="#10b981" strokeWidth={2} strokeDasharray="5 5" dot={false} />
                <Line type="monotone" dataKey="liabilities" stroke="#ef4444" strokeWidth={2} strokeDasharray="5 5" dot={false} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
          <div className="flex justify-center gap-6 mt-4">
            <div className="flex items-center gap-2 text-xs text-zinc-400">
              <div className="w-3 h-3 rounded-full bg-blue-500" /> Чистый капитал
            </div>
            <div className="flex items-center gap-2 text-xs text-zinc-400">
              <div className="w-3 h-3 rounded-full border border-dashed border-emerald-500" /> Активы
            </div>
            <div className="flex items-center gap-2 text-xs text-zinc-400">
              <div className="w-3 h-3 rounded-full border border-dashed border-red-500" /> Обязательства
            </div>
          </div>
        </div>
      </section>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        
        {/* 2. Financial Health Radar */}
        <section className="space-y-4">
          <div className="px-1">
            <h2 className="text-lg font-bold text-white flex items-center gap-2">
              <Activity className="w-5 h-5 text-emerald-400" />
              Финансовое здоровье
            </h2>
            <p className="text-sm text-zinc-400">Оценка по 5 ключевым метрикам</p>
          </div>
          <div className="bg-zinc-900/50 border border-zinc-800 rounded-3xl p-6 h-[400px]">
            <ResponsiveContainer width="100%" height="100%">
              <RadarChart cx="50%" cy="50%" outerRadius="80%" data={healthMetrics}>
                <PolarGrid stroke="#27272a" />
                <PolarAngleAxis dataKey="subject" tick={{ fill: '#71717a', fontSize: 12 }} />
                <PolarRadiusAxis angle={30} domain={[0, 100]} tick={false} axisLine={false} />
                <Radar
                  name="Показатель"
                  dataKey="A"
                  stroke="#10b981"
                  fill="#10b981"
                  fillOpacity={0.5}
                />
                <Tooltip contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', borderRadius: '12px' }} />
              </RadarChart>
            </ResponsiveContainer>
          </div>
        </section>

        {/* 3. 50/30/20 Rule Analysis */}
        <section className="space-y-4">
          <div className="px-1">
            <h2 className="text-lg font-bold text-white flex items-center gap-2">
              <BarChart3 className="w-5 h-5 text-amber-400" />
              Правило 50/30/20
            </h2>
            <p className="text-sm text-zinc-400">Распределение бюджета за текущий месяц</p>
          </div>
          <div className="bg-zinc-900/50 border border-zinc-800 rounded-3xl p-6 h-[400px] flex flex-col">
            <div className="flex-1">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={budgetRuleData} layout="vertical" margin={{ left: 40, right: 40 }}>
                  <XAxis type="number" hide domain={[0, 100]} />
                  <YAxis dataKey="name" type="category" stroke="#71717a" fontSize={12} width={100} axisLine={false} tickLine={false} />
                  <Tooltip 
                    cursor={{ fill: 'transparent' }}
                    content={({ active, payload }) => {
                      if (active && payload && payload.length) {
                        const data = payload[0].payload;
                        return (
                          <div className="bg-zinc-900 border border-zinc-800 p-3 rounded-xl shadow-xl">
                            <p className="text-sm font-bold text-white mb-1">{data.name}</p>
                            <p className="text-xs text-zinc-400">Факт: <span className="text-white">{data.percent.toFixed(1)}%</span></p>
                            <p className="text-xs text-zinc-400">Цель: <span className="text-white">{data.target}%</span></p>
                          </div>
                        );
                      }
                      return null;
                    }}
                  />
                  <Bar dataKey="percent" radius={[0, 4, 4, 0]} barSize={32}>
                    {budgetRuleData.map((entry, index) => (
                      <Cell 
                        key={`cell-${index}`} 
                        fill={entry.percent > entry.target && entry.name !== 'Сбережения (20%)' ? '#ef4444' : '#10b981'} 
                      />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
            <div className="mt-4 space-y-3">
              {budgetRuleData.map((item, i) => (
                <div key={i} className="flex items-center justify-between text-sm">
                  <span className="text-zinc-400">{item.name}</span>
                  <div className="flex items-center gap-3">
                    <span className="text-zinc-500">{item.value.toLocaleString()} {baseCurrency}</span>
                    <span className={cn(
                      "font-bold px-2 py-0.5 rounded-lg text-xs",
                      item.percent > item.target && item.name !== 'Сбережения (20%)' ? "bg-red-500/10 text-red-400" : "bg-emerald-500/10 text-emerald-400"
                    )}>
                      {item.percent.toFixed(1)}%
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>
      </div>

      {/* 4. Lifestyle Creep Analysis */}
      <section className="space-y-4">
        <div className="px-1">
          <h2 className="text-lg font-bold text-white flex items-center gap-2">
            <TrendingUp className="w-5 h-5 text-purple-400" />
            Анализ "Инфляции образа жизни"
          </h2>
          <p className="text-sm text-zinc-400">Соотношение роста доходов к росту расходов</p>
        </div>
        <div className="bg-zinc-900/50 border border-zinc-800 rounded-3xl p-6">
          <div className="h-[300px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={creepData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                <XAxis dataKey="name" stroke="#71717a" fontSize={12} tickLine={false} axisLine={false} />
                <YAxis stroke="#71717a" fontSize={12} tickLine={false} axisLine={false} />
                <Tooltip 
                  contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', borderRadius: '16px' }}
                  itemStyle={{ color: '#fff' }}
                />
                <Legend verticalAlign="top" height={36} iconType="circle" />
                <Line name="Доходы" type="monotone" dataKey="income" stroke="#10b981" strokeWidth={3} dot={{ r: 4, fill: '#10b981' }} activeDot={{ r: 6 }} />
                <Line name="Расходы" type="monotone" dataKey="expense" stroke="#ef4444" strokeWidth={3} dot={{ r: 4, fill: '#ef4444' }} activeDot={{ r: 6 }} />
              </LineChart>
            </ResponsiveContainer>
          </div>
          <div className="mt-6 p-4 bg-zinc-950/50 rounded-2xl border border-zinc-800/50 flex items-center gap-4">
            <div className="p-3 bg-purple-500/10 rounded-xl">
              <Zap className="w-6 h-6 text-purple-400" />
            </div>
            <div>
              <p className="text-sm text-white font-medium">Инсайт</p>
              <p className="text-xs text-zinc-400">
                {creepData[creepData.length-1].ratio > creepData[0].ratio 
                  ? "Ваши расходы растут быстрее доходов. Попробуйте зафиксировать уровень трат."
                  : "Отличная работа! Вы сохраняете контроль над расходами при росте доходов."}
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* 5. Spending Heatmap */}
      <section className="space-y-4">
        <div className="px-1 flex items-center justify-between">
          <div>
            <h2 className="text-lg font-bold text-white flex items-center gap-2">
              <Calendar className="w-5 h-5 text-zinc-400" />
              Интенсивность трат
            </h2>
            <p className="text-sm text-zinc-400">Активность за последние 90 дней</p>
          </div>
          <div className="flex items-center gap-1 text-[10px] text-zinc-500 uppercase tracking-tighter">
            <span>Меньше</span>
            <div className="flex gap-1 mx-1">
              <div className="w-3 h-3 rounded-sm bg-zinc-800" />
              <div className="w-3 h-3 rounded-sm bg-emerald-900/40" />
              <div className="w-3 h-3 rounded-sm bg-emerald-700/60" />
              <div className="w-3 h-3 rounded-sm bg-emerald-500/80" />
              <div className="w-3 h-3 rounded-sm bg-emerald-400" />
            </div>
            <span>Больше</span>
          </div>
        </div>
        <div className="bg-zinc-900/50 border border-zinc-800 rounded-3xl p-6 overflow-x-auto">
          <div className="flex flex-wrap gap-1.5 min-w-[600px]">
            {heatmapData.map((day, i) => {
              const intensity = day.amount === 0 ? 0 : 
                               day.amount < 50 ? 1 : 
                               day.amount < 200 ? 2 : 
                               day.amount < 500 ? 3 : 4;
              return (
                <motion.div
                  key={i}
                  initial={{ scale: 0 }}
                  animate={{ scale: 1 }}
                  transition={{ delay: i * 0.005 }}
                  className={cn(
                    "w-4 h-4 rounded-sm transition-all cursor-pointer hover:ring-2 hover:ring-white/20",
                    intensity === 0 ? "bg-zinc-800" :
                    intensity === 1 ? "bg-emerald-900/40" :
                    intensity === 2 ? "bg-emerald-700/60" :
                    intensity === 3 ? "bg-emerald-500/80" : "bg-emerald-400"
                  )}
                  title={`${day.date}: ${day.amount.toFixed(2)} ${baseCurrency}`}
                />
              );
            })}
          </div>
        </div>
      </section>

      {/* 6. "What If?" Scenario Modeling */}
      <section className="space-y-4">
        <div className="px-1">
          <h2 className="text-lg font-bold text-white flex items-center gap-2">
            <RefreshCw className="w-5 h-5 text-blue-400" />
            Моделирование "Что если?"
          </h2>
          <p className="text-sm text-zinc-400">Прогноз роста капитала при разных условиях</p>
        </div>
        <div className="bg-zinc-900/50 border border-zinc-800 rounded-3xl p-6 space-y-8">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <div className="space-y-2">
              <label className="text-xs text-zinc-500 uppercase">Ежемесячно ({baseCurrency})</label>
              <input 
                type="range" min="100" max="5000" step="100"
                value={scenario.monthly}
                onChange={(e) => setScenario({...scenario, monthly: Number(e.target.value)})}
                className="w-full accent-blue-500"
              />
              <p className="text-lg font-bold text-white">{scenario.monthly.toLocaleString()}</p>
            </div>
            <div className="space-y-2">
              <label className="text-xs text-zinc-500 uppercase">Доходность (% год)</label>
              <input 
                type="range" min="1" max="30" step="1"
                value={scenario.rate}
                onChange={(e) => setScenario({...scenario, rate: Number(e.target.value)})}
                className="w-full accent-blue-500"
              />
              <p className="text-lg font-bold text-white">{scenario.rate}%</p>
            </div>
            <div className="space-y-2">
              <label className="text-xs text-zinc-500 uppercase">Срок (лет)</label>
              <input 
                type="range" min="1" max="40" step="1"
                value={scenario.years}
                onChange={(e) => setScenario({...scenario, years: Number(e.target.value)})}
                className="w-full accent-blue-500"
              />
              <p className="text-lg font-bold text-white">{scenario.years}</p>
            </div>
            <div className="space-y-2">
              <label className="text-xs text-zinc-500 uppercase">Инфляция (% год)</label>
              <input 
                type="range" min="0" max="20" step="1"
                value={scenario.inflation}
                onChange={(e) => setScenario({...scenario, inflation: Number(e.target.value)})}
                className="w-full accent-blue-500"
              />
              <p className="text-lg font-bold text-white">{scenario.inflation}%</p>
            </div>
          </div>

          <div className="h-[300px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={scenarioData}>
                <defs>
                  <linearGradient id="colorCap" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                <XAxis dataKey="year" stroke="#71717a" fontSize={12} tickLine={false} axisLine={false} />
                <YAxis stroke="#71717a" fontSize={12} tickLine={false} axisLine={false} tickFormatter={(value) => `${value/1000}k`} />
                <Tooltip 
                  contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', borderRadius: '16px' }}
                  itemStyle={{ color: '#fff' }}
                />
                <Area name="Номинальный капитал" type="monotone" dataKey="capital" stroke="#3b82f6" strokeWidth={3} fillOpacity={1} fill="url(#colorCap)" />
                <Area name="Реальный капитал" type="monotone" dataKey="realCapital" stroke="#10b981" strokeWidth={2} fillOpacity={0.1} fill="#10b981" />
              </AreaChart>
            </ResponsiveContainer>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="p-4 bg-blue-500/5 border border-blue-500/10 rounded-2xl">
              <p className="text-xs text-blue-400 uppercase mb-1">Итого через {scenario.years} лет</p>
              <p className="text-2xl font-black text-white">{scenarioData[scenarioData.length-1].capital.toLocaleString()} {baseCurrency}</p>
            </div>
            <div className="p-4 bg-emerald-500/5 border border-emerald-500/10 rounded-2xl">
              <p className="text-xs text-emerald-400 uppercase mb-1">С учетом инфляции</p>
              <p className="text-2xl font-black text-white">{scenarioData[scenarioData.length-1].realCapital.toLocaleString()} {baseCurrency}</p>
            </div>
          </div>
        </div>
      </section>

      {/* 7. Savings Progress Summary */}
      <section className="space-y-4">
        <div className="px-1 flex items-center justify-between">
          <div>
            <h2 className="text-lg font-bold text-white flex items-center gap-2">
              <PiggyBank className="w-5 h-5 text-pink-400" />
              Прогресс накоплений
            </h2>
            <p className="text-sm text-zinc-400">Все ваши финансовые цели в одном месте</p>
          </div>
          <button 
            onClick={() => setShowDetails(showDetails === 'savings' ? null : 'savings')}
            className="text-xs text-zinc-500 hover:text-white flex items-center gap-1 transition-colors"
          >
            {showDetails === 'savings' ? 'Скрыть' : 'Подробнее'}
            {showDetails === 'savings' ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {savingsGoals.map(goal => (
            <div key={goal.id} className="bg-zinc-900/50 border border-zinc-800 rounded-3xl p-5 relative overflow-hidden group">
              <div className="absolute top-0 left-0 w-1 h-full" style={{ backgroundColor: goal.color }} />
              <div className="flex justify-between items-start mb-4">
                <h3 className="font-bold text-white">{goal.title}</h3>
                <span className="text-xs font-bold px-2 py-0.5 rounded-full bg-zinc-800 text-zinc-400">
                  {Math.round((goal.currentAmount / goal.targetAmount) * 100)}%
                </span>
              </div>
              <div className="space-y-2">
                <div className="flex justify-between text-xs">
                  <span className="text-zinc-500">Накоплено</span>
                  <span className="text-white font-medium">{goal.currentAmount.toLocaleString()} / {goal.targetAmount.toLocaleString()} {goal.currency || baseCurrency}</span>
                </div>
                <div className="h-2 bg-zinc-800 rounded-full overflow-hidden">
                  <motion.div 
                    initial={{ width: 0 }}
                    animate={{ width: `${Math.min((goal.currentAmount / goal.targetAmount) * 100, 100)}%` }}
                    className="h-full rounded-full"
                    style={{ backgroundColor: goal.color }}
                  />
                </div>
              </div>
            </div>
          ))}
          {savingsGoals.length === 0 && (
            <div className="col-span-full py-12 text-center bg-zinc-900/30 border border-dashed border-zinc-800 rounded-3xl">
              <PiggyBank className="w-12 h-12 text-zinc-700 mx-auto mb-3" />
              <p className="text-zinc-500">У вас пока нет активных целей накопления</p>
            </div>
          )}
        </div>
      </section>

      {/* 8. Budget Adherence Detail */}
      <section className="space-y-4">
        <div className="px-1 flex items-center justify-between">
          <div>
            <h2 className="text-lg font-bold text-white flex items-center gap-2">
              <Target className="w-5 h-5 text-emerald-400" />
              Соблюдение лимитов
            </h2>
            <p className="text-sm text-zinc-400">Анализ дисциплины по категориям</p>
          </div>
        </div>

        <div className="bg-zinc-900/50 border border-zinc-800 rounded-3xl p-6">
          <div className="space-y-6">
            {budgetLimits.map(limit => {
              const spent = transactions
                .filter(t => t.category === limit.category && t.type === 'expense' && isSameMonth(parseISO(t.date), new Date()))
                .reduce((sum, t) => {
                  const account = accounts.find(a => a.id === t.accountId);
                  return sum + convertCurrency(t.amount, account?.currency || baseCurrency, limit.currency || baseCurrency);
                }, 0);
              const percent = (spent / limit.amount) * 100;
              const isOver = spent > limit.amount;

              return (
                <div key={limit.id} className="space-y-2">
                  <div className="flex justify-between items-end">
                    <div>
                      <span className="text-sm font-medium text-white">{limit.category}</span>
                      <p className="text-xs text-zinc-500">Лимит: {limit.amount} {limit.currency || baseCurrency}</p>
                    </div>
                    <div className="text-right">
                      <span className={cn("text-sm font-bold", isOver ? "text-red-400" : "text-emerald-400")}>
                        {spent.toLocaleString()} {limit.currency || baseCurrency}
                      </span>
                      <p className="text-[10px] text-zinc-500 uppercase tracking-wider">{percent.toFixed(0)}% использовано</p>
                    </div>
                  </div>
                  <div className="h-3 bg-zinc-800 rounded-full overflow-hidden relative">
                    <motion.div 
                      initial={{ width: 0 }}
                      animate={{ width: `${Math.min(percent, 100)}%` }}
                      className={cn(
                        "h-full rounded-full transition-all duration-1000",
                        percent > 90 ? "bg-red-500" : percent > 70 ? "bg-amber-500" : "bg-emerald-500"
                      )}
                    />
                    {percent > 100 && (
                      <div className="absolute top-0 right-0 h-full w-[2px] bg-white/20" />
                    )}
                  </div>
                </div>
              );
            })}
            {budgetLimits.length === 0 && (
              <div className="py-8 text-center text-zinc-500">
                Установите лимиты в разделе "Бюджет", чтобы видеть аналитику здесь
              </div>
            )}
          </div>
        </div>
      </section>

    </div>
  );
}
