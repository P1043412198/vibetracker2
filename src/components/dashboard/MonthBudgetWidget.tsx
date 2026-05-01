import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { startOfMonth, format, subMonths, addMonths } from 'date-fns';
import { ru } from 'date-fns/locale';
import { ChevronLeft, ChevronRight, Wallet, ArrowUpRight } from 'lucide-react';
import { useStore } from '../../store/useStore';
import { useCurrencyConverter } from '../../hooks/useCurrencyConverter';
import {
  monthKeyOf, computeMonthFacts, daysLeftInMonth,
  computeFreeFunds, dailyAllowance,
} from '../../lib/monthlyBudget';
import type { Currency } from '../../types';

function MiniDonut({ income, expense, free }: { income: number; expense: number; free: number }) {
  const size = 96;
  const thickness = 12;
  const r = (size - thickness) / 2;
  const c = 2 * Math.PI * r;
  const denom = Math.max(income, expense + Math.max(free, 0), 1);
  const expLen = (expense / denom) * c;
  const freeLen = (Math.max(free, 0) / denom) * c;
  return (
    <svg width={size} height={size} className="block">
      <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="rgba(34,197,94,0.12)" strokeWidth={thickness} />
      <circle
        cx={size / 2} cy={size / 2} r={r} fill="none" stroke="#E07A5F" strokeWidth={thickness}
        strokeDasharray={`${expLen} ${c - expLen}`}
        strokeDashoffset={c / 4}
        transform={`rotate(-90 ${size / 2} ${size / 2})`}
      />
      <circle
        cx={size / 2} cy={size / 2} r={r} fill="none" stroke="#34D399" strokeWidth={thickness}
        strokeDasharray={`${freeLen} ${c - freeLen}`}
        strokeDashoffset={c / 4 - expLen}
        transform={`rotate(-90 ${size / 2} ${size / 2})`}
      />
    </svg>
  );
}

export function MonthBudgetWidget() {
  const {
    transactions = [],
    accounts = [],
    monthlyBudgetPlans = [],
    baseCurrency = 'USD',
  } = useStore();
  const convert = useCurrencyConverter();

  const [month, setMonth] = useState<Date>(() => startOfMonth(new Date()));
  const monthKey = monthKeyOf(month);

  const plan = useMemo(
    () => monthlyBudgetPlans.find(p => p.monthKey === monthKey),
    [monthlyBudgetPlans, monthKey]
  );
  const planCurrency: Currency = (plan?.currency as Currency) || baseCurrency;

  const stats = useMemo(
    () => computeMonthFacts({ month, transactions, accounts, baseCurrency: planCurrency, convert }),
    [month, transactions, accounts, planCurrency, convert]
  );

  const plannedIncome = plan?.plannedIncome ?? 0;
  const { incomeRef, free } = computeFreeFunds(plannedIncome, stats.income, stats.expense);
  const daily = dailyAllowance(free, daysLeftInMonth(month));

  const fmt = (v: number) => `${Math.round(v).toLocaleString('ru-RU')} ${planCurrency}`;

  return (
    <div className="bg-zinc-900/80 border border-zinc-800 rounded-3xl p-5 h-full flex flex-col">
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <Wallet className="w-4 h-4 text-emerald-400" />
          <h3 className="text-sm font-semibold text-white">Бюджет месяца</h3>
        </div>
        <div className="flex items-center gap-1">
          <button
            onClick={() => setMonth(m => subMonths(m, 1))}
            className="p-1 rounded-lg hover:bg-zinc-800 text-zinc-400"
            aria-label="Предыдущий месяц"
          >
            <ChevronLeft className="w-3.5 h-3.5" />
          </button>
          <span className="text-xs text-zinc-300 capitalize min-w-[70px] text-center font-medium">
            {format(month, 'LLL yyyy', { locale: ru })}
          </span>
          <button
            onClick={() => setMonth(m => addMonths(m, 1))}
            className="p-1 rounded-lg hover:bg-zinc-800 text-zinc-400"
            aria-label="Следующий месяц"
          >
            <ChevronRight className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      <div className="flex items-center gap-4 flex-1">
        <div className="relative">
          <MiniDonut income={incomeRef} expense={stats.expense} free={free} />
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <span className="text-[9px] uppercase tracking-wide text-zinc-400 font-bold">Свободно</span>
            <span className={`text-xs font-black ${free >= 0 ? 'text-emerald-300' : 'text-rose-300'}`}>
              {fmt(free)}
            </span>
          </div>
        </div>
        <div className="flex-1 space-y-1.5 text-xs">
          <Row label="Доход" value={fmt(incomeRef)} accent="emerald" />
          <Row label="Расход" value={fmt(stats.expense)} accent="rose" />
          <Row label="В день" value={fmt(daily)} accent="emerald" />
          {!plan && (
            <p className="text-[10px] text-amber-300/80 mt-1">План на месяц не задан</p>
          )}
        </div>
      </div>

      <Link
        to="/finance?tab=monthly-plan"
        className="mt-3 inline-flex items-center justify-center gap-1.5 text-xs font-semibold text-emerald-300 hover:text-emerald-200 bg-emerald-500/10 hover:bg-emerald-500/20 rounded-xl py-2 transition-colors"
      >
        Открыть план месяца <ArrowUpRight className="w-3.5 h-3.5" />
      </Link>
    </div>
  );
}

function Row({ label, value, accent }: { label: string; value: string; accent: 'emerald' | 'rose' }) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-zinc-400">{label}</span>
      <span className={`font-bold tabular-nums ${accent === 'emerald' ? 'text-emerald-300' : 'text-rose-300'}`}>
        {value}
      </span>
    </div>
  );
}
