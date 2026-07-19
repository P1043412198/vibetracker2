import React, { useMemo, useState } from 'react';
import { useStore } from '../store/useStore';
import { useCurrencyConverter } from '../hooks/useCurrencyConverter';
import { getDueRecurring } from '../lib/finance/recurring';
import { cn } from '../lib/utils';
import { CalendarClock, Check, X, ArrowDownCircle, ArrowUpCircle } from 'lucide-react';

const FREQ_LABEL: Record<string, string> = {
  weekly: 'еженедельно',
  biweekly: 'раз в 2 недели',
  monthly: 'ежемесячно',
  yearly: 'ежегодно',
};

function formatDate(iso: string): string {
  try {
    return new Date(iso + 'T00:00:00Z').toLocaleDateString('ru-RU', {
      day: 'numeric',
      month: 'short',
      timeZone: 'UTC',
    });
  } catch {
    return iso;
  }
}

/**
 * Surfaces recurring rules whose latest occurrence is due and awaiting the
 * user's confirmation. One tap posts the transaction to the chosen account;
 * "Пропустить" dismisses just this occurrence.
 */
export function RecurringReviewCard({ compact = false }: { compact?: boolean }) {
  const {
    regularPayments = [],
    transactions = [],
    recurringSkips = [],
    accounts = [],
    baseCurrency = 'BYN',
    confirmRecurring,
    skipRecurring,
  } = useStore();
  const convertCurrency = useCurrencyConverter();

  const todayISO = new Date().toISOString().split('T')[0];
  const due = useMemo(
    () => getDueRecurring(regularPayments, transactions, recurringSkips, todayISO),
    [regularPayments, transactions, recurringSkips, todayISO],
  );

  const [accountByRule, setAccountByRule] = useState<Record<string, string>>({});

  if (due.length === 0) return null;

  return (
    <div className="bg-amber-500/10 border border-amber-500/30 rounded-2xl p-4 space-y-3">
      <div className="flex items-center gap-2">
        <CalendarClock className="w-5 h-5 text-amber-500" />
        <h3 className="font-bold text-zinc-900">
          Подтвердите регулярные операции
          <span className="ml-2 text-xs font-semibold text-amber-600">{due.length}</span>
        </h3>
      </div>

      <div className="space-y-2">
        {due.map(({ rule, periodKey, dateISO, ref }) => {
          const isIncome = rule.type === 'income';
          const defaultAccount =
            (rule.accountId && accounts.some((a) => a.id === rule.accountId) ? rule.accountId : '') ||
            accounts[0]?.id ||
            '';
          const accountId = accountByRule[ref] ?? defaultAccount;
          const inBase = convertCurrency(rule.amount, rule.currency || baseCurrency, baseCurrency);

          return (
            <div
              key={ref}
              className="bg-white rounded-xl border border-stone-200 p-3 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between"
            >
              <div className="flex items-center gap-3 min-w-0">
                {isIncome ? (
                  <ArrowUpCircle className="w-5 h-5 text-emerald-500 shrink-0" />
                ) : (
                  <ArrowDownCircle className="w-5 h-5 text-red-400 shrink-0" />
                )}
                <div className="min-w-0">
                  <p className="font-medium text-zinc-900 truncate">{rule.name}</p>
                  <p className="text-xs text-zinc-500">
                    {formatDate(dateISO)} · {FREQ_LABEL[rule.frequency || 'monthly']} · {rule.category}
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-2 flex-wrap">
                <span className={cn('font-bold whitespace-nowrap', isIncome ? 'text-emerald-600' : 'text-zinc-900')}>
                  {isIncome ? '+' : '−'}
                  {rule.amount.toFixed(2)} {rule.currency || baseCurrency}
                </span>
                {(rule.currency || baseCurrency) !== baseCurrency && (
                  <span className="text-[11px] text-zinc-400 whitespace-nowrap">≈ {inBase.toFixed(2)} {baseCurrency}</span>
                )}

                {!compact && accounts.length > 1 && (
                  <select
                    value={accountId}
                    onChange={(e) => setAccountByRule((m) => ({ ...m, [ref]: e.target.value }))}
                    className="bg-stone-100 text-xs text-zinc-900 rounded-lg px-2 py-1.5 border border-stone-300 focus:outline-none focus:border-amber-500"
                  >
                    {accounts.map((a) => (
                      <option key={a.id} value={a.id}>{a.name}</option>
                    ))}
                  </select>
                )}

                <button
                  onClick={() => confirmRecurring(rule.id, periodKey, accountId || undefined)}
                  className="flex items-center gap-1 text-xs font-medium bg-emerald-600 text-white px-3 py-1.5 rounded-lg hover:bg-emerald-700"
                >
                  <Check className="w-3.5 h-3.5" /> Подтвердить
                </button>
                <button
                  onClick={() => skipRecurring(rule.id, periodKey)}
                  className="flex items-center gap-1 text-xs text-zinc-500 px-2 py-1.5 rounded-lg hover:bg-stone-100"
                >
                  <X className="w-3.5 h-3.5" /> Пропустить
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
