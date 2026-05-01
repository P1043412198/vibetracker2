import React, { useMemo, useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  format, startOfMonth, endOfMonth, parseISO, isWithinInterval,
  getDaysInMonth, getDate, addMonths, subMonths, isSameMonth, isAfter,
} from 'date-fns';
import { ru } from 'date-fns/locale';
import {
  ChevronLeft, ChevronRight, Plus, Save, Trash2, Edit3, X,
  TrendingUp, TrendingDown, Wallet, Calculator, Sparkles, AlertTriangle,
  CheckCircle2, Calendar,
} from 'lucide-react';
import { useStore } from '../store/useStore';
import { useCurrencyConverter } from '../hooks/useCurrencyConverter';
import { cn } from '../lib/utils';
import type { MonthlyBudgetPlan, Currency } from '../types';

// Default expense categories used when no plan exists yet
const DEFAULT_CATEGORIES = [
  'Продукты', 'Транспорт', 'Жильё', 'Развлечения', 'Одежда',
  'Здоровье', 'Рестораны', 'Связь', 'Подарки', 'Подписки', 'Другое',
];

const monthKeyOf = (date: Date) => format(date, 'yyyy-MM');

function formatMoney(value: number, currency: string) {
  return `${value.toLocaleString('ru-RU', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  })} ${currency}`;
}

type CategoryRow = { category: string; planned: number; actual: number };

interface DonutProps {
  income: number;
  expense: number;
  free: number; // can be negative
  size?: number;
  thickness?: number;
}

/**
 * Custom-painted donut showing income / expense / free split.
 * Income = full circle. Expense + Free fill the ring proportionally.
 */
function BudgetDonut({ income, expense, free, size = 220, thickness = 22 }: DonutProps) {
  const radius = (size - thickness) / 2;
  const c = 2 * Math.PI * radius;

  const denom = Math.max(income, expense + Math.max(free, 0), 1);
  const expenseLen = (expense / denom) * c;
  const freeLen = (Math.max(free, 0) / denom) * c;

  return (
    <svg width={size} height={size} className="block">
      {/* Track */}
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        fill="none"
        stroke="#E5F0E5"
        strokeWidth={thickness}
      />
      {/* Expense arc (red-ish) */}
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        fill="none"
        stroke="#E07A5F"
        strokeWidth={thickness}
        strokeDasharray={`${expenseLen} ${c - expenseLen}`}
        strokeDashoffset={c / 4}
        transform={`rotate(-90 ${size / 2} ${size / 2})`}
        strokeLinecap="butt"
      />
      {/* Free arc (green) */}
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        fill="none"
        stroke="#2E7D52"
        strokeWidth={thickness}
        strokeDasharray={`${freeLen} ${c - freeLen}`}
        strokeDashoffset={c / 4 - expenseLen}
        transform={`rotate(-90 ${size / 2} ${size / 2})`}
        strokeLinecap="butt"
      />
    </svg>
  );
}

interface MonthPickerProps {
  value: Date;
  onChange: (d: Date) => void;
}

function MonthPicker({ value, onChange }: MonthPickerProps) {
  const [open, setOpen] = useState(false);
  const [yearCursor, setYearCursor] = useState(value.getFullYear());

  return (
    <div className="relative">
      <div className="flex items-center gap-1 bg-white border border-emerald-100 rounded-2xl p-1 shadow-sm">
        <button
          onClick={() => onChange(subMonths(value, 1))}
          className="p-2 hover:bg-emerald-50 rounded-xl text-emerald-700 transition-colors"
          aria-label="Предыдущий месяц"
        >
          <ChevronLeft className="w-4 h-4" />
        </button>
        <button
          onClick={() => setOpen(o => !o)}
          className="px-3 py-1.5 text-sm font-semibold text-emerald-900 capitalize min-w-[140px]"
        >
          {format(value, 'LLLL yyyy', { locale: ru })}
        </button>
        <button
          onClick={() => onChange(addMonths(value, 1))}
          className="p-2 hover:bg-emerald-50 rounded-xl text-emerald-700 transition-colors"
          aria-label="Следующий месяц"
        >
          <ChevronRight className="w-4 h-4" />
        </button>
      </div>

      {open && (
        <div className="absolute right-0 mt-2 z-30 bg-white border border-emerald-100 rounded-2xl shadow-lg p-3 w-[280px]">
          <div className="flex items-center justify-between mb-3">
            <button
              onClick={() => setYearCursor(yearCursor - 1)}
              className="p-1.5 hover:bg-emerald-50 rounded-lg text-emerald-700"
            >
              <ChevronLeft className="w-4 h-4" />
            </button>
            <span className="font-semibold text-emerald-900">{yearCursor}</span>
            <button
              onClick={() => setYearCursor(yearCursor + 1)}
              className="p-1.5 hover:bg-emerald-50 rounded-lg text-emerald-700"
            >
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>
          <div className="grid grid-cols-3 gap-1.5">
            {Array.from({ length: 12 }).map((_, i) => {
              const d = new Date(yearCursor, i, 1);
              const active = isSameMonth(d, value);
              return (
                <button
                  key={i}
                  onClick={() => { onChange(d); setOpen(false); }}
                  className={cn(
                    "px-2 py-2 text-xs font-medium rounded-xl capitalize transition-colors",
                    active
                      ? "bg-emerald-600 text-white shadow-sm"
                      : "text-emerald-900 hover:bg-emerald-50"
                  )}
                >
                  {format(d, 'LLL', { locale: ru })}
                </button>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}

export function MonthlyBudgetPlanTab() {
  const {
    transactions = [],
    accounts = [],
    monthlyBudgetPlans = [],
    saveMonthlyBudgetPlan,
    deleteMonthlyBudgetPlan,
    baseCurrency = 'BYN',
  } = useStore();

  const convert = useCurrencyConverter();

  const [month, setMonth] = useState<Date>(() => startOfMonth(new Date()));
  const monthKey = monthKeyOf(month);

  const plan = useMemo(
    () => monthlyBudgetPlans.find(p => p.monthKey === monthKey),
    [monthlyBudgetPlans, monthKey]
  );

  // Compute factual income/expense for selected month in base currency.
  const stats = useMemo(() => {
    const start = startOfMonth(month);
    const end = endOfMonth(month);
    const monthTx = transactions.filter(t => {
      try {
        return isWithinInterval(parseISO(t.date), { start, end });
      } catch {
        return false;
      }
    });

    const income = monthTx
      .filter(t => t.type === 'income')
      .reduce((sum, t) => {
        const acc = accounts.find(a => a.id === t.accountId);
        const cur = acc?.currency || baseCurrency;
        return sum + convert(t.amount, cur, baseCurrency);
      }, 0);

    const expense = monthTx
      .filter(t => t.type === 'expense')
      .reduce((sum, t) => {
        const acc = accounts.find(a => a.id === t.accountId);
        const cur = acc?.currency || baseCurrency;
        return sum + convert(t.amount, cur, baseCurrency);
      }, 0);

    const expenseByCategory: Record<string, number> = {};
    for (const t of monthTx) {
      if (t.type !== 'expense') continue;
      const acc = accounts.find(a => a.id === t.accountId);
      const cur = acc?.currency || baseCurrency;
      const v = convert(t.amount, cur, baseCurrency);
      expenseByCategory[t.category] = (expenseByCategory[t.category] || 0) + v;
    }

    return { income, expense, expenseByCategory, monthTx };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [transactions, accounts, month, baseCurrency]);

  const plannedIncome = plan?.plannedIncome ?? 0;
  const plannedTotalExpense = (plan?.categoryPlans || []).reduce((s, c) => s + c.planned, 0);

  // Show planned values when a plan exists, otherwise actuals only.
  const incomeRef = plannedIncome > 0 ? plannedIncome : stats.income;
  const expenseRef = stats.expense;
  const free = incomeRef - expenseRef;

  // "Свободно сегодня" / "Можно тратить в день":
  // For current month, use days remaining; for past months use 1; for future, days in month.
  const today = new Date();
  const daysInMonth = getDaysInMonth(month);
  const daysLeft = isSameMonth(month, today)
    ? Math.max(daysInMonth - getDate(today) + 1, 1)
    : isAfter(month, today) ? daysInMonth : 1;

  const dailyAllowance = free > 0 ? free / daysLeft : 0;

  // Build category rows merged from plan + actuals.
  const categoryRows: CategoryRow[] = useMemo(() => {
    const rows = new Map<string, CategoryRow>();
    for (const c of plan?.categoryPlans || []) {
      rows.set(c.category, { category: c.category, planned: c.planned, actual: 0 });
    }
    for (const [cat, val] of Object.entries(stats.expenseByCategory)) {
      const r = rows.get(cat);
      if (r) r.actual = val;
      else rows.set(cat, { category: cat, planned: 0, actual: val });
    }
    return Array.from(rows.values()).sort((a, b) => (b.planned + b.actual) - (a.planned + a.actual));
  }, [plan, stats.expenseByCategory]);

  // Edit modal state
  const [isEditing, setEditing] = useState(false);
  const [editIncome, setEditIncome] = useState<string>('');
  const [editCategories, setEditCategories] = useState<{ category: string; planned: string }[]>([]);
  const [editNotes, setEditNotes] = useState('');

  useEffect(() => {
    if (!isEditing) return;
    setEditIncome(plan?.plannedIncome ? String(plan.plannedIncome) : '');
    setEditNotes(plan?.notes || '');
    if (plan && plan.categoryPlans.length > 0) {
      setEditCategories(plan.categoryPlans.map(c => ({ category: c.category, planned: String(c.planned) })));
    } else {
      // Seed from actual categories or defaults
      const seed = Object.keys(stats.expenseByCategory);
      const cats = seed.length > 0 ? seed : DEFAULT_CATEGORIES;
      setEditCategories(cats.map(c => ({ category: c, planned: '' })));
    }
  }, [isEditing, plan, stats.expenseByCategory]);

  const handleSavePlan = () => {
    const parsedIncome = Number(editIncome) || 0;
    const cleaned = editCategories
      .map(c => ({ category: c.category.trim(), planned: Number(c.planned) || 0 }))
      .filter(c => c.category && c.planned > 0);

    saveMonthlyBudgetPlan({
      ...(plan?.id ? { id: plan.id } : {}),
      monthKey,
      plannedIncome: parsedIncome,
      currency: baseCurrency,
      categoryPlans: cleaned,
      notes: editNotes,
    });
    setEditing(false);
  };

  const applyTemplate503020 = () => {
    const inc = Number(editIncome) || 0;
    if (!inc) return;
    setEditCategories([
      { category: 'Нужды (50%)', planned: String(Math.round(inc * 0.5)) },
      { category: 'Хотелки (30%)', planned: String(Math.round(inc * 0.3)) },
      { category: 'Сбережения (20%)', planned: String(Math.round(inc * 0.2)) },
    ]);
  };

  return (
    <div className="bg-[#F4FAF4] -m-4 sm:-m-6 p-4 sm:p-6 min-h-[calc(100vh-200px)] rounded-3xl text-emerald-950">
      {/* Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between mb-4">
        <div>
          <h2 className="text-xl font-bold text-emerald-900 flex items-center gap-2">
            <Wallet className="w-6 h-6 text-emerald-600" />
            Бюджет на месяц
          </h2>
          <p className="text-sm text-emerald-700/70">
            План vs Факт — выбери любой месяц, задай план и сравни с реальностью
          </p>
        </div>
        <div className="flex items-center gap-2">
          <MonthPicker value={month} onChange={setMonth} />
          <button
            onClick={() => setEditing(true)}
            className="flex items-center gap-2 px-4 py-2 rounded-2xl bg-emerald-600 hover:bg-emerald-700 text-white text-sm font-semibold shadow-sm transition-colors"
          >
            {plan ? <Edit3 className="w-4 h-4" /> : <Plus className="w-4 h-4" />}
            {plan ? 'Редактировать план' : 'Создать план'}
          </button>
        </div>
      </div>

      {/* Summary card */}
      <div className="grid grid-cols-1 lg:grid-cols-[280px_1fr] gap-4 mb-4">
        {/* Donut + center content */}
        <div className="bg-white border border-emerald-100 rounded-3xl p-5 flex flex-col items-center shadow-sm">
          <div className="relative w-[220px] h-[220px] flex items-center justify-center">
            <BudgetDonut income={incomeRef} expense={expenseRef} free={free} />
            <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
              <span className="text-[11px] uppercase tracking-wide text-emerald-700/60 font-bold">Свободно</span>
              <span className={cn(
                "text-2xl font-black",
                free >= 0 ? "text-emerald-700" : "text-rose-600"
              )}>
                {formatMoney(free, baseCurrency)}
              </span>
              <span className="text-[10px] text-emerald-700/60 mt-1">
                из {formatMoney(incomeRef, baseCurrency)}
              </span>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3 w-full mt-4">
            <Stat label="Доход" value={incomeRef} suffix={baseCurrency} accent="emerald" />
            <Stat label="Расход" value={expenseRef} suffix={baseCurrency} accent="rose" />
          </div>
        </div>

        {/* Stat cards: today, daily allowance, plan totals */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <BigStatCard
            icon={<Sparkles className="w-5 h-5 text-emerald-700" />}
            title="Свободно сегодня"
            value={formatMoney(free, baseCurrency)}
            hint={
              isSameMonth(month, today)
                ? `Осталось ${daysLeft} дн.`
                : isAfter(month, today)
                  ? 'Месяц ещё не начался'
                  : 'Месяц завершён'
            }
            accent={free >= 0 ? 'emerald' : 'rose'}
          />
          <BigStatCard
            icon={<Calculator className="w-5 h-5 text-emerald-700" />}
            title="Можно тратить в день"
            value={formatMoney(dailyAllowance, baseCurrency)}
            hint={isSameMonth(month, today) ? 'До конца месяца' : '—'}
            accent="emerald"
          />
          <BigStatCard
            icon={<Wallet className="w-5 h-5 text-emerald-700" />}
            title="План расходов"
            value={formatMoney(plannedTotalExpense, baseCurrency)}
            hint={
              plannedIncome > 0
                ? `Доход: ${formatMoney(plannedIncome, baseCurrency)}`
                : 'План не задан'
            }
            accent="emerald"
          />
        </div>
      </div>

      {/* Plan vs Fact category breakdown */}
      <div className="bg-white border border-emerald-100 rounded-3xl p-5 shadow-sm">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-base font-bold text-emerald-900 flex items-center gap-2">
            <Calendar className="w-5 h-5 text-emerald-600" />
            План vs Факт по категориям
          </h3>
          {plan && (
            <button
              onClick={() => deleteMonthlyBudgetPlan(plan.id)}
              className="text-rose-600 hover:bg-rose-50 px-3 py-1.5 rounded-xl text-xs font-semibold flex items-center gap-1.5 transition-colors"
            >
              <Trash2 className="w-3.5 h-3.5" /> Удалить план
            </button>
          )}
        </div>

        {categoryRows.length === 0 ? (
          <div className="py-10 text-center text-emerald-700/60">
            <Calendar className="w-10 h-10 mx-auto mb-2 text-emerald-400" />
            <p className="text-sm">
              {plan
                ? 'Добавь категории в план или операции в этом месяце'
                : 'Создай план или добавь операции'}
            </p>
          </div>
        ) : (
          <div className="space-y-3">
            {categoryRows.map(row => {
              const planAmt = row.planned;
              const actAmt = row.actual;
              const ratio = planAmt > 0 ? Math.min(actAmt / planAmt, 1.5) : (actAmt > 0 ? 1 : 0);
              const overBudget = planAmt > 0 && actAmt > planAmt;
              const noPlan = planAmt === 0;
              return (
                <div key={row.category} className="space-y-1.5">
                  <div className="flex items-baseline justify-between gap-3">
                    <div className="flex items-center gap-2 min-w-0">
                      <span className="text-sm font-semibold text-emerald-900 truncate">{row.category}</span>
                      {overBudget && (
                        <span className="inline-flex items-center gap-1 text-[10px] font-bold uppercase text-rose-600 bg-rose-50 px-2 py-0.5 rounded-full">
                          <AlertTriangle className="w-3 h-3" /> Превышено
                        </span>
                      )}
                      {noPlan && actAmt > 0 && (
                        <span className="inline-flex items-center gap-1 text-[10px] font-bold uppercase text-amber-700 bg-amber-50 px-2 py-0.5 rounded-full">
                          Без плана
                        </span>
                      )}
                      {!overBudget && !noPlan && actAmt <= planAmt && (
                        <span className="inline-flex items-center gap-1 text-[10px] font-bold uppercase text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full">
                          <CheckCircle2 className="w-3 h-3" /> В рамках
                        </span>
                      )}
                    </div>
                    <div className="text-xs text-emerald-700/70 whitespace-nowrap">
                      <span className={cn("font-bold", overBudget ? "text-rose-600" : "text-emerald-900")}>
                        {formatMoney(actAmt, baseCurrency)}
                      </span>
                      {' / '}
                      <span>{planAmt > 0 ? formatMoney(planAmt, baseCurrency) : '—'}</span>
                    </div>
                  </div>
                  <div className="h-2.5 bg-emerald-50 rounded-full overflow-hidden">
                    <div
                      className={cn(
                        "h-full rounded-full transition-all",
                        overBudget ? "bg-rose-500" : "bg-emerald-500"
                      )}
                      style={{ width: `${(ratio * 100).toFixed(1)}%`, maxWidth: '100%' }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Edit modal */}
      <AnimatePresence>
        {isEditing && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/40 p-2 sm:p-6"
            onClick={() => setEditing(false)}
          >
            <motion.div
              initial={{ y: 40, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              exit={{ y: 40, opacity: 0 }}
              onClick={e => e.stopPropagation()}
              className="bg-white rounded-3xl w-full max-w-2xl max-h-[90vh] overflow-y-auto shadow-2xl"
            >
              <div className="flex items-center justify-between p-5 border-b border-emerald-100 sticky top-0 bg-white z-10">
                <div>
                  <h3 className="text-lg font-bold text-emerald-900 capitalize">
                    План на {format(month, 'LLLL yyyy', { locale: ru })}
                  </h3>
                  <p className="text-xs text-emerald-700/60">Зарплата + лимиты по категориям</p>
                </div>
                <button onClick={() => setEditing(false)} className="p-2 hover:bg-emerald-50 rounded-xl text-emerald-700">
                  <X className="w-5 h-5" />
                </button>
              </div>

              <div className="p-5 space-y-4">
                <div>
                  <label className="text-xs font-bold uppercase text-emerald-700/70 tracking-wide block mb-1.5">
                    Планируемый доход
                  </label>
                  <div className="flex items-center gap-2">
                    <input
                      type="number"
                      inputMode="decimal"
                      value={editIncome}
                      onChange={e => setEditIncome(e.target.value)}
                      placeholder="0"
                      className="flex-1 px-4 py-3 rounded-2xl border border-emerald-200 bg-emerald-50/40 text-emerald-900 text-lg font-semibold focus:outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-200"
                    />
                    <span className="text-emerald-700 font-semibold">{baseCurrency}</span>
                  </div>
                  <button
                    onClick={applyTemplate503020}
                    className="mt-2 text-xs font-semibold text-emerald-700 hover:text-emerald-900 inline-flex items-center gap-1"
                  >
                    <Sparkles className="w-3.5 h-3.5" /> Применить 50/30/20
                  </button>
                </div>

                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="text-xs font-bold uppercase text-emerald-700/70 tracking-wide">
                      Лимиты по категориям
                    </label>
                    <button
                      onClick={() => setEditCategories(prev => [...prev, { category: '', planned: '' }])}
                      className="text-xs text-emerald-700 hover:text-emerald-900 font-semibold inline-flex items-center gap-1"
                    >
                      <Plus className="w-3.5 h-3.5" /> Добавить
                    </button>
                  </div>
                  <div className="space-y-2">
                    {editCategories.map((c, i) => (
                      <div key={i} className="flex items-center gap-2">
                        <input
                          type="text"
                          value={c.category}
                          placeholder="Категория"
                          onChange={e => {
                            const v = e.target.value;
                            setEditCategories(prev => prev.map((x, idx) => idx === i ? { ...x, category: v } : x));
                          }}
                          className="flex-1 px-3 py-2 rounded-xl border border-emerald-200 bg-white text-sm focus:outline-none focus:border-emerald-500"
                        />
                        <input
                          type="number"
                          inputMode="decimal"
                          value={c.planned}
                          placeholder="0"
                          onChange={e => {
                            const v = e.target.value;
                            setEditCategories(prev => prev.map((x, idx) => idx === i ? { ...x, planned: v } : x));
                          }}
                          className="w-28 px-3 py-2 rounded-xl border border-emerald-200 bg-emerald-50/40 text-sm font-semibold text-right focus:outline-none focus:border-emerald-500"
                        />
                        <button
                          onClick={() => setEditCategories(prev => prev.filter((_, idx) => idx !== i))}
                          className="p-2 text-rose-500 hover:bg-rose-50 rounded-xl"
                          aria-label="Удалить категорию"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    ))}
                  </div>
                  <div className="mt-2 flex justify-between text-xs text-emerald-700/70">
                    <span>Сумма лимитов:</span>
                    <span className="font-semibold text-emerald-900">
                      {formatMoney(
                        editCategories.reduce((s, c) => s + (Number(c.planned) || 0), 0),
                        baseCurrency,
                      )}
                    </span>
                  </div>
                  {Number(editIncome) > 0 && (
                    <div className="flex justify-between text-xs text-emerald-700/70 mt-0.5">
                      <span>Свободные средства:</span>
                      <span className="font-semibold text-emerald-900">
                        {formatMoney(
                          (Number(editIncome) || 0) -
                          editCategories.reduce((s, c) => s + (Number(c.planned) || 0), 0),
                          baseCurrency,
                        )}
                      </span>
                    </div>
                  )}
                </div>

                <div>
                  <label className="text-xs font-bold uppercase text-emerald-700/70 tracking-wide block mb-1.5">
                    Заметки (по желанию)
                  </label>
                  <textarea
                    rows={2}
                    value={editNotes}
                    onChange={e => setEditNotes(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl border border-emerald-200 bg-white text-sm focus:outline-none focus:border-emerald-500 resize-none"
                    placeholder="Например: отпуск, ремонт..."
                  />
                </div>
              </div>

              <div className="p-5 border-t border-emerald-100 flex items-center justify-end gap-2 sticky bottom-0 bg-white">
                <button
                  onClick={() => setEditing(false)}
                  className="px-4 py-2 rounded-2xl text-emerald-700 hover:bg-emerald-50 font-semibold text-sm"
                >
                  Отмена
                </button>
                <button
                  onClick={handleSavePlan}
                  className="px-5 py-2 rounded-2xl bg-emerald-600 hover:bg-emerald-700 text-white font-semibold text-sm flex items-center gap-2 shadow-sm transition-colors"
                >
                  <Save className="w-4 h-4" /> Сохранить план
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

interface StatProps {
  label: string;
  value: number;
  suffix: string;
  accent: 'emerald' | 'rose';
}
function Stat({ label, value, suffix, accent }: StatProps) {
  return (
    <div className={cn(
      "rounded-2xl p-3 border",
      accent === 'emerald'
        ? 'border-emerald-100 bg-emerald-50/60'
        : 'border-rose-100 bg-rose-50/60'
    )}>
      <div className="flex items-center gap-1.5 mb-0.5">
        {accent === 'emerald'
          ? <TrendingUp className="w-3.5 h-3.5 text-emerald-700" />
          : <TrendingDown className="w-3.5 h-3.5 text-rose-700" />}
        <span className={cn(
          "text-[10px] uppercase tracking-wide font-bold",
          accent === 'emerald' ? 'text-emerald-700/80' : 'text-rose-700/80'
        )}>{label}</span>
      </div>
      <div className={cn(
        "text-base font-bold tabular-nums",
        accent === 'emerald' ? 'text-emerald-900' : 'text-rose-900'
      )}>
        {value.toLocaleString('ru-RU', { maximumFractionDigits: 0 })} <span className="text-xs">{suffix}</span>
      </div>
    </div>
  );
}

interface BigStatProps {
  icon: React.ReactNode;
  title: string;
  value: string;
  hint: string;
  accent: 'emerald' | 'rose';
}
function BigStatCard({ icon, title, value, hint, accent }: BigStatProps) {
  return (
    <div className="bg-white border border-emerald-100 rounded-3xl p-5 shadow-sm">
      <div className="flex items-center gap-2 mb-3">
        <div className={cn(
          "p-2 rounded-2xl",
          accent === 'emerald' ? 'bg-emerald-50' : 'bg-rose-50'
        )}>
          {icon}
        </div>
        <span className="text-xs font-bold uppercase tracking-wide text-emerald-700/70">{title}</span>
      </div>
      <div className={cn(
        "text-2xl font-black",
        accent === 'emerald' ? 'text-emerald-900' : 'text-rose-700'
      )}>{value}</div>
      <div className="text-xs text-emerald-700/60 mt-1">{hint}</div>
    </div>
  );
}
