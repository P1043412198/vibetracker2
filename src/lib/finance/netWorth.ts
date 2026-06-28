/// Trend analytics for a net-worth-over-time series, shared by the React and
/// Flutter finance views. Input is the month-end net worth values, oldest
/// first (assets − debts, already in the base currency).

export type NetWorthTrend = {
  current: number;
  previous: number | null;
  /** Net change from the first to the last point in the series. */
  change: number;
  /** Average change per month across the series. */
  monthlyRate: number;
  /** 'up' | 'down' | 'flat' — direction of [monthlyRate]. */
  direction: 'up' | 'down' | 'flat';
};

/** Values within this band (base currency) are treated as flat. */
const FLAT_EPSILON = 0.5;

export function computeNetWorthTrend(values: number[]): NetWorthTrend | null {
  if (values.length === 0) return null;
  const current = values[values.length - 1];
  const first = values[0];
  const previous = values.length > 1 ? values[values.length - 2] : null;
  const change = current - first;
  const spans = values.length - 1;
  const monthlyRate = spans > 0 ? change / spans : 0;
  const direction =
    monthlyRate > FLAT_EPSILON ? 'up' : monthlyRate < -FLAT_EPSILON ? 'down' : 'flat';
  return { current, previous, change, monthlyRate, direction };
}
