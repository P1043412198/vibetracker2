import React, { useState, useMemo } from 'react';
import { motion } from 'framer-motion';
import { useStore } from '../store/useStore';
import { useCurrencyConverter } from '../hooks/useCurrencyConverter';
import { format, isSameMonth, parseISO, getDaysInMonth, getDate, addMonths } from 'date-fns';
import { ru } from 'date-fns/locale';
import { cn } from '../lib/utils';
import { 
  ShieldAlert, CalendarClock, Mail, Scale, Plus, Trash2, Edit2, 
  AlertTriangle, CheckCircle2, Wallet, ArrowRight, Target, X
} from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Cell, ReferenceLine } from 'recharts';
import { RecurringReviewCard } from './RecurringReviewCard';
import { lastDueOccurrence, isOccurrencePosted } from '../lib/finance/recurring';
import type { RecurringFrequency, TransactionType } from '../types';

const EXPENSE_CATEGORIES = [
  'Продукты', 'Транспорт', 'Жилье', 'Развлечения', 'Одежда', 
  'Здоровье', 'Рестораны', 'Связь', 'Подарки', 'Другое'
];

export function BudgetControlTab() {
  const { 
    transactions = [], 
    accounts = [],
    rates = {},
    baseCurrency = 'BYN',
    budgetLimits = [], addBudgetLimit, updateBudgetLimit, deleteBudgetLimit,
    regularPayments = [], addRegularPayment, updateRegularPayment, deleteRegularPayment,
    confirmRecurring,
    envelopes = [], addEnvelope, updateEnvelope, deleteEnvelope
  } = useStore();

  const convertCurrency = useCurrencyConverter();

  const [activeSubTab, setActiveSubTab] = useState<'budgets' | 'payments' | 'envelopes' | 'zbb'>('budgets');

  const currentMonth = new Date();
  const daysInMonth = getDaysInMonth(currentMonth);
  const currentDay = getDate(currentMonth);
  const daysLeft = daysInMonth - currentDay + 1;

  // --- 1. Бюджеты (Лимиты) ---
  const [isAddingBudget, setIsAddingBudget] = useState(false);
  const [budgetCategory, setBudgetCategory] = useState(EXPENSE_CATEGORIES[0]);
  const [budgetAmount, setBudgetAmount] = useState('');
  const [budgetCurrency, setBudgetCurrency] = useState<string>(baseCurrency);

  const handleAddBudget = (e: React.FormEvent) => {
    e.preventDefault();
    if (!budgetAmount) return;
    
    const existing = budgetLimits.find(b => b.category === budgetCategory);
    if (existing) {
      updateBudgetLimit(existing.id, { amount: Number(budgetAmount), currency: budgetCurrency });
    } else {
      addBudgetLimit({
        category: budgetCategory,
        amount: Number(budgetAmount),
        currency: budgetCurrency,
        period: 'month'
      });
    }
    setIsAddingBudget(false);
    setBudgetAmount('');
  };

  const budgetProgress = useMemo(() => {
    const currentMonthTx = transactions.filter(t => 
      t.type === 'expense' && isSameMonth(parseISO(t.date), currentMonth)
    );

    return budgetLimits.map(limit => {
      const spent = currentMonthTx
        .filter(t => t.category === limit.category)
        .reduce((sum, t) => {
          const account = accounts.find(a => a.id === t.accountId);
          const currency = account?.currency || baseCurrency;
          return sum + convertCurrency(t.amount, currency, limit.currency || baseCurrency);
        }, 0);
      
      const remaining = limit.amount - spent;
      const percent = Math.min((spent / limit.amount) * 100, 100);
      const safePerDay = remaining > 0 ? remaining / daysLeft : 0;

      return { ...limit, spent, remaining, percent, safePerDay };
    }).sort((a, b) => b.percent - a.percent);
  }, [budgetLimits, transactions, currentMonth, daysLeft, accounts, rates]);

  // --- 2. Регулярные платежи ---
  const [isAddingPayment, setIsAddingPayment] = useState(false);
  const [paymentName, setPaymentName] = useState('');
  const [paymentAmount, setPaymentAmount] = useState('');
  const [paymentCurrency, setPaymentCurrency] = useState<string>(baseCurrency);
  const [paymentDay, setPaymentDay] = useState('1');
  const [paymentType, setPaymentType] = useState<TransactionType>('expense');
  const [paymentFreq, setPaymentFreq] = useState<RecurringFrequency>('monthly');
  const [paymentWeekday, setPaymentWeekday] = useState('1');
  const [paymentMonth, setPaymentMonth] = useState('1');
  const [paymentAnchor, setPaymentAnchor] = useState(new Date().toISOString().split('T')[0]);
  const [paymentAccount, setPaymentAccount] = useState<string>(accounts[0]?.id || '');
  const [paymentAutoConfirm, setPaymentAutoConfirm] = useState(false);

  const handleAddPayment = (e: React.FormEvent) => {
    e.preventDefault();
    if (!paymentName || !paymentAmount) return;

    addRegularPayment({
      name: paymentName,
      type: paymentType,
      amount: Number(paymentAmount),
      currency: paymentCurrency,
      dueDate: Number(paymentDay),
      frequency: paymentFreq,
      weekday: paymentFreq === 'weekly' || paymentFreq === 'biweekly' ? Number(paymentWeekday) : undefined,
      month: paymentFreq === 'yearly' ? Number(paymentMonth) : undefined,
      anchorDate: paymentFreq === 'biweekly' ? paymentAnchor : undefined,
      accountId: paymentAccount || undefined,
      autoConfirm: paymentAutoConfirm,
      category: paymentType === 'income' ? 'Доход' : 'Подписки',
      isActive: true
    });
    setIsAddingPayment(false);
    setPaymentName('');
    setPaymentAmount('');
    setPaymentDay('1');
    setPaymentAutoConfirm(false);
  };

  const todayISO = new Date().toISOString().split('T')[0];
  const upcomingPayments = useMemo(() => {
    return regularPayments
      .filter(p => p.isActive)
      .map(p => {
        let status = 'upcoming';
        if (p.dueDate < currentDay) status = 'past';
        if (p.dueDate === currentDay) status = 'today';

        const occ = lastDueOccurrence(p, todayISO);
        const isPaid = occ ? isOccurrencePosted(transactions, p.id, occ.periodKey) : false;

        return { ...p, status, isPaid };
      })
      .sort((a, b) => a.dueDate - b.dueDate);
  }, [regularPayments, currentDay, transactions, todayISO]);

  const [processingPayment, setProcessingPayment] = useState<string | null>(null);
  const [selectedAccount, setSelectedAccount] = useState<string>(accounts[0]?.id || '');

  const handleProcessPayment = (id: string) => {
    if (!selectedAccount) {
      alert('Выберите счет для оплаты');
      return;
    }
    const rule = regularPayments.find(p => p.id === id);
    const occ = rule ? lastDueOccurrence(rule, todayISO) : null;
    if (occ) confirmRecurring(id, occ.periodKey, selectedAccount);
    setProcessingPayment(null);
  };

  const totalUpcoming = upcomingPayments
    .filter(p => p.status === 'upcoming' || p.status === 'today')
    .reduce((sum, p) => sum + convertCurrency(p.amount, p.currency || baseCurrency, baseCurrency), 0);

  // --- 3. Конверты ---
  const [isAddingEnvelope, setIsAddingEnvelope] = useState(false);
  const [envName, setEnvName] = useState('');
  const [envTarget, setEnvTarget] = useState('');
  const [envColor, setEnvColor] = useState('#3b82f6');

  const [activeAction, setActiveAction] = useState<{ id: string, type: 'add' | 'take' } | null>(null);
  const [actionAmount, setActionAmount] = useState('');
  const [actionError, setActionError] = useState('');

  const handleEnvelopeAction = (id: string, type: 'add' | 'take') => {
    setActiveAction({ id, type });
    setActionAmount('');
    setActionError('');
  };

  const submitEnvelopeAction = () => {
    if (!activeAction) return;
    const amount = parseFloat(actionAmount);
    if (isNaN(amount) || amount <= 0) {
      setActionError('Введите корректную сумму');
      return;
    }

    const env = envelopes.find(e => e.id === activeAction.id);
    if (!env) return;

    if (activeAction.type === 'add') {
      if (amount > freeMoney) {
        setActionError('Недостаточно свободных средств!');
        return;
      }
      updateEnvelope(env.id, { currentAmount: env.currentAmount + amount });
    } else {
      if (amount > env.currentAmount) {
        setActionError('В конверте нет столько средств!');
        return;
      }
      updateEnvelope(env.id, { currentAmount: env.currentAmount - amount });
    }

    setActiveAction(null);
  };

  const handleAddEnvelope = (e: React.FormEvent) => {
    e.preventDefault();
    if (!envName) return;
    
    addEnvelope({
      name: envName,
      targetAmount: envTarget ? Number(envTarget) : undefined,
      currentAmount: 0,
      color: envColor
    });
    setIsAddingEnvelope(false);
    setEnvName('');
    setEnvTarget('');
  };

  const totalInEnvelopes = envelopes.reduce((sum, e) => sum + e.currentAmount, 0);
  
  // Вычисляем "свободные" деньги (общий баланс минус конверты)
  const totalBalance = accounts.reduce((sum, a) => {
    const txs = transactions.filter(t => t.accountId === a.id || t.toAccountId === a.id);
    const balance = txs.reduce((s, t) => {
      if (t.type === 'income' && t.accountId === a.id) return s + t.amount;
      if (t.type === 'expense' && t.accountId === a.id) return s - t.amount;
      if (t.type === 'transfer') {
        if (t.accountId === a.id) return s - t.amount;
        if (t.toAccountId === a.id) {
          const fromAccount = accounts.find(acc => acc.id === t.accountId);
          if (fromAccount && fromAccount.currency !== a.currency) {
            const amountInAnchor = t.amount * (rates[fromAccount.currency] || 1);
            return s + (amountInAnchor / (rates[a.currency] || 1));
          }
          return s + t.amount;
        }
      }
      return s;
    }, a.initialBalance || 0);
    return sum + convertCurrency(balance, a.currency || baseCurrency, baseCurrency);
  }, 0);
  const freeMoney = totalBalance - totalInEnvelopes;

  // --- 4. Zero-Based Budgeting (План vs Факт) ---
  const zbbData = useMemo(() => {
    const currentMonthTx = transactions.filter(t => isSameMonth(parseISO(t.date), currentMonth));
    const income = currentMonthTx.filter(t => t.type === 'income').reduce((sum, t) => {
      const account = accounts.find(a => a.id === t.accountId);
      return sum + convertCurrency(t.amount, account?.currency || baseCurrency, baseCurrency);
    }, 0);
    const expense = currentMonthTx.filter(t => t.type === 'expense').reduce((sum, t) => {
      const account = accounts.find(a => a.id === t.accountId);
      return sum + convertCurrency(t.amount, account?.currency || baseCurrency, baseCurrency);
    }, 0);
    
    const plannedExpense = budgetLimits.reduce((sum, l) => sum + convertCurrency(l.amount, l.currency || baseCurrency, baseCurrency), 0);
    const plannedSavings = income - plannedExpense; // Все, что не в бюджете - в сбережения
    
    const actualSavings = income - expense;

    return [
      { name: 'Доход', План: income, Факт: income },
      { name: 'Расходы', План: plannedExpense, Факт: expense },
      { name: 'Сбережения', План: plannedSavings > 0 ? plannedSavings : 0, Факт: actualSavings }
    ];
  }, [transactions, budgetLimits, currentMonth, accounts, rates, baseCurrency]);

  return (
    <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
      
      {/* Навигация по подразделам */}
      <div className="flex flex-wrap gap-2 pb-2">
        <button
          onClick={() => setActiveSubTab('budgets')}
          className={cn(
            "flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium whitespace-nowrap transition-all",
            activeSubTab === 'budgets' ? "bg-stone-100 text-zinc-900 shadow-sm" : "bg-white/60 text-zinc-500 hover:text-zinc-800"
          )}
        >
          <ShieldAlert className="w-4 h-4" />
          Лимиты
        </button>
        <button
          onClick={() => setActiveSubTab('payments')}
          className={cn(
            "flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium whitespace-nowrap transition-all",
            activeSubTab === 'payments' ? "bg-stone-100 text-zinc-900 shadow-sm" : "bg-white/60 text-zinc-500 hover:text-zinc-800"
          )}
        >
          <CalendarClock className="w-4 h-4" />
          Подписки
        </button>
        <button
          onClick={() => setActiveSubTab('envelopes')}
          className={cn(
            "flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium whitespace-nowrap transition-all",
            activeSubTab === 'envelopes' ? "bg-stone-100 text-zinc-900 shadow-sm" : "bg-white/60 text-zinc-500 hover:text-zinc-800"
          )}
        >
          <Mail className="w-4 h-4" />
          Конверты
        </button>
        <button
          onClick={() => setActiveSubTab('zbb')}
          className={cn(
            "flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium whitespace-nowrap transition-all",
            activeSubTab === 'zbb' ? "bg-stone-100 text-zinc-900 shadow-sm" : "bg-white/60 text-zinc-500 hover:text-zinc-800"
          )}
        >
          <Scale className="w-4 h-4" />
          План / Факт
        </button>
      </div>

      {/* 1. ЛИМИТЫ (БЮДЖЕТЫ) */}
      {activeSubTab === 'budgets' && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-lg font-bold text-zinc-900">Бюджеты на месяц</h2>
              <p className="text-sm text-zinc-500">Контролируйте расходы по категориям</p>
            </div>
            <button 
              onClick={() => setIsAddingBudget(!isAddingBudget)}
              className="p-2 bg-stone-100 text-zinc-900 rounded-xl hover:bg-stone-200 transition-colors"
            >
              <Plus className="w-5 h-5" />
            </button>
          </div>

          {isAddingBudget && (
            <form onSubmit={handleAddBudget} className="bg-white p-4 rounded-xl border border-stone-200 space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs text-zinc-500 mb-1">Категория</label>
                  <select
                    value={budgetCategory}
                    onChange={(e) => setBudgetCategory(e.target.value)}
                    className="w-full bg-stone-100 text-zinc-900 rounded-lg px-3 py-2 border border-stone-300 focus:outline-none focus:border-emerald-500"
                  >
                    {EXPENSE_CATEGORIES.map(c => (
                      <option key={c} value={c}>{c}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-xs text-zinc-500 mb-1">Лимит</label>
                  <div className="flex gap-2">
                    <input
                      type="number"
                      value={budgetAmount}
                      onChange={(e) => setBudgetAmount(e.target.value)}
                      placeholder="0.00"
                      className="flex-1 bg-stone-100 text-zinc-900 rounded-lg px-3 py-2 border border-stone-300 focus:outline-none focus:border-emerald-500"
                      required
                    />
                    <select
                      value={budgetCurrency}
                      onChange={(e) => setBudgetCurrency(e.target.value)}
                      className="w-24 bg-stone-100 text-zinc-900 rounded-lg px-2 py-2 border border-stone-300 focus:outline-none focus:border-emerald-500"
                    >
                      {['BYN', 'USD', 'EUR', 'RUB', 'PLN'].map(c => (
                        <option key={c} value={c}>{c}</option>
                      ))}
                    </select>
                  </div>
                </div>
              </div>
              <div className="flex justify-end gap-2">
                <button type="button" onClick={() => setIsAddingBudget(false)} className="px-4 py-2 text-sm text-zinc-500 hover:text-zinc-900">Отмена</button>
                <button type="submit" className="px-4 py-2 bg-emerald-600 text-zinc-900 text-sm font-medium rounded-lg hover:bg-emerald-700">Сохранить</button>
              </div>
            </form>
          )}

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {budgetProgress.map(budget => (
              <div key={budget.id} className="bg-white p-4 rounded-xl border border-stone-200">
                <div className="flex justify-between items-start mb-2">
                  <div>
                    <h3 className="font-medium text-zinc-900">{budget.category}</h3>
                    <p className="text-xs text-zinc-500">
                      Осталось: <span className={cn("font-bold", budget.remaining < 0 ? "text-red-400" : "text-emerald-400")}>
                        {budget.remaining.toFixed(2)} {budget.currency || baseCurrency}
                      </span>
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-bold text-zinc-900">{budget.spent.toFixed(0)} / {budget.amount} {budget.currency || baseCurrency}</span>
                    <button onClick={() => deleteBudgetLimit(budget.id)} className="text-zinc-600 hover:text-red-400">
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
                
                <div className="h-2 bg-stone-100 rounded-full overflow-hidden mb-2">
                  <div 
                    className={cn(
                      "h-full rounded-full transition-all",
                      budget.percent >= 100 ? "bg-red-500" : 
                      budget.percent >= 80 ? "bg-amber-500" : "bg-emerald-500"
                    )}
                    style={{ width: `${Math.min(budget.percent, 100)}%` }}
                  />
                </div>
                
                {budget.remaining > 0 ? (
                  <p className="text-xs text-zinc-500 flex items-center gap-1">
                    <Target className="w-3 h-3" />
                    Безопасно тратить: <span className="text-zinc-900">{budget.safePerDay.toFixed(1)} {budget.currency || baseCurrency} / день</span>
                  </p>
                ) : (
                  <p className="text-xs text-red-400 flex items-center gap-1">
                    <AlertTriangle className="w-3 h-3" />
                    Лимит превышен
                  </p>
                )}
              </div>
            ))}
            {budgetLimits.length === 0 && !isAddingBudget && (
              <div className="col-span-full text-center py-8 text-zinc-500">
                Нет установленных лимитов. Добавьте первый бюджет!
              </div>
            )}
          </div>
        </div>
      )}

      {/* 2. РЕГУЛЯРНЫЕ ПЛАТЕЖИ */}
      {activeSubTab === 'payments' && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-lg font-bold text-zinc-900">Регулярные платежи</h2>
              <p className="text-sm text-zinc-500">Подписки, кредиты, коммуналка</p>
            </div>
            <button 
              onClick={() => setIsAddingPayment(!isAddingPayment)}
              className="p-2 bg-stone-100 text-zinc-900 rounded-xl hover:bg-stone-200 transition-colors"
            >
              <Plus className="w-5 h-5" />
            </button>
          </div>

          <div className="bg-emerald-500/10 border border-emerald-500/20 rounded-xl p-4 flex items-center gap-3">
            <AlertTriangle className="w-5 h-5 text-emerald-400" />
            <div>
              <p className="text-sm text-emerald-400">К оплате до конца месяца:</p>
              <p className="text-xl font-bold text-zinc-900">{totalUpcoming.toFixed(2)} {baseCurrency}</p>
            </div>
          </div>

          <RecurringReviewCard />

          {isAddingPayment && (
            <form onSubmit={handleAddPayment} className="bg-white p-4 rounded-xl border border-stone-200 space-y-4">
              <div className="grid grid-cols-2 gap-2">
                <button
                  type="button"
                  onClick={() => setPaymentType('expense')}
                  className={cn('py-2 rounded-lg text-sm font-medium border', paymentType === 'expense' ? 'bg-red-500/10 border-red-400 text-red-500' : 'bg-stone-100 border-stone-300 text-zinc-500')}
                >Расход</button>
                <button
                  type="button"
                  onClick={() => setPaymentType('income')}
                  className={cn('py-2 rounded-lg text-sm font-medium border', paymentType === 'income' ? 'bg-emerald-500/10 border-emerald-500 text-emerald-600' : 'bg-stone-100 border-stone-300 text-zinc-500')}
                >Доход</button>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs text-zinc-500 mb-1">Название</label>
                  <input
                    type="text"
                    value={paymentName}
                    onChange={(e) => setPaymentName(e.target.value)}
                    placeholder="Netflix"
                    className="w-full bg-stone-100 text-zinc-900 rounded-lg px-3 py-2 border border-stone-300 focus:outline-none focus:border-emerald-500"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs text-zinc-500 mb-1">Сумма</label>
                  <div className="flex gap-2">
                    <input
                      type="number"
                      value={paymentAmount}
                      onChange={(e) => setPaymentAmount(e.target.value)}
                      placeholder="0.00"
                      className="flex-1 bg-stone-100 text-zinc-900 rounded-lg px-3 py-2 border border-stone-300 focus:outline-none focus:border-emerald-500"
                      required
                    />
                    <select
                      value={paymentCurrency}
                      onChange={(e) => setPaymentCurrency(e.target.value)}
                      className="w-24 bg-stone-100 text-zinc-900 rounded-lg px-2 py-2 border border-stone-300 focus:outline-none focus:border-emerald-500"
                    >
                      {['BYN', 'USD', 'EUR', 'RUB', 'PLN'].map(c => (
                        <option key={c} value={c}>{c}</option>
                      ))}
                    </select>
                  </div>
                </div>
                <div>
                  <label className="block text-xs text-zinc-500 mb-1">Периодичность</label>
                  <select
                    value={paymentFreq}
                    onChange={(e) => setPaymentFreq(e.target.value as RecurringFrequency)}
                    className="w-full bg-stone-100 text-zinc-900 rounded-lg px-3 py-2 border border-stone-300 focus:outline-none focus:border-emerald-500"
                  >
                    <option value="monthly">Ежемесячно</option>
                    <option value="weekly">Еженедельно</option>
                    <option value="biweekly">Раз в 2 недели</option>
                    <option value="yearly">Ежегодно</option>
                  </select>
                </div>
                {(paymentFreq === 'monthly' || paymentFreq === 'yearly') && (
                  <div>
                    <label className="block text-xs text-zinc-500 mb-1">День</label>
                    <input
                      type="number"
                      min="1" max="31"
                      value={paymentDay}
                      onChange={(e) => setPaymentDay(e.target.value)}
                      className="w-full bg-stone-100 text-zinc-900 rounded-lg px-3 py-2 border border-stone-300 focus:outline-none focus:border-emerald-500"
                      required
                    />
                  </div>
                )}
                {paymentFreq === 'yearly' && (
                  <div>
                    <label className="block text-xs text-zinc-500 mb-1">Месяц</label>
                    <select
                      value={paymentMonth}
                      onChange={(e) => setPaymentMonth(e.target.value)}
                      className="w-full bg-stone-100 text-zinc-900 rounded-lg px-3 py-2 border border-stone-300 focus:outline-none focus:border-emerald-500"
                    >
                      {['Янв','Фев','Мар','Апр','Май','Июн','Июл','Авг','Сен','Окт','Ноя','Дек'].map((m, i) => (
                        <option key={m} value={i + 1}>{m}</option>
                      ))}
                    </select>
                  </div>
                )}
                {paymentFreq === 'weekly' && (
                  <div>
                    <label className="block text-xs text-zinc-500 mb-1">День недели</label>
                    <select
                      value={paymentWeekday}
                      onChange={(e) => setPaymentWeekday(e.target.value)}
                      className="w-full bg-stone-100 text-zinc-900 rounded-lg px-3 py-2 border border-stone-300 focus:outline-none focus:border-emerald-500"
                    >
                      {['Вс','Пн','Вт','Ср','Чт','Пт','Сб'].map((d, i) => (
                        <option key={d} value={i}>{d}</option>
                      ))}
                    </select>
                  </div>
                )}
                {paymentFreq === 'biweekly' && (
                  <div>
                    <label className="block text-xs text-zinc-500 mb-1">Первая дата</label>
                    <input
                      type="date"
                      value={paymentAnchor}
                      onChange={(e) => setPaymentAnchor(e.target.value)}
                      className="w-full bg-stone-100 text-zinc-900 rounded-lg px-3 py-2 border border-stone-300 focus:outline-none focus:border-emerald-500"
                    />
                  </div>
                )}
                <div>
                  <label className="block text-xs text-zinc-500 mb-1">Счёт</label>
                  <select
                    value={paymentAccount}
                    onChange={(e) => setPaymentAccount(e.target.value)}
                    className="w-full bg-stone-100 text-zinc-900 rounded-lg px-3 py-2 border border-stone-300 focus:outline-none focus:border-emerald-500"
                  >
                    {accounts.map(a => (
                      <option key={a.id} value={a.id}>{a.name}</option>
                    ))}
                  </select>
                </div>
              </div>
              <label className="flex items-center gap-2 text-sm text-zinc-600 cursor-pointer">
                <input
                  type="checkbox"
                  checked={paymentAutoConfirm}
                  onChange={(e) => setPaymentAutoConfirm(e.target.checked)}
                  className="w-4 h-4 accent-emerald-600"
                />
                Создавать автоматически, без подтверждения
              </label>
              <div className="flex justify-end gap-2">
                <button type="button" onClick={() => setIsAddingPayment(false)} className="px-4 py-2 text-sm text-zinc-500 hover:text-zinc-900">Отмена</button>
                <button type="submit" className="px-4 py-2 bg-emerald-600 text-white text-sm font-medium rounded-lg hover:bg-emerald-700">Добавить</button>
              </div>
            </form>
          )}

          <div className="space-y-2">
            {upcomingPayments.map(payment => (
              <div key={payment.id} className={cn(
                "flex items-center justify-between bg-white p-4 rounded-xl border transition-all",
                payment.status === 'today' ? "border-amber-500/50 shadow-lg shadow-amber-500/5" : "border-stone-200",
                payment.isPaid && "opacity-60"
              )}>
                <div className="flex items-center gap-4">
                  <div className={cn(
                    "w-12 h-12 rounded-xl flex flex-col items-center justify-center",
                    payment.status === 'past' ? "bg-stone-100 text-zinc-500" :
                    payment.status === 'today' ? "bg-amber-500/20 text-amber-400 border border-amber-500/50" :
                    "bg-emerald-500/10 text-emerald-400"
                  )}>
                    <span className="text-xs uppercase">День</span>
                    <span className="text-lg font-bold leading-none">{payment.dueDate}</span>
                  </div>
                  <div>
                    <h3 className={cn("font-medium", (payment.status === 'past' || payment.isPaid) ? "text-zinc-500 line-through" : "text-zinc-900")}>
                      {payment.name}
                    </h3>
                    <p className="text-xs text-zinc-500">
                      {payment.isPaid ? 'Оплачено' :
                       payment.status === 'past' ? 'Уже списано' : 
                       payment.status === 'today' ? 'Списание сегодня!' : 
                       `Через ${payment.dueDate - currentDay} дн.`}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-4">
                  <span className={cn("font-bold", (payment.status === 'past' || payment.isPaid) ? "text-zinc-500" : "text-zinc-900")}>
                    {payment.amount.toFixed(2)} {payment.currency || baseCurrency}
                  </span>
                  
                  {!payment.isPaid && (
                    <>
                      {processingPayment === payment.id ? (
                        <div className="flex items-center gap-2">
                          <select 
                            value={selectedAccount}
                            onChange={(e) => setSelectedAccount(e.target.value)}
                            className="bg-stone-100 text-xs text-zinc-900 rounded px-2 py-1 border border-stone-300"
                          >
                            {accounts.map(a => (
                              <option key={a.id} value={a.id}>{a.name}</option>
                            ))}
                          </select>
                          <button 
                            onClick={() => handleProcessPayment(payment.id)}
                            className="text-xs bg-emerald-600 text-zinc-900 px-2 py-1 rounded hover:bg-emerald-700"
                          >
                            Ок
                          </button>
                          <button 
                            onClick={() => setProcessingPayment(null)}
                            className="text-xs text-zinc-500"
                          >
                            <X className="w-4 h-4" />
                          </button>
                        </div>
                      ) : (
                        <button 
                          onClick={() => setProcessingPayment(payment.id)}
                          className="text-xs bg-stone-100 text-zinc-700 px-2 py-1 rounded hover:bg-stone-200"
                        >
                          Оплатить
                        </button>
                      )}
                    </>
                  )}

                  <button onClick={() => deleteRegularPayment(payment.id)} className="text-zinc-600 hover:text-red-400">
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            ))}
            {regularPayments.length === 0 && !isAddingPayment && (
              <div className="text-center py-8 text-zinc-500">
                Нет регулярных платежей. Добавьте подписки для контроля.
              </div>
            )}
          </div>
        </div>
      )}

      {/* 3. КОНВЕРТЫ */}
      {activeSubTab === 'envelopes' && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-lg font-bold text-zinc-900">Метод конвертов</h2>
              <p className="text-sm text-zinc-500">Виртуальное разделение денег</p>
            </div>
            <button 
              onClick={() => setIsAddingEnvelope(!isAddingEnvelope)}
              className="p-2 bg-stone-100 text-zinc-900 rounded-xl hover:bg-stone-200 transition-colors"
            >
              <Plus className="w-5 h-5" />
            </button>
          </div>

          <div className="grid grid-cols-2 gap-4 mb-6">
            <div className="bg-white border border-stone-200 rounded-xl p-4">
              <p className="text-sm text-zinc-500 mb-1">Общий баланс</p>
              <p className="text-xl font-bold text-zinc-900">{totalBalance.toFixed(2)} {baseCurrency}</p>
            </div>
            <div className="bg-emerald-500/10 border border-emerald-500/20 rounded-xl p-4">
              <p className="text-sm text-emerald-400 mb-1">Свободно (вне конвертов)</p>
              <p className="text-xl font-bold text-emerald-400">{freeMoney.toFixed(2)} {baseCurrency}</p>
            </div>
          </div>

          {isAddingEnvelope && (
            <form onSubmit={handleAddEnvelope} className="bg-white p-4 rounded-xl border border-stone-200 space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div>
                  <label className="block text-xs text-zinc-500 mb-1">Название конверта</label>
                  <input
                    type="text"
                    value={envName}
                    onChange={(e) => setEnvName(e.target.value)}
                    placeholder="На отпуск"
                    className="w-full bg-stone-100 text-zinc-900 rounded-lg px-3 py-2 border border-stone-300 focus:outline-none focus:border-emerald-500"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs text-zinc-500 mb-1">Цель (необязательно)</label>
                  <input
                    type="number"
                    value={envTarget}
                    onChange={(e) => setEnvTarget(e.target.value)}
                    placeholder="0.00"
                    className="w-full bg-stone-100 text-zinc-900 rounded-lg px-3 py-2 border border-stone-300 focus:outline-none focus:border-emerald-500"
                  />
                </div>
                <div>
                  <label className="block text-xs text-zinc-500 mb-1">Цвет</label>
                  <input
                    type="color"
                    value={envColor}
                    onChange={(e) => setEnvColor(e.target.value)}
                    className="w-full h-[42px] bg-stone-100 rounded-lg border border-stone-300 cursor-pointer"
                  />
                </div>
              </div>
              <div className="flex justify-end gap-2">
                <button type="button" onClick={() => setIsAddingEnvelope(false)} className="px-4 py-2 text-sm text-zinc-500 hover:text-zinc-900">Отмена</button>
                <button type="submit" className="px-4 py-2 bg-emerald-600 text-zinc-900 text-sm font-medium rounded-lg hover:bg-emerald-700">Создать</button>
              </div>
            </form>
          )}

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {envelopes.map(env => (
              <div key={env.id} className="bg-white p-4 rounded-xl border border-stone-200 relative overflow-hidden group">
                <div className="absolute top-0 left-0 w-1 h-full" style={{ backgroundColor: env.color }} />
                
                <div className="flex justify-between items-start mb-4 pl-2">
                  <h3 className="font-bold text-zinc-900">{env.name}</h3>
                  <button onClick={() => deleteEnvelope(env.id)} className="text-zinc-600 hover:text-red-400 opacity-0 group-hover:opacity-100 transition-opacity">
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>

                <div className="pl-2">
                  <div className="flex items-end gap-2 mb-2">
                    <span className="text-2xl font-bold text-zinc-900">{env.currentAmount.toFixed(0)}</span>
                    <span className="text-sm text-zinc-500 mb-1">{baseCurrency}</span>
                  </div>

                  {env.targetAmount && (
                    <>
                      <div className="flex justify-between text-xs text-zinc-500 mb-1">
                        <span>Прогресс</span>
                        <span>{env.targetAmount} {baseCurrency}</span>
                      </div>
                      <div className="h-1.5 bg-stone-100 rounded-full overflow-hidden">
                        <div 
                          className="h-full rounded-full"
                          style={{ 
                            width: `${Math.min((env.currentAmount / env.targetAmount) * 100, 100)}%`,
                            backgroundColor: env.color
                          }}
                        />
                      </div>
                    </>
                  )}

                  {activeAction?.id === env.id ? (
                    <div className="mt-4 space-y-2">
                      <div className="flex gap-2">
                        <input
                          type="number"
                          value={actionAmount}
                          onChange={(e) => setActionAmount(e.target.value)}
                          placeholder="Сумма"
                          className="flex-1 bg-stone-50 border border-stone-200 rounded-lg px-3 py-1.5 text-sm text-zinc-900 focus:outline-none focus:border-emerald-500/50"
                          autoFocus
                        />
                        <button
                          onClick={submitEnvelopeAction}
                          className="px-3 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-zinc-900 text-sm font-medium rounded-lg transition-colors"
                        >
                          ОК
                        </button>
                        <button
                          onClick={() => setActiveAction(null)}
                          className="px-3 py-1.5 bg-stone-100 hover:bg-stone-200 text-zinc-900 text-sm font-medium rounded-lg transition-colors"
                        >
                          <X className="w-4 h-4" />
                        </button>
                      </div>
                      {actionError && <p className="text-xs text-red-400">{actionError}</p>}
                    </div>
                  ) : (
                    <div className="flex gap-2 mt-4">
                      <button 
                        onClick={() => handleEnvelopeAction(env.id, 'add')}
                        className="flex-1 py-1.5 bg-stone-100 hover:bg-stone-200 text-zinc-900 text-xs rounded-lg transition-colors"
                      >
                        Пополнить
                      </button>
                      <button 
                        onClick={() => handleEnvelopeAction(env.id, 'take')}
                        className="flex-1 py-1.5 bg-stone-100 hover:bg-stone-200 text-zinc-900 text-xs rounded-lg transition-colors"
                      >
                        Взять
                      </button>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* 4. PLAN VS FACT (ZBB) */}
      {activeSubTab === 'zbb' && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-lg font-bold text-zinc-900">План vs Факт</h2>
              <p className="text-sm text-zinc-500">Zero-Based Budgeting</p>
            </div>
          </div>

          <div className="bg-white border border-stone-200 rounded-2xl p-6">
            <div className="h-[300px] w-full">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={zbbData} margin={{ top: 20, right: 30, left: 0, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                  <XAxis dataKey="name" stroke="#71717a" fontSize={12} tickLine={false} axisLine={false} />
                  <YAxis stroke="#71717a" fontSize={12} tickLine={false} axisLine={false} />
                  <Tooltip 
                    contentStyle={{ backgroundColor: '#18181b', borderColor: '#27272a', borderRadius: '12px', color: '#fff' }}
                    cursor={{ fill: '#27272a', opacity: 0.4 }}
                  />
                  <Bar dataKey="План" fill="#3f3f46" radius={[4, 4, 0, 0]} />
                  <Bar dataKey="Факт" radius={[4, 4, 0, 0]}>
                    {zbbData.map((entry, index) => (
                      <Cell 
                        key={`cell-${index}`} 
                        fill={
                          entry.name === 'Расходы' && entry.Факт > entry.План ? '#ef4444' : 
                          entry.name === 'Сбережения' && entry.Факт < entry.План ? '#ef4444' : 
                          '#10b981'
                        } 
                      />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
            
            <div className="mt-6 grid grid-cols-3 gap-4 text-center">
              <div>
                <p className="text-xs text-zinc-500 mb-1">План расходов</p>
                <p className="text-lg font-bold text-zinc-900">{zbbData[1].План.toFixed(0)} {baseCurrency}</p>
              </div>
              <div>
                <p className="text-xs text-zinc-500 mb-1">Факт расходов</p>
                <p className={cn("text-lg font-bold", zbbData[1].Факт > zbbData[1].План ? "text-red-400" : "text-emerald-400")}>
                  {zbbData[1].Факт.toFixed(0)} {baseCurrency}
                </p>
              </div>
              <div>
                <p className="text-xs text-zinc-500 mb-1">Отклонение</p>
                <p className={cn("text-lg font-bold", zbbData[1].Факт > zbbData[1].План ? "text-red-400" : "text-emerald-400")}>
                  {Math.abs(zbbData[1].План - zbbData[1].Факт).toFixed(0)} {baseCurrency}
                </p>
              </div>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}
