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
import { useStore } from '../store/useStore';
import { useNavigate } from 'react-router-dom';

type TabId = 'calc' | 'glossary' | 'courses' | 'templates';

const TABS: { id: TabId; label: string; icon: React.ComponentType<any> }[] = [
  { id: 'calc', label: 'Калькуляторы', icon: Calculator },
  { id: 'glossary', label: 'Глоссарий', icon: BookOpen },
  { id: 'courses', label: 'Мини-курсы', icon: GraduationCap },
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

function SalaryCalc() {
  const [gross, setGross] = useState(2000);
  const [children, setChildren] = useState(0);
  const [dependents, setDependents] = useState(0);
  const r = calcNetSalary({ gross, children, dependents });
  return (
    <div className="space-y-4">
      <h2 className="text-base font-semibold">Зарплата на руки (РБ)</h2>
      <div className="grid grid-cols-2 gap-3">
        <NumberField label="Грязная зарплата" value={gross} onChange={setGross} step={50} suffix="BYN" />
        <NumberField label="Детей" value={children} onChange={setChildren} step={1} />
        <NumberField label="Иждивенцев" value={dependents} onChange={setDependents} step={1} />
      </div>
      <div className="bg-stone-50 rounded-2xl p-3">
        <ResultRow label="Подоходный 13%" value={formatCurrency(r.incomeTax)} />
        <ResultRow label="ФСЗН 1%" value={formatCurrency(r.fszn)} />
        <ResultRow label="Налогооблагаемая база" value={formatCurrency(r.taxableBase)} />
        <ResultRow label="Вычеты" value={formatCurrency(r.deductions)} />
        <ResultRow label="На руки" value={formatCurrency(r.net)} />
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
