/**
 * Belarus-specific tax calculators. All percentages and figures reflect the
 * mainstream rules as of 2024-2025; values that change every year (МЗП,
 * базовая величина, льготные пороги вычетов) are exposed as constants and
 * can be tweaked from one place.
 *
 * NOTE: this is an estimator — not a substitute for an accountant.
 */

/**
 * Год-зависимые параметры НК РБ. Значения МЗП, базовой величины и пороги
 * вычетов меняются почти каждый год — держим их в таблице по годам, чтобы
 * обновление сводилось к добавлению одной записи.
 *
 * ⚠️ Подтверждены только значения 2024 года. Значения 2025/2026 нужно
 * добавить из официальных источников (постановления Совмина по МЗП/БВ и
 * ст. 209 НК РБ по вычетам).
 */
export interface ByTaxYearConstants {
  /** Базовая величина (BV). */
  baseValueByn: number;
  /** Минимальная заработная плата (МЗП). */
  minWageByn: number;
  /** Стандартный вычет «на себя» (ст. 209 НК РБ) — порог дохода. */
  stdDeductionIncomeLimit: number;
  /** Сумма стандартного вычета «на себя». */
  stdDeduction: number;
  /** Вычет на одного ребёнка / иждивенца. */
  childDeduction: number;
  /** Вычет на ребёнка для семей с 2+ детьми / одинокого родителя. */
  childDeductionTwoPlus: number;
  /** Подоходный налог, %. */
  incomeTaxPct: number;
  /** ФСЗН с работника, %. */
  fsznEmployeePct: number;
}

export const BY_TAX_BY_YEAR: Record<number, ByTaxYearConstants> = {
  2024: {
    baseValueByn: 42,
    minWageByn: 626,
    stdDeductionIncomeLimit: 1054,
    stdDeduction: 174,
    childDeduction: 51,
    childDeductionTwoPlus: 97,
    incomeTaxPct: 13,
    fsznEmployeePct: 1,
  },
};

/** Последний год с подтверждёнными значениями — используется по умолчанию. */
export const CURRENT_TAX_YEAR = 2024;

/**
 * Возвращает константы для года: точное совпадение → ближайший предыдущий
 * заполненный год → последний доступный. Так калькулятор не падает, если
 * запрошен год, для которого таблица ещё не обновлена.
 */
export function getByTaxConstants(year: number = CURRENT_TAX_YEAR): ByTaxYearConstants {
  const years = Object.keys(BY_TAX_BY_YEAR)
    .map(Number)
    .sort((a, b) => a - b);
  if (BY_TAX_BY_YEAR[year]) return BY_TAX_BY_YEAR[year];
  const fallbackYear =
    [...years].reverse().find(y => y <= year) ?? years[years.length - 1];
  return BY_TAX_BY_YEAR[fallbackYear];
}

const CURRENT = getByTaxConstants(CURRENT_TAX_YEAR);

/** Базовая величина (BV) для текущего года. */
export const BASE_VALUE_BYN = CURRENT.baseValueByn;

/** Минимальная заработная плата (МЗП) для текущего года. */
export const MIN_WAGE_BYN = CURRENT.minWageByn;

/** Стандартный вычет «на себя» (ст. 209 НК РБ) — порог дохода. */
export const STD_DEDUCTION_INCOME_LIMIT = CURRENT.stdDeductionIncomeLimit;
export const STD_DEDUCTION = CURRENT.stdDeduction;

/** Вычет на ребёнка / иждивенца (по умолчанию). */
export const CHILD_DEDUCTION = CURRENT.childDeduction;
export const CHILD_DEDUCTION_TWO_PLUS = CURRENT.childDeductionTwoPlus;

/** Подоходный налог. */
export const INCOME_TAX_PCT = CURRENT.incomeTaxPct;

/** ФСЗН с работника (1%). */
export const FSZN_EMPLOYEE_PCT = CURRENT.fsznEmployeePct;

/**
 * Дополнительное удержание из зарплаты — профсоюз, ДМС, благотворительность,
 * пенсионная программа, кредитные удержания, алименты и т.д.
 */
export interface SalaryDeduction {
  /** Стабильный идентификатор. */
  id: string;
  /** Название (например «Профсоюз»). */
  label: string;
  /** Тип значения: процент от грязной или фикс. сумма в BYN. */
  kind: 'percent' | 'fixed';
  /** Значение: либо процент (0..100), либо BYN. */
  value: number;
  /**
   * Если `true` — удержание уменьшает налогооблагаемую базу (как соц. вычет).
   * По умолчанию `false` — удерживается из «на руки» после налогов.
   *
   * Профсоюзные взносы по сложившейся практике не уменьшают подоходный
   * налог, поэтому правильное значение для профсоюза — `false`.
   */
  taxable?: boolean;
}

export interface SalaryInput {
  /** Грязная зарплата (до налогов). */
  gross: number;
  /** Сколько детей у работника (для детского вычета). */
  children?: number;
  /** Иждивенцы (родители, неработающий супруг и т.д.). */
  dependents?: number;
  /** Применять стандартный вычет «на себя», если доход ≤ порога? */
  applyStandardDeduction?: boolean;
  /** Произвольные удержания: профсоюз, ДМС, благотворительность и т.д. */
  extraDeductions?: SalaryDeduction[];
}

export interface SalaryDeductionLine {
  id: string;
  label: string;
  amount: number;
  /** Уменьшила ли налоговую базу. */
  taxable: boolean;
}

export interface SalaryResult {
  gross: number;
  fszn: number;
  taxableBase: number;
  /** Сумма стандартных + детских + иждивенских вычетов. */
  deductions: number;
  /** Сумма pre-tax удержаний (уменьшили базу), напр. ДМС. */
  pretaxDeductions: number;
  /** Сумма post-tax удержаний (например, профсоюз). */
  postTaxDeductions: number;
  /** Разбивка по каждому extra-удержанию (для UI). */
  extraDeductionsApplied: SalaryDeductionLine[];
  incomeTax: number;
  net: number;
}

/**
 * Расчёт «зарплаты на руки» в Беларуси.
 *
 *   налогооблагаемая база = max(0, gross − стандартные вычеты − дет. вычеты
 *                                  − pre-tax extra-удержания)
 *   подоходный            = база × 13%
 *   ФСЗН (с работника)    = gross × 1%
 *   на руки               = gross − подоходный − ФСЗН
 *                           − pre-tax extra (уже учтены в базе → списываем)
 *                           − post-tax extra (профсоюз, ДМС, благотворительность)
 */
export function calcNetSalary(input: SalaryInput): SalaryResult {
  const {
    gross,
    children = 0,
    dependents = 0,
    applyStandardDeduction = true,
    extraDeductions = [],
  } = input;

  let deductions = 0;
  if (applyStandardDeduction && gross <= STD_DEDUCTION_INCOME_LIMIT) {
    deductions += STD_DEDUCTION;
  }
  if (children > 0) {
    if (children === 1) deductions += CHILD_DEDUCTION;
    else deductions += children * CHILD_DEDUCTION_TWO_PLUS;
  }
  if (dependents > 0) deductions += dependents * CHILD_DEDUCTION;

  const extraLines: SalaryDeductionLine[] = extraDeductions.map(d => {
    const amount = d.kind === 'percent'
      ? (gross * d.value) / 100
      : d.value;
    return {
      id: d.id,
      label: d.label,
      amount: Math.max(0, amount),
      taxable: Boolean(d.taxable),
    };
  });

  const pretaxDeductions = extraLines
    .filter(l => l.taxable)
    .reduce((s, l) => s + l.amount, 0);
  const postTaxDeductions = extraLines
    .filter(l => !l.taxable)
    .reduce((s, l) => s + l.amount, 0);

  const taxableBase = Math.max(0, gross - deductions - pretaxDeductions);
  const incomeTax = (taxableBase * INCOME_TAX_PCT) / 100;
  const fszn = (gross * FSZN_EMPLOYEE_PCT) / 100;
  const net = gross - incomeTax - fszn - pretaxDeductions - postTaxDeductions;

  return {
    gross,
    fszn,
    taxableBase,
    deductions,
    pretaxDeductions,
    postTaxDeductions,
    extraDeductionsApplied: extraLines,
    incomeTax,
    net,
  };
}

/** Inverse: какая «грязная» нужна для целевой «на руки»? */
export function grossFromNet(targetNet: number, opts: Omit<SalaryInput, 'gross'> = {}): number {
  // Binary search — нелинейно из-за порога льгот.
  let lo = 0,
    hi = targetNet * 3,
    mid = 0;
  for (let i = 0; i < 80; i++) {
    mid = (lo + hi) / 2;
    const { net } = calcNetSalary({ ...opts, gross: mid });
    if (Math.abs(net - targetNet) < 0.01) return mid;
    if (net < targetNet) lo = mid;
    else hi = mid;
  }
  return mid;
}

/* ------------------------------------------------------------------ */
/*                       Депозит — налог 13%                           */
/* ------------------------------------------------------------------ */

export interface DepositInput {
  amount: number;
  annualRatePct: number;
  termMonths: number;
  /**
   * Применять ли подоходный налог 13% на проценты по вкладам сроком
   * меньше года (для физлиц с 2024). Передавайте false для безотзывных
   * длинных депозитов и для валютных вкладов >= 2 лет.
   */
  taxApplies?: boolean;
  /** Капитализация процентов (true) или ежемесячная выплата (false). */
  capitalize?: boolean;
}

export interface DepositResult {
  totalInterestGross: number;
  totalTax: number;
  totalInterestNet: number;
  finalBalance: number;
}

export function calcDepositBY(input: DepositInput): DepositResult {
  const {
    amount,
    annualRatePct,
    termMonths,
    taxApplies = true,
    capitalize = true,
  } = input;
  const monthlyRate = annualRatePct / 100 / 12;

  let balance = amount;
  let interestGross = 0;
  for (let m = 1; m <= termMonths; m++) {
    const i = balance * monthlyRate;
    interestGross += i;
    if (capitalize) balance += i;
  }
  const tax = taxApplies ? (interestGross * INCOME_TAX_PCT) / 100 : 0;
  const interestNet = interestGross - tax;
  return {
    totalInterestGross: interestGross,
    totalTax: tax,
    totalInterestNet: interestNet,
    finalBalance: capitalize ? balance - tax : amount + interestNet,
  };
}

/* ------------------------------------------------------------------ */
/*                       ИП на УСН (5% / 3%)                           */
/* ------------------------------------------------------------------ */

export interface IpUsnInput {
  /** Годовая выручка ИП. */
  annualRevenue: number;
  /** 5% — без НДС, 3% — с НДС. */
  ratePct: 3 | 5;
  /** Фиксированный взнос ФСЗН в месяц (вводится пользователем). */
  fsznMonthly: number;
}

export interface IpUsnResult {
  usnTax: number;
  fsznTotal: number;
  totalLoad: number;
  net: number;
  effectivePct: number;
}

export function calcIpUsn(input: IpUsnInput): IpUsnResult {
  const { annualRevenue, ratePct, fsznMonthly } = input;
  const usnTax = (annualRevenue * ratePct) / 100;
  const fsznTotal = fsznMonthly * 12;
  const totalLoad = usnTax + fsznTotal;
  const net = annualRevenue - totalLoad;
  return {
    usnTax,
    fsznTotal,
    totalLoad,
    net,
    effectivePct: annualRevenue ? (totalLoad / annualRevenue) * 100 : 0,
  };
}

/* ------------------------------------------------------------------ */
/*                Налог на профессиональный доход (НПД)                */
/* ------------------------------------------------------------------ */

/**
 * Самозанятые физлица:
 *   10% — при работе с физлицами и иностранными организациями;
 *   20% — для дохода свыше 60 000 руб. в год (или сверхлимит).
 */
export const NPD_LOW_RATE_PCT = 10;
export const NPD_HIGH_RATE_PCT = 20;
export const NPD_HIGH_RATE_THRESHOLD = 60_000;

export interface NpdInput {
  annualRevenue: number;
}

export interface NpdResult {
  taxLow: number;
  taxHigh: number;
  total: number;
  net: number;
  effectivePct: number;
}

export function calcNpd(input: NpdInput): NpdResult {
  const r = input.annualRevenue;
  const low = Math.min(r, NPD_HIGH_RATE_THRESHOLD);
  const high = Math.max(0, r - NPD_HIGH_RATE_THRESHOLD);
  const taxLow = (low * NPD_LOW_RATE_PCT) / 100;
  const taxHigh = (high * NPD_HIGH_RATE_PCT) / 100;
  const total = taxLow + taxHigh;
  return {
    taxLow,
    taxHigh,
    total,
    net: r - total,
    effectivePct: r ? (total / r) * 100 : 0,
  };
}

/* ------------------------------------------------------------------ */
/*                       Отпускные / больничные                        */
/* ------------------------------------------------------------------ */

/**
 * Отпускные (упрощённо): среднедневной заработок × число календарных дней
 * отпуска. Среднедневной = доход за 12 мес / (12 × 29.7).
 */
export function calcVacationPay(
  totalEarningsLast12m: number,
  daysOff: number
): { avgDaily: number; payment: number } {
  const avgDaily = totalEarningsLast12m / (12 * 29.7);
  return { avgDaily, payment: avgDaily * daysOff };
}
