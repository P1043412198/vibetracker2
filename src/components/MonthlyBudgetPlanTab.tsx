import React, { useMemo, useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  format, startOfMonth, addMonths, subMonths, isSameMonth, isAfter,
} from 'date-fns';
import { ru } from 'date-fns/locale';
import {
  ChevronLeft, ChevronRight, Plus, Save, Trash2, Edit3, X,
  TrendingUp, TrendingDown, Wallet, Calculator, Sparkles, AlertTriangle,
  CheckCircle2, Calendar, Copy, Repeat, History,
} from 'lucide-react';
import { useStore } from '../store/useStore';
import { useCurrencyConverter } from '../hooks/useCurrencyConverter';
import { cn } from '../lib/utils';
import type { Currency } from '../types';
import {
  monthKeyOf, previousMonthKey,
  computeMonthFacts, daysLeftInMonth, effectiveLimit,
  computeFreeFunds, dailyAllowance, subscriptionsBudget,
} from '../lib/monthlyBudget';

const CURRENCIES: Currency[] = ['BYN', 'USD', 'EUR', 'RUB', 'PLN', 'USDT'];

// Default expense categories used when no plan exists yet
const DEFAULT_CATEGORIES = [
  'Продукты', 'Транспорт', 'Жильё', 'Развлечения', 'Одежда',
  'Здоровье', 'Рестораны', 'Связь', 'Подарки', 'Подписки', 'Другое',
];

// Quick-add suggestions tailored for Belarus household
const QUICK_CATEGORIES: { label: string; emoji: string }[] = [
  { label: 'Продукты', emoji: '🛒' },
  { label: 'ЖКХ', emoji: '🏠' },
  { label: 'Связь', emoji: '📱' },
  { label: 'Интернет', emoji: '🌐' },
  { label: 'Транспорт', emoji: '🚌' },
  { label: 'Топливо', emoji: '⛽' },
  { label: 'Кафе и рестораны', emoji: '🍽️' },
  { label: 'Здоровье', emoji: '💊' },
  { label: 'Аптека', emoji: '🩹' },
  { label: 'Одежда', emoji: '👕' },
  { label: 'Дети', emoji: '🧒' },
  { label: 'Образование', emoji: '🎓' },
  { label: 'Подписки', emoji: '🔁' },
  { label: 'Кредит', emoji: '💳' },
  { label: 'Накопления', emoji: '🐖' },
  { label: 'Подарки', emoji: '🎁' },
  { label: 'Развлечения', emoji: '🎭' },
  { label: 'Спорт', emoji: '🏋️' },
  { label: 'Авто (обслуживание)', emoji: '🛠️' },
  { label: 'Дача / огород', emoji: '🌿' },
  { label: 'Питомцы', emoji: '🐈' },
  { label: 'ИРИП / ЕРИП', emoji: '📑' },
];

function formatMoney(value: number, currency: string) {
  return `${value.toLocaleString('ru-RU', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  })} ${currency}`;
}

type CategoryRow = {
  category: string;
  planned: number;     // base limit from the active plan
  carry: number;       // rollover carry-in (>=0)
  effective: number;   // planned + carry
  actual: number;
};

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
                      ? "bg-emerald-600 text-zinc-900 shadow-sm"
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
    regularPayments = [],
    saveMonthlyBudgetPlan,
    deleteMonthlyBudgetPlan,
    baseCurrency = 'BYN',
  } = useStore();

  const convert = useCurrencyConverter();

  const [month, setMonth] = useState<Date>(() => startOfMonth(new Date()));
  const monthKey = monthKeyOf(month);
  const prevKey = previousMonthKey(monthKey);

  const plan = useMemo(
    () => monthlyBudgetPlans.find(p => p.monthKey === monthKey),
    [monthlyBudgetPlans, monthKey]
  );
  const previousPlan = useMemo(
    () => monthlyBudgetPlans.find(p => p.monthKey === prevKey),
    [monthlyBudgetPlans, prevKey]
  );

  // Effective currency: per-plan currency overrides global base.
  const planCurrency: Currency = (plan?.currency as Currency) || baseCurrency;

  // Compute factual income/expense for selected month in plan currency.
  const stats = useMemo(
    () => computeMonthFacts({ month, transactions, accounts, baseCurrency: planCurrency, convert }),
    [month, transactions, accounts, planCurrency, convert]
  );

  // Previous-month actuals (for rollover carry-in calculation).
  const previousStats = useMemo(
    () => computeMonthFacts({
      month: subMonths(month, 1),
      transactions, accounts, baseCurrency: planCurrency, convert,
    }),
    [month, transactions, accounts, planCurrency, convert]
  );

  const plannedIncome = plan?.plannedIncome ?? 0;
  const plannedTotalExpense = (plan?.categoryPlans || []).reduce((s, c) => s + c.planned, 0);

  const { incomeRef, free } = computeFreeFunds(plannedIncome, stats.income, stats.expense);
  const expenseRef = stats.expense;

  const today = new Date();
  const daysLeft = daysLeftInMonth(month, today);
  const dailyAllowanceValue = dailyAllowance(free, daysLeft);

  // Category rows merged from plan + actuals + (optional) carry-in from prev month.
  const categoryRows: CategoryRow[] = useMemo(() => {
    const rows = new Map<string, CategoryRow>();
    for (const c of plan?.categoryPlans || []) {
      const carry = effectiveLimit({
        category: c.category,
        monthPlan: plan,
        previousPlan,
        previousActuals: previousStats.expenseByCategory,
      }) - c.planned;
      rows.set(c.category, {
        category: c.category,
        planned: c.planned,
        carry: Math.max(carry, 0),
        effective: c.planned + Math.max(carry, 0),
        actual: 0,
      });
    }
    for (const [cat, val] of Object.entries(stats.expenseByCategory)) {
      const r = rows.get(cat);
      if (r) r.actual = val;
      else rows.set(cat, { category: cat, planned: 0, carry: 0, effective: 0, actual: val });
    }
    return Array.from(rows.values())
      .sort((a, b) => (b.effective + b.actual) - (a.effective + a.actual));
  }, [plan, previousPlan, previousStats.expenseByCategory, stats.expenseByCategory]);

  // Edit modal state
  const [isEditing, setEditing] = useState(false);
  const [editIncome, setEditIncome] = useState<string>('');
  const [editCategories, setEditCategories] = useState<{ category: string; planned: string }[]>([]);
  const [editNotes, setEditNotes] = useState('');
  const [editCurrency, setEditCurrency] = useState<Currency>(planCurrency);
  const [editRollover, setEditRollover] = useState<boolean>(false);

  // Reset edit form ONLY when the modal opens (toggle from false→true) or
  // when switching to a different month/plan. Do NOT depend on `stats`,
  // `baseCurrency` or other refs that change on every render — that wipes
  // user input on every keystroke.
  useEffect(() => {
    if (!isEditing) return;
    setEditIncome(plan?.plannedIncome ? String(plan.plannedIncome) : '');
    setEditNotes(plan?.notes || '');
    setEditCurrency((plan?.currency as Currency) || baseCurrency);
    setEditRollover(Boolean(plan?.rollover));
    if (plan && plan.categoryPlans.length > 0) {
      setEditCategories(plan.categoryPlans.map(c => ({ category: c.category, planned: String(c.planned) })));
    } else {
      const seed = Object.keys(stats.expenseByCategory);
      const cats = seed.length > 0 ? seed : DEFAULT_CATEGORIES;
      setEditCategories(cats.map(c => ({ category: c, planned: '' })));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isEditing, plan?.id]);

  const handleSavePlan = () => {
    const parsedIncome = Number(editIncome) || 0;
    const cleaned = editCategories
      .map(c => ({ category: c.category.trim(), planned: Number(c.planned) || 0 }))
      .filter(c => c.category && c.planned > 0);

    saveMonthlyBudgetPlan({
      ...(plan?.id ? { id: plan.id } : {}),
      monthKey,
      plannedIncome: parsedIncome,
      currency: editCurrency,
      categoryPlans: cleaned,
      rollover: editRollover,
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

  // Pull plan structure (income + categories) verbatim from previous month.
  const copyFromPreviousPlan = () => {
    if (!previousPlan) return;
    setEditIncome(String(previousPlan.plannedIncome || ''));
    setEditCategories(
      previousPlan.categoryPlans.length > 0
        ? previousPlan.categoryPlans.map(c => ({ category: c.category, planned: String(c.planned) }))
        : []
    );
  };

  // Use previous month's actual spending as next month's plan baseline.
  const seedFromPreviousActuals = () => {
    const cats = Object.entries(previousStats.expenseByCategory)
      .filter(([, v]) => v > 0)
      .sort((a, b) => b[1] - a[1])
      .map(([cat, v]) => ({ category: cat, planned: String(Math.round(v)) }));
    if (cats.length === 0) return;
    setEditCategories(cats);
    if (!editIncome) {
      const inc = previousStats.income;
      if (inc > 0) setEditIncome(String(Math.round(inc)));
    }
  };

  // Auto-fill the "Подписки" limit from active recurring payments.
  const fillSubscriptionsFromRegular = () => {
    const value = subscriptionsBudget({
      payments: regularPayments,
      baseCurrency: editCurrency,
      convert,
    });
    if (value <= 0) return;
    setEditCategories(prev => {
      const existing = prev.find(c => c.category.trim().toLowerCase() === 'подписки');
      if (existing) {
        return prev.map(c => c === existing ? { ...c, planned: String(Math.round(value)) } : c);
      }
      return [...prev, { category: 'Подписки', planned: String(Math.round(value)) }];
    });
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
            className="flex items-center gap-2 px-4 py-2.5 rounded-2xl bg-emerald-600 hover:bg-emerald-700 active:bg-emerald-800 text-white text-sm font-bold shadow-md transition-colors"
          >
            {plan ? <Edit3 className="w-4 h-4" /> : <Plus className="w-4 h-4" />}
            {plan ? 'Редактировать' : 'Создать план'}
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
                {formatMoney(free, planCurrency)}
              </span>
              <span className="text-[10px] text-emerald-700/60 mt-1">
                из {formatMoney(incomeRef, planCurrency)}
              </span>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3 w-full mt-4">
            <Stat label="Доход" value={incomeRef} suffix={planCurrency} accent="emerald" />
            <Stat label="Расход" value={expenseRef} suffix={planCurrency} accent="rose" />
          </div>
        </div>

        {/* Stat cards: today, daily allowance, plan totals */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <BigStatCard
            icon={<Sparkles className="w-5 h-5 text-emerald-700" />}
            title="Свободно сегодня"
            value={formatMoney(free, planCurrency)}
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
            value={formatMoney(dailyAllowanceValue, planCurrency)}
            hint={isSameMonth(month, today) ? 'До конца месяца' : '—'}
            accent="emerald"
          />
          <BigStatCard
            icon={<Wallet className="w-5 h-5 text-emerald-700" />}
            title="План расходов"
            value={formatMoney(plannedTotalExpense, planCurrency)}
            hint={
              plannedIncome > 0
                ? `Доход: ${formatMoney(plannedIncome, planCurrency)}`
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
              const limit = row.effective || row.planned;
              const actAmt = row.actual;
              const ratio = limit > 0 ? Math.min(actAmt / limit, 1.5) : (actAmt > 0 ? 1 : 0);
              const overBudget = limit > 0 && actAmt > limit;
              const noPlan = row.planned === 0 && row.carry === 0;
              return (
                <div key={row.category} className="space-y-1.5">
                  <div className="flex items-baseline justify-between gap-3">
                    <div className="flex items-center gap-2 min-w-0 flex-wrap">
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
                      {!overBudget && !noPlan && actAmt <= limit && (
                        <span className="inline-flex items-center gap-1 text-[10px] font-bold uppercase text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full">
                          <CheckCircle2 className="w-3 h-3" /> В рамках
                        </span>
                      )}
                      {row.carry > 0 && (
                        <span
                          className="inline-flex items-center gap-1 text-[10px] font-bold uppercase text-emerald-700 bg-emerald-100 px-2 py-0.5 rounded-full"
                          title="Перенесено с прошлого месяца"
                        >
                          <Repeat className="w-3 h-3" /> +{formatMoney(row.carry, planCurrency)}
                        </span>
                      )}
                    </div>
                    <div className="text-xs text-emerald-700/70 whitespace-nowrap">
                      <span className={cn("font-bold", overBudget ? "text-rose-600" : "text-emerald-900")}>
                        {formatMoney(actAmt, planCurrency)}
                      </span>
                      {' / '}
                      <span>{limit > 0 ? formatMoney(limit, planCurrency) : '—'}</span>
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

      {/* Edit modal — full-screen on mobile, centered card on desktop */}
      <AnimatePresence>
        {isEditing && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[100] flex items-stretch sm:items-center justify-center bg-zinc-900/40 sm:p-6"
            onClick={() => setEditing(false)}
          >
            <motion.div
              initial={{ y: 40, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              exit={{ y: 40, opacity: 0 }}
              onClick={e => e.stopPropagation()}
              className="bg-white w-full max-w-2xl shadow-2xl flex flex-col h-full sm:h-auto sm:max-h-[92vh] sm:rounded-3xl overflow-hidden"
            >
              <div
                className="flex items-center justify-between px-4 py-3 sm:px-5 sm:py-4 border-b border-emerald-100 bg-white shrink-0"
                style={{ paddingTop: 'max(0.75rem, env(safe-area-inset-top))' }}
              >
                <div className="min-w-0 flex-1">
                  <h3 className="text-base sm:text-lg font-bold text-emerald-900 capitalize truncate">
                    План на {format(month, 'LLLL yyyy', { locale: ru })}
                  </h3>
                  <p className="text-[11px] sm:text-xs text-emerald-700/60 truncate">Зарплата и лимиты по категориям</p>
                </div>
                <button onClick={() => setEditing(false)} className="p-2 hover:bg-emerald-50 rounded-xl text-emerald-700 shrink-0">
                  <X className="w-5 h-5" />
                </button>
              </div>

              <div className="flex-1 min-h-0 overflow-y-auto px-4 py-4 sm:px-5 space-y-4">
                {/* Quick actions: copy plan / seed from facts / subscriptions */}
                <div className="flex flex-wrap gap-2">
                  <button
                    type="button"
                    onClick={copyFromPreviousPlan}
                    disabled={!previousPlan}
                    className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-emerald-50 hover:bg-emerald-100 disabled:opacity-50 disabled:cursor-not-allowed text-emerald-800 text-xs font-semibold"
                    title="Скопировать структуру плана из предыдущего месяца"
                  >
                    <Copy className="w-3.5 h-3.5" /> План из {prevKey}
                  </button>
                  <button
                    type="button"
                    onClick={seedFromPreviousActuals}
                    disabled={Object.keys(previousStats.expenseByCategory).length === 0}
                    className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-emerald-50 hover:bg-emerald-100 disabled:opacity-50 disabled:cursor-not-allowed text-emerald-800 text-xs font-semibold"
                    title="Заполнить план фактическими тратами прошлого месяца"
                  >
                    <History className="w-3.5 h-3.5" /> По факту прошлого
                  </button>
                  <button
                    type="button"
                    onClick={fillSubscriptionsFromRegular}
                    disabled={regularPayments.filter(p => p.isActive).length === 0}
                    className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-emerald-50 hover:bg-emerald-100 disabled:opacity-50 disabled:cursor-not-allowed text-emerald-800 text-xs font-semibold"
                    title="Авто-заполнить лимит «Подписки» из активных регулярных платежей"
                  >
                    <Repeat className="w-3.5 h-3.5" /> Подписки авто
                  </button>
                </div>

                <div className="space-y-3">
                  <div>
                    <label className="text-xs font-bold uppercase text-emerald-700/70 tracking-wide block mb-1.5">
                      Планируемый доход
                    </label>
                    <div className="flex gap-2">
                      <input
                        type="number"
                        inputMode="decimal"
                        value={editIncome}
                        onChange={e => setEditIncome(e.target.value)}
                        placeholder="0"
                        className="flex-1 min-w-0 px-4 py-3 rounded-2xl border border-emerald-200 bg-emerald-50/40 text-emerald-900 text-lg font-semibold focus:outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-200"
                      />
                      <select
                        value={editCurrency}
                        onChange={e => setEditCurrency(e.target.value as Currency)}
                        className="w-24 px-2 py-3 rounded-2xl border border-emerald-200 bg-white text-emerald-900 text-base font-semibold focus:outline-none focus:border-emerald-500"
                      >
                        {CURRENCIES.map(c => (
                          <option key={c} value={c}>{c}</option>
                        ))}
                      </select>
                    </div>
                    <button
                      onClick={applyTemplate503020}
                      className="mt-2 text-xs font-semibold text-emerald-700 hover:text-emerald-900 inline-flex items-center gap-1"
                    >
                      <Sparkles className="w-3.5 h-3.5" /> Применить 50/30/20
                    </button>
                  </div>
                </div>

                <label className="flex items-center gap-2 cursor-pointer text-sm font-semibold text-emerald-800 select-none">
                  <input
                    type="checkbox"
                    checked={editRollover}
                    onChange={e => setEditRollover(e.target.checked)}
                    className="w-4 h-4 accent-emerald-600"
                  />
                  Переносить неизрасходованный остаток с прошлого месяца
                  <span className="text-xs font-normal text-emerald-700/60">
                    — лимит этого месяца увеличится на (план − факт) прошлого
                  </span>
                </label>

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

                  {/* Quick-add Belarus presets */}
                  <div className="mb-2">
                    <p className="text-[10px] uppercase tracking-wide font-bold text-emerald-700/60 mb-1">
                      Быстрое добавление
                    </p>
                    <div className="flex flex-wrap gap-1.5">
                      {QUICK_CATEGORIES.filter(q =>
                        !editCategories.some(c => c.category.trim().toLowerCase() === q.label.toLowerCase())
                      ).slice(0, 14).map(q => (
                        <button
                          key={q.label}
                          type="button"
                          onClick={() => setEditCategories(prev => [...prev, { category: q.label, planned: '' }])}
                          className="inline-flex items-center gap-1 px-2 py-1 rounded-full bg-emerald-50 hover:bg-emerald-100 border border-emerald-100 text-[11px] text-emerald-800 font-medium"
                        >
                          <span>{q.emoji}</span>
                          <span>{q.label}</span>
                        </button>
                      ))}
                    </div>
                  </div>

                  <div className="space-y-2">
                    {editCategories.map((c, i) => (
                      <div
                        key={i}
                        className="bg-emerald-50/30 border border-emerald-100 rounded-2xl p-2 flex items-center gap-2"
                      >
                        <input
                          type="text"
                          value={c.category}
                          placeholder="Категория"
                          onChange={e => {
                            const v = e.target.value;
                            setEditCategories(prev => prev.map((x, idx) => idx === i ? { ...x, category: v } : x));
                          }}
                          className="flex-1 min-w-0 px-3 py-2 rounded-xl border border-emerald-200 bg-white text-sm focus:outline-none focus:border-emerald-500"
                        />
                        <div className="relative shrink-0">
                          <input
                            type="number"
                            inputMode="decimal"
                            value={c.planned}
                            placeholder="0"
                            onChange={e => {
                              const v = e.target.value;
                              setEditCategories(prev => prev.map((x, idx) => idx === i ? { ...x, planned: v } : x));
                            }}
                            className="w-24 sm:w-28 px-3 py-2 pr-10 rounded-xl border border-emerald-200 bg-white text-sm font-semibold text-right focus:outline-none focus:border-emerald-500"
                          />
                          <span className="absolute right-2.5 top-1/2 -translate-y-1/2 text-[10px] text-emerald-700/60 pointer-events-none">
                            {editCurrency}
                          </span>
                        </div>
                        <button
                          onClick={() => setEditCategories(prev => prev.filter((_, idx) => idx !== i))}
                          className="p-2 text-rose-500 hover:bg-rose-50 rounded-xl shrink-0"
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
                        editCurrency,
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
                          editCurrency,
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

              <div
                className="px-4 py-3 sm:px-5 sm:py-4 border-t border-emerald-100 bg-white flex items-center gap-2 shrink-0"
                style={{ paddingBottom: 'max(0.75rem, env(safe-area-inset-bottom))' }}
              >
                <button
                  onClick={() => setEditing(false)}
                  className="px-4 py-3 rounded-2xl text-emerald-700 hover:bg-emerald-50 font-semibold text-sm shrink-0"
                >
                  Отмена
                </button>
                <button
                  onClick={handleSavePlan}
                  className="flex-1 px-5 py-3 rounded-2xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-base flex items-center justify-center gap-2 shadow-md transition-colors active:scale-[0.98]"
                >
                  <Save className="w-5 h-5" /> Сохранить план
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
