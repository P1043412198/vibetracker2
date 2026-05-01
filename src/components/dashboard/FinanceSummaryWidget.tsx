import React, { useState } from 'react';
import { Zap, QrCode } from 'lucide-react';
import { Link } from 'react-router-dom';
import { motion } from 'motion/react';
import { cn } from '../../lib/utils';
import { ReceiptScanner } from '../ReceiptScanner';

interface FinanceSummaryWidgetProps {
  financeStats: {
    totalBalance: number;
    monthExpenses: number;
    budgetProgress: number;
    budgetTotal: number;
  };
}

export const FinanceSummaryWidget: React.FC<FinanceSummaryWidgetProps> = ({ financeStats }) => {
  const [isScannerOpen, setIsScannerOpen] = useState(false);

  return (
    <div className="bg-zinc-900 p-4 rounded-3xl shadow-sm border border-zinc-800">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-sm font-semibold text-white flex items-center gap-2">
          <Zap className="w-4 h-4 text-emerald-500" />
          Финансы
        </h2>
        <div className="flex items-center gap-2">
          <button 
            onClick={() => setIsScannerOpen(true)}
            className="p-1.5 bg-zinc-800 hover:bg-zinc-700 rounded-lg text-zinc-400 hover:text-white transition-colors"
            title="Сканировать чек"
          >
            <QrCode className="w-4 h-4" />
          </button>
          <Link to="/finance" className="text-[10px] text-zinc-500 hover:text-white transition-colors">Подробнее</Link>
        </div>
      </div>
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-zinc-950 p-3 rounded-2xl border border-zinc-800">
          <p className="text-[8px] text-zinc-500 uppercase tracking-wider mb-1">Баланс</p>
          <p className="text-sm font-bold text-white">{financeStats.totalBalance.toLocaleString()} <span className="text-[10px] font-normal text-zinc-500">BYN</span></p>
        </div>
        <div className="bg-zinc-950 p-3 rounded-2xl border border-zinc-800">
          <p className="text-[8px] text-zinc-500 uppercase tracking-wider mb-1">Расход (мес)</p>
          <p className="text-sm font-bold text-rose-400">-{financeStats.monthExpenses.toLocaleString()} <span className="text-[10px] font-normal text-zinc-500">BYN</span></p>
        </div>
      </div>
      {financeStats.budgetTotal > 0 && (
        <div className="mt-4">
          <div className="flex items-center justify-between mb-1.5">
            <p className="text-[8px] text-zinc-500 uppercase tracking-wider">Бюджет</p>
            <p className="text-[9px] font-bold text-white">{Math.round(financeStats.budgetProgress)}%</p>
          </div>
          <div className="w-full bg-zinc-950 h-1.5 rounded-full overflow-hidden border border-zinc-800">
            <motion.div 
              initial={{ width: 0 }}
              animate={{ width: `${Math.min(financeStats.budgetProgress, 100)}%` }}
              className={cn(
                "h-full rounded-full",
                financeStats.budgetProgress > 90 ? "bg-rose-500" : financeStats.budgetProgress > 70 ? "bg-amber-500" : "bg-emerald-500"
              )}
            />
          </div>
        </div>
      )}

      {isScannerOpen && (
        <ReceiptScanner onClose={() => setIsScannerOpen(false)} />
      )}
    </div>
  );
};
