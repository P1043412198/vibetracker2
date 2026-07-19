import React, { useMemo } from 'react';
import { Link } from 'react-router-dom';
import { Wallet, AlertTriangle } from 'lucide-react';
import { format } from 'date-fns';
import { ru } from 'date-fns/locale';
import { useStore } from '../../store/useStore';
import { cn } from '../../lib/utils';
import { computeCashflowForecast, loansAsPlannedExpenses } from '../../lib/finance/budgetPlanner';
import type { PlannedExpense } from '../../types';

function pluralizeDays(n: number): string {
  const mod10 = n % 10;
  const mod100 = n % 100;
  if (mod10 === 1 && mod100 !== 11) return 'день';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return 'дня';
  return 'дней';
}

/**
 * Compact "сколько можно тратить в день до следующей зарплаты" widget.
 * Anchored to the real balance over the selected accounts (so it reflects
 * actual spending live) minus planned obligations + loans. Uses the `auto`
 * range mode = today → next salary. Shown by default on the Dashboard and the
 * Finance hub; tapping it opens the full safe-to-spend card.
 */
export const SafeToSpendMini: React.FC<{ compact?: boolean }> = ({ compact = false }) => {
  const {
    accounts, transactions, rates, baseCurrency, incomeSources, plannedExpenses,
    loans, safeToSpendReserve, safeToSpendAccountIds,
  } = useStore();

  const forecast = useMemo(() => {
    const loanExpenses = loansAsPlannedExpenses({
      loans: loans || [],
      rates: rates || {},
      baseCurrency: baseCurrency || 'BYN',
    });
    const planned: PlannedExpense[] = loanExpenses.length > 0
      ? [...(plannedExpenses || []), ...loanExpenses]
      : (plannedExpenses || []);
    return computeCashflowForecast({
      accounts: accounts || [],
      transactions: transactions || [],
      rates: rates || {},
      baseCurrency: baseCurrency || 'BYN',
      incomeSources: incomeSources || [],
      plannedExpenses: planned,
      reserve: safeToSpendReserve || 0,
      rangeMode: 'auto',
      accountIds: safeToSpendAccountIds || [],
    });
  }, [accounts, transactions, rates, baseCurrency, incomeSources, plannedExpenses, loans, safeToSpendReserve, safeToSpendAccountIds]);

  const ccy = baseCurrency || 'BYN';
  const range = forecast.range;
  const daily = range ? range.smoothedDaily : forecast.dailyUntilNextIncome;
  const fmt = (n: number) => Math.round(n).toLocaleString('ru-RU');

  const body = !forecast.ok || !range ? (
    <p className="text-xs text-zinc-400">
      Добавьте доходы и счёт, чтобы рассчитать дневной лимит.
    </p>
  ) : (
    <>
      <div className="flex items-baseline gap-1.5">
        <span className={cn('text-2xl font-black', forecast.hasCashGap ? 'text-rose-500' : 'text-emerald-600')}>
          {fmt(daily)}
        </span>
        <span className="text-xs font-medium text-zinc-500">{ccy}/день</span>
      </div>
      <p className="text-[11px] text-zinc-500 mt-0.5">
        до {format(range.endDate, 'd MMM', { locale: ru })}
        {' · '}осталось {range.daysLeft} {pluralizeDays(range.daysLeft)}
      </p>
      <p className="text-[10px] text-zinc-400 mt-0.5">
        Сейчас на счетах {fmt(range.startBalance)} {ccy}
      </p>
      {forecast.hasCashGap && (
        <div className="flex items-center gap-1.5 mt-2 px-2 py-1 bg-rose-50 rounded-lg border border-rose-100">
          <AlertTriangle className="w-3.5 h-3.5 text-rose-500 shrink-0" />
          <span className="text-[10px] text-rose-600">Кассовый разрыв до зарплаты</span>
        </div>
      )}
    </>
  );

  if (compact) {
    return (
      <Link
        to="/finance"
        className="block bg-stone-50 p-3 rounded-2xl border border-stone-200 hover:border-stone-300 transition-colors"
      >
        <p className="text-[8px] text-zinc-500 uppercase tracking-wider mb-1 flex items-center gap-1">
          <Wallet className="w-3 h-3" /> Можно тратить
        </p>
        {body}
      </Link>
    );
  }

  return (
    <div className="bg-white p-4 rounded-3xl shadow-sm border border-stone-200">
      <div className="flex items-center justify-between mb-2">
        <h2 className="text-sm font-semibold text-zinc-900 flex items-center gap-2">
          <Wallet className="w-4 h-4 text-emerald-500" />
          Сколько можно тратить
        </h2>
        <Link to="/finance" className="text-[10px] text-zinc-500 hover:text-zinc-900 transition-colors">Подробнее</Link>
      </div>
      {body}
    </div>
  );
};
