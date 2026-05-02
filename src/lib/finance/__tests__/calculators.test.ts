import { describe, expect, it } from 'vitest';
import {
  buildLoanSchedule,
  compoundInterest,
  applyDevaluation,
  currencyExposure,
  fireNumber,
  safetyFundTarget,
  yearsToFire,
} from '../calculators';

describe('compoundInterest', () => {
  it('returns principal when years=0', () => {
    const r = compoundInterest({ principal: 1000, annualRatePct: 10, years: 0 });
    expect(r.finalBalance).toBeCloseTo(1000, 6);
    expect(r.totalContributed).toBeCloseTo(1000, 6);
    expect(r.totalInterest).toBeCloseTo(0, 6);
  });

  it('compounds annually with no contribution', () => {
    const r = compoundInterest({
      principal: 1000,
      annualRatePct: 10,
      years: 2,
      compoundingPerYear: 1,
    });
    expect(r.finalBalance).toBeCloseTo(1210, 2); // 1000 * 1.1^2
  });

  it('handles monthly contributions', () => {
    const r = compoundInterest({
      principal: 0,
      annualRatePct: 12,
      years: 1,
      monthlyContribution: 100,
    });
    // After ~12 deposits compounded, balance should clearly exceed contributions.
    expect(r.totalContributed).toBeCloseTo(1200, 1);
    expect(r.finalBalance).toBeGreaterThan(1260);
    expect(r.series).toHaveLength(12);
  });
});

describe('buildLoanSchedule', () => {
  it('annuity totals add up and balance reaches zero', () => {
    const r = buildLoanSchedule({
      amount: 10_000,
      annualRatePct: 12,
      termMonths: 12,
      type: 'annuity',
    });
    expect(r.schedule).toHaveLength(12);
    expect(r.schedule.at(-1)!.balance).toBeLessThan(0.01);
    const principalSum = r.schedule.reduce((s, x) => s + x.principal, 0);
    expect(principalSum).toBeCloseTo(10_000, 0);
    expect(r.totalInterest).toBeGreaterThan(0);
  });

  it('differential schedule: payment monotonically decreases', () => {
    const r = buildLoanSchedule({
      amount: 12_000,
      annualRatePct: 12,
      termMonths: 12,
      type: 'differential',
    });
    expect(r.schedule).toHaveLength(12);
    for (let i = 1; i < r.schedule.length; i++) {
      expect(r.schedule[i].payment).toBeLessThan(r.schedule[i - 1].payment);
    }
    expect(r.schedule.at(-1)!.balance).toBeLessThan(0.01);
  });

  it('zero-rate annuity equals straight-line repayment', () => {
    const r = buildLoanSchedule({
      amount: 1200,
      annualRatePct: 0,
      termMonths: 12,
      type: 'annuity',
    });
    expect(r.monthlyPayment).toBeCloseTo(100, 6);
    expect(r.totalInterest).toBeCloseTo(0, 6);
  });
});

describe('currencyExposure', () => {
  it('computes share per currency', () => {
    const exp = currencyExposure(
      [
        { currency: 'BYN', amount: 1000 },
        { currency: 'USD', amount: 100 },
      ],
      { BYN: 1, USD: 3 }
    );
    expect(exp).toHaveLength(2);
    const usd = exp.find((e) => e.currency === 'USD')!;
    expect(usd.baseValue).toBeCloseTo(300, 6);
    expect(usd.share).toBeCloseTo(300 / 1300, 6);
  });
});

describe('applyDevaluation', () => {
  it('hurts BYN holdings, helps foreign-currency holdings', () => {
    const buckets = [
      { currency: 'BYN', amount: 1000 },
      { currency: 'USD', amount: 100 },
    ];
    const rates = { BYN: 1, USD: 3 };
    const r = applyDevaluation(buckets, rates, 30);
    // Foreign value goes up, so net worth in base goes up too.
    expect(r.deltaPct).toBeGreaterThan(0);
    expect(r.before).toBeCloseTo(1300, 6);
  });
});

describe('safetyFundTarget', () => {
  it('multiplies expenses by months', () => {
    expect(safetyFundTarget(1500, 6)).toBe(9000);
  });
});

describe('FIRE', () => {
  it('fireNumber = annualExpenses / SWR', () => {
    expect(fireNumber({ annualExpenses: 24000, swrPct: 4 })).toBe(600_000);
  });
  it('returns 0 when already at target', () => {
    expect(yearsToFire({
      currentNet: 1_000_000,
      targetNet: 600_000,
      monthlySaving: 0,
      annualReturnPct: 4,
    })).toBe(0);
  });
});
