import { describe, it, expect } from 'vitest';
import { computeNetWorthTrend } from '../netWorth';

describe('computeNetWorthTrend', () => {
  it('returns null for an empty series', () => {
    expect(computeNetWorthTrend([])).toBeNull();
  });

  it('flat trend for a single point', () => {
    const t = computeNetWorthTrend([1000])!;
    expect(t.current).toBe(1000);
    expect(t.previous).toBeNull();
    expect(t.change).toBe(0);
    expect(t.monthlyRate).toBe(0);
    expect(t.direction).toBe('flat');
  });

  it('detects an upward trend with averaged monthly rate', () => {
    const t = computeNetWorthTrend([100, 200, 400])!;
    expect(t.current).toBe(400);
    expect(t.previous).toBe(200);
    expect(t.change).toBe(300);
    expect(t.monthlyRate).toBe(150);
    expect(t.direction).toBe('up');
  });

  it('detects a downward trend', () => {
    const t = computeNetWorthTrend([500, 300, 100])!;
    expect(t.change).toBe(-400);
    expect(t.monthlyRate).toBe(-200);
    expect(t.direction).toBe('down');
  });

  it('treats sub-epsilon drift as flat', () => {
    const t = computeNetWorthTrend([1000, 1000.2])!;
    expect(t.direction).toBe('flat');
  });
});
