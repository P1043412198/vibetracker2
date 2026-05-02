/**
 * Раздел «Инструменты» — финансовая грамотность под Беларусь:
 *  - Калькуляторы (сложный %, депозит РБ с 13%, кредит, зарплата, ИП УСН, НПД, FIRE)
 *  - Глоссарий
 *  - Мини-курсы
 *  - Шаблоны привычек/целей
 */
import React, { useMemo, useState } from 'react';
import {
  Calculator,
  BookOpen,
  Sparkles,
  Layers,
  PiggyBank,
  TrendingUp,
  Briefcase,
  CreditCard,
  Wallet,
  ShieldCheck,
  Wind,
  GraduationCap,
} from 'lucide-react';
import { cn } from '../lib/utils';
import { formatCurrency, formatPercent } from '../lib/format';
import {
  buildLoanSchedule,
  compoundInterest,
  applyDevaluation,
  fireNumber,
  safetyFundTarget,
  yearsToFire,
} from '../lib/finance/calculators';
import {
  calcDepositBY,
  calcIpUsn,
  calcNetSalary,
  calcNpd,
  calcVacationPay,
} from '../lib/finance/byTax';
import { GLOSSARY } from '../data/glossary';
import { COURSES, type Course } from '../data/courses';
import { FINLIT_BY_2026, type FinTipCategory, type FinTip } from '../data/finlitTips';
import { useStore } from '../store/useStore';
import { useNavigate } from 'react-router-dom';
import { Plus, Trash2, BookmarkPlus, Save } from 'lucide-react';
import type { SalaryDeductionPreset } from '../types';
import { v4 as uuidv4 } from 'uuid';

type TabId = 'calc' | 'finlit' | 'glossary' | 'courses' | 'templates';

const TABS: { id: TabId; label: string; icon: React.ComponentType<any> }[] = [
  { id: 'calc', label: 'Калькуляторы', icon: Calculator },
  { id: 'finlit', label: 'Финграмотность 2026', icon: GraduationCap },
  { id: 'glossary', label: 'Глоссарий', icon: BookOpen },
  { id: 'courses', label: 'Мини-курсы', icon: BookOpen },
  { id: 'templates', label: 'Шаблоны', icon: Sparkles },
];

const CALC_LIST = [
  { id: 'compound', label: 'Сложный процент', icon: TrendingUp },
  { id: 'deposit-by', label: 'Депозит (РБ)', icon: PiggyBank },
  { id: 'credit', label: 'Кредит', icon: CreditCard },
  { id: 'salary-by', label: 'Зарплата на руки', icon: Wallet },
  { id: 'ip-usn', label: 'ИП на УСН', icon: Briefcase },
  { id: 'npd', label: 'НПД (самозанятые)', icon: Briefcase },
  { id: 'safety-fund', label: 'Подушка безопасности', icon: ShieldCheck },
  { id: 'fx-stress', label: 'Валютный стресс-тест', icon: Wind },
  { id: 'vacation', label: 'Отпускные', icon: Sparkles },
  { id: 'fire', label: 'FIRE', icon: TrendingUp },
] as const;
type CalcId = (typeof CALC_LIST)[number]['id'];

export function Tools() {
  const [tab, setTab] = useState<TabId>('calc');
  const [calcId, setCalcId] = useState<CalcId>('compound');
  const refRate = useStore((s) => s.refinancingRate);
  const refRateAt = useStore((s) => s.refinancingRateUpdatedAt);
  const fetchRefRate = useStore((s) => s.fetchRefinancingRate);

  React.useEffect(() => {
    fetchRefRate();
  }, [fetchRefRate]);

  return (
    <div className="px-4 py-4 sm:py-6 max-w-5xl mx-auto pb-24 md:pb-8">
      <header className="mb-4 sm:mb-6 flex items-start gap-3">
        <div className="inline-flex items-center justify-center w-10 h-10 rounded-2xl bg-emerald-100 text-emerald-700">
          <Layers className="w-5 h-5" />
        </div>
        <div className="flex-1">
          <h1 className="text-xl sm:text-2xl font-bold text-zinc-900">
            Инструменты
          </h1>
          <p className="text-xs text-zinc-500">
            Калькуляторы, глоссарий и мини-курсы по финграмотности — под Беларусь.
          </p>
        </div>
        {refRate != null && (
          <div className="text-right hidden sm:block">
            <div className="text-[10px] uppercase text-zinc-500">
              Ставка рефинансирования НБРБ
            </div>
            <div className="text-lg font-semibold text-emerald-700">
              {formatPercent(refRate)}
            </div>
            {refRateAt && (
              <div className="text-[9px] text-zinc-400">
                обновлено {new Date(refRateAt).toLocaleDateString('ru-BY')}
              </div>
            )}
          </div>
        )}
      </header>

      <div className="flex gap-1 mb-4 overflow-x-auto pb-1 -mx-1 px-1">
        {TABS.map((t) => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            className={cn(
              'inline-flex items-center gap-1.5 rounded-2xl px-3 py-2 text-xs font-medium transition-colors shrink-0',
              tab === t.id
                ? 'bg-emerald-600 text-white'
                : 'bg-stone-100 text-zinc-700 hover:bg-stone-200'
            )}
          >
            <t.icon className="w-3.5 h-3.5" />
            {t.label}
          </button>
        ))}
      </div>

      {tab === 'calc' && (
        <CalcsTab calcId={calcId} setCalcId={setCalcId} />
      )}
      {tab === 'finlit' && <FinLitTab />}
      {tab === 'glossary' && <GlossaryTab />}
      {tab === 'courses' && <CoursesTab />}
      {tab === 'templates' && <TemplatesTab />}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/*                            Калькуляторы                             */
/* ------------------------------------------------------------------ */

function CalcsTab({ calcId, setCalcId }: { calcId: CalcId; setCalcId: (id: CalcId) => void }) {
  return (
    <div className="grid md:grid-cols-[200px_1fr] gap-4">
      <aside className="space-y-1 max-h-[80vh] overflow-y-auto">
        {CALC_LIST.map((c) => (
          <button
            key={c.id}
            onClick={() => setCalcId(c.id)}
            className={cn(
              'w-full text-left flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-medium transition-colors',
              calcId === c.id
                ? 'bg-emerald-100 text-emerald-800'
                : 'hover:bg-stone-50 text-zinc-700'
            )}
          >
            <c.icon className="w-3.5 h-3.5" />
            {c.label}
          </button>
        ))}
      </aside>
      <section className="bg-white rounded-3xl border border-stone-200 p-4 sm:p-5 shadow-sm">
        {calcId === 'compound' && <CompoundCalc />}
        {calcId === 'deposit-by' && <DepositByCalc />}
        {calcId === 'credit' && <CreditCalc />}
        {calcId === 'salary-by' && <SalaryCalc />}
        {calcId === 'ip-usn' && <IpUsnCalc />}
        {calcId === 'npd' && <NpdCalc />}
        {calcId === 'safety-fund' && <SafetyFundCalc />}
        {calcId === 'fx-stress' && <FxStressCalc />}
        {calcId === 'vacation' && <VacationCalc />}
        {calcId === 'fire' && <FireCalc />}
      </section>
    </div>
  );
}

function NumberField({
  label,
  value,
  onChange,
  step = 1,
  suffix,
}: {
  label: string;
  value: number;
  onChange: (n: number) => void;
  step?: number;
  suffix?: string;
}) {
  return (
    <label className="block text-xs text-zinc-700">
      <span className="block mb-1 font-medium">{label}</span>
      <div className="relative">
        <input
          type="number"
          value={Number.isFinite(value) ? value : 0}
          step={step}
          onChange={(e) => onChange(Number(e.target.value))}
          className="w-full bg-white border border-stone-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:border-emerald-500"
        />
        {suffix && (
          <span className="absolute right-3 top-1/2 -translate-y-1/2 text-[10px] text-zinc-400">
            {suffix}
          </span>
        )}
      </div>
    </label>
  );
}

function ResultRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between text-sm py-1.5 border-b border-stone-100 last:border-0">
      <span className="text-zinc-600">{label}</span>
      <span className="font-semibold text-zinc-900">{value}</span>
    </div>
  );
}

function CompoundCalc() {
  const [principal, setPrincipal] = useState(10_000);
  const [rate, setRate] = useState(10);
  const [years, setYears] = useState(10);
  const [monthly, setMonthly] = useState(0);
  const r = compoundInterest({
    principal,
    annualRatePct: rate,
    years,
    monthlyContribution: monthly,
  });
  return (
    <div className="space-y-4">
      <h2 className="text-base font-semibold">Сложный процент</h2>
      <div className="grid grid-cols-2 gap-3">
        <NumberField label="Начальный капитал" value={principal} onChange={setPrincipal} step={100} suffix="BYN" />
        <NumberField label="Годовая ставка" value={rate} onChange={setRate} step={0.5} suffix="%" />
        <NumberField label="Срок" value={years} onChange={setYears} step={1} suffix="лет" />
        <NumberField label="Пополнение в месяц" value={monthly} onChange={setMonthly} step={50} suffix="BYN" />
      </div>
      <div className="bg-stone-50 rounded-2xl p-3">
        <ResultRow label="Итоговый капитал" value={formatCurrency(r.finalBalance)} />
        <ResultRow label="Внесено" value={formatCurrency(r.totalContributed)} />
        <ResultRow label="Проценты" value={formatCurrency(r.totalInterest)} />
      </div>
    </div>
  );
}

function DepositByCalc() {
  const [amount, setAmount] = useState(5_000);
  const [rate, setRate] = useState(12);
  const [months, setMonths] = useState(6);
  const [taxApplies, setTaxApplies] = useState(true);
  const [capitalize, setCapitalize] = useState(true);
  const r = calcDepositBY({
    amount,
    annualRatePct: rate,
    termMonths: months,
    taxApplies,
    capitalize,
  });
  return (
    <div className="space-y-4">
      <h2 className="text-base font-semibold">Депозит (РБ)</h2>
      <div className="grid grid-cols-2 gap-3">
        <NumberField label="Сумма вклада" value={amount} onChange={setAmount} step={100} suffix="BYN" />
        <NumberField label="Годовая ставка" value={rate} onChange={setRate} step={0.5} suffix="%" />
        <NumberField label="Срок" value={months} onChange={setMonths} step={1} suffix="мес." />
        <label className="text-xs text-zinc-700 flex flex-col gap-2 justify-end">
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={taxApplies}
              onChange={(e) => setTaxApplies(e.target.checked)}
            />
            Применять налог 13% (вклад &lt; 1 года)
          </label>
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={capitalize}
              onChange={(e) => setCapitalize(e.target.checked)}
            />
            Капитализация процентов
          </label>
        </label>
      </div>
      <div className="bg-stone-50 rounded-2xl p-3">
        <ResultRow label="Проценты до налога" value={formatCurrency(r.totalInterestGross)} />
        <ResultRow label="Налог 13%" value={formatCurrency(r.totalTax)} />
        <ResultRow label="Чистые проценты" value={formatCurrency(r.totalInterestNet)} />
        <ResultRow label="Итог на счёте" value={formatCurrency(r.finalBalance)} />
      </div>
      <p className="text-[11px] text-zinc-500">
        С 2024 года проценты по вкладам физлиц со сроком меньше 1 года облагаются подоходным 13%. По длинным депозитам (≥ 1 года) налог не применяется. Гарантийный фонд НБРБ компенсирует вклады в любом банке.
      </p>
    </div>
  );
}

function CreditCalc() {
  const [amount, setAmount] = useState(20_000);
  const [rate, setRate] = useState(15);
  const [months, setMonths] = useState(60);
  const [type, setType] = useState<'annuity' | 'differential'>('annuity');
  const r = buildLoanSchedule({ amount, annualRatePct: rate, termMonths: months, type });
  return (
    <div className="space-y-4">
      <h2 className="text-base font-semibold">Кредит</h2>
      <div className="grid grid-cols-2 gap-3">
        <NumberField label="Сумма" value={amount} onChange={setAmount} step={500} suffix="BYN" />
        <NumberField label="Годовая ставка" value={rate} onChange={setRate} step={0.5} suffix="%" />
        <NumberField label="Срок" value={months} onChange={setMonths} step={1} suffix="мес." />
        <label className="text-xs text-zinc-700 flex flex-col gap-1">
          <span className="font-medium">График</span>
          <select
            value={type}
            onChange={(e) => setType(e.target.value as any)}
            className="bg-white border border-stone-200 rounded-xl px-3 py-2 text-sm"
          >
            <option value="annuity">Аннуитет (одинаковый платёж)</option>
            <option value="differential">Дифференцированный</option>
          </select>
        </label>
      </div>
      <div className="bg-stone-50 rounded-2xl p-3">
        {type === 'annuity' ? (
          <ResultRow label="Ежемесячный платёж" value={formatCurrency(r.monthlyPayment)} />
        ) : (
          <>
            <ResultRow label="Первый платёж" value={formatCurrency(r.schedule[0]?.payment ?? 0)} />
            <ResultRow label="Последний платёж" value={formatCurrency(r.schedule.at(-1)?.payment ?? 0)} />
          </>
        )}
        <ResultRow label="Всего выплат" value={formatCurrency(r.totalPayment)} />
        <ResultRow label="Переплата" value={formatCurrency(r.totalInterest)} />
      </div>
    </div>
  );
}

const SUGGESTED_DEDUCTIONS: { label: string; kind: 'percent' | 'fixed'; value: number; taxable?: boolean }[] = [
  { label: 'Профсоюз', kind: 'percent', value: 1, taxable: false },
  { label: 'ДМС (медстраховка)', kind: 'fixed', value: 50, taxable: true },
  { label: 'Благотворительность', kind: 'fixed', value: 30, taxable: false },
  { label: 'Пенсионная программа', kind: 'percent', value: 3, taxable: true },
  { label: 'Алименты', kind: 'percent', value: 25, taxable: false },
  { label: 'Кредитное удержание', kind: 'fixed', value: 200, taxable: false },
];

function SalaryCalc() {
  const presets = useStore(s => s.salaryDeductionPresets ?? []);
  const upsertPreset = useStore(s => s.upsertSalaryDeductionPreset);
  const deletePreset = useStore(s => s.deleteSalaryDeductionPreset);
  const togglePreset = useStore(s => s.toggleSalaryDeductionPreset);

  const [gross, setGross] = useState(2000);
  const [children, setChildren] = useState(0);
  const [dependents, setDependents] = useState(0);

  const enabledPresets = presets.filter(p => p.enabled);
  const r = calcNetSalary({
    gross,
    children,
    dependents,
    extraDeductions: enabledPresets.map(p => ({
      id: p.id,
      label: p.label,
      kind: p.kind,
      value: p.value,
      taxable: p.taxable,
    })),
  });

  const totalKept = r.gross > 0 ? Math.round((r.net / r.gross) * 100) : 0;

  const breakdown = [
    { label: 'На руки', value: r.net, color: '#10b981' },
    { label: 'Подоходный', value: r.incomeTax, color: '#ef4444' },
    { label: 'ФСЗН', value: r.fszn, color: '#f59e0b' },
    ...r.extraDeductionsApplied.map(line => ({
      label: line.label,
      value: line.amount,
      color: line.taxable ? '#3b82f6' : '#a855f7',
    })),
  ].filter(s => s.value > 0);

  return (
    <div className="space-y-4">
      <h2 className="text-base font-semibold">Зарплата на руки (РБ)</h2>
      <div className="grid grid-cols-2 gap-3">
        <NumberField label="Грязная зарплата" value={gross} onChange={setGross} step={50} suffix="BYN" />
        <NumberField label="Детей" value={children} onChange={setChildren} step={1} />
        <NumberField label="Иждивенцев" value={dependents} onChange={setDependents} step={1} />
      </div>

      <SalaryDeductionsEditor
        presets={presets}
        onUpsert={upsertPreset}
        onDelete={deletePreset}
        onToggle={togglePreset}
      />

      {/* Visual breakdown */}
      <div className="bg-stone-50 rounded-2xl p-3 space-y-3">
        <div className="flex items-center justify-between">
          <span className="text-xs uppercase font-bold text-zinc-500 tracking-wide">Куда уходит зарплата</span>
          <span className="text-[11px] text-zinc-500">
            {totalKept}% остаётся на руки
          </span>
        </div>
        <SalaryStackedBar parts={breakdown} total={r.gross} />
        <div className="grid grid-cols-2 gap-x-3 gap-y-1.5">
          {breakdown.map(p => (
            <div key={p.label} className="flex items-center gap-1.5 text-[11px] min-w-0">
              <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ background: p.color }} />
              <span className="truncate text-zinc-600">{p.label}</span>
              <span className="ml-auto font-semibold text-zinc-900 tabular-nums">
                {formatCurrency(p.value)}
              </span>
            </div>
          ))}
        </div>
      </div>

      <div className="bg-stone-50 rounded-2xl p-3">
        <ResultRow label="Подоходный 13%" value={formatCurrency(r.incomeTax)} />
        <ResultRow label="ФСЗН 1%" value={formatCurrency(r.fszn)} />
        <ResultRow label="Налогооблагаемая база" value={formatCurrency(r.taxableBase)} />
        <ResultRow label="Стандартные/детские вычеты" value={formatCurrency(r.deductions)} />
        {r.pretaxDeductions > 0 && (
          <ResultRow label="Уменьшили базу (pre-tax)" value={formatCurrency(r.pretaxDeductions)} />
        )}
        {r.postTaxDeductions > 0 && (
          <ResultRow label="Удержано после налога" value={formatCurrency(r.postTaxDeductions)} />
        )}
        <ResultRow label="На руки" value={formatCurrency(r.net)} />
      </div>
      <p className="text-[11px] text-zinc-500">
        Профсоюзные взносы по сложившейся практике не уменьшают подоходный налог — снимай галочку «уменьшает налоговую базу». ДМС/пенсионную программу обычно можно оформить как соц. вычет — тогда галочку оставляй.
      </p>
    </div>
  );
}

function SalaryStackedBar({ parts, total }: { parts: { label: string; value: number; color: string }[]; total: number }) {
  if (total <= 0) return null;
  return (
    <div className="h-3 rounded-full overflow-hidden bg-stone-200 flex">
      {parts.map(p => {
        const pct = (p.value / total) * 100;
        if (pct <= 0) return null;
        return (
          <div
            key={p.label}
            className="h-full"
            style={{ width: `${pct}%`, background: p.color }}
            title={`${p.label}: ${formatCurrency(p.value)}`}
          />
        );
      })}
    </div>
  );
}

function SalaryDeductionsEditor({
  presets,
  onUpsert,
  onDelete,
  onToggle,
}: {
  presets: SalaryDeductionPreset[];
  onUpsert: (p: SalaryDeductionPreset) => void;
  onDelete: (id: string) => void;
  onToggle: (id: string) => void;
}) {
  const [showSuggestions, setShowSuggestions] = useState(false);

  const addCustom = () => {
    onUpsert({
      id: uuidv4(),
      label: 'Своё удержание',
      kind: 'percent',
      value: 1,
      taxable: false,
      enabled: true,
    });
  };

  const addSuggestion = (s: typeof SUGGESTED_DEDUCTIONS[number]) => {
    onUpsert({
      id: uuidv4(),
      label: s.label,
      kind: s.kind,
      value: s.value,
      taxable: s.taxable,
      enabled: true,
    });
    setShowSuggestions(false);
  };

  return (
    <div className="bg-white border border-stone-200 rounded-2xl p-3 sm:p-4 space-y-2">
      <div className="flex items-center justify-between gap-2">
        <div>
          <h3 className="text-sm font-semibold text-zinc-900">Дополнительные удержания</h3>
          <p className="text-[11px] text-zinc-500">Профсоюз, ДМС, благотворительность, кредитные удержания…</p>
        </div>
        <div className="flex items-center gap-1.5 shrink-0">
          <button
            onClick={() => setShowSuggestions(v => !v)}
            className="inline-flex items-center gap-1 px-2 py-1.5 rounded-xl bg-emerald-50 text-emerald-700 text-[11px] font-semibold hover:bg-emerald-100"
            title="Готовые шаблоны"
          >
            <BookmarkPlus className="w-3.5 h-3.5" /> Шаблоны
          </button>
          <button
            onClick={addCustom}
            className="inline-flex items-center gap-1 px-2 py-1.5 rounded-xl bg-emerald-600 text-white text-[11px] font-semibold hover:bg-emerald-700"
          >
            <Plus className="w-3.5 h-3.5" /> Добавить
          </button>
        </div>
      </div>

      {showSuggestions && (
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-1.5 pt-2 border-t border-stone-100">
          {SUGGESTED_DEDUCTIONS.map(s => (
            <button
              key={s.label}
              onClick={() => addSuggestion(s)}
              className="text-left px-3 py-2 rounded-xl bg-stone-50 hover:bg-emerald-50 text-xs flex items-center justify-between gap-2"
            >
              <span className="font-medium text-zinc-900 truncate">{s.label}</span>
              <span className="text-[10px] text-zinc-500 shrink-0">
                {s.kind === 'percent' ? `${s.value}%` : `${s.value} BYN`}
              </span>
            </button>
          ))}
        </div>
      )}

      {presets.length === 0 ? (
        <p className="text-xs text-zinc-500 text-center py-3">
          Нет удержаний. Добавь шаблон или своё.
        </p>
      ) : (
        <div className="space-y-1.5">
          {presets.map(p => (
            <SalaryDeductionRow
              key={p.id}
              preset={p}
              onUpdate={onUpsert}
              onDelete={() => onDelete(p.id)}
              onToggle={() => onToggle(p.id)}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function SalaryDeductionRow({
  preset,
  onUpdate,
  onDelete,
  onToggle,
}: {
  preset: SalaryDeductionPreset;
  onUpdate: (p: SalaryDeductionPreset) => void;
  onDelete: () => void;
  onToggle: () => void;
}) {
  const [draft, setDraft] = useState(preset);
  React.useEffect(() => setDraft(preset), [preset.id, preset.enabled]);

  const commit = () => {
    if (draft.label.trim() === '') return onUpdate({ ...draft, label: 'Удержание' });
    onUpdate(draft);
  };

  return (
    <div className={cn(
      'rounded-xl border p-2.5 transition-colors',
      preset.enabled ? 'border-stone-200 bg-white' : 'border-dashed border-stone-300 bg-stone-50/60 opacity-70'
    )}>
      <div className="flex items-center gap-2">
        <label className="relative inline-flex items-center cursor-pointer shrink-0" title="Включить/отключить">
          <input
            type="checkbox"
            className="sr-only peer"
            checked={preset.enabled}
            onChange={onToggle}
          />
          <div className="w-9 h-5 bg-stone-200 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-stone-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-emerald-500" />
        </label>
        <input
          type="text"
          value={draft.label}
          onChange={e => setDraft({ ...draft, label: e.target.value })}
          onBlur={commit}
          placeholder="Название"
          className="flex-1 min-w-0 px-2 py-1 rounded-lg border border-stone-200 bg-white text-xs focus:outline-none focus:border-emerald-500"
        />
        <button
          onClick={onDelete}
          className="p-1.5 text-rose-500 hover:bg-rose-50 rounded-lg shrink-0"
          aria-label="Удалить удержание"
        >
          <Trash2 className="w-3.5 h-3.5" />
        </button>
      </div>
      <div className="flex items-center gap-1.5 mt-2">
        <select
          value={draft.kind}
          onChange={e => {
            const next = { ...draft, kind: e.target.value as 'percent' | 'fixed' };
            setDraft(next);
            onUpdate(next);
          }}
          className="px-2 py-1 rounded-lg border border-stone-200 bg-white text-[11px] focus:outline-none focus:border-emerald-500"
        >
          <option value="percent">% от грязной</option>
          <option value="fixed">BYN (фикс.)</option>
        </select>
        <input
          type="number"
          inputMode="decimal"
          value={Number.isFinite(draft.value) ? draft.value : 0}
          step={draft.kind === 'percent' ? 0.5 : 10}
          onChange={e => setDraft({ ...draft, value: Number(e.target.value) })}
          onBlur={commit}
          className="w-20 px-2 py-1 rounded-lg border border-stone-200 bg-white text-xs text-right focus:outline-none focus:border-emerald-500"
        />
        <span className="text-[10px] text-zinc-500 w-8 shrink-0">
          {draft.kind === 'percent' ? '%' : 'BYN'}
        </span>
        <label className="flex items-center gap-1 cursor-pointer text-[10px] text-zinc-700 ml-auto" title="Уменьшает налогооблагаемую базу (как соц. вычет)">
          <input
            type="checkbox"
            checked={Boolean(draft.taxable)}
            onChange={e => {
              const next = { ...draft, taxable: e.target.checked };
              setDraft(next);
              onUpdate(next);
            }}
            className="w-3 h-3 accent-emerald-500"
          />
          уменьшает базу
        </label>
      </div>
    </div>
  );
}

function IpUsnCalc() {
  const [revenue, setRevenue] = useState(80_000);
  const [rate, setRate] = useState<3 | 5>(5);
  const [fszn, setFszn] = useState(220);
  const r = calcIpUsn({ annualRevenue: revenue, ratePct: rate, fsznMonthly: fszn });
  return (
    <div className="space-y-4">
      <h2 className="text-base font-semibold">ИП на УСН</h2>
      <div className="grid grid-cols-2 gap-3">
        <NumberField label="Годовая выручка" value={revenue} onChange={setRevenue} step={500} suffix="BYN" />
        <label className="text-xs text-zinc-700 flex flex-col gap-1">
          <span className="font-medium">Ставка УСН</span>
          <select
            value={rate}
            onChange={(e) => setRate(Number(e.target.value) as 3 | 5)}
            className="bg-white border border-stone-200 rounded-xl px-3 py-2 text-sm"
          >
            <option value={5}>5% (без НДС)</option>
            <option value={3}>3% (с НДС)</option>
          </select>
        </label>
        <NumberField label="ФСЗН в месяц" value={fszn} onChange={setFszn} step={5} suffix="BYN" />
      </div>
      <div className="bg-stone-50 rounded-2xl p-3">
        <ResultRow label={`Налог УСН ${rate}%`} value={formatCurrency(r.usnTax)} />
        <ResultRow label="ФСЗН за год" value={formatCurrency(r.fsznTotal)} />
        <ResultRow label="Итого нагрузка" value={formatCurrency(r.totalLoad)} />
        <ResultRow label="Чистый доход" value={formatCurrency(r.net)} />
        <ResultRow label="Эффективная ставка" value={formatPercent(r.effectivePct)} />
      </div>
    </div>
  );
}

function NpdCalc() {
  const [revenue, setRevenue] = useState(40_000);
  const r = calcNpd({ annualRevenue: revenue });
  return (
    <div className="space-y-4">
      <h2 className="text-base font-semibold">НПД (самозанятые)</h2>
      <NumberField label="Годовой доход" value={revenue} onChange={setRevenue} step={500} suffix="BYN" />
      <div className="bg-stone-50 rounded-2xl p-3">
        <ResultRow label="Налог 10%" value={formatCurrency(r.taxLow)} />
        <ResultRow label="Налог 20% (свыше 60 000)" value={formatCurrency(r.taxHigh)} />
        <ResultRow label="Итого налог" value={formatCurrency(r.total)} />
        <ResultRow label="Чистый доход" value={formatCurrency(r.net)} />
        <ResultRow label="Эффективная ставка" value={formatPercent(r.effectivePct)} />
      </div>
      <p className="text-[11px] text-zinc-500">
        Ставки НПД для самозанятых физлиц (РБ): 10% при работе с физлицами и иностранными организациями; превышение лимита 60 000 BYN/год — 20%.
      </p>
    </div>
  );
}

function SafetyFundCalc() {
  const [monthly, setMonthly] = useState(1500);
  const target3 = safetyFundTarget(monthly, 3);
  const target6 = safetyFundTarget(monthly, 6);
  const target12 = safetyFundTarget(monthly, 12);
  return (
    <div className="space-y-4">
      <h2 className="text-base font-semibold">Подушка безопасности</h2>
      <NumberField label="Среднемесячные расходы" value={monthly} onChange={setMonthly} step={50} suffix="BYN" />
      <div className="bg-stone-50 rounded-2xl p-3">
        <ResultRow label="3 месяца — старт" value={formatCurrency(target3)} />
        <ResultRow label="6 месяцев — рекомендуется" value={formatCurrency(target6)} />
        <ResultRow label="12 месяцев — спокойствие" value={formatCurrency(target12)} />
      </div>
      <p className="text-[11px] text-zinc-500">
        Храните подушку отдельно от основного счёта (валютный депозит/накопительный). В РБ — половина в BYN на бытовые форс-мажоры, половина в USD/EUR от девальвации.
      </p>
    </div>
  );
}

function FxStressCalc() {
  const rates = useStore((s) => s.rates);
  const [byn, setByn] = useState(5_000);
  const [usd, setUsd] = useState(500);
  const [eur, setEur] = useState(0);
  const [shock, setShock] = useState(30);
  const r = applyDevaluation(
    [
      { currency: 'BYN', amount: byn },
      { currency: 'USD', amount: usd },
      { currency: 'EUR', amount: eur },
    ],
    rates,
    shock
  );
  return (
    <div className="space-y-4">
      <h2 className="text-base font-semibold">Валютный стресс-тест</h2>
      <div className="grid grid-cols-2 gap-3">
        <NumberField label="BYN" value={byn} onChange={setByn} step={100} />
        <NumberField label="USD" value={usd} onChange={setUsd} step={50} />
        <NumberField label="EUR" value={eur} onChange={setEur} step={50} />
        <NumberField label="Шок к BYN" value={shock} onChange={setShock} step={5} suffix="%" />
      </div>
      <div className="bg-stone-50 rounded-2xl p-3">
        <ResultRow label="До шока (в BYN)" value={formatCurrency(r.before)} />
        <ResultRow label="После шока (в BYN)" value={formatCurrency(r.after)} />
        <ResultRow label="Изменение" value={formatPercent(r.deltaPct)} />
      </div>
      <p className="text-[11px] text-zinc-500">
        Курс обновляется автоматически из api.nbrb.by. Стресс-тест считает, что иностранная валюта дорожает к BYN, а сумма в иностранной валюте остаётся той же.
      </p>
    </div>
  );
}

function VacationCalc() {
  const [earnings, setEarnings] = useState(24_000);
  const [days, setDays] = useState(24);
  const r = calcVacationPay(earnings, days);
  return (
    <div className="space-y-4">
      <h2 className="text-base font-semibold">Отпускные (РБ)</h2>
      <div className="grid grid-cols-2 gap-3">
        <NumberField label="Доход за 12 мес" value={earnings} onChange={setEarnings} step={100} suffix="BYN" />
        <NumberField label="Дней отпуска" value={days} onChange={setDays} step={1} />
      </div>
      <div className="bg-stone-50 rounded-2xl p-3">
        <ResultRow label="Среднедневной заработок" value={formatCurrency(r.avgDaily)} />
        <ResultRow label="Сумма отпускных" value={formatCurrency(r.payment)} />
      </div>
      <p className="text-[11px] text-zinc-500">
        Упрощённая формула: средний доход за 12 месяцев / (12 × 29.7) × количество календарных дней отпуска.
      </p>
    </div>
  );
}

function FireCalc() {
  const [annual, setAnnual] = useState(24_000);
  const [swr, setSwr] = useState(4);
  const [current, setCurrent] = useState(20_000);
  const [monthly, setMonthly] = useState(500);
  const [returnPct, setReturnPct] = useState(7);
  const target = fireNumber({ annualExpenses: annual, swrPct: swr });
  const yrs = yearsToFire({
    currentNet: current,
    monthlySaving: monthly,
    annualReturnPct: returnPct,
    targetNet: target,
  });
  return (
    <div className="space-y-4">
      <h2 className="text-base font-semibold">FIRE (Financial Independence)</h2>
      <div className="grid grid-cols-2 gap-3">
        <NumberField label="Расходы в год" value={annual} onChange={setAnnual} step={500} suffix="BYN" />
        <NumberField label="SWR" value={swr} onChange={setSwr} step={0.25} suffix="%" />
        <NumberField label="Текущий капитал" value={current} onChange={setCurrent} step={500} suffix="BYN" />
        <NumberField label="В месяц инвестирую" value={monthly} onChange={setMonthly} step={50} suffix="BYN" />
        <NumberField label="Доходность портфеля" value={returnPct} onChange={setReturnPct} step={0.5} suffix="%" />
      </div>
      <div className="bg-stone-50 rounded-2xl p-3">
        <ResultRow label="FIRE-число (целевой капитал)" value={formatCurrency(target)} />
        <ResultRow
          label="Лет до цели"
          value={Number.isFinite(yrs) ? `${yrs}` : '> 100'}
        />
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/*                              Глоссарий                              */
/* ------------------------------------------------------------------ */

function GlossaryTab() {
  const groups = useMemo(() => {
    const labels: Record<string, string> = {
      personal: 'Личные финансы',
      belarus: 'Беларусь',
      invest: 'Инвестиции',
      tax: 'Налоги',
      credit: 'Кредиты и долги',
    };
    const map: Record<string, typeof GLOSSARY> = {};
    for (const e of GLOSSARY) {
      map[e.group] = map[e.group] || [];
      map[e.group].push(e);
    }
    return Object.entries(map).map(([g, items]) => ({ id: g, label: labels[g] ?? g, items }));
  }, []);

  return (
    <div className="space-y-6">
      {groups.map((g) => (
        <section key={g.id}>
          <h2 className="text-sm font-bold text-zinc-900 mb-3 uppercase tracking-wider">
            {g.label}
          </h2>
          <div className="grid sm:grid-cols-2 gap-3">
            {g.items.map((e) => (
              <article
                key={e.term}
                className="bg-white border border-stone-200 rounded-2xl p-3"
              >
                <h3 className="text-sm font-semibold text-zinc-900 mb-1">{e.term}</h3>
                <p className="text-xs text-zinc-700">{e.definition}</p>
                {e.example && (
                  <p className="text-[11px] text-zinc-500 mt-2 italic">{e.example}</p>
                )}
              </article>
            ))}
          </div>
        </section>
      ))}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/*                             Мини-курсы                              */
/* ------------------------------------------------------------------ */

const COURSE_PROGRESS_KEY = 'vibetracker.course-progress';

function loadProgress(): Record<string, number> {
  try {
    const raw = localStorage.getItem(COURSE_PROGRESS_KEY);
    return raw ? JSON.parse(raw) : {};
  } catch {
    return {};
  }
}

function saveProgress(value: Record<string, number>) {
  try {
    localStorage.setItem(COURSE_PROGRESS_KEY, JSON.stringify(value));
  } catch {
    /* localStorage unavailable */
  }
}

function CoursesTab() {
  const [progress, setProgress] = useState<Record<string, number>>(() => loadProgress());
  const [openCourse, setOpenCourse] = useState<Course | null>(null);

  const setStep = (courseId: string, step: number) => {
    const next = { ...progress, [courseId]: step };
    setProgress(next);
    saveProgress(next);
  };

  if (openCourse) {
    return (
      <CoursePlayer
        course={openCourse}
        currentStep={progress[openCourse.id] ?? 0}
        onSetStep={(s) => setStep(openCourse.id, s)}
        onClose={() => setOpenCourse(null)}
      />
    );
  }

  return (
    <div className="grid sm:grid-cols-2 gap-3">
      {COURSES.map((c) => {
        const done = progress[c.id] ?? 0;
        const total = c.steps.length;
        const pct = Math.round((done / total) * 100);
        return (
          <button
            key={c.id}
            onClick={() => setOpenCourse(c)}
            className="text-left bg-white border border-stone-200 rounded-2xl p-4 hover:border-emerald-400 transition-colors"
          >
            <h3 className="text-sm font-semibold text-zinc-900 mb-1">{c.title}</h3>
            <p className="text-xs text-zinc-600 mb-3">{c.blurb}</p>
            <div className="flex items-center justify-between text-[10px] text-zinc-500">
              <span>{c.duration}</span>
              <span>
                {done}/{total} · {pct}%
              </span>
            </div>
            <div className="mt-1 h-1.5 bg-stone-100 rounded-full overflow-hidden">
              <div
                className="h-full bg-emerald-500"
                style={{ width: `${pct}%` }}
              />
            </div>
          </button>
        );
      })}
    </div>
  );
}

function CoursePlayer({
  course,
  currentStep,
  onSetStep,
  onClose,
}: {
  course: Course;
  currentStep: number;
  onSetStep: (s: number) => void;
  onClose: () => void;
}) {
  const navigate = useNavigate();
  const i = Math.min(currentStep, course.steps.length - 1);
  const step = course.steps[i];

  return (
    <article className="bg-white rounded-3xl border border-stone-200 p-5 max-w-2xl mx-auto">
      <button
        onClick={onClose}
        className="text-xs text-emerald-700 mb-3 hover:underline"
      >
        ← Все курсы
      </button>
      <h2 className="text-lg font-bold text-zinc-900">{course.title}</h2>
      <p className="text-[11px] text-zinc-500 mb-4">
        Шаг {i + 1} из {course.steps.length}
      </p>
      <h3 className="text-sm font-semibold text-zinc-900">{step.title}</h3>
      <p className="text-sm text-zinc-700 whitespace-pre-line mt-2 mb-4">
        {step.body}
      </p>
      <div className="flex items-center gap-2">
        <button
          onClick={() => onSetStep(Math.max(0, i - 1))}
          disabled={i === 0}
          className="px-3 py-1.5 rounded-xl bg-stone-100 text-zinc-700 text-xs disabled:opacity-40"
        >
          Назад
        </button>
        <button
          onClick={() => onSetStep(Math.min(course.steps.length, i + 1))}
          className="px-3 py-1.5 rounded-xl bg-emerald-600 text-white text-xs"
        >
          {i === course.steps.length - 1 ? 'Закончить' : 'Далее'}
        </button>
        {step.action?.route && (
          <button
            onClick={() => navigate(step.action!.route!)}
            className="px-3 py-1.5 rounded-xl border border-emerald-200 text-emerald-700 text-xs"
          >
            {step.action.label}
          </button>
        )}
      </div>
    </article>
  );
}

/* ------------------------------------------------------------------ */
/*                              Шаблоны                                */
/* ------------------------------------------------------------------ */

const HABIT_TEMPLATES = [
  {
    title: 'Записывать каждую трату вечером',
    icon: '✍️',
    why: 'Главная привычка финграмотности. 1 минута в день.',
  },
  {
    title: 'Читать про деньги 10 минут в день',
    icon: '📖',
    why: 'Каждый месяц — новая глава, новая идея.',
  },
  {
    title: 'Откладывать 20% сразу с дохода',
    icon: '🪙',
    why: 'Pay yourself first. До бюджета — на накопления.',
  },
  {
    title: 'Раз в неделю смотреть на чистую стоимость',
    icon: '📊',
    why: 'Net worth — главный показатель прогресса.',
  },
];

const GOAL_TEMPLATES = [
  {
    title: 'Накопить подушку 6 месяцев',
    type: 'goal',
    why: 'Базовая защита от форс-мажоров.',
  },
  {
    title: 'Закрыть кредит досрочно',
    type: 'goal',
    why: 'Освободить cash flow от долговой петли.',
  },
  {
    title: 'Прочитать 3 книги по финансам',
    type: 'book',
    why: 'Например: «Богатый папа», «Психология денег», «Самый богатый человек в Вавилоне».',
  },
  {
    title: 'Освоить инвестиции для белоруса',
    type: 'skill',
    why: 'Диверсификация по валютам, доступные инструменты, риски.',
  },
];

function TemplatesTab() {
  return (
    <div className="space-y-6">
      <section>
        <h2 className="text-sm font-bold text-zinc-900 mb-3 uppercase tracking-wider">
          Привычки финграмотности
        </h2>
        <div className="grid sm:grid-cols-2 gap-3">
          {HABIT_TEMPLATES.map((h) => (
            <article
              key={h.title}
              className="bg-white border border-stone-200 rounded-2xl p-3"
            >
              <h3 className="text-sm font-semibold text-zinc-900 mb-1">
                <span className="mr-2">{h.icon}</span>
                {h.title}
              </h3>
              <p className="text-xs text-zinc-600">{h.why}</p>
            </article>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-sm font-bold text-zinc-900 mb-3 uppercase tracking-wider">
          Цели на год
        </h2>
        <div className="grid sm:grid-cols-2 gap-3">
          {GOAL_TEMPLATES.map((g) => (
            <article
              key={g.title}
              className="bg-white border border-stone-200 rounded-2xl p-3"
            >
              <h3 className="text-sm font-semibold text-zinc-900 mb-1">
                {g.title}
              </h3>
              <p className="text-[10px] text-emerald-700 uppercase tracking-wider mb-1">
                {g.type === 'goal' ? 'Цель' : g.type === 'book' ? 'Книга' : 'Навык'}
              </p>
              <p className="text-xs text-zinc-600">{g.why}</p>
            </article>
          ))}
        </div>
      </section>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/*                      Финграмотность Беларусь 2026                   */
/* ------------------------------------------------------------------ */

const FINLIT_ACCENT: Record<FinTipCategory['accent'], { bg: string; chip: string; ring: string }> = {
  emerald: { bg: 'bg-emerald-50',  chip: 'bg-emerald-100 text-emerald-800',  ring: 'border-emerald-200' },
  blue:    { bg: 'bg-blue-50',     chip: 'bg-blue-100 text-blue-800',        ring: 'border-blue-200' },
  amber:   { bg: 'bg-amber-50',    chip: 'bg-amber-100 text-amber-800',      ring: 'border-amber-200' },
  rose:    { bg: 'bg-rose-50',     chip: 'bg-rose-100 text-rose-800',        ring: 'border-rose-200' },
  indigo:  { bg: 'bg-indigo-50',   chip: 'bg-indigo-100 text-indigo-800',    ring: 'border-indigo-200' },
  violet:  { bg: 'bg-violet-50',   chip: 'bg-violet-100 text-violet-800',    ring: 'border-violet-200' },
};

const TIP_BADGE: Record<FinTip['kind'], { label: string; className: string }> = {
  tip:     { label: '💡 Совет',     className: 'bg-emerald-100 text-emerald-800' },
  warning: { label: '⚠️ Осторожно', className: 'bg-rose-100 text-rose-800' },
  rule:    { label: '📜 Правило',   className: 'bg-blue-100 text-blue-800' },
  fact:    { label: '🧠 Факт',      className: 'bg-amber-100 text-amber-800' },
};

function FinLitTab() {
  const [openCategoryId, setOpenCategoryId] = useState<string | null>(null);
  const open = openCategoryId
    ? FINLIT_BY_2026.find((c) => c.id === openCategoryId) ?? null
    : null;

  if (open) {
    const accent = FINLIT_ACCENT[open.accent];
    return (
      <article className="space-y-3">
        <button
          onClick={() => setOpenCategoryId(null)}
          className="text-xs text-emerald-700 hover:underline"
        >
          ← Все темы
        </button>
        <header className={cn('rounded-3xl border p-5', accent.bg, accent.ring)}>
          <div className="flex items-start gap-3">
            <span className="text-3xl">{open.emoji}</span>
            <div>
              <h2 className="text-xl font-bold text-zinc-900">{open.title}</h2>
              <p className="text-sm text-zinc-700">{open.blurb}</p>
            </div>
          </div>
        </header>
        <div className="space-y-3">
          {open.tips.map((tip) => {
            const badge = TIP_BADGE[tip.kind];
            return (
              <article
                key={tip.id}
                className="bg-white border border-stone-200 rounded-2xl p-4"
              >
                <div className="flex items-start gap-2 mb-2">
                  <span className={cn('text-[10px] font-bold uppercase tracking-wide px-2 py-0.5 rounded-full', badge.className)}>
                    {badge.label}
                  </span>
                </div>
                <h3 className="text-sm font-semibold text-zinc-900 mb-1">{tip.title}</h3>
                <p className="text-sm text-zinc-700 whitespace-pre-line">{tip.body}</p>
                {tip.tags && tip.tags.length > 0 && (
                  <div className="mt-3 flex flex-wrap gap-1.5">
                    {tip.tags.map((t) => (
                      <span
                        key={t}
                        className={cn('text-[10px] px-2 py-0.5 rounded-full', accent.chip)}
                      >
                        {t}
                      </span>
                    ))}
                  </div>
                )}
              </article>
            );
          })}
        </div>
      </article>
    );
  }

  const totalTips = FINLIT_BY_2026.reduce((s, c) => s + c.tips.length, 0);

  return (
    <section className="space-y-4">
      <header className="bg-gradient-to-br from-emerald-50 to-blue-50 rounded-3xl border border-emerald-100 p-5">
        <div className="flex items-start gap-3">
          <span className="text-3xl">🇧🇾</span>
          <div className="flex-1">
            <h2 className="text-base font-bold text-zinc-900 mb-1">
              Финансовая грамотность · Беларусь 2026
            </h2>
            <p className="text-sm text-zinc-700">
              {FINLIT_BY_2026.length} тем · {totalTips} практических советов и правил.
              Налоги, ФСЗН, ИРИП, депозиты, кредиты, инвестиции, защита от мошенничества.
            </p>
            <p className="text-[10px] text-zinc-500 mt-2">
              Не является индивидуальной налоговой/инвестиционной консультацией.
            </p>
          </div>
        </div>
      </header>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        {FINLIT_BY_2026.map((cat) => {
          const accent = FINLIT_ACCENT[cat.accent];
          return (
            <button
              key={cat.id}
              onClick={() => setOpenCategoryId(cat.id)}
              className={cn(
                'text-left rounded-3xl border p-4 transition-colors hover:brightness-95',
                accent.bg,
                accent.ring,
              )}
            >
              <div className="flex items-start gap-3">
                <span className="text-2xl shrink-0">{cat.emoji}</span>
                <div className="flex-1 min-w-0">
                  <h3 className="text-sm font-bold text-zinc-900 mb-0.5">{cat.title}</h3>
                  <p className="text-xs text-zinc-700">{cat.blurb}</p>
                  <div className="flex items-center gap-2 mt-2">
                    <span className={cn('text-[10px] font-semibold px-2 py-0.5 rounded-full', accent.chip)}>
                      {cat.tips.length} советов
                    </span>
                  </div>
                </div>
              </div>
            </button>
          );
        })}
      </div>
    </section>
  );
}
