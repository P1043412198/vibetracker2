import React, { useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useStore } from '../store/useStore';
import { useCurrencyConverter } from '../hooks/useCurrencyConverter';
import { 
  AlertTriangle, Info, TrendingUp, TrendingDown, 
  Zap, ArrowRight, X, AlertCircle, Sparkles,
  Timer, Target, ShoppingCart
} from 'lucide-react';
import { 
  format, startOfMonth, endOfMonth, 
  isWithinInterval, parseISO, getDate, getDaysInMonth 
} from 'date-fns';
import { cn } from '../lib/utils';

export function SmartFinanceAlerts() {
  const { 
    transactions = [], 
    budgetLimits = [], 
    regularPayments = [],
    accounts = [],
    rates = {},
    baseCurrency = 'BYN'
  } = useStore();

  const convertCurrency = useCurrencyConverter();

  const now = new Date();
  const currentDay = getDate(now);
  const daysInMonth = getDaysInMonth(now);
  const daysLeft = daysInMonth - currentDay + 1;

  const alerts = useMemo(() => {
    const currentMonthStart = startOfMonth(now);
    const currentMonthEnd = endOfMonth(now);
    
    const currentMonthTx = transactions.filter(t => 
      t.type === 'expense' && 
      isWithinInterval(parseISO(t.date), { start: currentMonthStart, end: currentMonthEnd })
    );

    const generatedAlerts = [];

    // 1. Budget Overrun Prediction
    budgetLimits.forEach(limit => {
      const spent = currentMonthTx
        .filter(t => t.category === limit.category)
        .reduce((sum, t) => {
          const account = accounts.find(a => a.id === t.accountId);
          const currency = account?.currency || baseCurrency;
          return sum + convertCurrency(t.amount, currency, limit.currency || baseCurrency);
        }, 0);
      
      if (spent > 0) {
        const avgDailySpend = spent / currentDay;
        const projectedSpend = avgDailySpend * daysInMonth;
        
        if (projectedSpend > limit.amount && spent < limit.amount) {
          const daysUntilLimit = Math.floor((limit.amount - spent) / avgDailySpend);
          
          generatedAlerts.push({
            id: `budget-overrun-${limit.category}`,
            type: 'warning',
            icon: <AlertTriangle className="w-5 h-5 text-amber-500" />,
            title: `Лимит на "${limit.category}"`,
            message: `При текущем темпе трат лимит будет исчерпан через ${daysUntilLimit} дн.`,
            action: 'Пересмотреть план',
            color: 'amber'
          });
        } else if (spent >= limit.amount) {
          generatedAlerts.push({
            id: `budget-exceeded-${limit.category}`,
            type: 'critical',
            icon: <AlertCircle className="w-5 h-5 text-red-500" />,
            title: `Лимит превышен: ${limit.category}`,
            message: `Вы потратили на ${(spent - limit.amount).toFixed(0)} ${limit.currency || baseCurrency} больше плана.`,
            action: 'Анализировать',
            color: 'red'
          });
        }
      }
    });

    // 2. Unusual Spending Pattern (vs Average)
    // Simple logic: if spent in first half of month > 70% of budget
    if (currentDay < 15) {
      budgetLimits.forEach(limit => {
        const spent = currentMonthTx
          .filter(t => t.category === limit.category)
          .reduce((sum, t) => {
            const account = accounts.find(a => a.id === t.accountId);
            const currency = account?.currency || baseCurrency;
            return sum + convertCurrency(t.amount, currency, limit.currency || baseCurrency);
          }, 0);
        
        if (spent > limit.amount * 0.7) {
          generatedAlerts.push({
            id: `fast-spending-${limit.category}`,
            type: 'info',
            icon: <Zap className="w-5 h-5 text-blue-500" />,
            title: `Быстрые траты: ${limit.category}`,
            message: `Вы потратили 70% бюджета всего за ${currentDay} дней.`,
            action: 'Замедлиться',
            color: 'blue'
          });
        }
      });
    }

    // 3. Subscription Reminders
    const upcomingPayments = regularPayments
      .filter(p => p.isActive && p.dueDate > currentDay && p.dueDate <= currentDay + 3)
      .map(p => ({
        id: `payment-reminder-${p.id}`,
        type: 'reminder',
        icon: <Timer className="w-5 h-5 text-purple-500" />,
        title: `Скоро платеж: ${p.name}`,
        message: `Через ${p.dueDate - currentDay} дн. будет списано ${p.amount} ${p.currency || baseCurrency}.`,
        action: 'Проверить баланс',
        color: 'purple'
      }));
    
    generatedAlerts.push(...upcomingPayments);

    // 4. Savings Opportunity
    const totalIncome = transactions
      .filter(t => t.type === 'income' && isWithinInterval(parseISO(t.date), { start: currentMonthStart, end: currentMonthEnd }))
      .reduce((sum, t) => {
        const account = accounts.find(a => a.id === t.accountId);
        const currency = account?.currency || baseCurrency;
        return sum + convertCurrency(t.amount, currency, baseCurrency);
      }, 0);
    
    const totalExpense = currentMonthTx.reduce((sum, t) => {
      const account = accounts.find(a => a.id === t.accountId);
      const currency = account?.currency || baseCurrency;
      return sum + convertCurrency(t.amount, currency, baseCurrency);
    }, 0);
    const currentBalance = totalIncome - totalExpense;

    if (currentBalance > 1000 && currentDay > 20) {
      generatedAlerts.push({
        id: 'savings-opportunity',
        type: 'success',
        icon: <Sparkles className="w-5 h-5 text-emerald-500" />,
        title: 'Свободные средства',
        message: `У вас осталось ${currentBalance.toFixed(0)} ${baseCurrency}. Отложите часть в копилку?`,
        action: 'В копилку',
        color: 'emerald'
      });
    }

    return generatedAlerts;
  }, [transactions, budgetLimits, regularPayments, now, currentDay, daysInMonth]);

  if (alerts.length === 0) return null;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between px-1">
        <h3 className="text-sm font-bold text-zinc-900 flex items-center gap-2">
          <Zap className="w-4 h-4 text-amber-400" />
          Умные уведомления
        </h3>
        <span className="text-[10px] text-zinc-500 uppercase font-bold tracking-widest">
          {alerts.length} новых
        </span>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        <AnimatePresence>
          {alerts.map((alert) => (
            <motion.div
              key={alert.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className={cn(
                "p-4 rounded-2xl border flex items-start gap-4 relative group transition-all",
                alert.color === 'amber' ? "bg-amber-500/5 border-amber-500/20" :
                alert.color === 'red' ? "bg-red-500/5 border-red-500/20" :
                alert.color === 'blue' ? "bg-blue-500/5 border-blue-500/20" :
                alert.color === 'purple' ? "bg-purple-500/5 border-purple-500/20" :
                "bg-emerald-500/5 border-emerald-500/20"
              )}
            >
              <div className={cn(
                "p-2 rounded-xl shrink-0",
                alert.color === 'amber' ? "bg-amber-500/10" :
                alert.color === 'red' ? "bg-red-500/10" :
                alert.color === 'blue' ? "bg-blue-500/10" :
                alert.color === 'purple' ? "bg-purple-500/10" :
                "bg-emerald-500/10"
              )}>
                {alert.icon}
              </div>

              <div className="flex-1 min-w-0">
                <h4 className="text-sm font-bold text-zinc-900 truncate">{alert.title}</h4>
                <p className="text-xs text-zinc-500 mt-1 leading-relaxed">{alert.message}</p>
                
                <button className={cn(
                  "mt-3 text-[10px] font-black uppercase tracking-widest flex items-center gap-1 transition-all",
                  alert.color === 'amber' ? "text-amber-400 hover:text-amber-300" :
                  alert.color === 'red' ? "text-red-400 hover:text-red-300" :
                  alert.color === 'blue' ? "text-blue-400 hover:text-blue-300" :
                  alert.color === 'purple' ? "text-purple-400 hover:text-purple-300" :
                  "text-emerald-400 hover:text-emerald-300"
                )}>
                  {alert.action}
                  <ArrowRight className="w-3 h-3" />
                </button>
              </div>

              <button className="absolute top-4 right-4 text-zinc-600 hover:text-zinc-500 opacity-0 group-hover:opacity-100 transition-opacity">
                <X className="w-4 h-4" />
              </button>
            </motion.div>
          ))}
        </AnimatePresence>
      </div>
    </div>
  );
}
