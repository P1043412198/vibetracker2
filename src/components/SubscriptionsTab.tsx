import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Plus, Trash2, Calendar, CreditCard, TrendingUp, AlertCircle, CheckCircle2, X } from 'lucide-react';
import { useStore } from '../store/useStore';
import { useCurrencyConverter } from '../hooks/useCurrencyConverter';
import { cn } from '../lib/utils';
import { Currency } from '../types';

export function SubscriptionsTab() {
  const { regularPayments = [], addRegularPayment, updateRegularPayment, deleteRegularPayment, rates = {}, baseCurrency = 'USD' } = useStore();
  const [isAdding, setIsAdding] = useState(false);
  const [name, setName] = useState('');
  const [amount, setAmount] = useState('');
  const [currency, setCurrency] = useState<Currency>(baseCurrency);
  const [dueDate, setDueDate] = useState('1');
  const [category, setCategory] = useState('Подписки');

  const convertCurrency = useCurrencyConverter();

  const handleAdd = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name || !amount || !dueDate) return;
    
    addRegularPayment({
      name,
      amount: parseFloat(amount),
      currency,
      dueDate: parseInt(dueDate, 10),
      category,
      isActive: true
    });
    
    setName('');
    setAmount('');
    setDueDate('1');
    setIsAdding(false);
  };

  const activeSubscriptions = regularPayments.filter(p => p.isActive);
  
  const totalMonthlyInBase = activeSubscriptions.reduce((sum, sub) => {
    return sum + convertCurrency(sub.amount, sub.currency || baseCurrency, baseCurrency);
  }, 0);
  
  const totalYearlyInBase = totalMonthlyInBase * 12;

  // Sort by due date
  const sortedSubscriptions = [...regularPayments].sort((a, b) => a.dueDate - b.dueDate);

  const today = new Date().getDate();

  return (
    <div className="space-y-6">
      {/* Dashboard Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div className="bg-white/80 border border-stone-200 p-6 rounded-3xl relative overflow-hidden">
          <div className="absolute top-0 right-0 p-4 opacity-10">
            <Calendar className="w-24 h-24" />
          </div>
          <div className="relative z-10">
            <p className="text-[10px] text-zinc-500 uppercase font-bold tracking-wider mb-2">Сумма в месяц</p>
            <p className="text-3xl font-bold text-zinc-900 mb-1">
              {totalMonthlyInBase.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} {baseCurrency}
            </p>
            <p className="text-xs text-zinc-500">Ежемесячные списания</p>
          </div>
        </div>
        <div className="bg-white/80 border border-stone-200 p-6 rounded-3xl relative overflow-hidden">
          <div className="absolute top-0 right-0 p-4 opacity-10">
            <TrendingUp className="w-24 h-24" />
          </div>
          <div className="relative z-10">
            <p className="text-[10px] text-zinc-500 uppercase font-bold tracking-wider mb-2">Сумма в год</p>
            <p className="text-3xl font-bold text-red-400 mb-1">
              {totalYearlyInBase.toLocaleString('ru-RU', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} {baseCurrency}
            </p>
            <p className="text-xs text-zinc-500">Столько сервисы съедают за год</p>
          </div>
        </div>
      </div>

      <div className="flex justify-between items-center">
        <h2 className="text-lg font-semibold text-zinc-900">Мои подписки</h2>
        <button
          onClick={() => setIsAdding(!isAdding)}
          className="p-2 bg-blue-500 text-zinc-900 rounded-xl hover:bg-blue-600 transition-colors"
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
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="space-y-2">
                <label className="text-xs text-zinc-500 uppercase">Название сервиса</label>
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="Netflix, Spotify, Интернет..."
                  className="w-full bg-stone-50 border border-stone-200 rounded-xl py-2 px-4 text-sm text-zinc-900 focus:outline-none focus:border-blue-500/50"
                />
              </div>
              <div className="space-y-2">
                <label className="text-xs text-zinc-500 uppercase">Сумма</label>
                <div className="flex gap-2">
                  <input
                    type="number"
                    step="0.01"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    placeholder="0.00"
                    className="flex-1 bg-stone-50 border border-stone-200 rounded-xl py-2 px-4 text-sm text-zinc-900 focus:outline-none focus:border-blue-500/50"
                  />
                  <select
                    value={currency}
                    onChange={(e) => setCurrency(e.target.value as Currency)}
                    className="w-24 bg-stone-50 border border-stone-200 rounded-xl py-2 px-3 text-sm text-zinc-900 focus:outline-none focus:border-blue-500/50"
                  >
                    <option value="BYN">BYN</option>
                    <option value="USD">USD</option>
                    <option value="EUR">EUR</option>
                    <option value="RUB">RUB</option>
                    <option value="PLN">PLN</option>
                  </select>
                </div>
              </div>
              <div className="space-y-2">
                <label className="text-xs text-zinc-500 uppercase">День списания (1-31)</label>
                <input
                  type="number"
                  min="1"
                  max="31"
                  value={dueDate}
                  onChange={(e) => setDueDate(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-xl py-2 px-4 text-sm text-zinc-900 focus:outline-none focus:border-blue-500/50"
                />
              </div>
              <div className="space-y-2">
                <label className="text-xs text-zinc-500 uppercase">Категория</label>
                <select
                  value={category}
                  onChange={(e) => setCategory(e.target.value)}
                  className="w-full bg-stone-50 border border-stone-200 rounded-xl py-2 px-4 text-sm text-zinc-900 focus:outline-none focus:border-blue-500/50"
                >
                  <option value="Подписки">Подписки</option>
                  <option value="Коммуналка">Коммуналка</option>
                  <option value="Связь">Связь / Интернет</option>
                  <option value="Кредиты">Кредиты</option>
                  <option value="Другое">Другое</option>
                </select>
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
                className="flex-1 py-2 bg-blue-500 text-zinc-900 rounded-xl text-xs font-bold"
              >
                Добавить
              </button>
            </div>
          </motion.form>
        )}
      </AnimatePresence>

      <div className="space-y-3">
        {sortedSubscriptions.map((sub) => {
          const isUpcoming = sub.dueDate >= today && sub.dueDate <= today + 5;
          const isPast = sub.dueDate < today;
          
          return (
            <div key={sub.id} className="bg-white border border-stone-200 rounded-2xl p-4 flex items-center justify-between group">
              <div className="flex items-center gap-4">
                <div className={cn(
                  "w-12 h-12 rounded-xl flex items-center justify-center text-lg font-bold",
                  sub.isActive ? "bg-stone-100 text-zinc-900" : "bg-stone-100/60 text-zinc-600"
                )}>
                  {sub.dueDate}
                </div>
                <div>
                  <h3 className={cn("font-bold", sub.isActive ? "text-zinc-900" : "text-zinc-500 line-through")}>{sub.name}</h3>
                  <div className="flex items-center gap-2 text-xs">
                    <span className="text-zinc-500">{sub.category}</span>
                    {sub.isActive && isUpcoming && (
                      <span className="flex items-center gap-1 text-amber-500 bg-amber-500/10 px-2 py-0.5 rounded-full">
                        <AlertCircle className="w-3 h-3" /> Скоро
                      </span>
                    )}
                    {sub.isActive && isPast && (
                      <span className="flex items-center gap-1 text-emerald-500 bg-emerald-500/10 px-2 py-0.5 rounded-full">
                        <CheckCircle2 className="w-3 h-3" /> Оплачено
                      </span>
                    )}
                  </div>
                </div>
              </div>
              <div className="flex items-center gap-4">
                <div className="text-right">
                  <p className={cn("font-bold", sub.isActive ? "text-zinc-900" : "text-zinc-500")}>
                    {sub.amount.toLocaleString()} {sub.currency || baseCurrency}
                  </p>
                  <p className="text-[10px] text-zinc-500">в месяц</p>
                </div>
                <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                  <button
                    onClick={() => updateRegularPayment(sub.id, { isActive: !sub.isActive })}
                    className="p-2 text-zinc-500 hover:text-zinc-900 transition-colors bg-stone-100 rounded-lg"
                    title={sub.isActive ? "Отключить" : "Включить"}
                  >
                    {sub.isActive ? <X className="w-4 h-4" /> : <CheckCircle2 className="w-4 h-4" />}
                  </button>
                  <button
                    onClick={() => deleteRegularPayment(sub.id)}
                    className="p-2 text-zinc-500 hover:text-red-400 transition-colors bg-stone-100 rounded-lg"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            </div>
          );
        })}

        {sortedSubscriptions.length === 0 && (
          <div className="text-center py-12 bg-white/30 rounded-3xl border border-dashed border-stone-200">
            <div className="w-16 h-16 bg-white rounded-full flex items-center justify-center mx-auto mb-4">
              <CreditCard className="w-8 h-8 text-zinc-700" />
            </div>
            <p className="text-zinc-500">У вас пока нет добавленных подписок</p>
          </div>
        )}
      </div>
    </div>
  );
}
