import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/payment_reminders.dart';
import '../../state/providers.dart';

const _reminderWindowDays = 7;

String _todayIso() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

/// Upcoming, not-yet-acknowledged payment reminders (bills + loans).
final upcomingRemindersProvider = Provider<List<PaymentReminder>>((ref) {
  final rules = ref.watch(regularPaymentsProvider);
  final loans = ref.watch(loansProvider);
  final acked = ref.watch(paymentRemindersAckProvider).toSet();
  return getUpcomingReminders(rules, loans, _todayIso(),
          windowDays: _reminderWindowDays)
      .where((r) => !acked.contains(r.id))
      .toList(growable: false);
});

String _dueLabel(int daysUntil) {
  if (daysUntil <= 0) return 'сегодня';
  if (daysUntil == 1) return 'завтра';
  return 'через $daysUntil дн.';
}

/// Card listing upcoming bill/loan payments with one-tap acknowledge.
class PaymentRemindersCard extends ConsumerWidget {
  const PaymentRemindersCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(upcomingRemindersProvider);
    if (reminders.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      color: Colors.lightBlue.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active,
                    size: 20, color: Colors.lightBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Скоро оплата',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.lightBlue,
                  child: Text('${reminders.length}',
                      style: const TextStyle(fontSize: 12, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final r in reminders)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      r.kind == ReminderKind.loan
                          ? Icons.account_balance
                          : Icons.event_repeat,
                      size: 18,
                      color: Colors.lightBlue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            '${_dueLabel(r.daysUntil)} · ${r.dueISO}'
                            '${r.kind == ReminderKind.loan ? ' · кредит' : ''}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text('${r.amount.toStringAsFixed(2)} ${r.currency}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Понятно',
                      icon: Icon(Icons.check_circle, color: scheme.primary),
                      onPressed: () => ref
                          .read(paymentRemindersAckProvider.notifier)
                          .ack(r.id),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
