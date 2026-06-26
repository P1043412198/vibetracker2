import React, { useState, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Plus, Trash2, Edit3, X, Check, ChevronDown, ChevronUp,
  Wallet, Banknote, Calendar, TrendingUp, TrendingDown,
  CheckCircle2, Circle, AlertTriangle, Clock, ArrowRight,
  DollarSign, PiggyBank, BarChart3,
} from 'lucide-react';
import { format, differenceInCalendarDays, parseISO } from 'date-fns';
import { ru } from 'date-fns/locale';
import { useStore } from '../store/useStore';
import { cn } from '../lib/utils';
import { computeBudgetCycles, computeCashflowForecast, getPayDate } from '../lib/finance/budgetPlanner';
import type { CashflowForecast, CashflowRangeMode } from '../lib/finance/budgetPlanner';
import type { IncomeSource, IncomeSourceType, PlannedExpense } from '../types';
import {
  PieChart, Pie, Cell, ResponsiveContainer, BarChart, Bar, XAxis, YAxis,
  CartesianGrid, Tooltip,
} from 'recharts';

type Section = 'income' | 'expenses' | 'fact';

const TYPE_LABELS: Record<IncomeSourceType, string> = {
  salary: 'Зарплата',
  advance: 'Аванс',
  additional: 'Дополнительный',
};

const DONUT_COLORS = ['#10b981', '#f59e0b', '#6366f1', '#ec4899', '#8b5cf6', '#14b8a6'];

export function BudgetPlannerTab() {
  const [section, setSection] = useState<Section>('fact');

  return (
    <div className="space-y-4">
      {/* Section tabs */}
      <div className="grid grid-cols-3 gap-1 bg-white/60 p-1 rounded-xl">
        {([
          ['income', 'План доходов', Wallet],
          ['expenses', 'План расходов', Banknote],
          ['fact', 'Факт', BarChart3],
        ] as const).map(([key, label, Icon]) => (
          <button
            key={key}
            onClick={() => setSection(key)}
            className={cn(
              "flex items-center justify-center gap-1.5 py-2 rounded-lg text-xs font-medium transition-all",
              section === key
                ? "bg-stone-100 text-zinc-900 shadow-sm"
                : "text-zinc-500 hover:text-zinc-800"
            )}
          >
            <Icon className="w-3.5 h-3.5" />
            <span>{label}</span>
          </button>
        ))}
      </div>

      <motion.div
        key={section}
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.2 }}
      >
        {section === 'income' && <IncomePlanSection />}
        {section === 'expenses' && <ExpensePlanSection />}
        {section === 'fact' && <FactSection />}
      </motion.div>
    </div>
  );
}

// ═══════════════ INCOME PLAN ═══════════════

function IncomePlanSection() {
  const { incomeSources, addIncomeSource, updateIncomeSource, deleteIncomeSource } = useStore();
  const [showForm, setShowForm] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [form, setForm] = useState({
    name: '',
    type: 'salary' as IncomeSourceType,
    amount: '',
    dayOfMonth: '15',
    adjustForHolidays: true,
  });

  const sources = incomeSources || [];
  const totalIncome = sources.filter(s => s.isActive).reduce((sum, s) => sum + s.amount, 0);

  const resetForm = () => {
    setForm({ name: '', type: 'salary', amount: '', dayOfMonth: '15', adjustForHolidays: true });
    setShowForm(false);
    setEditId(null);
  };

  const handleSave = () => {
    const amount = parseFloat(form.amount);
    if (!form.name || isNaN(amount)) return;
    const data = {
      name: form.name,
      type: form.type,
      amount,
      dayOfMonth: parseInt(form.dayOfMonth) || (form.type === 'advance' ? 31 : 15),
      adjustForHolidays: form.adjustForHolidays,
      isActive: true,
    };
    if (editId) {
      updateIncomeSource(editId, data);
    } else {
      addIncomeSource(data);
    }
    resetForm();
  };

  const startEdit = (source: IncomeSource) => {
    setForm({
      name: source.name,
      type: source.type,
      amount: String(source.amount),
      dayOfMonth: String(source.dayOfMonth || 15),
      adjustForHolidays: source.adjustForHolidays !== false,
    });
    setEditId(source.id);
    setShowForm(true);
  };

  const now = new Date();

  return (
    <div className="space-y-4">
      {/* Total card */}
      <div className="bg-gradient-to-r from-emerald-500 to-emerald-600 p-4 rounded-2xl text-white shadow-lg shadow-emerald-500/30">
        <div className="flex items-center gap-2 mb-1">
          <Wallet className="w-4 h-4 opacity-80" />
          <span className="text-xs font-bold uppercase opacity-80">Общий план доходов</span>
        </div>
        <p className="text-2xl font-bold">{totalIncome.toLocaleString('ru-RU')} BYN</p>
        <p className="text-xs opacity-70 mt-1">{sources.filter(s => s.isActive).length} активных источников</p>
      </div>

      {/* Income list */}
      <div className="space-y-2">
        {sources.map(source => {
          const payDate = getPayDate(source, now.getFullYear(), now.getMonth());
          return (
            <motion.div
              key={source.id}
              layout
              className={cn(
                "bg-white p-4 rounded-2xl border border-stone-200 transition-opacity",
                !source.isActive && "opacity-50"
              )}
            >
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <span className={cn(
                      "text-[9px] px-2 py-0.5 rounded-full font-bold uppercase",
                      source.type === 'salary' ? "bg-emerald-100 text-emerald-700" :
                      source.type === 'advance' ? "bg-blue-100 text-blue-700" :
                      "bg-purple-100 text-purple-700"
                    )}>
                      {TYPE_LABELS[source.type]}
                    </span>
                    {source.adjustForHolidays && (
                      <span className="text-[9px] text-zinc-400">авто-перенос</span>
                    )}
                  </div>
                  <p className="text-sm font-bold text-zinc-900">{source.name}</p>
                  <div className="flex items-center gap-3 mt-1 text-xs text-zinc-500">
                    <span className="font-bold text-emerald-600">{source.amount.toLocaleString('ru-RU')} BYN</span>
                    {source.dayOfMonth && (
                      <span className="flex items-center gap-1">
                        <Calendar className="w-3 h-3" />
                        {source.dayOfMonth}-е число
                      </span>
                    )}
                    {payDate && (
                      <span className="text-indigo-500">
                        → {format(payDate, 'd MMM', { locale: ru })}
                      </span>
                    )}
                  </div>
                </div>
                <div className="flex items-center gap-1">
                  <button
                    onClick={() => updateIncomeSource(source.id, { isActive: !source.isActive })}
                    className={cn(
                      "p-1.5 rounded-lg transition-colors",
                      source.isActive ? "text-emerald-500 hover:bg-emerald-50" : "text-zinc-300 hover:bg-stone-50"
                    )}
                  >
                    {source.isActive ? <CheckCircle2 className="w-4 h-4" /> : <Circle className="w-4 h-4" />}
                  </button>
                  <button onClick={() => startEdit(source)} className="p-1.5 text-zinc-400 hover:text-zinc-700 hover:bg-stone-50 rounded-lg">
                    <Edit3 className="w-4 h-4" />
                  </button>
                  <button onClick={() => deleteIncomeSource(source.id)} className="p-1.5 text-zinc-300 hover:text-rose-500 hover:bg-rose-50 rounded-lg">
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            </motion.div>
          );
        })}
      </div>

      {/* Add / Edit form */}
      <AnimatePresence>
        {showForm && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            className="bg-white p-4 rounded-2xl border border-stone-200 space-y-3 overflow-hidden"
          >
            <h4 className="text-xs font-bold text-zinc-500 uppercase">
              {editId ? 'Редактировать' : 'Добавить'} источник дохода
            </h4>
            <div className="grid grid-cols-3 gap-2">
              {(['salary', 'advance', 'additional'] as const).map(t => (
                <button
                  key={t}
                  onClick={() => {
                    setForm({
                      ...form,
                      type: t,
                      dayOfMonth: t === 'salary' ? '15' : t === 'advance' ? '31' : form.dayOfMonth,
                      name: form.name || TYPE_LABELS[t],
                    });
                  }}
                  className={cn(
                    "py-2 rounded-xl text-xs font-bold transition-all border",
                    form.type === t
                      ? "bg-emerald-500 text-white border-emerald-500"
                      : "bg-stone-50 text-zinc-500 border-stone-200"
                  )}
                >
                  {TYPE_LABELS[t]}
                </button>
              ))}
            </div>
            <input
              value={form.name}
              onChange={e => setForm({ ...form, name: e.target.value })}
              placeholder="Название"
              className="w-full px-3 py-2 bg-stone-50 border border-stone-200 rounded-xl text-sm"
            />
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-[10px] text-zinc-500 uppercase font-bold mb-1 block">Сумма (BYN)</label>
                <input
                  type="number"
                  value={form.amount}
                  onChange={e => setForm({ ...form, amount: e.target.value })}
                  placeholder="0"
                  className="w-full px-3 py-2 bg-stone-50 border border-stone-200 rounded-xl text-sm"
                />
              </div>
              <div>
                <label className="text-[10px] text-zinc-500 uppercase font-bold mb-1 block">День месяца</label>
                <input
                  type="number"
                  min="1"
                  max="31"
                  value={form.dayOfMonth}
                  onChange={e => setForm({ ...form, dayOfMonth: e.target.value })}
                  className="w-full px-3 py-2 bg-stone-50 border border-stone-200 rounded-xl text-sm"
                />
              </div>
            </div>
            <label className="flex items-center gap-2 text-xs text-zinc-600 cursor-pointer">
              <input
                type="checkbox"
                checked={form.adjustForHolidays}
                onChange={e => setForm({ ...form, adjustForHolidays: e.target.checked })}
                className="rounded accent-emerald-500"
              />
              Переносить на последний рабочий день (выходные/праздники РБ)
            </label>
            <div className="flex gap-2">
              <button onClick={resetForm} className="flex-1 py-2 text-xs font-bold text-zinc-500 hover:text-zinc-700">
                Отмена
              </button>
              <button
                onClick={handleSave}
                className="flex-1 py-2 bg-emerald-500 text-white rounded-xl text-xs font-bold hover:bg-emerald-600 shadow-md shadow-emerald-500/30"
              >
                {editId ? 'Сохранить' : 'Добавить'}
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {!showForm && (
        <button
          onClick={() => { resetForm(); setShowForm(true); }}
          className="w-full py-3 border-2 border-dashed border-stone-200 rounded-2xl text-zinc-400 hover:text-zinc-600 hover:border-stone-300 flex items-center justify-center gap-2 text-xs font-bold transition-colors"
        >
          <Plus className="w-4 h-4" /> Добавить источник дохода
        </button>
      )}
    </div>
  );
}

// ═══════════════ EXPENSE PLAN ═══════════════

function ExpensePlanSection() {
  const { plannedExpenses, addPlannedExpense, updatePlannedExpense, deletePlannedExpense, markExpensePaid, markExpenseUnpaid } = useStore();
  const [showForm, setShowForm] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [form, setForm] = useState({
    name: '',
    amount: '',
    dayFrom: '1',
    dayTo: '5',
    category: '',
  });

  const expenses = plannedExpenses || [];
  const totalPlanned = expenses.filter(e => e.isActive).reduce((sum, e) => sum + e.amount, 0);
  const totalPaid = expenses.filter(e => e.isPaid).reduce((sum, e) => sum + (e.paidAmount || e.amount), 0);

  const resetForm = () => {
    setForm({ name: '', amount: '', dayFrom: '1', dayTo: '5', category: '' });
    setShowForm(false);
    setEditId(null);
  };

  const handleSave = () => {
    const amount = parseFloat(form.amount);
    if (!form.name || isNaN(amount)) return;
    const data = {
      name: form.name,
      amount,
      dayFrom: parseInt(form.dayFrom) || 1,
      dayTo: parseInt(form.dayTo) || 5,
      category: form.category || undefined,
      isPaid: false,
      isActive: true,
    };
    if (editId) {
      updatePlannedExpense(editId, data);
    } else {
      addPlannedExpense(data);
    }
    resetForm();
  };

  const startEdit = (expense: PlannedExpense) => {
    setForm({
      name: expense.name,
      amount: String(expense.amount),
      dayFrom: String(expense.dayFrom),
      dayTo: String(expense.dayTo),
      category: expense.category || '',
    });
    setEditId(expense.id);
    setShowForm(true);
  };

  return (
    <div className="space-y-4">
      {/* Stats */}
      <div className="grid grid-cols-2 gap-3">
        <div className="bg-white p-4 rounded-2xl border border-stone-200">
          <span className="text-[10px] text-zinc-500 uppercase font-bold block mb-1">План расходов</span>
          <span className="text-xl font-bold text-rose-500">{totalPlanned.toLocaleString('ru-RU')} BYN</span>
        </div>
        <div className="bg-white p-4 rounded-2xl border border-stone-200">
          <span className="text-[10px] text-zinc-500 uppercase font-bold block mb-1">Оплачено</span>
          <span className="text-xl font-bold text-emerald-600">{totalPaid.toLocaleString('ru-RU')} BYN</span>
          <div className="mt-2 h-1.5 bg-stone-100 rounded-full overflow-hidden">
            <div
              className="h-full bg-emerald-500 rounded-full transition-all"
              style={{ width: `${totalPlanned > 0 ? Math.min(100, (totalPaid / totalPlanned) * 100) : 0}%` }}
            />
          </div>
        </div>
      </div>

      {/* Expense list */}
      <div className="space-y-2">
        {expenses.map(expense => (
          <motion.div
            key={expense.id}
            layout
            className={cn(
              "bg-white p-4 rounded-2xl border transition-all",
              expense.isPaid ? "border-emerald-200 bg-emerald-50/30" : "border-stone-200",
              !expense.isActive && "opacity-50"
            )}
          >
            <div className="flex items-start justify-between">
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-1">
                  <p className={cn(
                    "text-sm font-bold",
                    expense.isPaid ? "text-emerald-700 line-through" : "text-zinc-900"
                  )}>
                    {expense.name}
                  </p>
                  {expense.isPaid && (
                    <span className="text-[9px] px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-700 font-bold">
                      Оплачено
                    </span>
                  )}
                </div>
                <div className="flex items-center gap-3 text-xs text-zinc-500">
                  <span className="font-bold text-rose-500">{expense.amount.toLocaleString('ru-RU')} BYN</span>
                  <span className="flex items-center gap-1">
                    <Calendar className="w-3 h-3" />
                    {expense.dayFrom}–{expense.dayTo} число
                  </span>
                  {expense.category && (
                    <span className="text-zinc-400">{expense.category}</span>
                  )}
                </div>
                {expense.isPaid && expense.paidDate && (
                  <p className="text-[10px] text-emerald-500 mt-1">
                    Оплачено {format(new Date(expense.paidDate), 'd MMM', { locale: ru })}
                    {expense.paidAmount !== expense.amount && ` — ${expense.paidAmount?.toLocaleString('ru-RU')} BYN`}
                  </p>
                )}
              </div>
              <div className="flex items-center gap-1">
                <button
                  onClick={() => expense.isPaid ? markExpenseUnpaid(expense.id) : markExpensePaid(expense.id)}
                  className={cn(
                    "p-1.5 rounded-lg transition-colors",
                    expense.isPaid ? "text-emerald-500 hover:bg-emerald-100" : "text-zinc-300 hover:bg-stone-50"
                  )}
                  title={expense.isPaid ? 'Отменить оплату' : 'Отметить как оплачено'}
                >
                  {expense.isPaid ? <CheckCircle2 className="w-4 h-4" /> : <Circle className="w-4 h-4" />}
                </button>
                <button onClick={() => startEdit(expense)} className="p-1.5 text-zinc-400 hover:text-zinc-700 hover:bg-stone-50 rounded-lg">
                  <Edit3 className="w-4 h-4" />
                </button>
                <button onClick={() => deletePlannedExpense(expense.id)} className="p-1.5 text-zinc-300 hover:text-rose-500 hover:bg-rose-50 rounded-lg">
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            </div>
          </motion.div>
        ))}
      </div>

      {/* Add / Edit form */}
      <AnimatePresence>
        {showForm && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            className="bg-white p-4 rounded-2xl border border-stone-200 space-y-3 overflow-hidden"
          >
            <h4 className="text-xs font-bold text-zinc-500 uppercase">
              {editId ? 'Редактировать' : 'Добавить'} плановый расход
            </h4>
            <input
              value={form.name}
              onChange={e => setForm({ ...form, name: e.target.value })}
              placeholder="Название (напр. Аренда квартиры)"
              className="w-full px-3 py-2 bg-stone-50 border border-stone-200 rounded-xl text-sm"
            />
            <div className="grid grid-cols-3 gap-3">
              <div>
                <label className="text-[10px] text-zinc-500 uppercase font-bold mb-1 block">Сумма</label>
                <input
                  type="number"
                  value={form.amount}
                  onChange={e => setForm({ ...form, amount: e.target.value })}
                  placeholder="0"
                  className="w-full px-3 py-2 bg-stone-50 border border-stone-200 rounded-xl text-sm"
                />
              </div>
              <div>
                <label className="text-[10px] text-zinc-500 uppercase font-bold mb-1 block">С (день)</label>
                <input
                  type="number"
                  min="1"
                  max="31"
                  value={form.dayFrom}
                  onChange={e => setForm({ ...form, dayFrom: e.target.value })}
                  className="w-full px-3 py-2 bg-stone-50 border border-stone-200 rounded-xl text-sm"
                />
              </div>
              <div>
                <label className="text-[10px] text-zinc-500 uppercase font-bold mb-1 block">По (день)</label>
                <input
                  type="number"
                  min="1"
                  max="31"
                  value={form.dayTo}
                  onChange={e => setForm({ ...form, dayTo: e.target.value })}
                  className="w-full px-3 py-2 bg-stone-50 border border-stone-200 rounded-xl text-sm"
                />
              </div>
            </div>
            <input
              value={form.category}
              onChange={e => setForm({ ...form, category: e.target.value })}
              placeholder="Категория (необязательно)"
              className="w-full px-3 py-2 bg-stone-50 border border-stone-200 rounded-xl text-sm"
            />
            <div className="flex gap-2">
              <button onClick={resetForm} className="flex-1 py-2 text-xs font-bold text-zinc-500">Отмена</button>
              <button
                onClick={handleSave}
                className="flex-1 py-2 bg-rose-500 text-white rounded-xl text-xs font-bold hover:bg-rose-600 shadow-md shadow-rose-500/30"
              >
                {editId ? 'Сохранить' : 'Добавить'}
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {!showForm && (
        <button
          onClick={() => { resetForm(); setShowForm(true); }}
          className="w-full py-3 border-2 border-dashed border-stone-200 rounded-2xl text-zinc-400 hover:text-zinc-600 hover:border-stone-300 flex items-center justify-center gap-2 text-xs font-bold transition-colors"
        >
          <Plus className="w-4 h-4" /> Добавить плановый расход
        </button>
      )}
    </div>
  );
}

// ═══════════════ SAFE-TO-SPEND CARD ═══════════════

const fmtMoney = (n: number) => Math.round(n).toLocaleString('ru-RU');

const RANGE_OPTIONS: { mode: CashflowRangeMode; label: string }[] = [
  { mode: 'auto', label: 'До зарплаты' },
  { mode: 'next', label: 'До ближайшего' },
  { mode: 'advanceToAdvance', label: 'Аванс→Аванс' },
  { mode: 'salaryToSalary', label: 'Зарплата→Зарплата' },
  { mode: 'fullHorizon', label: 'Весь горизонт' },
  { mode: 'custom', label: 'Свой период' },
];

function SafeToSpendCard({
  forecast,
  reserve,
  onReserveChange,
  rangeMode,
  onRangeModeChange,
  customStart,
  customEnd,
  onCustomRangeChange,
}: {
  forecast: CashflowForecast;
  reserve: number;
  onReserveChange: (amount: number) => void;
  rangeMode: CashflowRangeMode;
  onRangeModeChange: (mode: CashflowRangeMode) => void;
  customStart?: string;
  customEnd?: string;
  onCustomRangeChange: (start?: string, end?: string) => void;
}) {
  const [reserveInput, setReserveInput] = useState(String(reserve || 0));
  const [showSegments, setShowSegments] = useState(false);

  // Keep local input in sync when store value changes elsewhere.
  React.useEffect(() => {
    setReserveInput(String(reserve || 0));
  }, [reserve]);

  const ccy = forecast.baseCurrency;

  const commitReserve = (raw: string) => {
    const parsed = parseFloat(raw.replace(',', '.'));
    onReserveChange(isNaN(parsed) ? 0 : Math.max(0, parsed));
  };

  return (
    <div className="bg-gradient-to-br from-indigo-500 to-violet-600 p-5 rounded-2xl text-white shadow-lg shadow-indigo-500/20">
      <div className="flex items-center gap-2 mb-3">
        <PiggyBank className="w-4 h-4 opacity-90" />
        <span className="text-[11px] uppercase font-bold tracking-wide opacity-90">
          Сколько можно тратить
        </span>
      </div>

      {!forecast.ok ? (
        <p className="text-sm opacity-90">
          Добавьте источники дохода с датами выплат, чтобы рассчитать дневной лимит.
        </p>
      ) : (
        <>
          {/* Headline: daily until next income */}
          <div className="mb-1">
            <span className="text-3xl font-bold">{fmtMoney(forecast.dailyUntilNextIncome)}</span>
            <span className="text-sm font-medium opacity-80 ml-1.5">{ccy}/день</span>
          </div>
          {forecast.nextIncome ? (
            <p className="text-xs opacity-85 mb-3">
              до «{forecast.nextIncome.name}» — через {forecast.nextIncome.daysUntil}{' '}
              {pluralizeDays(forecast.nextIncome.daysUntil)} ({format(forecast.nextIncome.date, 'd MMM', { locale: ru })},
              {' '}+{fmtMoney(forecast.nextIncome.amount)} {ccy})
            </p>
          ) : (
            <p className="text-xs opacity-85 mb-3">ближайших поступлений в горизонте нет</p>
          )}

          {/* Period selector */}
          <div className="mb-3">
            <span className="text-[10px] uppercase font-bold opacity-75 block mb-1.5">Период расчёта</span>
            <div className="flex flex-wrap gap-1.5">
              {RANGE_OPTIONS.map((opt) => (
                <button
                  key={opt.mode}
                  onClick={() => onRangeModeChange(opt.mode)}
                  className={cn(
                    'text-[11px] font-semibold rounded-lg px-2.5 py-1 transition-colors',
                    rangeMode === opt.mode
                      ? 'bg-white text-indigo-700'
                      : 'bg-white/15 text-white hover:bg-white/25'
                  )}
                >
                  {opt.label}
                </button>
              ))}
            </div>
            {rangeMode === 'custom' && (
              <div className="flex items-center gap-2 mt-2">
                <input
                  type="date"
                  value={customStart || ''}
                  onChange={(e) => onCustomRangeChange(e.target.value || undefined, customEnd)}
                  className="flex-1 bg-white/90 text-zinc-900 text-xs font-semibold rounded-lg px-2 py-1.5 outline-none"
                />
                <ArrowRight className="w-3.5 h-3.5 opacity-70 shrink-0" />
                <input
                  type="date"
                  value={customEnd || ''}
                  onChange={(e) => onCustomRangeChange(customStart, e.target.value || undefined)}
                  className="flex-1 bg-white/90 text-zinc-900 text-xs font-semibold rounded-lg px-2 py-1.5 outline-none"
                />
              </div>
            )}
            {forecast.range && (
              <p className="text-[11px] opacity-85 mt-2">
                {forecast.range.label}: {format(forecast.range.startDate, 'd MMM', { locale: ru })} → {format(forecast.range.endDate, 'd MMM', { locale: ru })}
                {' '}({forecast.range.daysLeft} {pluralizeDays(forecast.range.daysLeft)})
                {forecast.range.totalIncome > 0 && <> · доход +{fmtMoney(forecast.range.totalIncome)} {ccy}</>}
                {forecast.range.totalObligations > 0 && <> · платежи −{fmtMoney(forecast.range.totalObligations)} {ccy}</>}
              </p>
            )}
          </div>

          {/* Balance + smoothed */}
          <div className="grid grid-cols-2 gap-3 mb-3">
            <div className="bg-white/15 rounded-xl p-3">
              <span className="text-[10px] uppercase font-bold opacity-75 block">Сейчас на счетах</span>
              <span className="text-lg font-bold">{fmtMoney(forecast.currentBalance)} {ccy}</span>
            </div>
            <div className="bg-white/15 rounded-xl p-3">
              <span className="text-[10px] uppercase font-bold opacity-75 block">Ровно в день ({forecast.range?.label ?? 'период'})</span>
              <span className="text-lg font-bold">{fmtMoney(forecast.smoothedDaily)} {ccy}</span>
            </div>
          </div>

          {/* Cash gap warning */}
          {forecast.hasCashGap && (
            <div className="flex items-start gap-2 bg-rose-500/30 border border-white/30 rounded-xl p-3 mb-3">
              <AlertTriangle className="w-4 h-4 mt-0.5 shrink-0" />
              <span className="text-xs leading-snug">
                Кассовый разрыв: остатка и резерва не хватает на обязательные платежи до следующего дохода.
              </span>
            </div>
          )}

          {/* Reserve input */}
          <div className="bg-white/15 rounded-xl p-3 mb-1">
            <label className="text-[10px] uppercase font-bold opacity-75 block mb-1.5">
              Несгораемый резерв
            </label>
            <div className="flex items-center gap-2">
              <input
                type="number"
                inputMode="decimal"
                min={0}
                value={reserveInput}
                onChange={(e) => setReserveInput(e.target.value)}
                onBlur={(e) => commitReserve(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') (e.target as HTMLInputElement).blur();
                }}
                className="flex-1 bg-white/90 text-zinc-900 text-sm font-semibold rounded-lg px-3 py-2 outline-none focus:ring-2 focus:ring-white/60"
              />
              <span className="text-sm font-medium opacity-90">{ccy}</span>
            </div>
            <p className="text-[10px] opacity-70 mt-1.5">
              Эта сумма не входит в дневной лимит — её приложение бережёт.
            </p>
          </div>

          {/* Segments toggle */}
          {forecast.segments.length > 0 && (
            <button
              onClick={() => setShowSegments((v) => !v)}
              className="flex items-center gap-1 text-xs font-medium opacity-90 mt-2"
            >
              {showSegments ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
              По периодам ({forecast.segments.length})
            </button>
          )}
          {showSegments && (
            <div className="space-y-2 mt-2">
              {forecast.segments.map((seg, i) => (
                <div key={i} className="bg-white/10 rounded-xl p-3">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-semibold">{seg.label}</span>
                    <span className={cn('text-sm font-bold', seg.shortfall && 'text-rose-200')}>
                      {fmtMoney(seg.dailyLimit)} {ccy}/день
                    </span>
                  </div>
                  <div className="flex items-center justify-between text-[10px] opacity-75 mt-1">
                    <span>
                      {format(seg.startDate, 'd MMM', { locale: ru })} → {format(seg.endDate, 'd MMM', { locale: ru })} ({seg.days}{' '}
                      {pluralizeDays(seg.days)})
                    </span>
                    {seg.obligations > 0 && <span>платежи: −{fmtMoney(seg.obligations)}</span>}
                  </div>
                  {seg.shortfall && (
                    <p className="text-[10px] text-rose-200 mt-1">
                      не хватает на платежи + резерв в этом окне
                    </p>
                  )}
                </div>
              ))}
            </div>
          )}
        </>
      )}
    </div>
  );
}

function pluralizeDays(n: number): string {
  const mod10 = n % 10;
  const mod100 = n % 100;
  if (mod10 === 1 && mod100 !== 11) return 'день';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return 'дня';
  return 'дней';
}

// ═══════════════ FACT SECTION ═══════════════

function FactSection() {
  const {
    incomeSources, plannedExpenses, actualExpenses, addActualExpense, deleteActualExpense,
    accounts, transactions, rates, baseCurrency, safeToSpendReserve, setSafeToSpendReserve,
    safeToSpendRangeMode, setSafeToSpendRangeMode,
    safeToSpendCustomStart, safeToSpendCustomEnd, setSafeToSpendCustomRange,
  } = useStore();
  const [showExpForm, setShowExpForm] = useState(false);
  const [expForm, setExpForm] = useState({ name: '', amount: '', date: format(new Date(), 'yyyy-MM-dd') });

  const sources = incomeSources || [];
  const planned = plannedExpenses || [];
  const actual = actualExpenses || [];

  const cycles = useMemo(() =>
    computeBudgetCycles({
      accounts: accounts || [],
      transactions: transactions || [],
      rates: rates || {},
      baseCurrency: baseCurrency || 'BYN',
      incomeSources: sources,
      plannedExpenses: planned,
      reserve: safeToSpendReserve || 0,
    }),
    [accounts, transactions, rates, baseCurrency, sources, planned, safeToSpendReserve]
  );

  const customStart = safeToSpendCustomStart ? parseISO(safeToSpendCustomStart) : undefined;
  const customEnd = safeToSpendCustomEnd ? parseISO(safeToSpendCustomEnd) : undefined;

  const forecast = useMemo(() =>
    computeCashflowForecast({
      accounts: accounts || [],
      transactions: transactions || [],
      rates: rates || {},
      baseCurrency: baseCurrency || 'BYN',
      incomeSources: sources,
      plannedExpenses: planned,
      reserve: safeToSpendReserve || 0,
      rangeMode: safeToSpendRangeMode || 'auto',
      customStart,
      customEnd,
    }),
    [accounts, transactions, rates, baseCurrency, sources, planned, safeToSpendReserve, safeToSpendRangeMode, safeToSpendCustomStart, safeToSpendCustomEnd]
  );

  const totalIncome = sources.filter(s => s.isActive).reduce((sum, s) => sum + s.amount, 0);
  const totalPlannedExp = planned.filter(e => e.isActive).reduce((sum, e) => sum + e.amount, 0);
  const totalPaid = planned.filter(e => e.isPaid).reduce((sum, e) => sum + (e.paidAmount || e.amount), 0);
  const totalActual = actual.reduce((sum, e) => sum + e.amount, 0);
  const totalSpent = totalPaid + totalActual;
  const remaining = totalIncome - totalSpent;

  const handleAddExpense = () => {
    const amount = parseFloat(expForm.amount);
    if (!expForm.name || isNaN(amount)) return;
    addActualExpense({ name: expForm.name, amount, date: expForm.date });
    setExpForm({ name: '', amount: '', date: format(new Date(), 'yyyy-MM-dd') });
    setShowExpForm(false);
  };

  // Donut data
  const donutData = [
    { name: 'Оплачено (план)', value: totalPaid, color: '#10b981' },
    { name: 'Фактические', value: totalActual, color: '#f59e0b' },
    { name: 'Осталось', value: Math.max(0, remaining), color: '#6366f1' },
  ].filter(d => d.value > 0);

  // Expense breakdown bar data
  const expenseBarData = planned.filter(e => e.isActive).map(e => ({
    name: e.name.length > 10 ? e.name.slice(0, 10) + '…' : e.name,
    план: e.amount,
    факт: e.isPaid ? (e.paidAmount || e.amount) : 0,
  }));

  if (sources.length === 0) {
    return (
      <div className="bg-white p-8 rounded-2xl border border-stone-200 text-center">
        <Wallet className="w-8 h-8 text-zinc-300 mx-auto mb-3" />
        <p className="text-sm text-zinc-500 mb-1">Сначала добавьте источники дохода</p>
        <p className="text-xs text-zinc-400">Перейдите во вкладку "План доходов"</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Safe-to-spend forecast */}
      <SafeToSpendCard
        forecast={forecast}
        reserve={safeToSpendReserve || 0}
        onReserveChange={setSafeToSpendReserve}
        rangeMode={safeToSpendRangeMode || 'auto'}
        onRangeModeChange={setSafeToSpendRangeMode}
        customStart={safeToSpendCustomStart}
        customEnd={safeToSpendCustomEnd}
        onCustomRangeChange={setSafeToSpendCustomRange}
      />

      {/* Summary cards */}
      <div className="grid grid-cols-2 gap-3">
        <div className="bg-gradient-to-br from-emerald-500 to-emerald-600 p-4 rounded-2xl text-white shadow-lg shadow-emerald-500/20">
          <span className="text-[10px] uppercase font-bold opacity-80 block mb-0.5">Доход</span>
          <span className="text-xl font-bold">{totalIncome.toLocaleString('ru-RU')}</span>
          <span className="text-xs opacity-70 ml-1">BYN</span>
        </div>
        <div className="bg-gradient-to-br from-rose-500 to-rose-600 p-4 rounded-2xl text-white shadow-lg shadow-rose-500/20">
          <span className="text-[10px] uppercase font-bold opacity-80 block mb-0.5">Расходы (план)</span>
          <span className="text-xl font-bold">{totalPlannedExp.toLocaleString('ru-RU')}</span>
          <span className="text-xs opacity-70 ml-1">BYN</span>
        </div>
      </div>

      {/* After expenses remaining */}
      <div className="bg-white p-4 rounded-2xl border border-stone-200">
        <div className="flex items-center justify-between mb-3">
          <span className="text-xs font-bold text-zinc-500 uppercase">Чистый остаток после плановых расходов</span>
          <span className={cn(
            "text-lg font-bold",
            (totalIncome - totalPlannedExp) >= 0 ? "text-emerald-600" : "text-rose-500"
          )}>
            {(totalIncome - totalPlannedExp).toLocaleString('ru-RU')} BYN
          </span>
        </div>
        <div className="h-2 bg-stone-100 rounded-full overflow-hidden">
          <div
            className={cn(
              "h-full rounded-full transition-all",
              totalSpent <= totalIncome ? "bg-emerald-500" : "bg-rose-500"
            )}
            style={{ width: `${totalIncome > 0 ? Math.min(100, (totalSpent / totalIncome) * 100) : 0}%` }}
          />
        </div>
        <div className="flex justify-between mt-1.5 text-[10px] text-zinc-400">
          <span>Потрачено: {totalSpent.toLocaleString('ru-RU')}</span>
          <span>{totalIncome > 0 ? Math.round((totalSpent / totalIncome) * 100) : 0}%</span>
        </div>
      </div>

      {/* Donut chart */}
      {donutData.length > 0 && (
        <div className="bg-white p-4 rounded-2xl border border-stone-200">
          <h3 className="text-xs font-bold text-zinc-500 uppercase mb-2">Распределение бюджета</h3>
          <div className="flex items-center gap-4">
            <div className="w-32 h-32">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={donutData}
                    cx="50%"
                    cy="50%"
                    innerRadius={35}
                    outerRadius={55}
                    paddingAngle={3}
                    dataKey="value"
                    strokeWidth={0}
                  >
                    {donutData.map((entry, i) => (
                      <Cell key={i} fill={entry.color} />
                    ))}
                  </Pie>
                </PieChart>
              </ResponsiveContainer>
            </div>
            <div className="flex-1 space-y-2">
              {donutData.map((d, i) => (
                <div key={i} className="flex items-center gap-2">
                  <div className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: d.color }} />
                  <span className="text-[11px] text-zinc-600 flex-1">{d.name}</span>
                  <span className="text-[11px] font-bold text-zinc-900">{d.value.toLocaleString('ru-RU')}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Budget cycles */}
      {cycles.map((cycle, i) => (
        <motion.div
          key={i}
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: i * 0.1 }}
          className="bg-white p-4 rounded-2xl border border-stone-200"
        >
          <div className="flex items-center gap-2 mb-3">
            <div className={cn(
              "p-1.5 rounded-lg",
              i === 0 ? "bg-blue-100" : i === 1 ? "bg-purple-100" : "bg-emerald-100"
            )}>
              <Clock className={cn(
                "w-4 h-4",
                i === 0 ? "text-blue-600" : i === 1 ? "text-purple-600" : "text-emerald-600"
              )} />
            </div>
            <div>
              <h3 className="text-sm font-bold text-zinc-900">{cycle.label}</h3>
              <p className="text-[10px] text-zinc-400">
                {format(cycle.startDate, 'd MMM', { locale: ru })} → {format(cycle.endDate, 'd MMM', { locale: ru })}
                {' · '}{cycle.totalDays} дн. · осталось {cycle.daysLeft} дн.
              </p>
            </div>
          </div>

          {/* Progress ring style */}
          <div className="grid grid-cols-3 gap-2 mb-3">
            <div className="text-center">
              <div className="relative w-16 h-16 mx-auto mb-1">
                <svg className="w-full h-full -rotate-90" viewBox="0 0 36 36">
                  <circle cx="18" cy="18" r="15.5" fill="none" stroke="#f4f4f5" strokeWidth="3" />
                  <circle
                    cx="18" cy="18" r="15.5" fill="none"
                    stroke={cycle.daysLeft > cycle.totalDays * 0.5 ? '#10b981' : cycle.daysLeft > cycle.totalDays * 0.25 ? '#f59e0b' : '#ef4444'}
                    strokeWidth="3"
                    strokeDasharray={`${(cycle.daysLeft / cycle.totalDays) * 97.4} 97.4`}
                    strokeLinecap="round"
                  />
                </svg>
                <span className="absolute inset-0 flex items-center justify-center text-xs font-bold text-zinc-900">
                  {cycle.daysLeft}д
                </span>
              </div>
              <span className="text-[9px] text-zinc-500 font-bold uppercase">Дней</span>
            </div>
            <div className="text-center">
              <div className="relative w-16 h-16 mx-auto mb-1">
                <svg className="w-full h-full -rotate-90" viewBox="0 0 36 36">
                  <circle cx="18" cy="18" r="15.5" fill="none" stroke="#f4f4f5" strokeWidth="3" />
                  <circle
                    cx="18" cy="18" r="15.5" fill="none" stroke="#6366f1"
                    strokeWidth="3"
                    strokeDasharray={`${cycle.totalIncome > 0 ? (cycle.remainingBudget / cycle.totalIncome) * 97.4 : 0} 97.4`}
                    strokeLinecap="round"
                  />
                </svg>
                <span className="absolute inset-0 flex items-center justify-center text-[10px] font-bold text-zinc-900">
                  {cycle.totalIncome > 0 ? Math.round((cycle.remainingBudget / cycle.totalIncome) * 100) : 0}%
                </span>
              </div>
              <span className="text-[9px] text-zinc-500 font-bold uppercase">Бюджет</span>
            </div>
            <div className="text-center">
              <div className="relative w-16 h-16 mx-auto mb-1">
                <svg className="w-full h-full -rotate-90" viewBox="0 0 36 36">
                  <circle cx="18" cy="18" r="15.5" fill="none" stroke="#f4f4f5" strokeWidth="3" />
                  <circle
                    cx="18" cy="18" r="15.5" fill="none" stroke="#f59e0b"
                    strokeWidth="3"
                    strokeDasharray={`${cycle.totalIncome > 0 ? Math.min(97.4, (cycle.totalPlannedExpenses / cycle.totalIncome) * 97.4) : 0} 97.4`}
                    strokeLinecap="round"
                  />
                </svg>
                <span className="absolute inset-0 flex items-center justify-center text-[10px] font-bold text-zinc-900">
                  {cycle.totalIncome > 0 ? Math.round((cycle.totalPlannedExpenses / cycle.totalIncome) * 100) : 0}%
                </span>
              </div>
              <span className="text-[9px] text-zinc-500 font-bold uppercase">Платежи</span>
            </div>
          </div>

          {/* Budget per day/week */}
          <div className="bg-stone-50 rounded-xl p-3 space-y-2">
            <div className="flex justify-between items-center">
              <span className="text-xs text-zinc-500">Остаток:</span>
              <span className={cn("text-sm font-bold", cycle.remainingBudget >= 0 ? "text-emerald-600" : "text-rose-500")}>
                {cycle.remainingBudget.toLocaleString('ru-RU', { maximumFractionDigits: 0 })} BYN
              </span>
            </div>
            <div className="h-px bg-stone-200" />
            <div className="flex justify-between items-center">
              <span className="text-xs text-zinc-500 flex items-center gap-1">
                <DollarSign className="w-3 h-3" /> В день:
              </span>
              <span className="text-lg font-bold text-indigo-600">
                {cycle.dailyBudget.toLocaleString('ru-RU', { maximumFractionDigits: 2 })} BYN
              </span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-xs text-zinc-500 flex items-center gap-1">
                <Calendar className="w-3 h-3" /> В неделю:
              </span>
              <span className="text-lg font-bold text-purple-600">
                {cycle.weeklyBudget.toLocaleString('ru-RU', { maximumFractionDigits: 2 })} BYN
              </span>
            </div>
            {cycle.fullWeeks > 0 && (
              <p className="text-[10px] text-zinc-400 text-center mt-1">
                {cycle.fullWeeks} {cycle.fullWeeks === 1 ? 'неделя' : cycle.fullWeeks < 5 ? 'недели' : 'недель'}
                {cycle.extraDays > 0 && ` и ${cycle.extraDays} ${cycle.extraDays === 1 ? 'день' : cycle.extraDays < 5 ? 'дня' : 'дней'}`}
              </p>
            )}
          </div>

          {cycle.remainingBudget < 0 && (
            <div className="flex items-center gap-2 mt-2 p-2 bg-rose-50 rounded-xl border border-rose-100">
              <AlertTriangle className="w-4 h-4 text-rose-500 shrink-0" />
              <p className="text-[10px] text-rose-600">Бюджет превышен на {Math.abs(cycle.remainingBudget).toLocaleString('ru-RU')} BYN</p>
            </div>
          )}
        </motion.div>
      ))}

      {/* Expense breakdown chart */}
      {expenseBarData.length > 0 && (
        <div className="bg-white p-4 rounded-2xl border border-stone-200">
          <h3 className="text-xs font-bold text-zinc-500 uppercase mb-3">План vs Факт расходов</h3>
          <div className="h-44">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={expenseBarData} barGap={2}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f4f4f5" />
                <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fontSize: 8, fill: '#71717a' }} />
                <YAxis axisLine={false} tickLine={false} tick={{ fontSize: 8, fill: '#71717a' }} />
                <Tooltip
                  contentStyle={{ backgroundColor: '#fff', border: '1px solid #e4e4e7', borderRadius: '12px', fontSize: '10px' }}
                />
                <Bar dataKey="план" fill="#e4e4e7" radius={[4, 4, 0, 0]} maxBarSize={24} />
                <Bar dataKey="факт" fill="#10b981" radius={[4, 4, 0, 0]} maxBarSize={24} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      {/* Actual expenses log */}
      <div className="bg-white p-4 rounded-2xl border border-stone-200">
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-xs font-bold text-zinc-500 uppercase">Фактические расходы</h3>
          <button
            onClick={() => setShowExpForm(!showExpForm)}
            className="p-1.5 bg-stone-100 text-zinc-500 rounded-xl hover:text-zinc-900 transition-colors"
          >
            <Plus className="w-4 h-4" />
          </button>
        </div>

        <AnimatePresence>
          {showExpForm && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
              className="space-y-2 mb-3 overflow-hidden"
            >
              <input
                value={expForm.name}
                onChange={e => setExpForm({ ...expForm, name: e.target.value })}
                placeholder="Описание"
                className="w-full px-3 py-2 bg-stone-50 border border-stone-200 rounded-xl text-sm"
              />
              <div className="grid grid-cols-2 gap-2">
                <input
                  type="number"
                  value={expForm.amount}
                  onChange={e => setExpForm({ ...expForm, amount: e.target.value })}
                  placeholder="Сумма"
                  className="px-3 py-2 bg-stone-50 border border-stone-200 rounded-xl text-sm"
                />
                <input
                  type="date"
                  value={expForm.date}
                  onChange={e => setExpForm({ ...expForm, date: e.target.value })}
                  className="px-3 py-2 bg-stone-50 border border-stone-200 rounded-xl text-sm"
                />
              </div>
              <button
                onClick={handleAddExpense}
                className="w-full py-2 bg-amber-500 text-white rounded-xl text-xs font-bold hover:bg-amber-600"
              >
                Добавить расход
              </button>
            </motion.div>
          )}
        </AnimatePresence>

        {actual.length === 0 ? (
          <p className="text-xs text-zinc-400 text-center py-3">Нет фактических расходов</p>
        ) : (
          <div className="space-y-1.5">
            {actual.slice().reverse().map(exp => (
              <div key={exp.id} className="flex items-center justify-between py-1.5 px-2 bg-stone-50 rounded-lg">
                <div>
                  <p className="text-xs font-medium text-zinc-700">{exp.name}</p>
                  <p className="text-[10px] text-zinc-400">{exp.date}</p>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-xs font-bold text-amber-600">{exp.amount.toLocaleString('ru-RU')} BYN</span>
                  <button onClick={() => deleteActualExpense(exp.id)} className="text-zinc-300 hover:text-rose-500">
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
