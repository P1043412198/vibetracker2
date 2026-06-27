import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/finance.dart';
import '../../state/currency_state.dart';
import '../../state/providers.dart';
import '../../services/recurring.dart';

const _freqLabel = {
  RecurringFrequency.weekly: 'еженедельно',
  RecurringFrequency.biweekly: 'раз в 2 недели',
  RecurringFrequency.monthly: 'ежемесячно',
  RecurringFrequency.yearly: 'ежегодно',
};

String _todayIso() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

/// Posts the due occurrence of [rule] for [periodKey] to [accountId] unless it
/// was already posted. Mirrors React `confirmRecurring`.
void confirmRecurring(
  WidgetRef ref,
  RegularPayment rule,
  String periodKey,
  String? accountId,
) {
  final transactions = ref.read(transactionsProvider);
  final ruleRef = refFor(rule.id, periodKey);
  if (transactions.any((t) => t.recurringRef == ruleRef)) return;

  final accounts = ref.read(accountsProvider);
  if (accounts.isEmpty) return;
  final target = accounts.firstWhere(
    (a) => a.id == (accountId ?? rule.accountId),
    orElse: () => accounts.first,
  );

  final rates = ref.read(currencyRatesProvider);
  final ruleCurrency = rule.currency ?? target.currency;
  final amount = convertCurrency(
    amount: rule.amount,
    from: ruleCurrency,
    to: target.currency,
    rates: rates,
  );

  final occ = lastDueOccurrence(rule, _todayIso());
  final date = occ?.periodKey == periodKey ? occ!.dateISO : _todayIso();

  ref.read(transactionsProvider.notifier).add(Transaction(
        id: const Uuid().v4(),
        type: rule.type == TransactionType.income
            ? TransactionType.income
            : TransactionType.expense,
        amount: amount,
        category: rule.category,
        date: date,
        notes: 'Регулярно: ${rule.name}',
        accountId: target.id,
        recurringRef: ruleRef,
      ));
}

/// Posts every due occurrence of rules flagged [autoConfirm] without user
/// interaction. Mirrors React `checkRegularPayments`; safe to call repeatedly
/// (the recurringRef guard prevents double-posting).
void processAutoRecurring(WidgetRef ref) {
  final rules = ref.read(regularPaymentsProvider);
  final transactions = ref.read(transactionsProvider);
  final skips = ref.read(recurringSkipsProvider);
  final auto = rules.where((r) => r.autoConfirm).toList(growable: false);
  if (auto.isEmpty) return;
  final due = getDueRecurring(auto, transactions, skips, _todayIso());
  for (final d in due) {
    confirmRecurring(ref, d.rule, d.periodKey, d.rule.accountId);
  }
}

void skipRecurring(WidgetRef ref, String ruleId, String periodKey) {
  final existing = ref.read(recurringSkipsProvider);
  if (existing.any((s) => s.ruleId == ruleId && s.periodKey == periodKey)) {
    return;
  }
  ref
      .read(recurringSkipsProvider.notifier)
      .add(RecurringSkip(ruleId: ruleId, periodKey: periodKey));
}

/// Surfaces recurring rules whose latest occurrence is due and awaiting the
/// user's confirmation. Renders nothing when the queue is empty.
class RecurringReviewCard extends ConsumerWidget {
  const RecurringReviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(regularPaymentsProvider);
    final transactions = ref.watch(transactionsProvider);
    final skips = ref.watch(recurringSkipsProvider);
    final accounts = ref.watch(accountsProvider);

    final due = getDueRecurring(rules, transactions, skips, _todayIso());
    if (due.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      color: scheme.tertiaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_repeat, size: 20, color: scheme.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Подтвердите регулярные операции',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                CircleAvatar(
                  radius: 12,
                  backgroundColor: scheme.tertiary,
                  child: Text('${due.length}',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onTertiary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final d in due)
              _DueRow(due: d, accounts: accounts),
          ],
        ),
      ),
    );
  }
}

class _DueRow extends ConsumerWidget {
  const _DueRow({required this.due, required this.accounts});
  final DueRecurring due;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rule = due.rule;
    final isIncome = rule.type == TransactionType.income;
    final scheme = Theme.of(context).colorScheme;
    final cur = rule.currency ?? (accounts.isNotEmpty ? accounts.first.currency : 'BYN');
    final sign = isIncome ? '+' : '−';

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isIncome ? Icons.south_west : Icons.north_east,
                size: 18,
                color: isIncome ? Colors.green : Colors.redAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rule.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '${due.dateISO} · ${_freqLabel[rule.frequency]} · ${rule.category}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                '$sign${rule.amount.toStringAsFixed(2)} $cur',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isIncome ? Colors.green : scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () =>
                    skipRecurring(ref, rule.id, due.periodKey),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Пропустить'),
                style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => confirmRecurring(
                    ref, rule, due.periodKey, rule.accountId),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Подтвердить'),
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
