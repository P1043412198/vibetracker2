import React, { useState, useRef, useMemo, useEffect, lazy, Suspense } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Wallet, ShoppingCart, LineChart as LineChartIcon, Plus, Trash2, ImagePlus, Camera, X, ArrowUpRight, ArrowDownRight, CreditCard, Banknote, Calculator, Eye, EyeOff, Download, Bot, Loader2, Clock, ChevronDown, ChevronUp, PiggyBank, TrendingUp, Activity, Globe } from 'lucide-react';
import { BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, PieChart, Pie, Cell, AreaChart, Area } from 'recharts';
import { startOfWeek, startOfMonth, startOfYear, subWeeks, subMonths, subYears, isAfter, isBefore, format, parseISO, getDaysInMonth, getDate, eachMonthOfInterval, endOfMonth, isWithinInterval, isSameMonth } from 'date-fns';
import { ru } from 'date-fns/locale';
import { useStore } from '../store/useStore';
import { useCurrencyConverter } from '../hooks/useCurrencyConverter';
import { cn } from '../lib/utils';
import { Transaction, TransactionType, PaymentMethod, Currency } from '../types';
import { ShoppingList } from './ShoppingList';
import { AIFinanceAssistant } from '../components/AIFinanceAssistant';
import { FinancialPlanTab } from '../components/FinancialPlanTab';
import { BudgetControlTab } from '../components/BudgetControlTab';
import { AccountsTab } from '../components/AccountsTab';
import { SmartFinanceAlerts } from '../components/SmartFinanceAlerts';
import { MonthlyBudgetPlanTab } from '../components/MonthlyBudgetPlanTab';
// Heavy / rarely-used finance tabs are split out so the initial bundle stays small.
const ProAnalyticsTab = lazy(() => import('../components/ProAnalyticsTab').then(m => ({ default: m.ProAnalyticsTab })));
const VacationPlanner = lazy(() => import('../components/VacationPlanner').then(m => ({ default: m.VacationPlanner })));
const DebtStrategyTab = lazy(() => import('../components/DebtStrategyTab').then(m => ({ default: m.DebtStrategyTab })));
const BudgetPlanningTab = lazy(() => import('../components/BudgetPlanningTab').then(m => ({ default: m.BudgetPlanningTab })));
const WealthTree = lazy(() => import('../components/WealthTree').then(m => ({ default: m.WealthTree })));
const SubscriptionsTab = lazy(() => import('../components/SubscriptionsTab').then(m => ({ default: m.SubscriptionsTab })));
const FIRECalculatorTab = lazy(() => import('../components/FIRECalculatorTab').then(m => ({ default: m.FIRECalculatorTab })));
const PredictiveBudgetTab = lazy(() => import('../components/PredictiveBudgetTab').then(m => ({ default: m.PredictiveBudgetTab })));

function LazyTabFallback() {
  return (
    <div className="flex items-center justify-center py-20">
      <Loader2 className="w-7 h-7 text-emerald-500 animate-spin" />
    </div>
  );
}

import { DailyFinancialTip } from '../components/DailyFinancialTip';
import { Target, Sparkles, ShieldAlert, Landmark, Plane, TrendingDown, CalendarRange, TreeDeciduous, Settings, Flame, BrainCircuit } from 'lucide-react';
import { GoogleGenAI, Type } from '@google/genai';
import Tesseract from 'tesseract.js';

export function Finance() {
  const { 
    transactions = [], 
    accounts = [], 
    loans = [], 
    savingsGoals = [],
    rates = {},
    baseCurrency = 'USD',
    fetchRates,
    setBaseCurrency
  } = useStore();
  const [activeTab, setActiveTab] = useState<'transactions' | 'accounts' | 'shopping' | 'analytics' | 'pro-analytics' | 'loans' | 'ai' | 'plan' | 'control' | 'vacation' | 'savings' | 'debt-strategy' | 'budget-planning' | 'monthly-plan' | 'wealth' | 'subscriptions' | 'fire' | 'predictive'>('monthly-plan');
  const [aiPrompt, setAiPrompt] = useState<string | undefined>();
  const [showCurrencySettings, setShowCurrencySettings] = useState(false);

  useEffect(() => {
    fetchRates();
  }, []);

  const convertToAnchor = (amount: number, currency: Currency) => {
    const rate = rates[currency] || 1;
    return amount * rate;
  };

  const convertFromAnchor = (amountInAnchor: number, targetCurrency: Currency) => {
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

  const netWorthInAnchor = totalAccountBalanceInAnchor + totalSavingsInAnchor - totalDebtInAnchor;
  const netWorthInBase = convertFromAnchor(netWorthInAnchor, baseCurrency);

  const FINANCE_TABS = {
    'Операции': [
      { id: 'transactions', label: 'Операции', icon: Wallet },
      { id: 'accounts', label: 'Счета', icon: Landmark },
      { id: 'shopping', label: 'Покупки', icon: ShoppingCart },
      { id: 'subscriptions', label: 'Подписки', icon: CreditCard, color: 'text-blue-400' },
    ],
    'Бюджет': [
      { id: 'monthly-plan', label: 'План месяца', icon: Target, color: 'text-emerald-500' },
      { id: 'budget-planning', label: 'Прогноз', icon: CalendarRange, color: 'text-emerald-400' },
      { id: 'predictive', label: 'ИИ Бюджет', icon: BrainCircuit, color: 'text-purple-500' },
      { id: 'control', label: 'Контроль', icon: ShieldAlert, color: 'text-emerald-400' },
    ],
    'Аналитика': [
      { id: 'analytics', label: 'Анализ', icon: LineChartIcon },
      { id: 'pro-analytics', label: 'Pro', icon: Sparkles, color: 'text-purple-400' },
      { id: 'ai', label: 'ИИ', icon: Bot },
    ],
    'Капитал': [
      { id: 'wealth', label: 'Дерево', icon: TreeDeciduous, color: 'text-emerald-500' },
      { id: 'savings', label: 'Копилка', icon: PiggyBank, color: 'text-pink-500' },
      { id: 'loans', label: 'Кредиты', icon: Calculator },
      { id: 'debt-strategy', label: 'Долги', icon: TrendingDown, color: 'text-red-400' },
      { id: 'fire', label: 'FIRE', icon: Flame, color: 'text-orange-500' },
    ],
    'Цели': [
      { id: 'plan', label: 'План', icon: Target },
      { id: 'vacation', label: 'Отпуск', icon: Plane },
    ]
  };

  const activeCategory = Object.entries(FINANCE_TABS).find(([_, tabs]) => tabs.some(t => t.id === activeTab))?.[0] || 'Операции';

  const switchToAI = (prompt: string) => {
    setAiPrompt(prompt);
    setActiveTab('ai');
  };

  return (
    <div className="space-y-6 pb-24">
      <header className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-zinc-900 mb-2">Финансы</h1>
          <p className="text-zinc-500">Учет доходов, расходов, покупки и кредиты</p>
        </div>
        <div className="flex items-center gap-2">
          <div className="bg-white/80 border border-stone-200 p-3 rounded-2xl flex items-center gap-4">
            <div className="p-2 bg-emerald-500/10 rounded-xl">
              <Target className="w-5 h-5 text-emerald-500" />
            </div>
            <div>
              <p className="text-[10px] text-zinc-500 uppercase font-bold tracking-wider">Чистый капитал</p>
              <p className={cn(
                "text-lg font-bold",
                netWorthInBase >= 0 ? "text-emerald-400" : "text-red-400"
              )}>
                {netWorthInBase.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} {baseCurrency}
              </p>
            </div>
          </div>
          <button 
            onClick={() => setShowCurrencySettings(!showCurrencySettings)}
            className="p-3 bg-white/80 border border-stone-200 rounded-2xl text-zinc-500 hover:text-zinc-900 transition-colors"
          >
            <Globe className="w-5 h-5" />
          </button>
        </div>
      </header>

      <AnimatePresence>
        {showCurrencySettings && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            className="overflow-hidden"
          >
            <div className="bg-white/80 border border-stone-200 p-4 rounded-2xl space-y-4">
              <div className="flex items-center justify-between">
                <h3 className="text-sm font-bold text-zinc-900 flex items-center gap-2">
                  <Globe className="w-4 h-4 text-blue-400" />
                  Настройки валюты
                </h3>
                <p className="text-[10px] text-zinc-500">Курсы НБРБ</p>
              </div>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                <div>
                  <label className="block text-[10px] text-zinc-500 uppercase font-bold mb-1">Основная валюта</label>
                  <select
                    value={baseCurrency}
                    onChange={(e) => setBaseCurrency(e.target.value as Currency)}
                    className="w-full bg-stone-100 text-zinc-900 text-sm rounded-xl px-3 py-2 border border-stone-300 focus:outline-none focus:border-blue-500"
                  >
                    <option value="BYN">BYN (Рубль)</option>
                    <option value="USD">USD (Доллар)</option>
                    <option value="EUR">EUR (Евро)</option>
                    <option value="RUB">RUB (Рос. рубль)</option>
                    <option value="PLN">PLN (Злотый)</option>
                  </select>
                </div>
                {Object.entries(rates).filter(([c]) => c !== 'BYN').map(([curr, rate]) => (
                  <div key={curr}>
                    <p className="text-[10px] text-zinc-500 uppercase font-bold mb-1">{curr}</p>
                    <p className="text-sm font-medium text-zinc-900">{rate.toFixed(4)} BYN</p>
                  </div>
                ))}
                <div className="flex items-end">
                  <button
                    onClick={() => fetchRates()}
                    className="w-full py-2 bg-stone-100 text-zinc-700 rounded-xl text-xs font-bold hover:bg-stone-200 transition-colors flex items-center justify-center gap-2"
                  >
                    <Loader2 className="w-3 h-3" />
                    Обновить курсы
                  </button>
                </div>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      <DailyFinancialTip />

      {/* Tabs */}
      <div className="space-y-2">
        {/* Categories */}
        <div className="grid grid-cols-2 sm:grid-cols-5 gap-1 bg-white/60 p-1 rounded-xl">
          {Object.keys(FINANCE_TABS).map((category) => (
            <button
              key={category}
              onClick={() => setActiveTab(FINANCE_TABS[category as keyof typeof FINANCE_TABS][0].id as typeof activeTab)}
              className={cn(
                "py-2 rounded-lg text-[10px] sm:text-sm font-medium transition-all",
                activeCategory === category ? "bg-stone-100 text-zinc-900 shadow-sm" : "text-zinc-500 hover:text-zinc-800"
              )}
            >
              {category}
            </button>
          ))}
        </div>

        {/* Sub-tabs */}
        <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-5 gap-1 bg-white/30 p-1 rounded-xl">
          {FINANCE_TABS[activeCategory as keyof typeof FINANCE_TABS].map((tab) => {
            const Icon = tab.icon;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={cn(
                  "flex items-center justify-center gap-2 py-2 rounded-lg text-[10px] sm:text-sm font-medium transition-all",
                  activeTab === tab.id ? "bg-stone-100 text-zinc-900 shadow-sm" : "text-zinc-500 hover:text-zinc-800"
                )}
              >
                <Icon className={cn("w-4 h-4", tab.color)} />
                <span>{tab.label}</span>
              </button>
            );
          })}
        </div>
      </div>

      <motion.div
        key={activeTab}
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.2 }}
      >
        {activeTab === 'transactions' && (
          <div className="space-y-6">
            <SmartFinanceAlerts />
            <TransactionsTab />
          </div>
        )}
        {activeTab === 'accounts' && <AccountsTab />}
        {activeTab === 'shopping' && <ShoppingList />}
        {activeTab === 'savings' && <SavingsTab />}
        {activeTab === 'loans' && <LoansTab />}
        {activeTab === 'plan' && <FinancialPlanTab onSwitchToAI={switchToAI} />}
        {activeTab === 'control' && <BudgetControlTab />}
        {activeTab === 'monthly-plan' && <MonthlyBudgetPlanTab />}
        {activeTab === 'analytics' && <FinanceAnalyticsTab />}
        {activeTab === 'ai' && <AIFinanceAssistant initialPrompt={aiPrompt} />}
        <Suspense fallback={<LazyTabFallback />}>
          {activeTab === 'vacation' && <VacationPlanner />}
          {activeTab === 'debt-strategy' && <DebtStrategyTab />}
          {activeTab === 'budget-planning' && <BudgetPlanningTab />}
          {activeTab === 'wealth' && <WealthTree />}
          {activeTab === 'pro-analytics' && <ProAnalyticsTab />}
          {activeTab === 'subscriptions' && <SubscriptionsTab />}
          {activeTab === 'fire' && <FIRECalculatorTab />}
          {activeTab === 'predictive' && <PredictiveBudgetTab />}
        </Suspense>
      </motion.div>
    </div>
  );
}

function SavingsTab() {
  const { savingsGoals = [], accounts = [], addSavingsGoal, updateSavingsGoal, deleteSavingsGoal, addSavingsContribution } = useStore();
  const [isAdding, setIsAdding] = useState(false);
  const [title, setTitle] = useState('');
  const [targetAmount, setTargetAmount] = useState('');
  const [color, setColor] = useState('#ec4899');
  
  const [activeAction, setActiveAction] = useState<{ id: string, type: 'deposit' | 'withdraw' } | null>(null);
  const [actionAmount, setActionAmount] = useState('');
  const [actionAccountId, setActionAccountId] = useState<string>('');

  const handleAdd = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title || !targetAmount) return;
    addSavingsGoal({
      title,
      targetAmount: parseFloat(targetAmount),
      currentAmount: 0,
      color
    });
    setTitle('');
    setTargetAmount('');
    setIsAdding(false);
  };

  const handleAction = (e: React.FormEvent) => {
    e.preventDefault();
    if (!activeAction || !actionAmount) return;
    if (accounts.length > 0 && !actionAccountId) return;
    const amount = parseFloat(actionAmount);
    if (isNaN(amount)) return;
    
    addSavingsContribution(activeAction.id, activeAction.type === 'deposit' ? amount : -amount);
    
    // Add to transactions for unified analytics
    const goal = savingsGoals.find(g => g.id === activeAction.id);
    useStore.getState().addTransaction({
      type: activeAction.type === 'deposit' ? 'expense' : 'income',
      amount: amount,
      category: 'Копилка',
      notes: `${activeAction.type === 'deposit' ? 'Пополнение' : 'Снятие'}: ${goal?.title || 'Копилка'}`,
      date: new Date().toISOString().split('T')[0],
      paymentMethod: accounts.length > 0 ? (accounts.find(a => a.id === actionAccountId)?.type === 'cash' ? 'cash' : 'card') : 'card',
      accountId: accounts.length > 0 ? actionAccountId : undefined
    });

    setActiveAction(null);
    setActionAmount('');
    setActionAccountId('');
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-lg font-semibold text-zinc-900">Копилки</h2>
        <button
          onClick={() => setIsAdding(!isAdding)}
          className="p-2 bg-pink-500 text-zinc-900 rounded-xl hover:bg-pink-600 transition-colors"
        >
          <Plus className="w-5 h-5" />
        </button>
      </div>

      <AnimatePresence>
        {isAdding && (
          <motion.form
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            onSubmit={handleAdd}
            className="bg-white border border-stone-200 rounded-2xl p-4 space-y-4 overflow-hidden"
          >
            <div className="space-y-2">
              <label className="text-xs text-zinc-500 uppercase">Название цели</label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="Напр: Новый iPhone"
                className="w-full bg-stone-50 border border-stone-200 rounded-xl py-2 px-4 text-sm text-zinc-900 focus:outline-none focus:border-pink-500/50"
              />
            </div>
            <div className="space-y-2">
              <label className="text-xs text-zinc-500 uppercase">Сумма цели</label>
              <input
                type="number"
                value={targetAmount}
                onChange={(e) => setTargetAmount(e.target.value)}
                placeholder="0"
                className="w-full bg-stone-50 border border-stone-200 rounded-xl py-2 px-4 text-sm text-zinc-900 focus:outline-none focus:border-pink-500/50"
              />
            </div>
            <div className="space-y-2">
              <label className="text-xs text-zinc-500 uppercase">Цвет</label>
              <div className="flex gap-2 flex-wrap">
                {['#ec4899', '#f59e0b', '#10b981', '#3b82f6', '#8b5cf6', '#ef4444'].map(c => (
                  <button
                    key={c}
                    type="button"
                    onClick={() => setColor(c)}
                    className={cn(
                      "w-8 h-8 rounded-full border-2 transition-all",
                      color === c ? "border-white scale-110" : "border-transparent"
                    )}
                    style={{ backgroundColor: c }}
                  />
                ))}
              </div>
            </div>
            <div className="flex gap-2 pt-2">
              <button
                type="button"
                onClick={() => setIsAdding(false)}
                className="flex-1 py-2 bg-stone-100 text-zinc-500 rounded-xl text-xs font-medium"
              >
                Отмена
              </button>
              <button
                type="submit"
                className="flex-1 py-2 bg-pink-500 text-zinc-900 rounded-xl text-xs font-bold"
              >
                Создать
              </button>
            </div>
          </motion.form>
        )}
      </AnimatePresence>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        {savingsGoals.map(goal => {
          const progress = Math.min((goal.currentAmount / goal.targetAmount) * 100, 100);
          const isFull = progress >= 100;
          const isActionActive = activeAction?.id === goal.id;
          
          return (
            <div 
              key={goal.id} 
              className={cn(
                "bg-white border rounded-3xl p-6 transition-all duration-500",
                isFull ? "border-amber-500/50 shadow-[0_0_20px_rgba(245,158,11,0.1)]" : "border-stone-200"
              )}
            >
              <div className="flex justify-between items-start mb-6">
                <div className="flex items-center gap-3">
                  <div className={cn("p-3 rounded-2xl", isFull ? "bg-amber-500/10" : "bg-pink-500/10")}>
                    <PiggyBank className={cn("w-6 h-6", isFull ? "text-amber-500" : "text-pink-500")} />
                  </div>
                  <div>
                    <h3 className="text-sm font-bold text-zinc-900">{goal.title}</h3>
                    <p className="text-[10px] text-zinc-500 uppercase tracking-wider">
                      {goal.currentAmount.toLocaleString()} / {goal.targetAmount.toLocaleString()} ₽
                    </p>
                  </div>
                </div>
                <button
                  onClick={() => deleteSavingsGoal(goal.id)}
                  className="p-2 text-zinc-600 hover:text-red-400 transition-colors"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>

              <div className="space-y-2 mb-6">
                <div className="flex justify-between text-[10px] font-bold uppercase tracking-wider">
                  <span className="text-zinc-500">Прогресс</span>
                  <span className={isFull ? "text-amber-500" : "text-pink-500"}>{progress.toFixed(1)}%</span>
                </div>
                <div className="h-2 bg-stone-50 rounded-full overflow-hidden border border-stone-200/70">
                  <motion.div
                    initial={{ width: 0 }}
                    animate={{ width: `${progress}%` }}
                    className={cn(
                      "h-full transition-all duration-1000",
                      isFull ? "bg-amber-500 shadow-[0_0_10px_rgba(245,158,11,0.5)]" : "bg-pink-500"
                    )}
                  />
                </div>
              </div>

              <AnimatePresence mode="wait">
                {isActionActive ? (
                  <motion.form
                    key="action-form"
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -10 }}
                    onSubmit={handleAction}
                    className="space-y-3"
                  >
                    <div className="relative">
                      <input
                        autoFocus
                        type="number"
                        value={actionAmount}
                        onChange={(e) => setActionAmount(e.target.value)}
                        placeholder={activeAction.type === 'deposit' ? "Сумма пополнения" : "Сумма снятия"}
                        className="w-full bg-stone-50 border border-stone-200 rounded-xl py-2 px-4 text-sm text-zinc-900 focus:outline-none focus:border-pink-500/50"
                      />
                      <div className="absolute right-3 top-1/2 -translate-y-1/2 text-[10px] text-zinc-500 font-bold">₽</div>
                    </div>
                    {accounts.length > 0 && (
                      <select
                        value={actionAccountId}
                        onChange={(e) => setActionAccountId(e.target.value)}
                        className="w-full bg-stone-50 border border-stone-200 rounded-xl py-2 px-4 text-sm text-zinc-900 focus:outline-none focus:border-pink-500/50"
                        required
                      >
                        <option value="" disabled>Выберите счет</option>
                        {accounts.map(acc => (
                          <option key={acc.id} value={acc.id}>{acc.name} ({acc.currency})</option>
                        ))}
                      </select>
                    )}
                    <div className="flex gap-2">
                      <button
                        type="button"
                        onClick={() => setActiveAction(null)}
                        className="flex-1 py-2 bg-stone-100 text-zinc-500 rounded-xl text-xs font-bold"
                      >
                        Отмена
                      </button>
                      <button
                        type="submit"
                        className={cn(
                          "flex-1 py-2 rounded-xl text-xs font-bold text-zinc-900",
                          activeAction.type === 'deposit' ? "bg-pink-500" : "bg-stone-200"
                        )}
                      >
                        {activeAction.type === 'deposit' ? "Пополнить" : "Снять"}
                      </button>
                    </div>
                  </motion.form>
                ) : (
                  <motion.div
                    key="action-buttons"
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -10 }}
                    className="flex gap-2"
                  >
                    <button
                      onClick={() => {
                        setActiveAction({ id: goal.id, type: 'deposit' });
                        setActionAmount('');
                      }}
                      className="flex-1 py-2 bg-pink-500 text-zinc-900 rounded-xl text-xs font-bold hover:bg-pink-600 transition-colors"
                    >
                      Пополнить
                    </button>
                    <button
                      onClick={() => {
                        setActiveAction({ id: goal.id, type: 'withdraw' });
                        setActionAmount('');
                      }}
                      className="flex-1 py-2 bg-stone-100 text-zinc-500 rounded-xl text-xs font-bold hover:bg-stone-200 transition-colors"
                    >
                      Снять
                    </button>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          );
        })}
      </div>

      {savingsGoals.length === 0 && (
        <div className="text-center py-12 bg-white/30 rounded-3xl border border-dashed border-stone-200">
          <div className="w-16 h-16 bg-white rounded-full flex items-center justify-center mx-auto mb-4">
            <PiggyBank className="w-8 h-8 text-zinc-700" />
          </div>
          <p className="text-zinc-500">У вас пока нет копилок</p>
        </div>
      )}
    </div>
  );
}

function TransactionsTab() {
  const { transactions = [], accounts = [], regularPayments = [], addTransaction, deleteTransaction, updateTransaction, rates = {}, baseCurrency = 'USD' } = useStore();
  const [isAdding, setIsAdding] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [type, setType] = useState<TransactionType>('expense');
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>('card');
  const [accountId, setAccountId] = useState<string>('');
  const [toAccountId, setToAccountId] = useState<string>('');
  const [amount, setAmount] = useState('');
  const [cashGiven, setCashGiven] = useState('');
  const [category, setCategory] = useState('');
  const [source, setSource] = useState('');
  const [date, setDate] = useState(new Date().toISOString().split('T')[0]);
  const [notes, setNotes] = useState('');
  const [tags, setTags] = useState('');
  const [photoUrl, setPhotoUrl] = useState<string | undefined>();
  const [isChangeConfirmed, setIsChangeConfirmed] = useState(false);
  const [isBalanceVisible, setIsBalanceVisible] = useState(false);
  const [parseMode, setParseMode] = useState<'none' | 'ai' | 'ocr'>('ai');
  const [isParsingReceipt, setIsParsingReceipt] = useState(false);
  const [fullscreenImage, setFullscreenImage] = useState<string | null>(null);
  const [periodFilter, setPeriodFilter] = useState<'all' | 'today' | 'week' | 'month' | 'year'>('month');
  const [showUpcoming, setShowUpcoming] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const cameraInputRef = useRef<HTMLInputElement>(null);

  const convertCurrency = useCurrencyConverter();

  // Set default account if available
  React.useEffect(() => {
    if (accounts.length > 0 && !accountId) {
      setAccountId(accounts[0].id);
    }
    if (accounts.length > 1 && !toAccountId) {
      setToAccountId(accounts[1].id);
    } else if (accounts.length > 0 && !toAccountId) {
      setToAccountId(accounts[0].id);
    }
  }, [accounts, accountId, toAccountId]);

  const now = new Date();
  const currentDay = now.getDate();

  const upcomingExpenses = regularPayments.filter(p => p.isActive && p.dueDate >= currentDay);
  const upcomingTotal = upcomingExpenses.reduce((sum, p) => sum + convertCurrency(p.amount, p.currency || baseCurrency, baseCurrency), 0);

  const filteredTransactions = transactions.filter(t => {
    if (periodFilter === 'all') return true;
    const tDate = new Date(t.date);
    if (periodFilter === 'today') {
      return tDate.toDateString() === now.toDateString();
    }
    if (periodFilter === 'week') {
      return tDate >= startOfWeek(now, { weekStartsOn: 1 });
    }
    if (periodFilter === 'month') {
      return tDate >= startOfMonth(now);
    }
    if (periodFilter === 'year') {
      return tDate >= startOfYear(now);
    }
    return true;
  });

  const parseReceiptWithAI = async (base64Image: string) => {
    if (!process.env.GEMINI_API_KEY) return;
    setIsParsingReceipt(true);
    try {
      const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });
      const base64Data = base64Image.split(',')[1];
      const mimeType = base64Image.split(';')[0].split(':')[1];

      const response = await ai.models.generateContent({
        model: 'gemini-3-flash-preview',
        contents: {
          parts: [
            {
              inlineData: {
                data: base64Data,
                mimeType: mimeType,
              },
            },
            {
              text: 'Ты финансовый помощник. Проанализируй этот чек. Верни JSON с полями: amount (число, итоговая сумма), category (строка, выбери наиболее подходящую категорию: Продукты, Кафе, Транспорт, Жилье, Развлечения, Одежда, Здоровье, Связь, Подарки, Другое), notes (строка, краткий список покупок через запятую).',
            },
          ],
        },
        config: {
          responseMimeType: 'application/json',
          responseSchema: {
            type: Type.OBJECT,
            properties: {
              amount: { type: Type.NUMBER, description: 'Итоговая сумма по чеку' },
              category: { type: Type.STRING, description: 'Категория расходов' },
              notes: { type: Type.STRING, description: 'Краткий список покупок' },
            },
            required: ['amount', 'category', 'notes'],
          },
        },
      });

      const text = response.text;
      if (text) {
        const data = JSON.parse(text);
        if (data.amount) setAmount(data.amount.toString());
        if (data.category) setCategory(data.category);
        if (data.notes) setNotes(data.notes);
      }
    } catch (error) {
      console.error('Error parsing receipt:', error);
    } finally {
      setIsParsingReceipt(false);
    }
  };

  const parseReceiptWithOCR = async (base64Image: string) => {
    setIsParsingReceipt(true);
    try {
      const result = await Tesseract.recognize(
        base64Image,
        'rus+eng',
        { logger: m => console.log(m) }
      );
      const text = result.data.text;
      
      // Simple heuristic to find amount
      const lines = text.split('\n');
      let foundAmount = 0;
      
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i].toLowerCase();
        if (line.includes('итог') || line.includes('сумма') || line.includes('к оплате') || line.includes('total')) {
          const match = line.match(/\d+[.,]\d{2}/);
          if (match) {
            foundAmount = parseFloat(match[0].replace(',', '.'));
            break;
          } else if (i + 1 < lines.length) {
            const nextMatch = lines[i+1].match(/\d+[.,]\d{2}/);
            if (nextMatch) {
              foundAmount = parseFloat(nextMatch[0].replace(',', '.'));
              break;
            }
          }
        }
      }
      
      if (foundAmount > 0) {
        setAmount(foundAmount.toString());
      }
      
      const cleanText = lines.filter(l => l.trim().length > 3).slice(0, 5).join(', ');
      setNotes(cleanText.substring(0, 100) + (cleanText.length > 100 ? '...' : ''));
      
    } catch (error) {
      console.error('Error parsing receipt with OCR:', error);
    } finally {
      setIsParsingReceipt(false);
    }
  };

  const handlePhotoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      const result = event.target?.result as string;
      setPhotoUrl(result);
      if (parseMode === 'ai') {
        parseReceiptWithAI(result);
      } else if (parseMode === 'ocr') {
        parseReceiptWithOCR(result);
      }
    };
    reader.readAsDataURL(file);
  };

  const handleEdit = (t: Transaction) => {
    setEditingId(t.id);
    setType(t.type);
    setPaymentMethod(t.paymentMethod || 'card');
    setAccountId(t.accountId || (accounts.length > 0 ? accounts[0].id : ''));
    setToAccountId(t.toAccountId || (accounts.length > 1 ? accounts[1].id : accounts.length > 0 ? accounts[0].id : ''));
    setAmount(t.amount.toString());
    setCashGiven(t.cashGiven ? t.cashGiven.toString() : '');
    setCategory(t.category);
    setSource(t.source || '');
    setDate(t.date);
    setNotes(t.notes || '');
    setTags(t.tags ? t.tags.join(', ') : '');
    setPhotoUrl(t.photoUrl);
    setIsAdding(true);
  };

  const resetForm = () => {
    setIsAdding(false);
    setEditingId(null);
    setAmount('');
    setCashGiven('');
    setCategory('');
    setSource('');
    setNotes('');
    setTags('');
    setPhotoUrl(undefined);
    setType('expense');
    setPaymentMethod('card');
    setIsChangeConfirmed(false);
    if (accounts.length > 0) {
      setAccountId(accounts[0].id);
      setToAccountId(accounts.length > 1 ? accounts[1].id : accounts[0].id);
    }
  };

  const selectedAccount = accounts.find(a => a.id === accountId);
  const transactionCurrency = selectedAccount?.currency || baseCurrency;

  const handleAdd = (e: React.FormEvent) => {
    e.preventDefault();
    if (!amount || !category || !date) return;
    if (accounts.length > 0 && !accountId) return; // Require account if accounts exist
    if (type === 'transfer' && accounts.length > 0 && (!accountId || !toAccountId || accountId === toAccountId)) return;

    const parsedAmount = parseFloat(amount) || 0;
    const parsedCashGiven = parseFloat(cashGiven) || 0;
    const change = parsedCashGiven > parsedAmount ? parsedCashGiven - parsedAmount : 0;

    const isCashTransaction = accounts.length > 0 
      ? accounts.find(a => a.id === accountId)?.type === 'cash'
      : paymentMethod === 'cash';

    if (type === 'expense' && isCashTransaction && change > 0 && !isChangeConfirmed) {
      return; // Require confirmation
    }

    const transactionData = {
      type,
      amount: parseFloat(amount),
      category,
      source: type === 'income' ? source : undefined,
      date,
      notes,
      tags: tags.split(',').map(t => t.trim()).filter(t => t.length > 0),
      photoUrl,
      paymentMethod: accounts.length > 0 ? (isCashTransaction ? 'cash' : 'card') : paymentMethod,
      accountId: accounts.length > 0 ? accountId : undefined,
      toAccountId: type === 'transfer' && accounts.length > 0 ? toAccountId : undefined,
      cashGiven: type === 'expense' && isCashTransaction && cashGiven ? parseFloat(cashGiven) : undefined
    };

    if (editingId) {
      updateTransaction(editingId, transactionData);
    } else {
      addTransaction(transactionData);
    }

    resetForm();
  };

  const totalIncome = transactions.filter(t => t.type === 'income').reduce((sum, t) => {
    const account = accounts.find(a => a.id === t.accountId);
    const currency = account?.currency || baseCurrency;
    return sum + convertCurrency(t.amount, currency, baseCurrency);
  }, 0);
  
  const totalExpense = transactions.filter(t => t.type === 'expense').reduce((sum, t) => {
    const account = accounts.find(a => a.id === t.accountId);
    const currency = account?.currency || baseCurrency;
    return sum + convertCurrency(t.amount, currency, baseCurrency);
  }, 0);

  const initialBalanceTotal = accounts.reduce((sum, acc) => sum + convertCurrency(acc.initialBalance, acc.currency || baseCurrency, baseCurrency), 0);
  const balance = initialBalanceTotal + totalIncome - totalExpense;

  const cardBalance = accounts.filter(a => a.type !== 'cash').reduce((sum, acc) => sum + convertCurrency(acc.initialBalance, acc.currency || baseCurrency, baseCurrency), 0) + transactions.reduce((acc, t) => {
    if (t.type === 'transfer') {
      let diff = 0;
      const fromAcc = accounts.find(a => a.id === t.accountId);
      const toAcc = accounts.find(a => a.id === t.toAccountId);
      if (fromAcc && fromAcc.type !== 'cash') diff -= convertCurrency(t.amount, fromAcc.currency || baseCurrency, baseCurrency);
      if (toAcc && toAcc.type !== 'cash') diff += convertCurrency(t.amount, fromAcc?.currency || baseCurrency, baseCurrency);
      return acc + diff;
    }
    const account = accounts.find(a => a.id === t.accountId);
    const method = account?.type || t.paymentMethod || 'card';
    const currency = account?.currency || baseCurrency;
    if (method !== 'cash') return acc + convertCurrency(t.type === 'income' ? t.amount : -t.amount, currency, baseCurrency);
    return acc;
  }, 0);

  const cashBalance = accounts.filter(a => a.type === 'cash').reduce((sum, acc) => sum + convertCurrency(acc.initialBalance, acc.currency || baseCurrency, baseCurrency), 0) + transactions.reduce((acc, t) => {
    if (t.type === 'transfer') {
      let diff = 0;
      const fromAcc = accounts.find(a => a.id === t.accountId);
      const toAcc = accounts.find(a => a.id === t.toAccountId);
      if (fromAcc && fromAcc.type === 'cash') diff -= convertCurrency(t.amount, fromAcc.currency || baseCurrency, baseCurrency);
      if (toAcc && toAcc.type === 'cash') diff += convertCurrency(t.amount, fromAcc?.currency || baseCurrency, baseCurrency);
      return acc + diff;
    }
    const account = accounts.find(a => a.id === t.accountId);
    const method = account?.type || t.paymentMethod || 'card';
    const currency = account?.currency || baseCurrency;
    if (method === 'cash') return acc + convertCurrency(t.type === 'income' ? t.amount : -t.amount, currency, baseCurrency);
    return acc;
  }, 0);

  const exportToCSV = () => {
    const headers = ['Дата', 'Тип', 'Категория', 'Источник', 'Сумма', 'Валюта', 'Счет', 'Заметки'];
    const rows = transactions.map(t => {
      let accountName = t.paymentMethod === 'cash' ? 'Наличные' : 'Карта';
      let currency = baseCurrency;
      if (t.accountId) {
        const acc = accounts.find(a => a.id === t.accountId);
        accountName = acc?.name || accountName;
        currency = acc?.currency || baseCurrency;
      }
      if (t.type === 'transfer' && t.toAccountId) {
        const toAccountName = accounts.find(a => a.id === t.toAccountId)?.name || 'Счет';
        accountName = `${accountName} -> ${toAccountName}`;
      }

      return [
        t.date,
        t.type === 'income' ? 'Доход' : t.type === 'transfer' ? 'Перевод' : 'Расход',
        t.category,
        `"${(t.source || '').replace(/"/g, '""')}"`,
        t.amount,
        currency,
        accountName,
        `"${(t.notes || '').replace(/"/g, '""')}"`
      ];
    });
    const csvContent = [headers, ...rows].map(e => e.join(',')).join('\n');
    const blob = new Blob([new Uint8Array([0xEF, 0xBB, 0xBF]), csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute('download', 'finance_export.csv');
    link.click();
  };

  const parsedAmount = parseFloat(amount) || 0;
  const parsedCashGiven = parseFloat(cashGiven) || 0;
  const change = parsedCashGiven > parsedAmount ? parsedCashGiven - parsedAmount : 0;

  const existingCategories = Array.from(new Set(transactions.filter(t => t.type === type).map(t => t.category))).filter(Boolean);

  return (
    <div className="space-y-6">
      {/* Summary Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70 relative">
          <div className="text-xs text-zinc-500 mb-1 flex justify-between items-center">
            <span>Общий баланс</span>
            <button onClick={() => setIsBalanceVisible(!isBalanceVisible)} className="text-zinc-500 hover:text-zinc-700">
              {isBalanceVisible ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            </button>
          </div>
          <div className={cn("text-xl font-bold", balance >= 0 ? "text-zinc-900" : "text-red-400")}>
            {isBalanceVisible ? `${balance.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${baseCurrency}` : '••••••'}
          </div>
          {upcomingTotal > 0 && (
            <div className="mt-2 pt-2 border-t border-stone-200/70">
              <div className="text-[10px] text-zinc-500 flex justify-between">
                <span>Доступно:</span>
                <span className="text-emerald-400 font-bold">
                  {isBalanceVisible ? `${(balance - upcomingTotal).toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${baseCurrency}` : '••••'}
                </span>
              </div>
            </div>
          )}
        </div>
        <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
          <div className="text-xs text-zinc-500 mb-1 flex items-center gap-1">
            <CreditCard className="w-3 h-3 text-blue-400" />
            На карте
          </div>
          <div className="text-lg font-bold text-blue-400">
            {isBalanceVisible ? `${cardBalance.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${baseCurrency}` : '••••••'}
          </div>
        </div>
        <div className="bg-white/60 p-4 rounded-2xl border border-stone-200/70">
          <div className="text-xs text-zinc-500 mb-1 flex items-center gap-1">
            <Banknote className="w-3 h-3 text-emerald-500" />
            Наличные
          </div>
          <div className="text-lg font-bold text-emerald-400">
            {isBalanceVisible ? `${cashBalance.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${baseCurrency}` : '••••••'}
          </div>
        </div>
      </div>

      {/* Upcoming Expenses Section */}
      {upcomingExpenses.length > 0 && (
        <div className="bg-white/30 border border-stone-200/70 rounded-2xl overflow-hidden">
          <button 
            onClick={() => setShowUpcoming(!showUpcoming)}
            className="w-full flex items-center justify-between p-4 hover:bg-stone-100/40 transition-colors"
          >
            <div className="flex items-center gap-3">
              <div className="p-2 bg-amber-500/10 rounded-lg">
                <Clock className="w-4 h-4 text-amber-500" />
              </div>
              <div className="text-left">
                <h3 className="text-sm font-bold text-zinc-900">Предстоящие расходы</h3>
                <p className="text-[10px] text-zinc-500">До конца месяца: {upcomingTotal.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} {baseCurrency}</p>
              </div>
            </div>
            {showUpcoming ? <ChevronUp className="w-4 h-4 text-zinc-500" /> : <ChevronDown className="w-4 h-4 text-zinc-500" />}
          </button>
          
          <AnimatePresence>
            {showUpcoming && (
              <motion.div 
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                className="px-4 pb-4 space-y-2"
              >
                {upcomingExpenses.sort((a, b) => a.dueDate - b.dueDate).map(p => (
                  <div key={p.id} className="flex items-center justify-between p-3 bg-stone-50/50 rounded-xl border border-stone-200/70">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-lg bg-white flex items-center justify-center text-xs font-bold text-zinc-500">
                        {p.dueDate}
                      </div>
                      <div>
                        <div className="text-xs font-medium text-zinc-900">{p.name}</div>
                        <div className="text-[10px] text-zinc-500">{p.category}</div>
                      </div>
                    </div>
                    <div className="text-xs font-bold text-zinc-700">
                      {p.amount.toLocaleString('ru-RU')} {p.currency || baseCurrency}
                    </div>
                  </div>
                ))}
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      )}

      <div className="flex justify-between items-center">
        <h2 className="text-lg font-semibold text-zinc-900">История операций</h2>
        <div className="flex gap-2">
          <button
            onClick={exportToCSV}
            className="p-2 bg-stone-100 text-zinc-700 rounded-lg hover:bg-stone-200 transition-colors"
            title="Экспорт в CSV"
          >
            <Download className="w-5 h-5" />
          </button>
          <button
            onClick={() => setIsAdding(!isAdding)}
            className="p-2 bg-stone-100 text-zinc-900 rounded-lg hover:bg-stone-200 transition-colors"
          >
            {isAdding ? <X className="w-5 h-5" /> : <Plus className="w-5 h-5" />}
          </button>
        </div>
      </div>

      <AnimatePresence>
        {isAdding && (
          <motion.form
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            onSubmit={handleAdd}
            className="bg-white p-4 rounded-2xl border border-stone-200 space-y-4 overflow-hidden"
          >
            <div className="flex gap-2 p-1 bg-stone-50 rounded-lg">
              <button
                type="button"
                onClick={() => setType('expense')}
                className={cn(
                  "flex-1 py-1.5 rounded-md text-sm font-medium transition-colors",
                  type === 'expense' ? "bg-red-500/20 text-red-400" : "text-zinc-500 hover:text-zinc-800"
                )}
              >
                Расход
              </button>
              <button
                type="button"
                onClick={() => setType('income')}
                className={cn(
                  "flex-1 py-1.5 rounded-md text-sm font-medium transition-colors",
                  type === 'income' ? "bg-emerald-500/20 text-emerald-400" : "text-zinc-500 hover:text-zinc-800"
                )}
              >
                Доход
              </button>
              <button
                type="button"
                onClick={() => {
                  setType('transfer');
                  setCategory('Перевод');
                }}
                className={cn(
                  "flex-1 py-1.5 rounded-md text-sm font-medium transition-colors",
                  type === 'transfer' ? "bg-blue-500/20 text-blue-400" : "text-zinc-500 hover:text-zinc-800"
                )}
              >
                Перевод
              </button>
            </div>

            {accounts.length > 0 ? (
              <div className={cn("grid gap-4", type === 'transfer' ? "grid-cols-2" : "grid-cols-1")}>
                <div className="space-y-1">
                  <label className="text-[10px] text-zinc-500">{type === 'transfer' ? 'Счет списания' : 'Счет'}</label>
                  <select
                    value={accountId}
                    onChange={(e) => setAccountId(e.target.value)}
                    className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-sm text-zinc-900 focus:outline-none focus:border-zinc-600 appearance-none"
                    required
                  >
                    <option value="" disabled>Выберите счет</option>
                    {accounts.map(acc => (
                      <option key={acc.id} value={acc.id}>{acc.name} ({acc.currency || baseCurrency})</option>
                    ))}
                  </select>
                </div>
                {type === 'transfer' && (
                  <div className="space-y-1">
                    <label className="text-[10px] text-zinc-500">Счет зачисления</label>
                    <select
                      value={toAccountId}
                      onChange={(e) => setToAccountId(e.target.value)}
                      className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-sm text-zinc-900 focus:outline-none focus:border-zinc-600 appearance-none"
                      required
                    >
                      <option value="" disabled>Выберите счет</option>
                      {accounts.map(acc => (
                        <option key={acc.id} value={acc.id} disabled={acc.id === accountId}>{acc.name} ({acc.currency || baseCurrency})</option>
                      ))}
                    </select>
                  </div>
                )}
              </div>
            ) : (
              <div className="flex gap-2 p-1 bg-stone-50 rounded-lg">
                <button
                  type="button"
                  onClick={() => setPaymentMethod('card')}
                  className={cn(
                    "flex-1 py-1.5 rounded-md text-sm font-medium transition-colors flex items-center justify-center gap-2",
                    paymentMethod === 'card' ? "bg-stone-100 text-zinc-900" : "text-zinc-500 hover:text-zinc-800"
                  )}
                >
                  <CreditCard className="w-4 h-4" />
                  {type === 'transfer' ? 'С карты на наличные' : 'Карта'}
                </button>
                <button
                  type="button"
                  onClick={() => setPaymentMethod('cash')}
                  className={cn(
                    "flex-1 py-1.5 rounded-md text-sm font-medium transition-colors flex items-center justify-center gap-2",
                    paymentMethod === 'cash' ? "bg-stone-100 text-zinc-900" : "text-zinc-500 hover:text-zinc-800"
                  )}
                >
                  <Banknote className="w-4 h-4" />
                  {type === 'transfer' ? 'С наличных на карту' : 'Наличные'}
                </button>
              </div>
            )}

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1">
                <label className="text-[10px] text-zinc-500">Сумма ({transactionCurrency})</label>
                <input
                  type="number"
                  required
                  min="0"
                  step="0.01"
                  value={amount}
                  onChange={e => setAmount(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-sm text-zinc-900 focus:outline-none focus:border-zinc-600"
                  placeholder="0"
                />
              </div>
              <div className="space-y-1">
                <label className="text-[10px] text-zinc-500">Дата</label>
                <input
                  type="date"
                  required
                  value={date}
                  onChange={e => setDate(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-sm text-zinc-900 focus:outline-none focus:border-zinc-600"
                />
              </div>
            </div>

            {type === 'expense' && (accounts.length > 0 ? selectedAccount?.type === 'cash' : paymentMethod === 'cash') && (
              <div className="grid grid-cols-2 gap-4 bg-stone-50/50 p-3 rounded-xl border border-stone-200/70">
                <div className="space-y-1">
                  <label className="text-[10px] text-zinc-500">Ваша купюра ({transactionCurrency})</label>
                  <input
                    type="number"
                    min="0"
                    step="0.01"
                    value={cashGiven}
                    onChange={e => setCashGiven(e.target.value)}
                    className="w-full bg-white border border-stone-200 rounded-lg px-3 py-2 text-sm text-zinc-900 focus:outline-none focus:border-zinc-600"
                    placeholder="Например, 100"
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-[10px] text-zinc-500">Сдача</label>
                  <div className="w-full bg-white border border-stone-200 rounded-lg px-3 py-2 text-sm text-emerald-400 font-medium flex items-center h-[38px]">
                    {change > 0 ? `${change.toFixed(2)} ${transactionCurrency}` : `0 ${transactionCurrency}`}
                  </div>
                </div>
                {change > 0 && (
                  <div className="col-span-2 flex items-center gap-2 mt-1">
                    <input
                      type="checkbox"
                      id="confirmChange"
                      checked={isChangeConfirmed}
                      onChange={e => setIsChangeConfirmed(e.target.checked)}
                      className="w-4 h-4 rounded border-stone-300 bg-white text-emerald-500 focus:ring-emerald-500 focus:ring-offset-zinc-950"
                    />
                    <label htmlFor="confirmChange" className="text-xs text-zinc-700 cursor-pointer">
                      Сдача получена
                    </label>
                  </div>
                )}
              </div>
            )}

            <div className="space-y-1">
              <label className="text-[10px] text-zinc-500">Категория</label>
              <input
                type="text"
                required
                value={category}
                onChange={e => setCategory(e.target.value)}
                className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-sm text-zinc-900 focus:outline-none focus:border-zinc-600"
                placeholder={type === 'expense' ? "Продукты, Кафе, Транспорт..." : type === 'income' ? "Зарплата, Подарок..." : "Перевод"}
                disabled={type === 'transfer'}
              />
              {type !== 'transfer' && existingCategories.length > 0 && (
                <div className="flex flex-wrap gap-1.5 pt-1">
                  {existingCategories.map(c => (
                    <button
                      key={c}
                      type="button"
                      onClick={() => setCategory(c)}
                      className="px-2 py-1 bg-stone-100 hover:bg-stone-200 rounded-md text-[10px] text-zinc-700 transition-colors"
                    >
                      {c}
                    </button>
                  ))}
                </div>
              )}
            </div>

            {type === 'income' && (
              <div className="space-y-1">
                <label className="text-[10px] text-zinc-500">Источник дохода</label>
                <input
                  type="text"
                  value={source}
                  onChange={e => setSource(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-sm text-zinc-900 focus:outline-none focus:border-zinc-600"
                  placeholder="Например: Работодатель, Клиент, Проект..."
                />
              </div>
            )}

            <div className="space-y-1">
              <label className="text-[10px] text-zinc-500">Заметки / Комментарий</label>
              <textarea
                value={notes}
                onChange={e => setNotes(e.target.value)}
                className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-sm text-zinc-900 focus:outline-none focus:border-zinc-600 min-h-[60px]"
                placeholder="Дополнительная информация..."
              />
            </div>

            <div className="space-y-1">
              <label className="text-[10px] text-zinc-500">Теги (через запятую)</label>
              <input
                type="text"
                value={tags}
                onChange={e => setTags(e.target.value)}
                className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-sm text-zinc-900 focus:outline-none focus:border-zinc-600"
                placeholder="#продукты, #ресторан"
              />
            </div>

            <div className="space-y-1">
              <label className="text-[10px] text-zinc-500">Чек / Фото</label>
              {photoUrl ? (
                <div className="relative rounded-lg overflow-hidden border border-stone-200 inline-block">
                  <img 
                    src={photoUrl} 
                    alt="Receipt" 
                    onClick={() => setFullscreenImage(photoUrl)}
                    className="h-32 w-auto object-cover cursor-pointer hover:opacity-80 transition-opacity" 
                  />
                  <button
                    type="button"
                    onClick={() => setPhotoUrl(undefined)}
                    className="absolute top-1 right-1 p-1 bg-zinc-900/30 rounded-full text-zinc-900 hover:bg-red-500/80 transition-colors"
                  >
                    <X className="w-4 h-4" />
                  </button>
                  {isParsingReceipt && (
                    <div className="absolute inset-0 bg-zinc-900/40 flex flex-col items-center justify-center text-zinc-900 pointer-events-none">
                      <Loader2 className="w-6 h-6 animate-spin mb-2" />
                      <span className="text-xs font-medium">Считывание...</span>
                    </div>
                  )}
                </div>
              ) : (
                <div className="space-y-3">
                  <div className="flex gap-2">
                    <input 
                      type="file" 
                      accept="image/*" 
                      className="hidden" 
                      ref={fileInputRef}
                      onChange={handlePhotoUpload} 
                    />
                    <input 
                      type="file" 
                      accept="image/*" 
                      capture="environment"
                      className="hidden" 
                      ref={cameraInputRef}
                      onChange={handlePhotoUpload} 
                    />
                    <button
                      type="button"
                      onClick={() => fileInputRef.current?.click()}
                      className="flex-1 flex flex-col items-center justify-center gap-1 h-20 border-2 border-dashed border-stone-200 rounded-lg hover:border-zinc-600 transition-colors text-zinc-500 hover:text-zinc-500"
                    >
                      <ImagePlus className="w-5 h-5" />
                      <span className="text-xs">Галерея</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => cameraInputRef.current?.click()}
                      className="flex-1 flex flex-col items-center justify-center gap-1 h-20 border-2 border-dashed border-stone-200 rounded-lg hover:border-zinc-600 transition-colors text-zinc-500 hover:text-zinc-500"
                    >
                      <Camera className="w-5 h-5" />
                      <span className="text-xs">Сделать фото</span>
                    </button>
                  </div>
                  <div className="space-y-2">
                    <label className="text-[10px] text-zinc-500">Режим считывания данных с чека:</label>
                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                      <label className={cn(
                        "flex items-center gap-2 p-2 rounded-lg border cursor-pointer transition-colors",
                        parseMode === 'ai' ? "bg-blue-500/10 border-blue-500/50 text-blue-400" : "bg-white border-stone-200 text-zinc-500 hover:bg-stone-100"
                      )}>
                        <input type="radio" name="parseMode" value="ai" checked={parseMode === 'ai'} onChange={() => setParseMode('ai')} className="hidden" />
                        <Bot className="w-4 h-4" />
                        <span className="text-xs font-medium">Умный (ИИ)</span>
                      </label>
                      <label className={cn(
                        "flex items-center gap-2 p-2 rounded-lg border cursor-pointer transition-colors",
                        parseMode === 'ocr' ? "bg-emerald-500/10 border-emerald-500/50 text-emerald-400" : "bg-white border-stone-200 text-zinc-500 hover:bg-stone-100"
                      )}>
                        <input type="radio" name="parseMode" value="ocr" checked={parseMode === 'ocr'} onChange={() => setParseMode('ocr')} className="hidden" />
                        <Calculator className="w-4 h-4" />
                        <span className="text-xs font-medium">Простой (OCR)</span>
                      </label>
                      <label className={cn(
                        "flex items-center gap-2 p-2 rounded-lg border cursor-pointer transition-colors",
                        parseMode === 'none' ? "bg-stone-100 border-stone-300 text-zinc-900" : "bg-white border-stone-200 text-zinc-500 hover:bg-stone-100"
                      )}>
                        <input type="radio" name="parseMode" value="none" checked={parseMode === 'none'} onChange={() => setParseMode('none')} className="hidden" />
                        <EyeOff className="w-4 h-4" />
                        <span className="text-xs font-medium">Не считывать</span>
                      </label>
                    </div>
                  </div>
                </div>
              )}
            </div>

            <button type="submit" className="w-full py-2 bg-white text-black rounded-lg text-sm font-medium">
              {editingId ? 'Сохранить изменения' : 'Добавить операцию'}
            </button>
          </motion.form>
        )}
      </AnimatePresence>

      {/* Period Filter */}
      {!isAdding && transactions.length > 0 && (
        <div className="space-y-4">
          <div className="flex flex-wrap gap-2 pb-2">
            {(['all', 'today', 'week', 'month', 'year'] as const).map(period => (
              <button
                key={period}
                onClick={() => setPeriodFilter(period)}
                className={cn(
                  "px-3 py-1.5 rounded-full text-xs font-medium transition-colors",
                  periodFilter === period 
                    ? "bg-white text-black" 
                    : "bg-white text-zinc-500 hover:text-zinc-900 border border-stone-200"
                )}
              >
                {period === 'all' && 'За все время'}
                {period === 'today' && 'Сегодня'}
                {period === 'week' && 'Эта неделя'}
                {period === 'month' && 'Этот месяц'}
                {period === 'year' && 'Этот год'}
              </button>
            ))}
          </div>
          
          <div className="grid grid-cols-2 gap-3">
            <div className="bg-white/60 p-3 rounded-xl border border-stone-200/70 flex flex-col">
              <span className="text-[10px] text-zinc-500 mb-1 uppercase tracking-wider">Расходы за период</span>
              <span className="text-lg font-bold text-zinc-900">
                {filteredTransactions.filter(t => t.type === 'expense').reduce((sum, t) => {
                  const account = accounts.find(a => a.id === t.accountId);
                  const currency = account?.currency || baseCurrency;
                  return sum + convertCurrency(t.amount, currency, baseCurrency);
                }, 0).toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} <span className="text-xs text-zinc-500 font-normal">{baseCurrency}</span>
              </span>
            </div>
            <div className="bg-white/60 p-3 rounded-xl border border-stone-200/70 flex flex-col">
              <span className="text-[10px] text-zinc-500 mb-1 uppercase tracking-wider">Доходы за период</span>
              <span className="text-lg font-bold text-emerald-400">
                +{filteredTransactions.filter(t => t.type === 'income').reduce((sum, t) => {
                  const account = accounts.find(a => a.id === t.accountId);
                  const currency = account?.currency || baseCurrency;
                  return sum + convertCurrency(t.amount, currency, baseCurrency);
                }, 0).toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} <span className="text-xs text-emerald-400/50 font-normal">{baseCurrency}</span>
              </span>
            </div>
          </div>
        </div>
      )}

      {!isAdding && (
        <div className="space-y-3">
          {filteredTransactions.length === 0 ? (
            <div className="text-center py-10 bg-white/30 rounded-2xl border border-dashed border-stone-200">
              <p className="text-zinc-500 text-sm">Нет операций за выбранный период.</p>
            </div>
          ) : (
            filteredTransactions.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime()).map(t => (
              <div key={t.id} className="bg-white p-4 rounded-xl border border-stone-200 flex flex-col gap-3">
                <div className="flex justify-between items-start">
                  <div className="flex items-center gap-3">
                    <div className={cn(
                      "w-10 h-10 rounded-full flex items-center justify-center",
                      t.type === 'income' ? "bg-emerald-500/10 text-emerald-400" : t.type === 'transfer' ? "bg-blue-500/10 text-blue-400" : "bg-red-500/10 text-red-400"
                    )}>
                      {t.type === 'income' ? <ArrowUpRight className="w-5 h-5" /> : t.type === 'transfer' ? <ArrowUpRight className="w-5 h-5 rotate-45" /> : <ArrowDownRight className="w-5 h-5" />}
                    </div>
                    <div>
                      <div className="text-sm font-medium text-zinc-900 flex items-center gap-2">
                        {t.category}
                        {t.source && <span className="text-[10px] text-zinc-500 font-normal">от {t.source}</span>}
                        {accounts.length > 0 ? (
                          t.type === 'transfer' ? (
                            <span className="px-1.5 py-0.5 rounded bg-stone-100 text-zinc-500 text-[10px] flex items-center gap-1">
                              {accounts.find(a => a.id === t.accountId)?.name || 'Счет'} → {accounts.find(a => a.id === t.toAccountId)?.name || 'Счет'}
                            </span>
                          ) : (
                            t.accountId && (
                              <span className="px-1.5 py-0.5 rounded bg-stone-100 text-zinc-500 text-[10px] flex items-center gap-1">
                                <Landmark className="w-3 h-3" /> {accounts.find(a => a.id === t.accountId)?.name || 'Счет'}
                              </span>
                            )
                          )
                        ) : (
                          t.type === 'transfer' ? (
                            <span className="px-1.5 py-0.5 rounded bg-stone-100 text-zinc-500 text-[10px] flex items-center gap-1">
                              {t.paymentMethod === 'card' ? 'С карты на наличные' : 'С наличных на карту'}
                            </span>
                          ) : (
                            <>
                              {t.paymentMethod === 'cash' && (
                                <span className="px-1.5 py-0.5 rounded bg-stone-100 text-zinc-500 text-[10px] flex items-center gap-1">
                                  <Banknote className="w-3 h-3" /> Наличные
                                </span>
                              )}
                              {t.paymentMethod === 'card' && (
                                <span className="px-1.5 py-0.5 rounded bg-stone-100 text-zinc-500 text-[10px] flex items-center gap-1">
                                  <CreditCard className="w-3 h-3" /> Карта
                                </span>
                              )}
                            </>
                          )
                        )}
                      </div>
                      <div className="text-[10px] text-zinc-500">{new Date(t.date).toLocaleDateString('ru-RU')}</div>
                    </div>
                  </div>
                  <div className="flex flex-col items-end gap-1">
                    <div className={cn(
                      "text-sm font-bold",
                      t.type === 'income' ? "text-emerald-400" : t.type === 'transfer' ? "text-blue-400" : "text-zinc-900"
                    )}>
                      {t.type === 'income' ? '+' : t.type === 'transfer' ? '' : '-'}{t.amount.toLocaleString('ru-RU')} {t.type === 'transfer' ? (accounts.find(a => a.id === t.accountId)?.currency || baseCurrency) : (t.accountId ? accounts.find(a => a.id === t.accountId)?.currency || baseCurrency : baseCurrency)}
                    </div>
                    <div className="flex items-center gap-2 mt-1">
                      <button
                        onClick={() => handleEdit(t)}
                        className="text-zinc-600 hover:text-zinc-900 transition-colors text-[10px] font-medium"
                      >
                        Изменить
                      </button>
                      <button
                        onClick={() => deleteTransaction(t.id)}
                        className="text-zinc-600 hover:text-red-400 transition-colors"
                      >
                        <Trash2 className="w-3 h-3" />
                      </button>
                    </div>
                  </div>
                </div>
                
                {(t.notes || t.photoUrl || t.cashGiven || (t.tags && t.tags.length > 0)) && (
                  <div className="pt-3 border-t border-stone-200/70 flex flex-col gap-2">
                    {t.cashGiven && t.cashGiven > t.amount && (
                      <div className="text-[10px] text-zinc-500 bg-stone-50 p-2 rounded-lg border border-stone-200/70">
                        Купюра: <span className="text-zinc-900">{t.cashGiven} {t.type === 'transfer' ? (accounts.find(a => a.id === t.accountId)?.currency || baseCurrency) : (t.accountId ? accounts.find(a => a.id === t.accountId)?.currency || baseCurrency : baseCurrency)}</span> • 
                        Сдача: <span className="text-emerald-400 ml-1">{(t.cashGiven - t.amount).toFixed(2)} {t.type === 'transfer' ? (accounts.find(a => a.id === t.accountId)?.currency || baseCurrency) : (t.accountId ? accounts.find(a => a.id === t.accountId)?.currency || baseCurrency : baseCurrency)}</span>
                      </div>
                    )}
                    {t.notes && <p className="text-xs text-zinc-500">{t.notes}</p>}
                    {t.tags && t.tags.length > 0 && (
                      <div className="flex flex-wrap gap-1">
                        {t.tags.map((tag, idx) => (
                          <span key={idx} className="text-[10px] bg-stone-100 text-zinc-700 px-1.5 py-0.5 rounded-md">
                            {tag}
                          </span>
                        ))}
                      </div>
                    )}
                    {t.photoUrl && (
                      <img 
                        src={t.photoUrl} 
                        alt="Receipt" 
                        onClick={() => setFullscreenImage(t.photoUrl!)}
                        className="rounded-lg border border-stone-200 max-h-48 object-contain self-start bg-stone-50 cursor-pointer hover:opacity-80 transition-opacity" 
                      />
                    )}
                  </div>
                )}
              </div>
            ))
          )}
        </div>
      )}

      {/* Fullscreen Image Modal */}
      <AnimatePresence>
        {fullscreenImage && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-white/90 p-4"
            onClick={() => setFullscreenImage(null)}
          >
            <button
              className="absolute top-4 right-4 p-2 bg-stone-100/60 text-zinc-900 rounded-full hover:bg-stone-200 transition-colors"
              onClick={() => setFullscreenImage(null)}
            >
              <X className="w-6 h-6" />
            </button>
            <motion.img
              initial={{ scale: 0.9 }}
              animate={{ scale: 1 }}
              exit={{ scale: 0.9 }}
              src={fullscreenImage}
              alt="Fullscreen Receipt"
              className="max-w-full max-h-full object-contain rounded-lg"
              onClick={(e) => e.stopPropagation()}
            />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

function LoansTab() {
  const { loans = [], addLoan, deleteLoan, addLoanPayment, deleteLoanPayment, updateLoanPayment, rates = {}, baseCurrency = 'USD' } = useStore();
  const [isAdding, setIsAdding] = useState(false);
  const [selectedLoanId, setSelectedLoanId] = useState<string | null>(null);
  
  const [name, setName] = useState('');
  const [amount, setAmount] = useState('');
  const [currency, setCurrency] = useState<Currency>(baseCurrency);
  const [rate, setRate] = useState('');
  const [termMonths, setTermMonths] = useState('');

  const convertCurrency = useCurrencyConverter();

  const [paymentAmount, setPaymentAmount] = useState('');
  const [paymentDate, setPaymentDate] = useState(new Date().toISOString().split('T')[0]);
  const [paymentType, setPaymentType] = useState<'payment' | 'withdrawal'>('payment');
  const [paymentAccountId, setPaymentAccountId] = useState<string>('');
  const [editingPaymentId, setEditingPaymentId] = useState<string | null>(null);
  const [viewMode, setViewMode] = useState<'operations' | 'schedule'>('operations');
  const [isBalanceVisible, setIsBalanceVisible] = useState(false);

  const resetPaymentForm = () => {
    setPaymentAmount('');
    setPaymentDate(new Date().toISOString().split('T')[0]);
    setPaymentType('payment');
    setPaymentAccountId('');
    setEditingPaymentId(null);
  };

  const handleAdd = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name || !amount || !rate || !termMonths) return;

    const S = parseFloat(amount);
    const r = parseFloat(rate) / 12 / 100; // Monthly interest rate
    const n = parseInt(termMonths, 10);

    // Annuity formula: P = S * (r * (1 + r)^n) / ((1 + r)^n - 1)
    let monthlyPayment = 0;
    if (r === 0) {
      monthlyPayment = S / n;
    } else {
      const pow = Math.pow(1 + r, n);
      monthlyPayment = S * (r * pow) / (pow - 1);
    }

    const totalPayment = monthlyPayment * n;
    const overpayment = totalPayment - S;

    addLoan({
      name,
      amount: S,
      currency,
      rate: parseFloat(rate),
      termMonths: n,
      monthlyPayment,
      totalPayment,
      overpayment
    });

    setIsAdding(false);
    setName('');
    setAmount('');
    setCurrency(baseCurrency);
    setRate('');
    setTermMonths('');
  };

  const selectedLoan = loans.find(l => l.id === selectedLoanId);

  if (selectedLoan) {
    const totalPaid = (selectedLoan.payments || [])
      .filter(p => p.type === 'payment')
      .reduce((sum, p) => sum + p.amount, 0);
    const totalWithdrawn = (selectedLoan.payments || [])
      .filter(p => p.type === 'withdrawal')
      .reduce((sum, p) => sum + p.amount, 0);
    
    const netPaid = totalPaid - totalWithdrawn;
    const remaining = selectedLoan.totalPayment - netPaid;

    const handleAddPayment = (e: React.FormEvent) => {
      e.preventDefault();
      if (!paymentAmount || !paymentDate) return;
      if (useStore.getState().accounts.length > 0 && !paymentAccountId) return;
      
      const amount = parseFloat(paymentAmount);

      if (editingPaymentId) {
        updateLoanPayment(selectedLoan.id, editingPaymentId, {
          amount: amount,
          date: paymentDate,
          type: paymentType
        });
      } else {
        addLoanPayment(selectedLoan.id, {
          amount: amount,
          date: paymentDate,
          type: paymentType
        });

        // Add to transactions for unified analytics
        useStore.getState().addTransaction({
          type: paymentType === 'payment' ? 'expense' : 'income',
          amount: amount,
          category: 'Кредит',
          notes: `${paymentType === 'payment' ? 'Платеж по кредиту' : 'Пополнение кредита'}: ${selectedLoan.name}`,
          date: paymentDate,
          paymentMethod: useStore.getState().accounts.length > 0 ? (useStore.getState().accounts.find(a => a.id === paymentAccountId)?.type === 'cash' ? 'cash' : 'card') : 'card',
          accountId: useStore.getState().accounts.length > 0 ? paymentAccountId : undefined
        });
      }
      resetPaymentForm();
    };

    const handleEditPayment = (payment: any) => {
      setEditingPaymentId(payment.id);
      setPaymentAmount(payment.amount.toString());
      setPaymentDate(payment.date);
      setPaymentType(payment.type);
    };

    const generateSchedule = () => {
      const schedule = [];
      let currentBalance = selectedLoan.amount;
      const r = selectedLoan.rate / 12 / 100;
      const monthlyPayment = selectedLoan.monthlyPayment;
      
      for (let i = 1; i <= selectedLoan.termMonths; i++) {
        const interestPayment = currentBalance * r;
        const principalPayment = monthlyPayment - interestPayment;
        currentBalance -= principalPayment;
        
        schedule.push({
          month: i,
          payment: monthlyPayment,
          principal: principalPayment,
          interest: interestPayment,
          remaining: Math.max(0, currentBalance)
        });
      }
      return schedule;
    };

    return (
      <div className="space-y-6">
        <div className="flex items-center gap-3">
          <button 
            onClick={() => setSelectedLoanId(null)}
            className="p-2 bg-white rounded-lg text-zinc-500 hover:text-zinc-900 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
          <h2 className="text-xl font-semibold text-zinc-900">{selectedLoan.name}</h2>
          <div className="flex-1" />
          <button onClick={() => setIsBalanceVisible(!isBalanceVisible)} className="p-2 bg-white rounded-lg text-zinc-500 hover:text-zinc-900 transition-colors">
            {isBalanceVisible ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
          </button>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div className="bg-white p-4 rounded-2xl border border-stone-200">
            <div className="text-sm text-zinc-500 mb-1">Остаток долга</div>
            <div className="text-2xl font-bold text-zinc-900">
              {isBalanceVisible ? `${remaining.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${selectedLoan.currency || baseCurrency}` : '••••••'}
            </div>
          </div>
          <div className="bg-white p-4 rounded-2xl border border-stone-200">
            <div className="text-sm text-zinc-500 mb-1">Всего выплачено</div>
            <div className="text-2xl font-bold text-emerald-400">
              {isBalanceVisible ? `${netPaid.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${selectedLoan.currency || baseCurrency}` : '••••••'}
            </div>
          </div>
        </div>

        <div className="flex gap-2 p-1 bg-white rounded-lg">
          <button
            onClick={() => setViewMode('operations')}
            className={cn(
              "flex-1 py-2 rounded-md text-sm font-medium transition-colors",
              viewMode === 'operations' ? "bg-stone-100 text-zinc-900" : "text-zinc-500 hover:text-zinc-800"
            )}
          >
            Операции
          </button>
          <button
            onClick={() => setViewMode('schedule')}
            className={cn(
              "flex-1 py-2 rounded-md text-sm font-medium transition-colors",
              viewMode === 'schedule' ? "bg-stone-100 text-zinc-900" : "text-zinc-500 hover:text-zinc-800"
            )}
          >
            График платежей
          </button>
        </div>

        {viewMode === 'operations' ? (
          <>
            <div className="bg-white p-4 rounded-2xl border border-stone-200 space-y-4">
              <h3 className="font-medium text-zinc-900">Добавить операцию</h3>
              <form onSubmit={handleAddPayment} className="space-y-4">
                <div className="flex gap-2 p-1 bg-stone-50 rounded-lg">
                  <button
                    type="button"
                    onClick={() => setPaymentType('payment')}
                    className={cn(
                      "flex-1 py-1.5 rounded-md text-sm font-medium transition-colors",
                      paymentType === 'payment' ? "bg-emerald-500/20 text-emerald-400" : "text-zinc-500 hover:text-zinc-800"
                    )}
                  >
                    Внесение
                  </button>
                  <button
                    type="button"
                    onClick={() => setPaymentType('withdrawal')}
                    className={cn(
                      "flex-1 py-1.5 rounded-md text-sm font-medium transition-colors",
                      paymentType === 'withdrawal' ? "bg-red-500/20 text-red-400" : "text-zinc-500 hover:text-zinc-800"
                    )}
                  >
                    Снятие
                  </button>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-1">
                    <label className="text-xs text-zinc-500">Сумма ({selectedLoan.currency || baseCurrency})</label>
                    <input
                      type="number"
                      required
                      min="0"
                      step="0.01"
                      value={paymentAmount}
                      onChange={e => setPaymentAmount(e.target.value)}
                      className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 focus:outline-none focus:border-zinc-600"
                      placeholder="0"
                    />
                  </div>
                  <div className="space-y-1">
                    <label className="text-xs text-zinc-500">Дата</label>
                    <input
                      type="date"
                      required
                      value={paymentDate}
                      onChange={e => setPaymentDate(e.target.value)}
                      className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 focus:outline-none focus:border-zinc-600"
                    />
                  </div>
                </div>
                {useStore.getState().accounts.length > 0 && (
                  <div className="space-y-1">
                    <label className="text-xs text-zinc-500">Счет списания/зачисления</label>
                    <select
                      value={paymentAccountId}
                      onChange={e => setPaymentAccountId(e.target.value)}
                      required
                      className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 focus:outline-none focus:border-zinc-600"
                    >
                      <option value="" disabled>Выберите счет</option>
                      {useStore.getState().accounts.map(acc => (
                        <option key={acc.id} value={acc.id}>{acc.name} ({acc.currency})</option>
                      ))}
                    </select>
                  </div>
                )}
                <div className="flex gap-2">
                  <button type="submit" className="flex-1 py-2 bg-white text-black rounded-lg font-medium">
                    {editingPaymentId ? 'Сохранить изменения' : 'Добавить'}
                  </button>
                  {editingPaymentId && (
                    <button 
                      type="button" 
                      onClick={resetPaymentForm}
                      className="px-4 py-2 bg-stone-100 text-zinc-900 rounded-lg font-medium hover:bg-stone-200 transition-colors"
                    >
                      Отмена
                    </button>
                  )}
                </div>
              </form>
            </div>

            <div className="space-y-3">
              <h3 className="font-medium text-zinc-900">История операций</h3>
              {(!selectedLoan.payments || selectedLoan.payments.length === 0) ? (
                <p className="text-zinc-500 text-sm">Пока нет операций</p>
              ) : (
                selectedLoan.payments.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime()).map(p => (
                  <div key={p.id} className="bg-white p-3 rounded-xl border border-stone-200 flex justify-between items-center">
                    <div className="flex items-center gap-3">
                      <div className={cn(
                        "w-8 h-8 rounded-full flex items-center justify-center",
                        p.type === 'payment' ? "bg-emerald-500/10 text-emerald-400" : "bg-red-500/10 text-red-400"
                      )}>
                        {p.type === 'payment' ? <ArrowUpRight className="w-4 h-4" /> : <ArrowDownRight className="w-4 h-4" />}
                      </div>
                      <div>
                        <div className="text-sm font-medium text-zinc-900">
                          {p.type === 'payment' ? 'Внесение' : 'Снятие'}
                        </div>
                        <div className="text-xs text-zinc-500">{new Date(p.date).toLocaleDateString('ru-RU')}</div>
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      <div className={cn(
                        "font-bold text-sm",
                        p.type === 'payment' ? "text-emerald-400" : "text-red-400"
                      )}>
                        {p.type === 'payment' ? '+' : '-'}{p.amount.toLocaleString('ru-RU')} {selectedLoan.currency || baseCurrency}
                      </div>
                      <div className="flex items-center gap-1">
                        <button
                          onClick={() => handleEditPayment(p)}
                          className="text-zinc-600 hover:text-zinc-900 transition-colors p-1"
                        >
                          <span className="text-xs font-medium">Изменить</span>
                        </button>
                        <button
                          onClick={() => deleteLoanPayment(selectedLoan.id, p.id)}
                          className="text-zinc-600 hover:text-red-400 transition-colors p-1"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  </div>
                ))
              )}
            </div>
          </>
        ) : (
          <div className="bg-white rounded-2xl border border-stone-200 overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm text-left">
                <thead className="text-xs text-zinc-500 bg-stone-50/50 border-b border-stone-200">
                  <tr>
                    <th className="px-4 py-3 font-medium">Месяц</th>
                    <th className="px-4 py-3 font-medium">Платеж</th>
                    <th className="px-4 py-3 font-medium">Основной долг</th>
                    <th className="px-4 py-3 font-medium">Проценты</th>
                    <th className="px-4 py-3 font-medium">Остаток</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-stone-200/50">
                  {generateSchedule().map((row) => (
                    <tr key={row.month} className="hover:bg-stone-100/40 transition-colors">
                      <td className="px-4 py-3 text-zinc-700">{row.month}</td>
                      <td className="px-4 py-3 font-medium text-zinc-900">{row.payment.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td>
                      <td className="px-4 py-3 text-emerald-400/80">{row.principal.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td>
                      <td className="px-4 py-3 text-red-400/80">{row.interest.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td>
                      <td className="px-4 py-3 font-medium text-zinc-900">{row.remaining.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-xl font-semibold text-zinc-900">Кредиты и рассрочки</h2>
        <div className="flex gap-2">
          <button onClick={() => setIsBalanceVisible(!isBalanceVisible)} className="p-2 bg-stone-100 text-zinc-700 rounded-lg hover:bg-stone-200 transition-colors">
            {isBalanceVisible ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
          </button>
          <button
            onClick={() => setIsAdding(!isAdding)}
            className="p-2 bg-stone-100 text-zinc-900 rounded-lg hover:bg-stone-200 transition-colors"
          >
            {isAdding ? <X className="w-5 h-5" /> : <Plus className="w-5 h-5" />}
          </button>
        </div>
      </div>

      <AnimatePresence>
        {isAdding && (
          <motion.form
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            onSubmit={handleAdd}
            className="bg-white p-4 rounded-2xl border border-stone-200 space-y-4 overflow-hidden"
          >
            <div className="space-y-1">
              <label className="text-xs text-zinc-500">Название (цель)</label>
              <input
                type="text"
                required
                value={name}
                onChange={e => setName(e.target.value)}
                className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 focus:outline-none focus:border-zinc-600"
                placeholder="Например, Автокредит"
              />
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
              <div className="space-y-1 sm:col-span-2">
                <label className="text-xs text-zinc-500">Сумма</label>
                <div className="flex gap-2">
                  <input
                    type="number"
                    required
                    min="0"
                    step="0.01"
                    value={amount}
                    onChange={e => setAmount(e.target.value)}
                    className="flex-1 bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 focus:outline-none focus:border-zinc-600"
                    placeholder="10000"
                  />
                  <select
                    value={currency}
                    onChange={e => setCurrency(e.target.value as Currency)}
                    className="w-24 bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 focus:outline-none focus:border-zinc-600"
                  >
                    <option value={baseCurrency}>{baseCurrency}</option>
                    <option value="USD">USD</option>
                    <option value="EUR">EUR</option>
                    <option value="RUB">RUB</option>
                    <option value="PLN">PLN</option>
                    <option value="USDT">USDT</option>
                  </select>
                </div>
              </div>
              <div className="space-y-1">
                <label className="text-xs text-zinc-500">Ставка (% годовых)</label>
                <input
                  type="number"
                  required
                  min="0"
                  step="0.01"
                  value={rate}
                  onChange={e => setRate(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 focus:outline-none focus:border-zinc-600"
                  placeholder="14.5"
                />
              </div>
              <div className="space-y-1">
                <label className="text-xs text-zinc-500">Срок (месяцев)</label>
                <input
                  type="number"
                  required
                  min="1"
                  step="1"
                  value={termMonths}
                  onChange={e => setTermMonths(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 focus:outline-none focus:border-zinc-600"
                  placeholder="36"
                />
              </div>
            </div>

            {/* Live Preview */}
            {amount && rate && termMonths && (
              <div className="bg-stone-50 p-4 rounded-xl border border-stone-200 space-y-2">
                <div className="text-sm font-medium text-zinc-900 mb-2">Предварительный расчет (аннуитет):</div>
                <div className="flex justify-between text-sm">
                  <span className="text-zinc-500">Ежемесячный платеж:</span>
                  <span className="text-zinc-900 font-bold">
                    {(() => {
                      const S = parseFloat(amount);
                      const r = parseFloat(rate) / 12 / 100;
                      const n = parseInt(termMonths, 10);
                      if (!S || !n) return '0';
                      if (r === 0) return (S / n).toFixed(2);
                      const pow = Math.pow(1 + r, n);
                      return (S * (r * pow) / (pow - 1)).toFixed(2);
                    })()} {currency}
                  </span>
                </div>
              </div>
            )}

            <button type="submit" className="w-full py-2 bg-white text-black rounded-lg font-medium">
              Сохранить кредит
            </button>
          </motion.form>
        )}
      </AnimatePresence>

      <div className="space-y-4">
        {loans.length === 0 ? (
          <div className="text-center py-10 bg-white/30 rounded-2xl border border-dashed border-stone-200">
            <p className="text-zinc-500 text-sm">Нет сохраненных кредитов</p>
          </div>
        ) : (
          loans.map(loan => {
            const totalPaid = (loan.payments || [])
              .filter(p => p.type === 'payment')
              .reduce((sum, p) => sum + p.amount, 0);
            const totalWithdrawn = (loan.payments || [])
              .filter(p => p.type === 'withdrawal')
              .reduce((sum, p) => sum + p.amount, 0);
            const netPaid = totalPaid - totalWithdrawn;
            const remaining = loan.totalPayment - netPaid;
            const progress = Math.min(100, Math.max(0, (netPaid / loan.totalPayment) * 100));

            return (
              <div 
                key={loan.id} 
                className="bg-white p-5 rounded-2xl border border-stone-200 space-y-4 cursor-pointer hover:border-stone-300 transition-colors"
                onClick={() => setSelectedLoanId(loan.id)}
              >
                <div className="flex justify-between items-start">
                  <div>
                    <h3 className="text-lg font-bold text-zinc-900">{loan.name}</h3>
                    <p className="text-sm text-zinc-500">
                      {loan.amount.toLocaleString('ru-RU')} {loan.currency || baseCurrency} • {loan.rate}% годовых • {loan.termMonths} мес.
                    </p>
                  </div>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      deleteLoan(loan.id);
                    }}
                    className="text-zinc-600 hover:text-red-400 transition-colors p-1"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>

                <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                  <div className="bg-stone-50 p-3 rounded-xl border border-stone-200/70">
                    <div className="text-xs text-zinc-500 mb-1">Остаток долга</div>
                    <div className="text-lg font-bold text-zinc-900">
                      {isBalanceVisible ? `${remaining.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${loan.currency || baseCurrency}` : '••••••'}
                    </div>
                  </div>
                  <div className="bg-stone-50 p-3 rounded-xl border border-stone-200/70">
                    <div className="text-xs text-zinc-500 mb-1">Выплачено</div>
                    <div className="text-lg font-bold text-emerald-400">
                      {isBalanceVisible ? `${netPaid.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${loan.currency || baseCurrency}` : '••••••'}
                    </div>
                  </div>
                  <div className="bg-stone-50 p-3 rounded-xl border border-stone-200/70 sm:col-span-1 col-span-2">
                    <div className="text-xs text-zinc-500 mb-1">Общая сумма к возврату</div>
                    <div className="text-lg font-bold text-zinc-900">
                      {isBalanceVisible ? `${loan.totalPayment.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${loan.currency || baseCurrency}` : '••••••'}
                    </div>
                  </div>
                </div>

                <div className="space-y-1">
                  <div className="flex justify-between text-xs">
                    <span className="text-zinc-500">Прогресс выплаты</span>
                    <span className="text-zinc-500">{progress.toFixed(1)}%</span>
                  </div>
                  <div className="h-1.5 bg-stone-50 rounded-full overflow-hidden">
                    <div 
                      className="h-full bg-emerald-500 rounded-full transition-all duration-500"
                      style={{ width: `${progress}%` }}
                    />
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}

const COLORS = ['#10b981', '#3b82f6', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899', '#14b8a6', '#f97316'];

function FinanceAnalyticsTab() {
  const { transactions = [], accounts = [], rates = {}, baseCurrency = 'USD', budgetLimits = [] } = useStore();
  const [period, setPeriod] = useState<'week' | 'month' | 'year' | 'all'>('month');

  const convertCurrency = useCurrencyConverter();

  const now = new Date();
  let startDate: Date;
  let prevStartDate: Date;
  let prevEndDate: Date;

  switch (period) {
    case 'week':
      startDate = startOfWeek(now, { weekStartsOn: 1 });
      prevStartDate = subWeeks(startDate, 1);
      prevEndDate = startDate;
      break;
    case 'month':
      startDate = startOfMonth(now);
      prevStartDate = subMonths(startDate, 1);
      prevEndDate = startDate;
      break;
    case 'year':
      startDate = startOfYear(now);
      prevStartDate = subYears(startDate, 1);
      prevEndDate = startDate;
      break;
    default:
      startDate = new Date(0);
      prevStartDate = new Date(0);
      prevEndDate = new Date(0);
  }

  const currentTransactions = transactions.filter(t => period === 'all' || isAfter(parseISO(t.date), startDate) || parseISO(t.date).getTime() === startDate.getTime());
  const prevTransactions = transactions.filter(t => period !== 'all' && isAfter(parseISO(t.date), prevStartDate) && isBefore(parseISO(t.date), prevEndDate));

  const currentExpense = currentTransactions.filter(t => t.type === 'expense').reduce((sum, t) => {
    const account = useStore.getState().accounts.find(a => a.id === t.accountId);
    const currency = account?.currency || baseCurrency;
    return sum + convertCurrency(t.amount, currency, baseCurrency);
  }, 0);
  const prevExpense = prevTransactions.filter(t => t.type === 'expense').reduce((sum, t) => {
    const account = useStore.getState().accounts.find(a => a.id === t.accountId);
    const currency = account?.currency || baseCurrency;
    return sum + convertCurrency(t.amount, currency, baseCurrency);
  }, 0);
  const currentIncome = currentTransactions.filter(t => t.type === 'income').reduce((sum, t) => {
    const account = useStore.getState().accounts.find(a => a.id === t.accountId);
    const currency = account?.currency || baseCurrency;
    return sum + convertCurrency(t.amount, currency, baseCurrency);
  }, 0);

  const expenseDiff = currentExpense - prevExpense;
  const expenseDiffPercent = prevExpense === 0 ? (currentExpense > 0 ? 100 : 0) : (expenseDiff / prevExpense) * 100;

  // Category Data for Pie Chart
  const expensesByCategory = currentTransactions
    .filter(t => t.type === 'expense')
    .reduce((acc, t) => {
      const account = useStore.getState().accounts.find(a => a.id === t.accountId);
      const currency = account?.currency || baseCurrency;
      acc[t.category] = (acc[t.category] || 0) + convertCurrency(t.amount, currency, baseCurrency);
      return acc;
    }, {} as Record<string, number>);

  const pieData = Object.entries(expensesByCategory)
    .map(([name, value]) => ({ name, value }))
    .sort((a, b) => b.value - a.value);

  const budgetChartData = useMemo(() => {
    if (period !== 'month') return [];
    
    return budgetLimits.map(limit => {
      const actual = expensesByCategory[limit.category] || 0;
      return {
        category: limit.category,
        actual,
        planned: limit.amount
      };
    });
  }, [budgetLimits, expensesByCategory, period]);

  // Tags Breakdown Data
  const expensesByTag = currentTransactions
    .filter(t => t.type === 'expense' && t.tags && t.tags.length > 0)
    .reduce((acc, t) => {
      const account = useStore.getState().accounts.find(a => a.id === t.accountId);
      const currency = account?.currency || baseCurrency;
      t.tags!.forEach(tag => {
        acc[tag] = (acc[tag] || 0) + convertCurrency(t.amount, currency, baseCurrency);
      });
      return acc;
    }, {} as Record<string, number>);

  const tagData = Object.entries(expensesByTag)
    .map(([name, value]) => ({ name, value }))
    .sort((a, b) => b.value - a.value);

  // Monthly/Daily Data for Bar Chart
  const sortedCurrentTransactions = [...currentTransactions].sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
  const sortedBarDataMap = sortedCurrentTransactions.reduce((acc, t) => {
    const dateStr = period === 'year' || period === 'all' 
      ? format(parseISO(t.date), 'MMM yyyy', { locale: ru })
      : format(parseISO(t.date), 'dd MMM', { locale: ru });
      
    if (!acc[dateStr]) {
      acc[dateStr] = { name: dateStr, income: 0, expense: 0 };
    }
    const account = useStore.getState().accounts.find(a => a.id === t.accountId);
    const currency = account?.currency || 'BYN';
    const amountInBase = convertCurrency(t.amount, currency, baseCurrency);
    if (t.type === 'income') acc[dateStr].income += amountInBase;
    else acc[dateStr].expense += amountInBase;
    return acc;
  }, {} as Record<string, { name: string, income: number, expense: number }>);
  const finalBarData = Object.values(sortedBarDataMap);

  // Forecast Logic (only relevant for current month)
  const daysInMonth = getDaysInMonth(now);
  const currentDay = getDate(now);
  const remainingDays = daysInMonth - currentDay;

  const threeMonthsAgo = subMonths(startOfMonth(now), 3);
  const startOfCurrent = startOfMonth(now);
  
  const past3MonthsTransactions = transactions.filter(t => 
    isAfter(parseISO(t.date), threeMonthsAgo) && 
    isBefore(parseISO(t.date), startOfCurrent)
  );

  const past3MonthsExpense = past3MonthsTransactions
    .filter(t => t.type === 'expense')
    .reduce((sum, t) => {
      const account = useStore.getState().accounts.find(a => a.id === t.accountId);
      const currency = account?.currency || baseCurrency;
      return sum + convertCurrency(t.amount, currency, baseCurrency);
    }, 0);

  const hasPastData = past3MonthsTransactions.length > 0;
  
  // Average daily expense based on past 3 months (approx 90 days)
  const avgDailyExpenseHistorical = hasPastData ? (past3MonthsExpense / 90) : (currentDay > 0 ? currentExpense / currentDay : 0);
  
  const projectedRemainingExpense = avgDailyExpenseHistorical * remainingDays;
  const projectedTotalExpense = currentExpense + projectedRemainingExpense;
  const projectedBalance = currentIncome - projectedTotalExpense;

  // Debt-to-Income Ratio Calculation
  const { loans = [] } = useStore();
  const monthlyDebtPayments = loans.reduce((sum, loan) => {
    const r = loan.rate / 12 / 100;
    const n = loan.termMonths;
    const S = loan.amount;
    let monthly = 0;
    if (r === 0) monthly = S / n;
    else {
      const pow = Math.pow(1 + r, n);
      monthly = S * (r * pow) / (pow - 1);
    }
    return sum + convertCurrency(monthly, loan.currency || baseCurrency, baseCurrency);
  }, 0);

  const dtiRatio = currentIncome > 0 ? (monthlyDebtPayments / currentIncome) * 100 : 0;

  // Lifestyle Creep Analysis (Income vs Expense over time)
  const lifestyleCreepData = useMemo(() => {
    const months = eachMonthOfInterval({
      start: subMonths(new Date(), 5),
      end: new Date()
    });

    return months.map(month => {
      const monthStr = format(month, 'MMM', { locale: ru });
      const monthStart = startOfMonth(month);
      const monthEnd = endOfMonth(month);

      const mIncome = transactions
        .filter(t => t.type === 'income' && isWithinInterval(parseISO(t.date), { start: monthStart, end: monthEnd }))
        .reduce((sum, t) => {
          const account = useStore.getState().accounts.find(a => a.id === t.accountId);
          const currency = account?.currency || baseCurrency;
          return sum + convertCurrency(t.amount, currency, baseCurrency);
        }, 0);
      
      const mExpense = transactions
        .filter(t => t.type === 'expense' && isWithinInterval(parseISO(t.date), { start: monthStart, end: monthEnd }))
        .reduce((sum, t) => {
          const account = useStore.getState().accounts.find(a => a.id === t.accountId);
          const currency = account?.currency || baseCurrency;
          return sum + convertCurrency(t.amount, currency, baseCurrency);
        }, 0);

      return {
        month: monthStr,
        income: mIncome,
        expense: mExpense,
        ratio: mIncome > 0 ? (mExpense / mIncome) * 100 : 0
      };
    });
  }, [transactions]);

  // Financial Health Score
  const healthScore = useMemo(() => {
    let score = 0;
    
    // 1. Savings Rate (up to 30 points)
    const savingsRate = currentIncome > 0 ? ((currentIncome - currentExpense) / currentIncome) * 100 : 0;
    score += Math.min(Math.max(0, (savingsRate / 20) * 30), 30);

    // 2. DTI Ratio (up to 30 points)
    const dtiScore = Math.max(0, 30 - (dtiRatio / 40) * 30);
    score += dtiScore;

    // 3. Emergency Fund (up to 20 points)
    const totalSavings = useStore.getState().savingsGoals.reduce((sum, g) => sum + convertCurrency(g.currentAmount, g.currency || baseCurrency, baseCurrency), 0);
    const avgExpense = currentExpense || 1;
    const monthsCovered = totalSavings / avgExpense;
    score += Math.min((monthsCovered / 3) * 20, 20);

    // 4. Budget Discipline (up to 20 points)
    const budgetLimits = useStore.getState().budgetLimits;
    if (budgetLimits.length > 0) {
      const adherence = budgetLimits.reduce((sum, limit) => {
        const spent = transactions
          .filter(t => t.category === limit.category && t.type === 'expense' && isSameMonth(parseISO(t.date), new Date()))
          .reduce((s, t) => {
            const account = useStore.getState().accounts.find(a => a.id === t.accountId);
            const currency = account?.currency || baseCurrency;
            return s + convertCurrency(t.amount, currency, baseCurrency);
          }, 0);
        const limitInBase = convertCurrency(limit.amount, limit.currency || baseCurrency, baseCurrency);
        return sum + (spent <= limitInBase ? 1 : 0);
      }, 0) / budgetLimits.length;
      score += adherence * 20;
    } else {
      score += 10; // Neutral if no limits set
    }

    return Math.round(score);
  }, [currentIncome, currentExpense, dtiRatio, transactions]);

  return (
    <div className="space-y-6">
      {/* Financial Health Score Card */}
      <div className="bg-gradient-to-br from-white to-zinc-950 border border-stone-200 rounded-3xl p-6 relative overflow-hidden">
        <div className="absolute top-0 right-0 w-32 h-32 bg-emerald-500/5 blur-3xl rounded-full -mr-16 -mt-16" />
        <div className="relative flex items-center justify-between">
          <div className="space-y-1">
            <h3 className="text-sm font-medium text-zinc-500 uppercase tracking-wider">Финансовое здоровье</h3>
            <div className="flex items-baseline gap-2">
              <span className="text-4xl font-black text-zinc-900">{healthScore}</span>
              <span className="text-zinc-500 font-medium">/ 100</span>
            </div>
          </div>
          <div className="w-16 h-16 rounded-full border-4 border-stone-200 flex items-center justify-center relative">
            <svg className="w-full h-full -rotate-90">
              <circle
                cx="32"
                cy="32"
                r="28"
                fill="none"
                stroke="currentColor"
                strokeWidth="4"
                className="text-zinc-800"
              />
              <circle
                cx="32"
                cy="32"
                r="28"
                fill="none"
                stroke="currentColor"
                strokeWidth="4"
                strokeDasharray={2 * Math.PI * 28}
                strokeDashoffset={2 * Math.PI * 28 * (1 - healthScore / 100)}
                className={cn(
                  "transition-all duration-1000",
                  healthScore > 70 ? "text-emerald-500" : healthScore > 40 ? "text-yellow-500" : "text-red-500"
                )}
              />
            </svg>
            <Activity className={cn(
              "absolute w-6 h-6",
              healthScore > 70 ? "text-emerald-500" : healthScore > 40 ? "text-yellow-500" : "text-red-500"
            )} />
          </div>
        </div>
        <div className="mt-4 flex flex-wrap gap-2 pb-2">
          <div className="px-3 py-1.5 bg-stone-100/60 rounded-full text-[10px] text-zinc-500 whitespace-nowrap">
            {healthScore > 70 ? "Отличное состояние" : healthScore > 40 ? "Требует внимания" : "Критическое состояние"}
          </div>
          <div className="px-3 py-1.5 bg-stone-100/60 rounded-full text-[10px] text-zinc-500 whitespace-nowrap">
            Долги: {Math.round(dtiRatio)}%
          </div>
          <div className="px-3 py-1.5 bg-stone-100/60 rounded-full text-[10px] text-zinc-500 whitespace-nowrap">
            Сбережения: {currentIncome > 0 ? Math.round(((currentIncome - currentExpense) / currentIncome) * 100) : 0}%
          </div>
        </div>
      </div>

      {/* Period Selector */}
      <div className="flex flex-wrap gap-2 p-1 bg-white rounded-lg">
        {['week', 'month', 'year', 'all'].map((p) => (
          <button
            key={p}
            onClick={() => setPeriod(p as any)}
            className={cn(
              "flex-1 py-1.5 px-3 rounded-md text-xs font-medium transition-colors",
              period === p ? "bg-stone-100 text-zinc-900" : "text-zinc-500 hover:text-zinc-800"
            )}
          >
            {p === 'week' ? 'Неделя' : p === 'month' ? 'Месяц' : p === 'year' ? 'Год' : 'Всё время'}
          </button>
        ))}
      </div>

      {/* Summary */}
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-white p-4 rounded-2xl border border-stone-200">
          <div className="text-xs text-zinc-500 mb-1">Расходы за период</div>
          <div className="text-xl font-bold text-zinc-900">{currentExpense.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} {baseCurrency}</div>
          {period !== 'all' && (
            <div className={cn("text-xs mt-1", expenseDiff > 0 ? "text-red-400" : "text-emerald-400")}>
              {expenseDiff > 0 ? '+' : ''}{expenseDiffPercent.toFixed(1)}% к прошлому периоду
            </div>
          )}
        </div>
        <div className="bg-white p-4 rounded-2xl border border-stone-200">
          <div className="text-xs text-zinc-500 mb-1">Доходы за период</div>
          <div className="text-xl font-bold text-emerald-400">{currentIncome.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} {baseCurrency}</div>
        </div>
      </div>

      {/* Line Chart */}
      <div className="bg-white p-4 rounded-2xl border border-stone-200">
        <h3 className="text-sm font-medium text-zinc-900 mb-4">Динамика</h3>
        <div className="h-64">
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={finalBarData} margin={{ top: 0, right: 0, left: -20, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
              <XAxis dataKey="name" stroke="#a1a1aa" fontSize={10} tickLine={false} axisLine={false} />
              <YAxis stroke="#a1a1aa" fontSize={10} tickLine={false} axisLine={false} tickFormatter={(value) => `${value}`} />
              <Tooltip 
                contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', borderRadius: '8px', fontSize: '12px' }}
                itemStyle={{ color: '#e4e4e7' }}
                cursor={{ stroke: '#27272a', strokeWidth: 1, strokeDasharray: '3 3' }}
              />
              <Legend wrapperStyle={{ fontSize: '12px' }} />
              <Line type="monotone" dataKey="income" name="Доход" stroke="#10b981" strokeWidth={3} dot={{ r: 3, fill: '#10b981' }} activeDot={{ r: 5 }} />
              <Line type="monotone" dataKey="expense" name="Расход" stroke="#ef4444" strokeWidth={3} dot={{ r: 3, fill: '#ef4444' }} activeDot={{ r: 5 }} />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Lifestyle Creep Analysis */}
      <div className="bg-white p-4 rounded-2xl border border-stone-200">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-sm font-medium text-zinc-900">Инфляция образа жизни</h3>
          <div className="p-1.5 bg-purple-500/10 rounded-lg">
            <TrendingUp className="w-4 h-4 text-purple-400" />
          </div>
        </div>
        <div className="h-64">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={lifestyleCreepData}>
              <defs>
                <linearGradient id="colorInc" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#10b981" stopOpacity={0.3}/>
                  <stop offset="95%" stopColor="#10b981" stopOpacity={0}/>
                </linearGradient>
                <linearGradient id="colorExp" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#ef4444" stopOpacity={0.3}/>
                  <stop offset="95%" stopColor="#ef4444" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
              <XAxis dataKey="month" stroke="#a1a1aa" fontSize={10} tickLine={false} axisLine={false} />
              <YAxis stroke="#a1a1aa" fontSize={10} tickLine={false} axisLine={false} />
              <Tooltip 
                contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', borderRadius: '8px', fontSize: '12px' }}
                itemStyle={{ color: '#e4e4e7' }}
              />
              <Area type="monotone" dataKey="income" name="Доход" stroke="#10b981" fillOpacity={1} fill="url(#colorInc)" />
              <Area type="monotone" dataKey="expense" name="Расход" stroke="#ef4444" fillOpacity={1} fill="url(#colorExp)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>
        <p className="text-[10px] text-zinc-500 mt-4 leading-relaxed">
          Если линия расходов растет быстрее линии доходов — это признак "инфляции образа жизни". 
          Старайтесь сохранять дельту между ними для формирования капитала.
        </p>
      </div>

      {/* Financial Literacy Insights */}
      <div className="bg-white p-4 rounded-2xl border border-stone-200 space-y-4">
        <h3 className="text-sm font-medium text-zinc-900 flex items-center gap-2">
          <Calculator className="w-4 h-4 text-blue-400" />
          Финансовый анализ
        </h3>
        
        <div className="space-y-3">
          {/* Forecast (Only show on 'month' view) */}
          {period === 'month' && (
            <div className="bg-stone-50 p-3 rounded-xl border border-stone-200/70">
              <div className="flex justify-between items-start mb-2">
                <span className="text-xs text-zinc-500">Прогноз на конец месяца</span>
                <span className={cn(
                  "text-sm font-bold",
                  projectedBalance > 0 ? "text-emerald-400" : "text-red-400"
                )}>
                  {projectedBalance > 0 ? '+' : ''}{projectedBalance.toLocaleString('ru-RU', { maximumFractionDigits: 0 })} {baseCurrency}
                </span>
              </div>
              <p className="text-[10px] text-zinc-500 leading-relaxed">
                Основано на ваших средних тратах ({Math.round(avgDailyExpenseHistorical)} {baseCurrency}/день). 
                Ожидаемые расходы до конца месяца: {Math.round(projectedRemainingExpense).toLocaleString('ru-RU')} {baseCurrency}.
                {projectedBalance < 0 && " Постарайтесь сократить ежедневные траты, чтобы не уйти в минус."}
              </p>
            </div>
          )}

          {/* Debt-to-Income Ratio */}
          <div className="bg-stone-50 p-3 rounded-xl border border-stone-200/70">
            <div className="flex justify-between items-start mb-2">
              <span className="text-xs text-zinc-500">Коэффициент долговой нагрузки (DTI)</span>
              <span className={cn(
                "text-sm font-bold",
                dtiRatio <= 30 ? "text-emerald-400" : 
                dtiRatio <= 40 ? "text-yellow-400" : "text-red-400"
              )}>
                {Math.round(dtiRatio)}%
              </span>
            </div>
            <p className="text-[10px] text-zinc-500 leading-relaxed">
              {currentIncome === 0 ? "Добавьте доходы для расчета DTI." :
               dtiRatio === 0 ? "У вас нет активных кредитов. Это отлично для финансовой устойчивости!" :
               dtiRatio <= 30 ? "Ваша долговая нагрузка в норме (до 30%). Банки считают вас надежным заемщиком." :
               dtiRatio <= 40 ? "Ваша нагрузка на грани (30-40%). Будьте осторожны с новыми кредитами." :
               "Критический уровень нагрузки (более 40%). Большая часть дохода уходит на долги. Рекомендуется рефинансирование или досрочное погашение."}
            </p>
          </div>

          {/* Savings Rate */}
          <div className="bg-stone-50 p-3 rounded-xl border border-stone-200/70">
            <div className="flex justify-between items-start mb-2">
              <span className="text-xs text-zinc-500">Уровень сбережений</span>
              <span className={cn(
                "text-sm font-bold",
                currentIncome > 0 && ((currentIncome - currentExpense) / currentIncome) >= 0.2 ? "text-emerald-400" : 
                currentIncome > 0 && ((currentIncome - currentExpense) / currentIncome) > 0 ? "text-yellow-400" : "text-red-400"
              )}>
                {currentIncome > 0 ? Math.round(((currentIncome - currentExpense) / currentIncome) * 100) : 0}%
              </span>
            </div>
            <p className="text-[10px] text-zinc-500 leading-relaxed">
              {currentIncome === 0 ? "Добавьте доходы для расчета уровня сбережений." :
               ((currentIncome - currentExpense) / currentIncome) >= 0.2 ? "Отличный результат! Вы откладываете 20% или более от своих доходов. Это золотой стандарт финансовой грамотности." :
               ((currentIncome - currentExpense) / currentIncome) > 0 ? "Вы тратите меньше, чем зарабатываете, но старайтесь довести уровень сбережений до 10-20% для создания подушки безопасности." :
               "Внимание: ваши расходы превышают доходы. Проанализируйте структуру расходов, чтобы избежать накопления долгов."}
            </p>
          </div>

          {/* Top Expense Category */}
          {pieData.length > 0 && (
            <div className="bg-stone-50 p-3 rounded-xl border border-stone-200/70">
              <div className="flex justify-between items-start mb-2">
                <span className="text-xs text-zinc-500">Главная статья расходов</span>
                <span className="text-sm font-bold text-zinc-900">{pieData[0].name}</span>
              </div>
              <p className="text-[10px] text-zinc-500 leading-relaxed">
                На эту категорию уходит <strong>{Math.round((pieData[0].value / currentExpense) * 100)}%</strong> всех ваших трат ({pieData[0].value.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} {baseCurrency}). 
                {Math.round((pieData[0].value / currentExpense) * 100) > 30 && " Если это не базовые потребности (жилье, еда), подумайте об оптимизации этой категории."}
              </p>
            </div>
          )}
        </div>
      </div>

      {/* Pie Chart */}
      <div className="bg-white p-4 rounded-2xl border border-stone-200">
        <h3 className="text-sm font-medium text-zinc-900 mb-4">Структура расходов</h3>
        {pieData.length === 0 ? (
          <p className="text-zinc-500 text-xs text-center py-10">Нет данных для отображения</p>
        ) : (
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={pieData}
                  cx="50%"
                  cy="50%"
                  innerRadius={60}
                  outerRadius={80}
                  paddingAngle={5}
                  dataKey="value"
                >
                  {pieData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip 
                  contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', borderRadius: '8px', fontSize: '12px' }}
                  itemStyle={{ color: '#e4e4e7' }}
                  formatter={(value: number) => [`${value.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${baseCurrency}`, 'Сумма']}
                />
                <Legend wrapperStyle={{ fontSize: '12px' }} />
              </PieChart>
            </ResponsiveContainer>
          </div>
        )}
      </div>

      {period === 'month' && budgetChartData.length > 0 && (
        <div className="bg-white/80 border border-stone-200 p-6 rounded-3xl">
          <h3 className="text-sm font-bold text-zinc-900 mb-6">Бюджет по категориям</h3>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={budgetChartData} layout="vertical" margin={{ top: 5, right: 30, left: 40, bottom: 5 }}>
              <CartesianGrid strokeDasharray="3 3" horizontal={false} stroke="#27272a" />
              <XAxis type="number" axisLine={false} tickLine={false} tick={{ fill: '#71717a', fontSize: 10 }} />
              <YAxis dataKey="category" type="category" axisLine={false} tickLine={false} tick={{ fill: '#a1a1aa', fontSize: 10 }} />
              <Tooltip 
                cursor={{ fill: '#27272a', opacity: 0.4 }}
                contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', color: '#fff', borderRadius: '12px', fontSize: '12px' }}
                formatter={(value: number) => value.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' ' + baseCurrency}
              />
              <Legend />
              <Bar dataKey="planned" name="План" fill="#3f3f46" radius={[0, 4, 4, 0]} />
              <Bar dataKey="actual" name="Факт" radius={[0, 4, 4, 0]}>
                {budgetChartData.map((entry, index) => (
                  <Cell 
                    key={`cell-${index}`} 
                    fill={entry.actual / entry.planned > 0.9 ? '#ef4444' : entry.actual / entry.planned > 0.7 ? '#f59e0b' : '#10b981'} 
                  />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* Tags Breakdown */}
      {tagData.length > 0 && (
        <div className="bg-white p-4 rounded-2xl border border-stone-200">
          <h3 className="text-sm font-medium text-zinc-900 mb-4">Расходы по тегам</h3>
          <div className="space-y-3">
            {tagData.map((tag, index) => (
              <div key={index} className="flex items-center justify-between bg-stone-50 p-3 rounded-xl border border-stone-200/70">
                <div className="flex items-center gap-2">
                  <span className="text-xs font-medium bg-stone-100 text-zinc-700 px-2 py-1 rounded-md">
                    {tag.name}
                  </span>
                </div>
                <div className="text-sm font-bold text-zinc-900">
                  {tag.value.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} {baseCurrency}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
