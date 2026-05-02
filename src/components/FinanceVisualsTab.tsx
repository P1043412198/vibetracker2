/**
 * Финансы → новая вкладка «Графики»: Sankey доходы→расходы, Treemap расходов
 * с цветом по % от плана, чистая стоимость + донат по валютам, календарь
 * трат за полгода.
 */
import React, { useMemo, useState } from 'react';
import {
  endOfMonth,
  format,
  parseISO,
  startOfMonth,
  startOfYear,
  subMonths,
} from 'date-fns';
import { ru } from 'date-fns/locale';
import { useStore } from '../store/useStore';
import { useCurrencyConverter } from '../hooks/useCurrencyConverter';
import { formatCurrency } from '../lib/format';
import { SankeyFlow } from './charts/SankeyFlow';
import { TreemapExpenses } from './charts/TreemapExpenses';
import { NetWorthChart, type NetWorthPoint } from './charts/NetWorthChart';
import { CurrencyDonut } from './charts/CurrencyDonut';
import { ExpensesCalendarHeatmap } from './charts/ExpensesCalendarHeatmap';
import { currencyExposure } from '../lib/finance/calculators';

type Range = 'month' | 'quarter' | 'year';

const RANGES: { id: Range; label: string }[] = [
  { id: 'month', label: 'Месяц' },
  { id: 'quarter', label: 'Квартал' },
  { id: 'year', label: 'Год' },
];

export function FinanceVisualsTab() {
  const { transactions = [], accounts = [], loans = [], rates = {}, baseCurrency = 'BYN', monthlyBudgetPlans = [] } = useStore();
  const convert = useCurrencyConverter();
  const [range, setRange] = useState<Range>('month');

  const since = useMemo(() => {
    const now = new Date();
    if (range === 'month') return startOfMonth(now);
    if (range === 'quarter') return startOfMonth(subMonths(now, 2));
    return startOfYear(now);
  }, [range]);

  const txInRange = useMemo(
    () =>
      transactions.filter((t) => {
        const d = parseISO(t.date);
        return d >= since;
      }),
    [transactions, since]
  );

  const fmt = (n: number) => formatCurrency(n, baseCurrency);

  /** Pull the currency from the txn's account. Falls back to base. */
  const txCurrency = (t: { accountId?: string }) => {
    const a = accounts.find((x) => x.id === t.accountId);
    return a?.currency ?? baseCurrency;
  };

  // Sankey: income source → "Доход" → expense category
  const sankeyFlows = useMemo(() => {
    const incomeBySource = new Map<string, number>();
    const expenseByCategory = new Map<string, number>();
    for (const t of txInRange) {
      const baseAmount = convert(t.amount, txCurrency(t), baseCurrency);
      if (t.type === 'income') {
        incomeBySource.set(t.category, (incomeBySource.get(t.category) ?? 0) + baseAmount);
      } else if (t.type === 'expense') {
        expenseByCategory.set(t.category, (expenseByCategory.get(t.category) ?? 0) + baseAmount);
      }
    }
    const flows: { source: string; target: string; value: number }[] = [];
    for (const [src, v] of incomeBySource) {
      flows.push({ source: src, target: 'Доход', value: v });
    }
    for (const [cat, v] of expenseByCategory) {
      flows.push({ source: 'Доход', target: cat, value: v });
    }
    return flows;
  }, [txInRange, convert, baseCurrency]);

  // Treemap: expense category → amount + plan
  const treemap = useMemo(() => {
    const expByCat = new Map<string, number>();
    for (const t of txInRange) {
      if (t.type !== 'expense') continue;
      const baseAmount = convert(t.amount, txCurrency(t), baseCurrency);
      expByCat.set(t.category, (expByCat.get(t.category) ?? 0) + baseAmount);
    }
    // Match categories to current month's plan (if it exists).
    const currentMonth = format(new Date(), 'yyyy-MM');
    const plan = monthlyBudgetPlans.find((p) => p.monthKey === currentMonth);
    const planByCat = new Map<string, number>();
    if (plan?.categoryPlans) {
      for (const cp of plan.categoryPlans) {
        planByCat.set(cp.category, cp.planned);
      }
    }
    return Array.from(expByCat.entries()).map(([category, value]) => ({
      category,
      value,
      plan: planByCat.get(category),
    }));
  }, [txInRange, convert, baseCurrency, monthlyBudgetPlans]);

  // Net worth time series — last 12 months
  const netWorthPoints = useMemo<NetWorthPoint[]>(() => {
    const months: NetWorthPoint[] = [];
    const now = new Date();
    for (let i = 11; i >= 0; i--) {
      const month = subMonths(now, i);
      const monthEnd = endOfMonth(month);
      const byCurrency: Record<string, number> = {};
      for (const acc of accounts) {
        const flowsThroughEnd = transactions
          .filter((t) => parseISO(t.date) <= monthEnd)
          .filter((t) => t.accountId === acc.id || t.toAccountId === acc.id);
        let bal = acc.initialBalance;
        for (const t of flowsThroughEnd) {
          if (t.type === 'income' && t.accountId === acc.id) bal += t.amount;
          else if (t.type === 'expense' && t.accountId === acc.id) bal -= t.amount;
          else if (t.type === 'transfer') {
            if (t.accountId === acc.id) bal -= t.amount;
            if (t.toAccountId === acc.id) bal += t.amount;
          }
        }
        const baseAmount = convert(bal, acc.currency, baseCurrency);
        byCurrency[acc.currency] = (byCurrency[acc.currency] ?? 0) + baseAmount;
      }
      const liabilities = loans.reduce((s, loan) => {
        // Approximate remaining principal by subtracting paid-down portion.
        const paid = (loan.payments ?? [])
          .filter((p) => parseISO(p.date) <= monthEnd)
          .reduce((sum, p) => sum + (p.type === 'payment' ? p.amount : -p.amount), 0);
        const remaining = Math.max(0, loan.amount - paid);
        return s + convert(remaining, loan.currency ?? baseCurrency, baseCurrency);
      }, 0);
      months.push({
        date: format(month, 'MMM yy', { locale: ru }),
        byCurrency,
        liabilities,
      });
    }
    return months;
  }, [accounts, transactions, loans, convert, baseCurrency]);

  const exposure = useMemo(() => {
    const buckets = accounts.map((acc) => ({
      currency: acc.currency,
      amount:
        acc.initialBalance +
        transactions
          .filter((t) => t.accountId === acc.id || t.toAccountId === acc.id)
          .reduce((s, t) => {
            if (t.type === 'income' && t.accountId === acc.id) return s + t.amount;
            if (t.type === 'expense' && t.accountId === acc.id) return s - t.amount;
            if (t.type === 'transfer') {
              if (t.accountId === acc.id) return s - t.amount;
              if (t.toAccountId === acc.id) return s + t.amount;
            }
            return s;
          }, 0),
    }));
    return currencyExposure(buckets, rates, baseCurrency);
  }, [accounts, transactions, rates, baseCurrency]);

  const expensesByDate = useMemo(() => {
    const map: Record<string, number> = {};
    for (const t of transactions) {
      if (t.type !== 'expense') continue;
      const baseAmount = convert(t.amount, txCurrency(t), baseCurrency);
      map[t.date] = (map[t.date] ?? 0) + baseAmount;
    }
    return map;
  }, [transactions, convert, baseCurrency]);

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between gap-2 flex-wrap">
        <h2 className="text-base font-semibold text-zinc-900">Графики и потоки</h2>
        <div className="flex gap-1 bg-stone-100 p-1 rounded-xl">
          {RANGES.map((r) => (
            <button
              key={r.id}
              onClick={() => setRange(r.id)}
              className={
                'px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ' +
                (range === r.id
                  ? 'bg-white text-zinc-900 shadow-sm'
                  : 'text-zinc-500 hover:text-zinc-800')
              }
            >
              {r.label}
            </button>
          ))}
        </div>
      </div>

      <Card title="Доходы → Расходы (Sankey)">
        <SankeyFlow flows={sankeyFlows} format={fmt} height={340} />
      </Card>

      <Card
        title="Карта расходов (Treemap)"
        hint="Цвет = соотношение факт/план (зелёный — в рамках, красный — перерасход)"
      >
        <TreemapExpenses data={treemap} format={fmt} height={340} />
      </Card>

      <div className="grid lg:grid-cols-3 gap-4">
        <Card className="lg:col-span-2" title="Чистая стоимость по месяцам">
          <NetWorthChart points={netWorthPoints} format={fmt} />
        </Card>
        <Card title="Состав по валютам">
          <CurrencyDonut exposure={exposure} format={fmt} />
        </Card>
      </div>

      <Card title="Календарь трат">
        <ExpensesCalendarHeatmap
          expensesByDate={expensesByDate}
          format={fmt}
        />
      </Card>
    </div>
  );
}

function Card({
  title,
  hint,
  children,
  className,
}: {
  title: string;
  hint?: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <section
      className={
        'bg-white border border-stone-200 rounded-2xl p-3 sm:p-4 ' +
        (className ?? '')
      }
    >
      <header className="mb-2">
        <h3 className="text-xs font-semibold text-zinc-700 uppercase tracking-wider">
          {title}
        </h3>
        {hint && <p className="text-[10px] text-zinc-500 mt-0.5">{hint}</p>}
      </header>
      {children}
    </section>
  );
}


