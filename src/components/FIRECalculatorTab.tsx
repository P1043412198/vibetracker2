import React, { useState, useMemo } from 'react';
import { motion } from 'framer-motion';
import { TrendingUp, Target, Calculator, Info, Flame } from 'lucide-react';
import { useStore } from '../store/useStore';
import { cn } from '../lib/utils';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

export function FIRECalculatorTab() {
  const { accounts = [], transactions = [], savingsGoals = [], loans = [], rates = {}, baseCurrency = 'USD' } = useStore();

  const convertToAnchor = (amount: number, currency: string) => {
    const rate = rates[currency] || 1;
    return amount * rate;
  };

  const convertFromAnchor = (amountInAnchor: number, targetCurrency: string) => {
    const rate = rates[targetCurrency] || 1;
    return amountInAnchor / rate;
  };

  const totalAccountBalanceInAnchor = accounts.reduce((sum, acc) => {
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
    return sum + convertToAnchor(balance, acc.currency);
  }, 0);
  const totalSavingsInAnchor = savingsGoals.reduce((sum, goal) => sum + convertToAnchor(goal.currentAmount, goal.currency || baseCurrency), 0);
  const totalDebtInAnchor = loans.reduce((sum, loan) => {
    const totalPaid = (loan.payments || [])
      .filter(p => p.type === 'payment')
      .reduce((s, p) => s + p.amount, 0);
    const totalWithdrawn = (loan.payments || [])
      .filter(p => p.type === 'withdrawal')
      .reduce((s, p) => s + p.amount, 0);
    const remaining = loan.totalPayment - (totalPaid - totalWithdrawn);
    return sum + convertToAnchor(remaining, loan.currency || baseCurrency);
  }, 0);

  const initialNetWorthInAnchor = totalAccountBalanceInAnchor + totalSavingsInAnchor - totalDebtInAnchor;
  const initialNetWorthInBase = convertFromAnchor(initialNetWorthInAnchor, baseCurrency);

  const [currentCapital, setCurrentCapital] = useState(Math.max(0, initialNetWorthInBase).toString());
  const [monthlyContribution, setMonthlyContribution] = useState('500');
  const [annualReturn, setAnnualReturn] = useState('8');
  const [safeWithdrawalRate, setSafeWithdrawalRate] = useState('4');
  const [targetMonthlyIncome, setTargetMonthlyIncome] = useState('2000');

  const calculateFIRE = () => {
    const capital = parseFloat(currentCapital) || 0;
    const contribution = parseFloat(monthlyContribution) || 0;
    const returnRate = (parseFloat(annualReturn) || 0) / 100;
    const swr = (parseFloat(safeWithdrawalRate) || 0) / 100;
    const targetIncome = parseFloat(targetMonthlyIncome) || 0;

    const targetCapital = (targetIncome * 12) / swr;
    
    let current = capital;
    let months = 0;
    const data = [];
    const maxYears = 50;
    const monthlyReturnRate = returnRate / 12;

    data.push({
      year: 0,
      capital: Math.round(current)
    });

    while (current < targetCapital && months < maxYears * 12) {
      current = current * (1 + monthlyReturnRate) + contribution;
      months++;

      if (months % 12 === 0) {
        data.push({
          year: months / 12,
          capital: Math.round(current)
        });
      }
    }

    return {
      targetCapital,
      yearsToFIRE: months / 12,
      data,
      isAchievable: months < maxYears * 12
    };
  };

  const { targetCapital, yearsToFIRE, data, isAchievable } = useMemo(calculateFIRE, [currentCapital, monthlyContribution, annualReturn, safeWithdrawalRate, targetMonthlyIncome]);

  return (
    <div className="space-y-6">
      <div className="bg-zinc-900 border border-zinc-800 rounded-3xl p-6">
        <div className="flex items-center gap-3 mb-6">
          <div className="p-3 bg-orange-500/10 rounded-2xl">
            <Flame className="w-6 h-6 text-orange-500" />
          </div>
          <div>
            <h2 className="text-lg font-bold text-white">Калькулятор FIRE</h2>
            <p className="text-xs text-zinc-400">Financial Independence, Retire Early</p>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-1 space-y-4">
            <div className="space-y-2">
              <label className="text-xs text-zinc-500 uppercase font-bold">Текущий капитал ({baseCurrency})</label>
              <input
                type="number"
                value={currentCapital}
                onChange={(e) => setCurrentCapital(e.target.value)}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-xl py-2 px-4 text-sm text-white focus:outline-none focus:border-orange-500/50"
              />
            </div>
            <div className="space-y-2">
              <label className="text-xs text-zinc-500 uppercase font-bold">Ежемесячное пополнение ({baseCurrency})</label>
              <input
                type="number"
                value={monthlyContribution}
                onChange={(e) => setMonthlyContribution(e.target.value)}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-xl py-2 px-4 text-sm text-white focus:outline-none focus:border-orange-500/50"
              />
            </div>
            <div className="space-y-2">
              <label className="text-xs text-zinc-500 uppercase font-bold">Желаемый доход в месяц ({baseCurrency})</label>
              <input
                type="number"
                value={targetMonthlyIncome}
                onChange={(e) => setTargetMonthlyIncome(e.target.value)}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-xl py-2 px-4 text-sm text-white focus:outline-none focus:border-orange-500/50"
              />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <label className="text-xs text-zinc-500 uppercase font-bold">Доходность (%)</label>
                <input
                  type="number"
                  value={annualReturn}
                  onChange={(e) => setAnnualReturn(e.target.value)}
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-xl py-2 px-4 text-sm text-white focus:outline-none focus:border-orange-500/50"
                />
              </div>
              <div className="space-y-2">
                <label className="text-xs text-zinc-500 uppercase font-bold" title="Safe Withdrawal Rate">SWR (%) <Info className="inline w-3 h-3" /></label>
                <input
                  type="number"
                  value={safeWithdrawalRate}
                  onChange={(e) => setSafeWithdrawalRate(e.target.value)}
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-xl py-2 px-4 text-sm text-white focus:outline-none focus:border-orange-500/50"
                />
              </div>
            </div>
          </div>

          <div className="lg:col-span-2 space-y-6">
            <div className="grid grid-cols-2 gap-4">
              <div className="bg-zinc-950 border border-zinc-800 p-4 rounded-2xl">
                <p className="text-[10px] text-zinc-500 uppercase font-bold tracking-wider mb-1">Целевой капитал</p>
                <p className="text-2xl font-bold text-white">
                  {targetCapital.toLocaleString('ru-RU', { maximumFractionDigits: 0 })} {baseCurrency}
                </p>
              </div>
              <div className="bg-zinc-950 border border-zinc-800 p-4 rounded-2xl">
                <p className="text-[10px] text-zinc-500 uppercase font-bold tracking-wider mb-1">Время до цели</p>
                <p className={cn("text-2xl font-bold", isAchievable ? "text-orange-400" : "text-red-400")}>
                  {isAchievable ? `${yearsToFIRE.toFixed(1)} лет` : '> 50 лет'}
                </p>
              </div>
            </div>

            <div className="h-[300px] w-full">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={data} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                  <defs>
                    <linearGradient id="colorCapital" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#f97316" stopOpacity={0.3}/>
                      <stop offset="95%" stopColor="#f97316" stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                  <XAxis 
                    dataKey="year" 
                    stroke="#52525b" 
                    fontSize={12}
                    tickFormatter={(value) => `${value}г`}
                  />
                  <YAxis 
                    stroke="#52525b" 
                    fontSize={12}
                    tickFormatter={(value) => `${(value / 1000).toFixed(0)}k`}
                  />
                  <Tooltip 
                    contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '12px' }}
                    itemStyle={{ color: '#f97316' }}
                    labelStyle={{ color: '#a1a1aa', marginBottom: '4px' }}
                    formatter={(value: number) => [`${value.toLocaleString()} ${baseCurrency}`, 'Капитал']}
                    labelFormatter={(label) => `Год ${label}`}
                  />
                  <Area 
                    type="monotone" 
                    dataKey="capital" 
                    stroke="#f97316" 
                    strokeWidth={2}
                    fillOpacity={1} 
                    fill="url(#colorCapital)" 
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
