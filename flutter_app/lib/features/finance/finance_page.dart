import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/finance.dart';
import '../../state/providers.dart';
import '../../state/settings_state.dart';

/// Counterpart of `src/pages/Finance.tsx`. The React page is 2700+ lines and
/// has tabs for accounts, transactions, charts, plan/fact comparison, AI etc.
/// This first Flutter pass keeps just the transactions feed + add flow —
/// the rest is on the migration roadmap.
class FinancePage extends ConsumerWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = [...ref.watch(transactionsProvider)]
      ..sort((a, b) => b.date.compareTo(a.date));
    final currency = ref.watch(defaultCurrencyProvider);

    final monthKey = DateFormat('yyyy-MM').format(DateTime.now());
    final monthTx =
        transactions.where((t) => t.date.startsWith(monthKey)).toList();
    final income = monthTx
        .where((t) => t.type == TransactionType.income)
        .fold<num>(0, (sum, t) => sum + t.amount);
    final expense = monthTx
        .where((t) => t.type == TransactionType.expense)
        .fold<num>(0, (sum, t) => sum + t.amount);

    return Scaffold(
      appBar: AppBar(title: const Text('Финансы')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _SummaryRow(income: income, expense: expense, currency: currency),
          const SizedBox(height: 16),
          if (transactions.isEmpty)
            const _EmptyFinance()
          else
            ...transactions.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TransactionTile(transaction: t, currency: currency),
                )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addTransaction(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Транзакция'),
      ),
    );
  }

  Future<void> _addTransaction(BuildContext context, WidgetRef ref) async {
    final amountController = TextEditingController();
    final categoryController = TextEditingController();
    final notesController = TextEditingController();
    var type = TransactionType.expense;
    DateTime date = DateTime.now();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (innerContext, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(innerContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Новая транзакция',
                      style:
                          Theme.of(innerContext).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(
                        value: TransactionType.expense,
                        icon: Icon(Icons.trending_down),
                        label: Text('Расход'),
                      ),
                      ButtonSegment(
                        value: TransactionType.income,
                        icon: Icon(Icons.trending_up),
                        label: Text('Доход'),
                      ),
                    ],
                    selected: {type},
                    onSelectionChanged: (s) =>
                        setState(() => type = s.first),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Сумма'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                        labelText: 'Категория',
                        hintText: 'Еда, Транспорт, Зарплата...'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Заметка'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(DateFormat.yMd('ru').format(date)),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: innerContext,
                              initialDate: date,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => date = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      final amount =
                          double.tryParse(amountController.text.trim()) ?? 0;
                      if (amount <= 0) return;
                      final tx = Transaction(
                        id: const Uuid().v4(),
                        type: type,
                        amount: amount,
                        category: categoryController.text.trim().isEmpty
                            ? 'Без категории'
                            : categoryController.text.trim(),
                        date: DateFormat('yyyy-MM-dd').format(date),
                        notes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                      );
                      await ref
                          .read(transactionsProvider.notifier)
                          .add(tx);
                      if (innerContext.mounted) {
                        Navigator.of(innerContext).pop();
                      }
                    },
                    child: const Text('Сохранить'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.income,
    required this.expense,
    required this.currency,
  });

  final num income;
  final num expense;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final fmt =
        NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 2);
    final balance = income - expense;
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Доход',
            value: '+ ${fmt.format(income)} $currency',
            color: const Color(0xFF22C55E),
            icon: Icons.trending_up,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: 'Расход',
            value: '- ${fmt.format(expense)} $currency',
            color: const Color(0xFFEF4444),
            icon: Icons.trending_down,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: 'Баланс',
            value:
                '${balance >= 0 ? '+' : '-'} ${fmt.format(balance.abs())} $currency',
            color: Theme.of(context).colorScheme.primary,
            icon: Icons.account_balance_wallet,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({
    required this.transaction,
    required this.currency,
  });

  final Transaction transaction;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt =
        NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 2);
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome
        ? const Color(0xFF22C55E)
        : transaction.type == TransactionType.expense
            ? const Color(0xFFEF4444)
            : Theme.of(context).colorScheme.primary;
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isIncome
                ? Icons.add
                : transaction.type == TransactionType.transfer
                    ? Icons.swap_horiz
                    : Icons.remove,
            color: color,
          ),
        ),
        title: Text(transaction.category),
        subtitle: Text(
          [
            transaction.date,
            if (transaction.notes != null) transaction.notes!
          ].join(' · '),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isIncome ? '+' : '-'} ${fmt.format(transaction.amount)} $currency',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => ref
                  .read(transactionsProvider.notifier)
                  .remove(transaction.id),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.delete_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class _EmptyFinance extends StatelessWidget {
  const _EmptyFinance();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Text('💸', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Пока нет транзакций',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Добавь первую транзакцию, чтобы отслеживать бюджет.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
