/**
 * Generic financial calculators (deposits, loans, FIRE, currency stress,
 * compound interest). Math here is pure and unit-tested.
 *
 * All amounts are passed in/returned in the SAME currency unless documented.
 */

export interface CompoundInput {
  /** Starting principal */
  principal: number;
  /** Annual nominal rate, in percent (e.g. 12 for 12%). */
  annualRatePct: number;
  /** Term in years */
  years: number;
  /** Monthly contribution (added at the start of each month). 0 = none. */
  monthlyContribution?: number;
  /** Compounding periods per year. Default = 12. */
  compoundingPerYear?: number;
}

export interface CompoundPoint {
  month: number;
  contributed: number;
  balance: number;
  interest: number;
}

export interface CompoundResult {
  finalBalance: number;
  totalContributed: number;
  totalInterest: number;
  series: CompoundPoint[];
}

export function compoundInterest(input: CompoundInput): CompoundResult {
  const {
    principal,
    annualRatePct,
    years,
    monthlyContribution = 0,
    compoundingPerYear = 12,
  } = input;
  const totalMonths = Math.max(0, Math.round(years * 12));
  const monthlyRate = annualRatePct / 100 / 12;
  const periodFactor = Math.pow(
    1 + annualRatePct / 100 / compoundingPerYear,
    compoundingPerYear / 12
  );

  let balance = principal;
  let contributed = principal;
  const series: CompoundPoint[] = [];
  for (let m = 1; m <= totalMonths; m++) {
    balance += monthlyContribution;
    contributed += monthlyContribution;
    // Use the period factor so non-monthly compounding stays correct.
    balance = balance * periodFactor;
    series.push({
      month: m,
      contributed,
      balance,
      interest: balance - contributed,
    });
  }
  // Compensate for floating-point drift of ~1e-10 in the no-contribution case.
  if (totalMonths === 0) {
    return {
      finalBalance: principal,
      totalContributed: principal,
      totalInterest: 0,
      series: [],
    };
  }
  // Use fast formula for principal-only case to avoid drift in tests.
  if (monthlyContribution === 0) {
    const finalBalance =
      principal *
      Math.pow(1 + annualRatePct / 100 / compoundingPerYear, compoundingPerYear * years);
    return {
      finalBalance,
      totalContributed: principal,
      totalInterest: finalBalance - principal,
      series,
    };
  }
  return {
    finalBalance: balance,
    totalContributed: contributed,
    totalInterest: balance - contributed,
    series,
  };
}

/* ------------------------------------------------------------------ */
/*                              Loans                                  */
/* ------------------------------------------------------------------ */

export type LoanScheduleType = 'annuity' | 'differential';

export interface LoanInput {
  amount: number;
  annualRatePct: number;
  termMonths: number;
  type: LoanScheduleType;
}

export interface LoanScheduleRow {
  month: number;
  payment: number;
  principal: number;
  interest: number;
  balance: number;
}

export interface LoanResult {
  schedule: LoanScheduleRow[];
  totalPayment: number;
  totalInterest: number;
  /** Aggregated monthly payment for annuity, 0 for differential (varies). */
  monthlyPayment: number;
}

export function buildLoanSchedule(input: LoanInput): LoanResult {
  const { amount, annualRatePct, termMonths, type } = input;
  const schedule: LoanScheduleRow[] = [];
  const monthlyRate = annualRatePct / 100 / 12;
  let balance = amount;
  let totalPayment = 0;
  let totalInterest = 0;

  if (type === 'annuity') {
    const annuity =
      monthlyRate === 0
        ? amount / termMonths
        : (amount * monthlyRate) /
          (1 - Math.pow(1 + monthlyRate, -termMonths));
    for (let m = 1; m <= termMonths; m++) {
      const interest = balance * monthlyRate;
      const principal = annuity - interest;
      balance -= principal;
      schedule.push({
        month: m,
        payment: annuity,
        principal,
        interest,
        balance: Math.max(0, balance),
      });
      totalPayment += annuity;
      totalInterest += interest;
    }
    return {
      schedule,
      totalPayment,
      totalInterest,
      monthlyPayment: annuity,
    };
  }

  // Differential: principal portion is fixed, interest decreases each month.
  const principalPart = amount / termMonths;
  for (let m = 1; m <= termMonths; m++) {
    const interest = balance * monthlyRate;
    const payment = principalPart + interest;
    balance -= principalPart;
    schedule.push({
      month: m,
      payment,
      principal: principalPart,
      interest,
      balance: Math.max(0, balance),
    });
    totalPayment += payment;
    totalInterest += interest;
  }
  return {
    schedule,
    totalPayment,
    totalInterest,
    monthlyPayment: 0,
  };
}

/* ------------------------------------------------------------------ */
/*                       Currency stress test                          */
/* ------------------------------------------------------------------ */

export interface StressBucket {
  currency: string;
  amount: number;
}

/** What % each currency makes of the total at current rates. */
export function currencyExposure(
  buckets: StressBucket[],
  rates: Record<string, number>,
  base = 'BYN'
): { currency: string; share: number; baseValue: number }[] {
  const baseRate = rates[base] || 1;
  const totals = buckets.map((b) => {
    const r = rates[b.currency] || 1;
    return { currency: b.currency, baseValue: (b.amount * r) / baseRate };
  });
  const total = totals.reduce((s, x) => s + x.baseValue, 0);
  return totals.map((t) => ({
    ...t,
    share: total ? t.baseValue / total : 0,
  }));
}

/** Apply a one-shot devaluation to base currency and recompute net worth. */
export function applyDevaluation(
  buckets: StressBucket[],
  rates: Record<string, number>,
  basePct: number,
  base = 'BYN'
): { before: number; after: number; deltaPct: number } {
  const baseRate = rates[base] || 1;
  const stressedRates: Record<string, number> = {};
  for (const [k, v] of Object.entries(rates)) {
    // Foreign currency rate goes UP relative to base when base devalues.
    stressedRates[k] = k === base ? v : v * (1 + basePct / 100);
  }
  const before = buckets.reduce(
    (s, b) => s + (b.amount * (rates[b.currency] || 1)) / baseRate,
    0
  );
  const after = buckets.reduce(
    (s, b) => s + (b.amount * (stressedRates[b.currency] || 1)) / baseRate,
    0
  );
  return {
    before,
    after,
    deltaPct: before ? ((after - before) / before) * 100 : 0,
  };
}

/* ------------------------------------------------------------------ */
/*                       Safety fund (подушка)                         */
/* ------------------------------------------------------------------ */

/** Required emergency fund = monthly avg expenses × months coverage. */
export function safetyFundTarget(
  monthlyExpenses: number,
  monthsCoverage: 3 | 6 | 12 = 6
): number {
  return Math.max(0, monthlyExpenses * monthsCoverage);
}

/* ------------------------------------------------------------------ */
/*                           FIRE / SWR                                */
/* ------------------------------------------------------------------ */

export interface FIREInput {
  annualExpenses: number;
  swrPct?: number; // Safe withdrawal rate, default 4%
}

export function fireNumber(input: FIREInput): number {
  const swr = (input.swrPct ?? 4) / 100;
  return swr === 0 ? Infinity : input.annualExpenses / swr;
}

export interface FIREProjectionInput {
  currentNet: number;
  monthlySaving: number;
  annualReturnPct: number;
  annualInflationPct?: number;
  targetNet: number;
  maxYears?: number;
}

export function yearsToFire(input: FIREProjectionInput): number {
  const {
    currentNet,
    monthlySaving,
    annualReturnPct,
    annualInflationPct = 0,
    targetNet,
    maxYears = 100,
  } = input;
  if (currentNet >= targetNet) return 0;
  const realMonthly = (annualReturnPct - annualInflationPct) / 100 / 12;
  let balance = currentNet;
  for (let m = 1; m <= maxYears * 12; m++) {
    balance = balance * (1 + realMonthly) + monthlySaving;
    if (balance >= targetNet) return Number((m / 12).toFixed(2));
  }
  return Infinity;
}
