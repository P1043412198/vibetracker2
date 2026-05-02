/**
 * Visualises a single habit's streak history as a horizontal stack of chips:
 *   ✓ ✓ ✓ ✓ ✓ ✗ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓
 * with the current and best streak called out above. Designed to slot into
 * the per-habit history block.
 */
import React from 'react';
import { Flame, Award } from 'lucide-react';
import { cn } from '../../lib/utils';

export interface StreakDay {
  iso: string;
  status: 'done' | 'failed' | 'skipped' | 'none';
}

interface Props {
  days: StreakDay[];
  current: number;
  best: number;
}

export function StreakChains({ days, current, best }: Props) {
  return (
    <div className="space-y-2">
      <div className="flex items-center gap-3 text-[11px]">
        <span className="inline-flex items-center gap-1 text-orange-600">
          <Flame className="w-3.5 h-3.5" />
          Текущая серия: <strong>{current}</strong>
        </span>
        <span className="inline-flex items-center gap-1 text-emerald-700">
          <Award className="w-3.5 h-3.5" />
          Рекорд: <strong>{best}</strong>
        </span>
      </div>
      <div className="flex flex-wrap gap-[3px]">
        {days.map((d) => (
          <div
            key={d.iso}
            title={`${d.iso} — ${d.status}`}
            className={cn(
              'w-2 h-4 rounded-[2px]',
              d.status === 'done' && 'bg-emerald-500',
              d.status === 'failed' && 'bg-rose-500',
              d.status === 'skipped' && 'bg-amber-400',
              d.status === 'none' && 'bg-stone-200'
            )}
          />
        ))}
      </div>
    </div>
  );
}
