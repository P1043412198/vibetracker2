import { describe, expect, it } from 'vitest';
import {
  BASE_VALUE_BYN,
  BY_TAX_BY_YEAR,
  CURRENT_TAX_YEAR,
  calcDepositBY,
  calcIpUsn,
  calcNetSalary,
  calcNpd,
  calcVacationPay,
  getByTaxConstants,
  grossFromNet,
  INCOME_TAX_PCT,
} from '../byTax';

describe('calcNetSalary', () => {
  it('computes net for a typical 2000 BYN salary', () => {
    const r = calcNetSalary({ gross: 2000 });
    // Above standard-deduction threshold → no deduction.
    expect(r.deductions).toBe(0);
    expect(r.fszn).toBeCloseTo(20, 2);
    expect(r.incomeTax).toBeCloseTo(2000 * 0.13, 2);
    expect(r.net).toBeCloseTo(2000 - r.incomeTax - r.fszn, 2);
  });

  it('applies standard deduction below the income limit', () => {
    const r = calcNetSalary({ gross: 1000 });
    expect(r.deductions).toBeGreaterThan(0);
    // Tax base is reduced by the deduction.
    expect(r.taxableBase).toBeLessThan(1000);
  });

  it('child deductions reduce taxable base', () => {
    const noKids = calcNetSalary({ gross: 3000 });
    const withKids = calcNetSalary({ gross: 3000, children: 2 });
    expect(withKids.taxableBase).toBeLessThan(noKids.taxableBase);
    expect(withKids.net).toBeGreaterThan(noKids.net);
  });

  it('grossFromNet round-trips approximately', () => {
    const target = 1500;
    const gross = grossFromNet(target);
    const back = calcNetSalary({ gross }).net;
    expect(back).toBeCloseTo(target, 0);
  });

  it('income tax matches 13% statutory rate', () => {
    expect(INCOME_TAX_PCT).toBe(13);
  });

  it('post-tax extra (профсоюз 1%) reduces net but not income tax', () => {
    const base = calcNetSalary({ gross: 2000 });
    const r = calcNetSalary({
      gross: 2000,
      extraDeductions: [
        { id: 'union', label: 'Профсоюз', kind: 'percent', value: 1 },
      ],
    });
    expect(r.incomeTax).toBeCloseTo(base.incomeTax, 2);
    expect(r.postTaxDeductions).toBeCloseTo(20, 2);
    expect(r.net).toBeCloseTo(base.net - 20, 2);
    expect(r.extraDeductionsApplied).toHaveLength(1);
    expect(r.extraDeductionsApplied[0].amount).toBeCloseTo(20, 2);
  });

  it('pre-tax extra reduces taxable base and net', () => {
    const r = calcNetSalary({
      gross: 3000,
      extraDeductions: [
        { id: 'dms', label: 'ДМС', kind: 'fixed', value: 100, taxable: true },
      ],
    });
    expect(r.taxableBase).toBeCloseTo(2900, 2);
    expect(r.incomeTax).toBeCloseTo(2900 * 0.13, 2);
    expect(r.pretaxDeductions).toBe(100);
  });

  it('mixed pre-tax and post-tax extras both reduce net', () => {
    const r = calcNetSalary({
      gross: 3000,
      extraDeductions: [
        { id: 'union', label: 'Профсоюз', kind: 'percent', value: 1 },
        { id: 'dms', label: 'ДМС', kind: 'fixed', value: 50, taxable: true },
      ],
    });
    expect(r.postTaxDeductions).toBeCloseTo(30, 2);
    expect(r.pretaxDeductions).toBe(50);
    // Tax base = 3000 - 50 = 2950
    expect(r.taxableBase).toBeCloseTo(2950, 2);
    // Net = 3000 - 13%*2950 - 1%*3000 - 50 - 30
    expect(r.net).toBeCloseTo(3000 - 2950 * 0.13 - 30 - 50 - 30, 2);
  });
});

describe('calcDepositBY', () => {
  it('applies 13% tax on interest by default', () => {
    const r = calcDepositBY({
      amount: 10000,
      annualRatePct: 12,
      termMonths: 12,
    });
    expect(r.totalInterestGross).toBeGreaterThan(0);
    expect(r.totalTax).toBeCloseTo(r.totalInterestGross * 0.13, 5);
    expect(r.totalInterestNet).toBeCloseTo(
      r.totalInterestGross - r.totalTax,
      5
    );
  });

  it('zero tax when taxApplies=false', () => {
    const r = calcDepositBY({
      amount: 10000,
      annualRatePct: 12,
      termMonths: 24,
      taxApplies: false,
    });
    expect(r.totalTax).toBe(0);
    expect(r.totalInterestNet).toBe(r.totalInterestGross);
  });
});

describe('calcIpUsn', () => {
  it('5% of revenue + ФСЗН × 12 ', () => {
    const r = calcIpUsn({
      annualRevenue: 50_000,
      ratePct: 5,
      fsznMonthly: 200,
    });
    expect(r.usnTax).toBe(2500);
    expect(r.fsznTotal).toBe(2400);
    expect(r.totalLoad).toBe(4900);
    expect(r.net).toBe(45_100);
    expect(r.effectivePct).toBeCloseTo(9.8, 1);
  });
});

describe('calcNpd', () => {
  it('uses 10% below threshold and 20% above', () => {
    const r = calcNpd({ annualRevenue: 80_000 });
    expect(r.taxLow).toBe(60_000 * 0.1);
    expect(r.taxHigh).toBe(20_000 * 0.2);
    expect(r.total).toBe(10_000);
    expect(r.net).toBe(70_000);
  });

  it('only 10% when fully below threshold', () => {
    const r = calcNpd({ annualRevenue: 30_000 });
    expect(r.taxHigh).toBe(0);
    expect(r.total).toBe(3_000);
  });
});

describe('calcVacationPay', () => {
  it('14 days off ≈ avgDaily × 14', () => {
    const r = calcVacationPay(36000, 14);
    expect(r.avgDaily).toBeCloseTo(36000 / (12 * 29.7), 2);
    expect(r.payment).toBeCloseTo(r.avgDaily * 14, 2);
  });
});

describe('getByTaxConstants (year-keyed table)', () => {
  it('returns exact constants for a year present in the table', () => {
    expect(getByTaxConstants(2024)).toBe(BY_TAX_BY_YEAR[2024]);
  });

  it('legacy exports reflect the current tax year', () => {
    expect(BASE_VALUE_BYN).toBe(BY_TAX_BY_YEAR[CURRENT_TAX_YEAR].baseValueByn);
  });

  it('falls back to the latest available year for a future, not-yet-filled year', () => {
    const latest = Math.max(...Object.keys(BY_TAX_BY_YEAR).map(Number));
    expect(getByTaxConstants(2099)).toBe(BY_TAX_BY_YEAR[latest]);
  });

  it('falls back to the earliest year for a year below the table', () => {
    const earliest = Math.min(...Object.keys(BY_TAX_BY_YEAR).map(Number));
    expect(getByTaxConstants(1990)).toBe(BY_TAX_BY_YEAR[earliest]);
  });
});
