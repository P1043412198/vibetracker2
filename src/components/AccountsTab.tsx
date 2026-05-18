import React, { useState, useMemo } from 'react';
import { motion } from 'framer-motion';
import { useStore } from '../store/useStore';
import { useCurrencyConverter } from '../hooks/useCurrencyConverter';
import { Account, AccountType, Currency } from '../types';
import { cn } from '../lib/utils';
import { 
  Wallet, CreditCard, Landmark, Bitcoin, Plus, Trash2, Edit2, 
  ArrowRightLeft, ArrowUpRight, ArrowDownRight, MoreVertical
} from 'lucide-react';

const ACCOUNT_TYPES: { value: AccountType; label: string; icon: React.ElementType }[] = [
  { value: 'card', label: 'Банковская карта', icon: CreditCard },
  { value: 'cash', label: 'Наличные', icon: Wallet },
  { value: 'deposit', label: 'Вклад / Сбережения', icon: Landmark },
  { value: 'crypto', label: 'Криптовалюта', icon: Bitcoin },
  { value: 'other', label: 'Другое', icon: Wallet },
];

const CURRENCIES: { value: Currency; label: string; symbol: string }[] = [
  { value: 'BYN', label: 'Белорусский рубль', symbol: 'BYN' },
  { value: 'USD', label: 'Доллар США', symbol: '$' },
  { value: 'EUR', label: 'Евро', symbol: '€' },
  { value: 'RUB', label: 'Российский рубль', symbol: '₽' },
  { value: 'PLN', label: 'Польский злотый', symbol: 'zł' },
  { value: 'USDT', label: 'Tether (USDT)', symbol: '₮' },
];

export function AccountsTab() {
  const { accounts = [], transactions = [], addAccount, updateAccount, deleteAccount, rates = {}, baseCurrency = 'BYN' } = useStore();
  const [isAdding, setIsAdding] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);

  const [name, setName] = useState('');
  const [type, setType] = useState<AccountType>('card');
  const [currency, setCurrency] = useState<Currency>(baseCurrency);
  const [initialBalance, setInitialBalance] = useState('');
  const [color, setColor] = useState('#3b82f6');

  const convertCurrency = useCurrencyConverter();

  const handleAddAccount = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name || !initialBalance) return;

    if (editingId) {
      updateAccount(editingId, {
        name,
        type,
        currency,
        initialBalance: Number(initialBalance),
        color
      });
      setEditingId(null);
    } else {
      addAccount({
        name,
        type,
        currency,
        initialBalance: Number(initialBalance),
        color
      });
    }

    setIsAdding(false);
    resetForm();
  };

  const resetForm = () => {
    setName('');
    setType('card');
    setCurrency(baseCurrency);
    setInitialBalance('');
    setColor('#3b82f6');
    setEditingId(null);
  };

  const handleEdit = (account: Account) => {
    setName(account.name);
    setType(account.type);
    setCurrency(account.currency);
    setInitialBalance(account.initialBalance.toString());
    setColor(account.color || '#3b82f6');
    setEditingId(account.id);
    setIsAdding(true);
  };

  // Вычисляем текущие балансы счетов
  const accountBalances = useMemo(() => {
    const balances: Record<string, number> = {};
    
    // Инициализируем начальными балансами
    accounts.forEach(acc => {
      balances[acc.id] = acc.initialBalance;
    });

    // Применяем транзакции
    transactions.forEach(t => {
      if (t.type === 'income' && t.accountId) {
        balances[t.accountId] = (balances[t.accountId] || 0) + t.amount;
      } else if (t.type === 'expense' && t.accountId) {
        balances[t.accountId] = (balances[t.accountId] || 0) - t.amount;
      } else if (t.type === 'transfer') {
        if (t.accountId) balances[t.accountId] = (balances[t.accountId] || 0) - t.amount;
        if (t.toAccountId) {
          const fromAccount = accounts.find(a => a.id === t.accountId);
          const toAccount = accounts.find(a => a.id === t.toAccountId);
          if (fromAccount && toAccount && fromAccount.currency !== toAccount.currency) {
            const convertedAmount = convertCurrency(t.amount, fromAccount.currency, toAccount.currency);
            balances[t.toAccountId] = (balances[t.toAccountId] || 0) + convertedAmount;
          } else {
            balances[t.toAccountId] = (balances[t.toAccountId] || 0) + t.amount;
          }
        }
      }
    });

    return balances;
  }, [accounts, transactions, rates]);

  // Группируем балансы по валютам
  const totalsByCurrency = useMemo(() => {
    const totals: Record<string, number> = {};
    accounts.forEach(acc => {
      const currentBalance = accountBalances[acc.id] || 0;
      totals[acc.currency] = (totals[acc.currency] || 0) + currentBalance;
    });
    return totals;
  }, [accounts, accountBalances]);

  return (
    <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
      
      {/* Итоговые балансы по валютам */}
      {Object.keys(totalsByCurrency).length > 0 && (
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
          {Object.entries(totalsByCurrency).map(([curr, total]) => {
            const currencyInfo = CURRENCIES.find(c => c.value === curr);
            return (
              <div key={curr} className="bg-white border border-stone-200 rounded-xl p-4">
                <p className="text-sm text-zinc-500 mb-1">{currencyInfo?.label || curr}</p>
                <p className="text-xl font-bold text-zinc-900">
                  {total.toFixed(2)} {currencyInfo?.symbol || curr}
                </p>
              </div>
            );
          })}
        </div>
      )}

      <div className="flex items-center justify-between">
        <h2 className="text-lg font-bold text-zinc-900">Мои счета</h2>
        <button 
          onClick={() => {
            if (isAdding) {
              setIsAdding(false);
              resetForm();
            } else {
              setIsAdding(true);
            }
          }}
          className="p-2 bg-stone-100 text-zinc-900 rounded-xl hover:bg-stone-200 transition-colors"
        >
          <Plus className={cn("w-5 h-5 transition-transform", isAdding && "rotate-45")} />
        </button>
      </div>

      {isAdding && (
        <form onSubmit={handleAddAccount} className="bg-white p-4 rounded-xl border border-stone-200 space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs text-zinc-500 mb-1">Название счета</label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Карта Альфа-Банк"
                className="w-full bg-stone-100 text-zinc-900 rounded-lg px-3 py-2 border border-stone-300 focus:outline-none focus:border-blue-500"
                required
              />
            </div>
            <div>
              <label className="block text-xs text-zinc-500 mb-1">Начальный баланс</label>
              <input
                type="number"
                step="0.01"
                value={initialBalance}
                onChange={(e) => setInitialBalance(e.target.value)}
                placeholder="0.00"
                className="w-full bg-stone-100 text-zinc-900 rounded-lg px-3 py-2 border border-stone-300 focus:outline-none focus:border-blue-500"
                required
              />
            </div>
            <div>
              <label className="block text-xs text-zinc-500 mb-1">Тип счета</label>
              <select
                value={type}
                onChange={(e) => setType(e.target.value as AccountType)}
                className="w-full bg-stone-100 text-zinc-900 rounded-lg px-3 py-2 border border-stone-300 focus:outline-none focus:border-blue-500"
              >
                {ACCOUNT_TYPES.map(t => (
                  <option key={t.value} value={t.value}>{t.label}</option>
                ))}
              </select>
            </div>
            <div className="grid grid-cols-2 gap-2">
              <div>
                <label className="block text-xs text-zinc-500 mb-1">Валюта</label>
                <select
                  value={currency}
                  onChange={(e) => setCurrency(e.target.value as Currency)}
                  className="w-full bg-stone-100 text-zinc-900 rounded-lg px-3 py-2 border border-stone-300 focus:outline-none focus:border-blue-500"
                >
                  {CURRENCIES.map(c => (
                    <option key={c.value} value={c.value}>{c.value} ({c.symbol})</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-xs text-zinc-500 mb-1">Цвет</label>
                <input
                  type="color"
                  value={color}
                  onChange={(e) => setColor(e.target.value)}
                  className="w-full h-[38px] bg-stone-100 rounded-lg border border-stone-300 cursor-pointer"
                />
              </div>
            </div>
          </div>
          <div className="flex justify-end gap-2 pt-2">
            <button type="button" onClick={() => { setIsAdding(false); resetForm(); }} className="px-4 py-2 text-sm text-zinc-500 hover:text-zinc-900">Отмена</button>
            <button type="submit" className="px-4 py-2 bg-blue-600 text-zinc-900 text-sm font-medium rounded-lg hover:bg-blue-700">
              {editingId ? 'Сохранить' : 'Создать счет'}
            </button>
          </div>
        </form>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {accounts.map(account => {
          const TypeIcon = ACCOUNT_TYPES.find(t => t.value === account.type)?.icon || Wallet;
          const currencySymbol = CURRENCIES.find(c => c.value === account.currency)?.symbol || account.currency;
          const currentBalance = accountBalances[account.id] || 0;
          
          return (
            <div key={account.id} className="bg-white rounded-xl border border-stone-200 overflow-hidden relative group">
              <div className="absolute top-0 left-0 w-full h-1" style={{ backgroundColor: account.color || '#3b82f6' }} />
              <div className="p-4">
                <div className="flex justify-between items-start mb-4">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-stone-100 flex items-center justify-center" style={{ color: account.color || '#3b82f6' }}>
                      <TypeIcon className="w-5 h-5" />
                    </div>
                    <div>
                      <h3 className="font-medium text-zinc-900">{account.name}</h3>
                      <p className="text-xs text-zinc-500">{ACCOUNT_TYPES.find(t => t.value === account.type)?.label}</p>
                    </div>
                  </div>
                  <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button onClick={() => handleEdit(account)} className="p-1.5 text-zinc-500 hover:text-zinc-900 rounded-lg hover:bg-stone-100">
                      <Edit2 className="w-4 h-4" />
                    </button>
                    <button onClick={() => deleteAccount(account.id)} className="p-1.5 text-zinc-500 hover:text-red-400 rounded-lg hover:bg-stone-100">
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
                
                <div>
                  <p className="text-sm text-zinc-500 mb-1">Текущий баланс</p>
                  <div className="flex items-baseline gap-1">
                    <span className="text-2xl font-bold text-zinc-900">{currentBalance.toFixed(2)}</span>
                    <span className="text-zinc-500">{currencySymbol}</span>
                  </div>
                </div>
              </div>
            </div>
          );
        })}
        {accounts.length === 0 && !isAdding && (
          <div className="col-span-full text-center py-12 text-zinc-500 bg-white/60 rounded-xl border border-stone-200 border-dashed">
            <Wallet className="w-12 h-12 mx-auto mb-3 opacity-20" />
            <p>У вас пока нет добавленных счетов.</p>
            <p className="text-sm mt-1">Добавьте банковскую карту, наличные или криптокошелек.</p>
          </div>
        )}
      </div>
    </div>
  );
}
