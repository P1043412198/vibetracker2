import React, { useState, useEffect, useMemo } from 'react';
import { motion } from 'framer-motion';
import { BrainCircuit, TrendingUp, AlertTriangle, CheckCircle2, Loader2, CalendarRange } from 'lucide-react';
import { useStore } from '../store/useStore';
import { useCurrencyConverter } from '../hooks/useCurrencyConverter';
import { cn } from '../lib/utils';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceLine } from 'recharts';
import { startOfMonth, endOfMonth, getDaysInMonth, getDate, format, parseISO, isSameMonth } from 'date-fns';
import { ru } from 'date-fns/locale';
import { GoogleGenAI } from '@google/genai';

export function PredictiveBudgetTab() {
  const { transactions = [], budgetLimits = [], accounts = [], rates = {}, baseCurrency = 'USD' } = useStore();
  const [aiInsight, setAiInsight] = useState<string | null>(null);
  const [isAnalyzing, setIsAnalyzing] = useState(false);

  const convertCurrency = useCurrencyConverter();

  const today = new Date();
  const currentMonth = startOfMonth(today);
  const daysInMonth = getDaysInMonth(today);
  const currentDay = getDate(today);

  // Calculate total budget for the month
  const totalBudgetInBase = budgetLimits.reduce((sum, limit) => {
    return sum + convertCurrency(limit.amount, limit.currency || baseCurrency, baseCurrency);
  }, 0);

  // Calculate current month expenses
  const currentMonthExpenses = transactions.filter(t => 
    t.type === 'expense' && isSameMonth(parseISO(t.date), today)
  );

  const totalSpentInBase = currentMonthExpenses.reduce((sum, t) => {
    const account = accounts.find(a => a.id === t.accountId);
    const currency = account?.currency || baseCurrency;
    return sum + convertCurrency(t.amount, currency, baseCurrency);
  }, 0);

  // Calculate average daily spend
  const averageDailySpend = currentDay > 0 ? totalSpentInBase / currentDay : 0;

  // Predict end of month spend
  const predictedTotalSpend = totalSpentInBase + (averageDailySpend * (daysInMonth - currentDay));

  // Generate chart data
  const chartData = useMemo(() => {
    const data = [];
    let cumulativeSpend = 0;

    for (let i = 1; i <= daysInMonth; i++) {
      const dateStr = format(new Date(today.getFullYear(), today.getMonth(), i), 'yyyy-MM-dd');
      
      if (i <= currentDay) {
        const daySpend = currentMonthExpenses
          .filter(t => t.date === dateStr)
          .reduce((sum, t) => {
            const account = accounts.find(a => a.id === t.accountId);
            const currency = account?.currency || baseCurrency;
            return sum + convertCurrency(t.amount, currency, baseCurrency);
          }, 0);
        cumulativeSpend += daySpend;
        
        data.push({
          day: i,
          actual: cumulativeSpend,
          predicted: cumulativeSpend,
          budget: totalBudgetInBase > 0 ? (totalBudgetInBase / daysInMonth) * i : null
        });
      } else {
        const predictedDaySpend = cumulativeSpend + (averageDailySpend * (i - currentDay));
        data.push({
          day: i,
          actual: null,
          predicted: predictedDaySpend,
          budget: totalBudgetInBase > 0 ? (totalBudgetInBase / daysInMonth) * i : null
        });
      }
    }
    return data;
  }, [currentMonthExpenses, currentDay, daysInMonth, averageDailySpend, totalBudgetInBase]);

  const analyzeWithAI = async () => {
    if (!process.env.GEMINI_API_KEY) return;
    setIsAnalyzing(true);
    try {
      const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });
      
      const prompt = `
        Проанализируй текущие расходы пользователя за этот месяц.
        Сегодня ${currentDay} день из ${daysInMonth}.
        Бюджет на месяц: ${totalBudgetInBase.toFixed(0)} ${baseCurrency}.
        Уже потрачено: ${totalSpentInBase.toFixed(0)} ${baseCurrency}.
        Средний расход в день: ${averageDailySpend.toFixed(0)} ${baseCurrency}.
        Прогноз трат к концу месяца: ${predictedTotalSpend.toFixed(0)} ${baseCurrency}.
        
        Напиши короткий, мотивирующий и полезный инсайт (максимум 3-4 предложения). 
        Предупреди о кассовом разрыве, если прогноз превышает бюджет. 
        Посоветуй, на сколько нужно сократить дневные траты, чтобы уложиться в бюджет.
      `;

      const response = await ai.models.generateContent({
        model: 'gemini-3-flash-preview',
        contents: prompt,
      });

      setAiInsight(response.text || 'Не удалось сгенерировать прогноз.');
    } catch (error) {
      console.error('AI Analysis error:', error);
      setAiInsight('Ошибка при обращении к ИИ.');
    } finally {
      setIsAnalyzing(false);
    }
  };

  useEffect(() => {
    if (totalSpentInBase > 0 && !aiInsight && !isAnalyzing) {
      analyzeWithAI();
    }
  }, [totalSpentInBase]);

  const isOverBudget = predictedTotalSpend > totalBudgetInBase && totalBudgetInBase > 0;

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3 mb-6">
        <div className="p-3 bg-purple-500/10 rounded-2xl">
          <BrainCircuit className="w-6 h-6 text-purple-500" />
        </div>
        <div>
          <h2 className="text-lg font-bold text-white">Предиктивный бюджет</h2>
          <p className="text-xs text-zinc-400">ИИ-прогноз ваших расходов до конца месяца</p>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="bg-zinc-900 border border-zinc-800 p-4 rounded-2xl">
          <p className="text-[10px] text-zinc-500 uppercase font-bold tracking-wider mb-1">Потрачено сейчас</p>
          <p className="text-2xl font-bold text-white">
            {totalSpentInBase.toLocaleString('ru-RU', { maximumFractionDigits: 0 })} {baseCurrency}
          </p>
          <p className="text-xs text-zinc-500 mt-1">За {currentDay} дней</p>
        </div>
        <div className="bg-zinc-900 border border-zinc-800 p-4 rounded-2xl">
          <p className="text-[10px] text-zinc-500 uppercase font-bold tracking-wider mb-1">Прогноз на конец месяца</p>
          <p className={cn("text-2xl font-bold", isOverBudget ? "text-red-400" : "text-emerald-400")}>
            {predictedTotalSpend.toLocaleString('ru-RU', { maximumFractionDigits: 0 })} {baseCurrency}
          </p>
          <p className="text-xs text-zinc-500 mt-1">При текущем темпе</p>
        </div>
        <div className="bg-zinc-900 border border-zinc-800 p-4 rounded-2xl">
          <p className="text-[10px] text-zinc-500 uppercase font-bold tracking-wider mb-1">Бюджет</p>
          <p className="text-2xl font-bold text-emerald-400">
            {totalBudgetInBase > 0 ? totalBudgetInBase.toLocaleString('ru-RU', { maximumFractionDigits: 0 }) : 'Не задан'} {baseCurrency}
          </p>
          <p className="text-xs text-zinc-500 mt-1">
            {totalBudgetInBase > 0 ? `Остаток: ${(totalBudgetInBase - totalSpentInBase).toLocaleString('ru-RU', { maximumFractionDigits: 0 })}` : 'Настройте лимиты'}
          </p>
        </div>
      </div>

      {aiInsight && (
        <motion.div 
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          className={cn(
            "p-4 rounded-2xl border flex gap-4 items-start",
            isOverBudget ? "bg-red-500/10 border-red-500/20" : "bg-emerald-500/10 border-emerald-500/20"
          )}
        >
          {isOverBudget ? (
            <AlertTriangle className="w-6 h-6 text-red-400 shrink-0 mt-1" />
          ) : (
            <CheckCircle2 className="w-6 h-6 text-emerald-400 shrink-0 mt-1" />
          )}
          <div>
            <h3 className={cn("text-sm font-bold mb-1", isOverBudget ? "text-red-400" : "text-emerald-400")}>
              ИИ-Анализ
            </h3>
            <p className="text-sm text-zinc-300 leading-relaxed">{aiInsight}</p>
          </div>
        </motion.div>
      )}

      <div className="bg-zinc-900 border border-zinc-800 rounded-3xl p-6">
        <h3 className="text-sm font-bold text-white mb-6">Траектория расходов</h3>
        <div className="h-[300px] w-full">
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={chartData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
              <XAxis 
                dataKey="day" 
                stroke="#52525b" 
                fontSize={12}
                tickFormatter={(value) => `${value}`}
              />
              <YAxis 
                stroke="#52525b" 
                fontSize={12}
                tickFormatter={(value) => `${(value / 1000).toFixed(0)}k`}
              />
              <Tooltip 
                contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '12px' }}
                itemStyle={{ color: '#a1a1aa' }}
                labelStyle={{ color: '#a1a1aa', marginBottom: '4px' }}
                formatter={(value: number, name: string) => [
                  `${value.toLocaleString('ru-RU', { maximumFractionDigits: 0 })} ${baseCurrency}`, 
                  name === 'actual' ? 'Факт' : name === 'predicted' ? 'Прогноз' : 'Бюджет'
                ]}
                labelFormatter={(label) => `${label} число`}
              />
              {totalBudgetInBase > 0 && (
                <Line 
                  type="monotone" 
                  dataKey="budget" 
                  stroke="#3b82f6" 
                  strokeWidth={2} 
                  strokeDasharray="5 5"
                  dot={false}
                  name="budget"
                />
              )}
              <Line 
                type="monotone" 
                dataKey="predicted" 
                stroke="#a1a1aa" 
                strokeWidth={2} 
                strokeDasharray="5 5"
                dot={false}
                name="predicted"
              />
              <Line 
                type="monotone" 
                dataKey="actual" 
                stroke="#10b981" 
                strokeWidth={3} 
                dot={false}
                name="actual"
              />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  );
}
