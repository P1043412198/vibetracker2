import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/finance.dart';
import '../../state/providers.dart';
import 'finance_shared.dart';

/// "Операции" tab — chronological list of transactions with quick filters
/// (account / period / type) and an FAB that opens the add-transaction sheet.
class TransactionsTab extends ConsumerStatefulWidget {
  const TransactionsTab({super.key});

  @override
  ConsumerState<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends ConsumerState<TransactionsTab> {
  String? _accountFilter;
  TransactionType? _typeFilter;
  String _periodFilter = 'month'; // 'month' | 'all'

  @override
  Widget build(BuildContext context) {
    final transactions = [...ref.watch(transactionsProvider)]
      ..sort((a, b) => b.date.compareTo(a.date));
    final accounts = ref.watch(accountsProvider);
    final monthKey = DateFormat('yyyy-MM').format(DateTime.now());

    final filtered = transactions.where((t) {
      if (_accountFilter != null &&
          t.accountId != _accountFilter &&
          t.toAccountId != _accountFilter) {
        return false;
      }
      if (_typeFilter != null && t.type != _typeFilter) return false;
      if (_periodFilter == 'month' && !t.date.startsWith(monthKey)) {
        return false;
      }
      return true;
    }).toList(growable: false);

    return Stack(
      children: [
        Column(
          children: [
            _FilterRow(
              accounts: accounts,
              accountFilter: _accountFilter,
              typeFilter: _typeFilter,
              periodFilter: _periodFilter,
              onAccount: (v) => setState(() => _accountFilter = v),
              onType: (v) => setState(() => _typeFilter = v),
              onPeriod: (v) => setState(() => _periodFilter = v),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const _Empty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _TransactionTile(
                          transaction: filtered[i],
                          accounts: accounts,
                        ),
                      ),
                    ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _openAddSheet(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Транзакция'),
          ),
        ),
      ],
    );
  }

  static Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => const _TransactionFormSheet(),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.accounts,
    required this.accountFilter,
    required this.typeFilter,
    required this.periodFilter,
    required this.onAccount,
    required this.onType,
    required this.onPeriod,
  });

  final List<Account> accounts;
  final String? accountFilter;
  final TransactionType? typeFilter;
  final String periodFilter;
  final ValueChanged<String?> onAccount;
  final ValueChanged<TransactionType?> onType;
  final ValueChanged<String> onPeriod;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          _Chip(
            label: periodFilter == 'month' ? 'Этот месяц' : 'Всё время',
            selected: true,
            onTap: () => onPeriod(periodFilter == 'month' ? 'all' : 'month'),
            icon: Icons.calendar_month,
          ),
          const SizedBox(width: 8),
          _Chip(
            label: typeFilter == TransactionType.income
                ? 'Доходы'
                : typeFilter == TransactionType.expense
                    ? 'Расходы'
                    : typeFilter == TransactionType.transfer
                        ? 'Переводы'
                        : 'Все типы',
            selected: typeFilter != null,
            onTap: () {
              const order = [
                null,
                TransactionType.expense,
                TransactionType.income,
                TransactionType.transfer,
              ];
              final idx = order.indexOf(typeFilter);
              onType(order[(idx + 1) % order.length]);
            },
            icon: Icons.swap_vert,
          ),
          const SizedBox(width: 8),
          _Chip(
            label: accountFilter == null
                ? 'Все счета'
                : accounts
                        .cast<Account?>()
                        .firstWhere(
                          (a) => a?.id == accountFilter,
                          orElse: () => null,
                        )
                        ?.name ??
                    'Все счета',
            selected: accountFilter != null,
            icon: Icons.account_balance_wallet,
            onTap: () async {
              final ids = <String?>[null, ...accounts.map((a) => a.id)];
              final names = ['Все счета', ...accounts.map((a) => a.name)];
              final picked = await showModalBottomSheet<String?>(
                context: context,
                builder: (sheetContext) => SafeArea(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: ids.length,
                    itemBuilder: (context, i) => ListTile(
                      title: Text(names[i]),
                      selected: ids[i] == accountFilter,
                      onTap: () =>
                          Navigator.of(sheetContext).pop(ids[i] ?? '__null__'),
                    ),
                  ),
                ),
              );
              if (picked != null) {
                onAccount(picked == '__null__' ? null : picked);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.12)
          : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({
    required this.transaction,
    required this.accounts,
  });

  final Transaction transaction;
  final List<Account> accounts;

  Account? _accountById(String? id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt =
        NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 2);
    final account = _accountById(transaction.accountId);
    final to = _accountById(transaction.toAccountId);
    final isIncome = transaction.type == TransactionType.income;
    final isTransfer = transaction.type == TransactionType.transfer;
    final color = isIncome
        ? const Color(0xFF22C55E)
        : isTransfer
            ? Theme.of(context).colorScheme.primary
            : const Color(0xFFEF4444);
    final currency = account?.currency ?? 'BYN';
    final accountLabel = isTransfer
        ? '${account?.name ?? '—'} → ${to?.name ?? '—'}'
        : account?.name ?? '';

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
                : isTransfer
                    ? Icons.swap_horiz
                    : Icons.remove,
            color: color,
          ),
        ),
        title: Text(
          isTransfer ? 'Перевод' : transaction.category,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            transaction.date,
            if (accountLabel.isNotEmpty) accountLabel,
            if (transaction.notes != null) transaction.notes!,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isIncome ? '+' : isTransfer ? '' : '-'} ${fmt.format(transaction.amount)} $currency',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            InkWell(
              onTap: () => ref
                  .read(transactionsProvider.notifier)
                  .remove(transaction.id),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💸', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Нет транзакций',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Сначала создай счёт во вкладке «Счета», затем добавляй транзакции.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionFormSheet extends ConsumerStatefulWidget {
  const _TransactionFormSheet();
  @override
  ConsumerState<_TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState
    extends ConsumerState<_TransactionFormSheet> {
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _notesController = TextEditingController();
  TransactionType _type = TransactionType.expense;
  DateTime _date = DateTime.now();
  String? _accountId;
  String? _toAccountId;

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    if (_accountId == null && accounts.isNotEmpty) {
      _accountId = accounts.first.id;
    }
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Новая транзакция',
                style: Theme.of(context).textTheme.titleLarge),
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
                ButtonSegment(
                  value: TransactionType.transfer,
                  icon: Icon(Icons.swap_horiz),
                  label: Text('Перевод'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Сумма'),
            ),
            const SizedBox(height: 12),
            if (accounts.isEmpty)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Сначала создай хотя бы один счёт во вкладке «Счета».',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              )
            else ...[
              DropdownButtonFormField<String>(
                value: _accountId,
                decoration: const InputDecoration(
                    labelText: 'Счёт списания / зачисления'),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.name} (${a.currency})'),
                    ),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
              if (_type == TransactionType.transfer) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _toAccountId,
                  decoration:
                      const InputDecoration(labelText: 'Счёт получатель'),
                  items: [
                    for (final a in accounts)
                      if (a.id != _accountId)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.name} (${a.currency})'),
                        ),
                  ],
                  onChanged: (v) => setState(() => _toAccountId = v),
                ),
              ],
            ],
            if (_type != TransactionType.transfer) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: 'Категория',
                  hintText: _type == TransactionType.income
                      ? 'Зарплата, подработка...'
                      : 'Еда, транспорт...',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final c in _type == TransactionType.income
                      ? kIncomeCategories
                      : kExpenseCategories)
                    ActionChip(
                      label: Text(c),
                      onPressed: () => _categoryController.text = c,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Заметка'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(DateFormat.yMd('ru').format(_date)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: accounts.isEmpty ? null : _save,
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) return;
    if (_type == TransactionType.transfer && _toAccountId == null) return;
    final tx = Transaction(
      id: const Uuid().v4(),
      type: _type,
      amount: amount,
      category: _type == TransactionType.transfer
          ? 'Перевод'
          : (_categoryController.text.trim().isEmpty
              ? 'Без категории'
              : _categoryController.text.trim()),
      date: DateFormat('yyyy-MM-dd').format(_date),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      accountId: _accountId,
      toAccountId: _type == TransactionType.transfer ? _toAccountId : null,
    );
    await ref.read(transactionsProvider.notifier).add(tx);
    if (mounted) Navigator.of(context).pop();
  }
}
