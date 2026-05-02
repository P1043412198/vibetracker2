import { describe, expect, it } from 'vitest';
import {
  calcDepositBY,
  calcIpUsn,
  calcNetSalary,
  calcNpd,
  calcVacationPay,
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
