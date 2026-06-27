import { useEffect, useMemo, useRef } from 'react';
import { useStore } from '../store/useStore';
import { useCurrencyConverter } from '../hooks/useCurrencyConverter';
import { getUpcomingReminders, type Reminder } from '../lib/finance/reminders';
import { BellRing, Check, CalendarClock, Landmark } from 'lucide-react';

const REMINDER_WINDOW_DAYS = 7;
/** Notify when an item comes due within this many days. */
const NOTIFY_LEAD_DAYS = 3;

function dueLabel(daysUntil: number): string {
  if (daysUntil <= 0) return 'сегодня';
  if (daysUntil === 1) return 'завтра';
  return `через ${daysUntil} дн.`;
}

/**
 * Computes upcoming payment reminders (recurring bills + loan instalments)
 * the user hasn't acknowledged. Shared by the card and the dashboard badge.
 */
export function useUpcomingReminders(): Reminder[] {
  const regularPayments = useStore((s) => s.regularPayments);
  const loans = useStore((s) => s.loans);
  const acked = useStore((s) => s.paymentRemindersAcked);

  return useMemo(() => {
    const todayISO = new Date().toISOString().split('T')[0];
    const ackedSet = new Set(acked || []);
    return getUpcomingReminders(regularPayments || [], loans || [], todayISO, REMINDER_WINDOW_DAYS)
      .filter((r) => !ackedSet.has(r.id));
  }, [regularPayments, loans, acked]);
}

/** Fires a one-time browser notification per due reminder while the app is open. */
function useReminderNotifications(reminders: Reminder[]) {
  const notifyEnabled = useStore((s) => s.notificationSettings?.payments ?? true);
  const firedRef = useRef<Set<string>>(new Set());

  useEffect(() => {
    if (!notifyEnabled) return;
    if (typeof Notification === 'undefined') return;

    const due = reminders.filter((r) => r.daysUntil <= NOTIFY_LEAD_DAYS);
    if (due.length === 0) return;

    const show = () => {
      for (const r of due) {
        if (firedRef.current.has(r.id)) continue;
        firedRef.current.add(r.id);
        try {
          new Notification('Скоро оплата', {
            body: `${r.name} — ${r.amount.toFixed(2)} ${r.currency} ${dueLabel(r.daysUntil)}`,
            tag: r.id,
          });
        } catch {
          // Some browsers throw if constructed outside a SW context — ignore.
        }
      }
    };

    if (Notification.permission === 'granted') {
      show();
    } else if (Notification.permission === 'default') {
      Notification.requestPermission().then((p) => {
        if (p === 'granted') show();
      });
    }
  }, [reminders, notifyEnabled]);
}

/** Card listing upcoming bills/loan payments with one-tap acknowledge. */
export function PaymentRemindersCard() {
  const reminders = useUpcomingReminders();
  const ackPaymentReminder = useStore((s) => s.ackPaymentReminder);
  const baseCurrency = useStore((s) => s.baseCurrency) || 'BYN';
  const convertCurrency = useCurrencyConverter();

  useReminderNotifications(reminders);

  if (reminders.length === 0) return null;

  return (
    <div className="bg-sky-500/10 border border-sky-500/30 rounded-2xl p-4 space-y-3">
      <div className="flex items-center gap-2">
        <BellRing className="w-5 h-5 text-sky-500" />
        <h3 className="font-bold text-zinc-900">
          Скоро оплата
          <span className="ml-2 text-xs font-semibold text-sky-600">{reminders.length}</span>
        </h3>
      </div>

      <div className="space-y-2">
        {reminders.map((r) => {
          const inBase = convertCurrency(r.amount, r.currency, baseCurrency);
          return (
            <div
              key={r.id}
              className="bg-white rounded-xl border border-stone-200 p-3 flex items-center justify-between gap-3"
            >
              <div className="flex items-center gap-3 min-w-0">
                {r.kind === 'loan' ? (
                  <Landmark className="w-5 h-5 text-sky-500 shrink-0" />
                ) : (
                  <CalendarClock className="w-5 h-5 text-sky-500 shrink-0" />
                )}
                <div className="min-w-0">
                  <p className="font-medium text-zinc-900 truncate">{r.name}</p>
                  <p className="text-xs text-zinc-500">
                    {dueLabel(r.daysUntil)} · {r.dueISO}
                    {r.kind === 'loan' ? ' · кредит' : ''}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-2 shrink-0">
                <span className="font-bold text-zinc-900 whitespace-nowrap">
                  {r.amount.toFixed(2)} {r.currency}
                </span>
                {r.currency !== baseCurrency && (
                  <span className="text-[11px] text-zinc-400 whitespace-nowrap">≈ {inBase.toFixed(2)} {baseCurrency}</span>
                )}
                <button
                  onClick={() => ackPaymentReminder(r.id)}
                  className="flex items-center gap-1 text-xs font-medium bg-sky-600 text-white px-3 py-1.5 rounded-lg hover:bg-sky-700"
                  title="Понятно — не напоминать"
                >
                  <Check className="w-3.5 h-3.5" /> Понятно
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
