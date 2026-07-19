import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/finance.dart';
import '../../models/misc.dart';
import '../../services/receipt_scanner.dart';
import '../../services/receipt_service.dart';
import '../../state/providers.dart';
import 'finance_shared.dart';
import 'recurring_review_card.dart';
import 'recurring_payments_page.dart';
import 'payment_reminders_card.dart';

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
  String? _tagFilter;

  @override
  Widget build(BuildContext context) {
    final transactions = [...ref.watch(transactionsProvider)]
      ..sort((a, b) => b.date.compareTo(a.date));
    final accounts = ref.watch(accountsProvider);
    final monthKey = DateFormat('yyyy-MM').format(DateTime.now());

    final allTags = <String>{};
    for (final t in transactions) {
      final tags = t.tags;
      if (tags != null) allTags.addAll(tags);
    }
    final sortedTags = allTags.toList()..sort();
    if (_tagFilter != null && !allTags.contains(_tagFilter)) {
      _tagFilter = null;
    }

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
      if (_tagFilter != null && !(t.tags?.contains(_tagFilter) ?? false)) {
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
              onManageRecurring: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const RecurringPaymentsPage()),
              ),
            ),
            if (sortedTags.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: FilterChip(
                        label: const Text('Все теги'),
                        selected: _tagFilter == null,
                        onSelected: (_) => setState(() => _tagFilter = null),
                      ),
                    ),
                    for (final tag in sortedTags)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 6),
                        child: FilterChip(
                          label: Text('#$tag'),
                          selected: _tagFilter == tag,
                          onSelected: (sel) => setState(
                              () => _tagFilter = sel ? tag : null),
                        ),
                      ),
                  ],
                ),
              ),
            const PaymentRemindersCard(),
            const RecurringReviewCard(),
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
    required this.onManageRecurring,
  });

  final List<Account> accounts;
  final String? accountFilter;
  final TransactionType? typeFilter;
  final String periodFilter;
  final ValueChanged<String?> onAccount;
  final ValueChanged<TransactionType?> onType;
  final ValueChanged<String> onPeriod;
  final VoidCallback onManageRecurring;

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
            label: 'Регулярные',
            selected: false,
            onTap: onManageRecurring,
            icon: Icons.event_repeat,
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

    final receiptCount = transaction.receiptPaths?.length ?? 0;
    return Card(
      child: ListTile(
        onTap: receiptCount > 0
            ? () => _openReceipts(context, transaction)
            : null,
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
        title: Row(
          children: [
            Expanded(
              child: Text(
                isTransfer
                    ? 'Перевод'
                    : (transaction.merchant?.isNotEmpty == true
                        ? transaction.merchant!
                        : transaction.category),
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (receiptCount > 0) ...[
              const SizedBox(width: 6),
              Icon(Icons.receipt_long_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary),
              if (receiptCount > 1)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text('×$receiptCount',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                      )),
                ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                transaction.date,
                if (transaction.merchant?.isNotEmpty == true && !isTransfer)
                  transaction.category,
                if (accountLabel.isNotEmpty) accountLabel,
                if (transaction.notes != null) transaction.notes!,
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (transaction.tags?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: [
                  for (final t in transaction.tags!)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '#$t',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
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

  Future<void> _openReceipts(BuildContext context, Transaction tx) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReceiptViewerSheet(transaction: tx),
    );
  }
}

class _ReceiptViewerSheet extends StatelessWidget {
  const _ReceiptViewerSheet({required this.transaction});
  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final paths = transaction.receiptPaths ?? const [];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scroll) {
        return SafeArea(
          top: false,
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              if (transaction.merchant?.isNotEmpty == true)
                Text(transaction.merchant!,
                    style: Theme.of(context).textTheme.titleLarge),
              Text(
                '${transaction.date} · ${transaction.category}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              for (final p in paths)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FutureBuilder<File>(
                      future: ReceiptService.instance.resolve(p),
                      builder: (context, snap) {
                        final f = snap.data;
                        if (f == null) {
                          return const SizedBox(
                            height: 120,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return Image.file(f, fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                      child: Icon(
                                          Icons.broken_image_outlined,
                                          size: 48)),
                                ));
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
  final _merchantController = TextEditingController();
  final _tagController = TextEditingController();
  TransactionType _type = TransactionType.expense;
  DateTime _date = DateTime.now();
  String? _accountId;
  String? _toAccountId;
  final List<String> _tags = [];
  final List<String> _receiptPaths = [];
  List<ReceiptLineItem> _scannedItems = const [];
  bool _scanning = false;

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    _merchantController.dispose();
    _tagController.dispose();
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
            if (_type != TransactionType.transfer) ...[
              const SizedBox(height: 12),
              _TagEditor(
                controller: _tagController,
                tags: _tags,
                suggestions: _allTags(),
                onAdd: _addTag,
                onRemove: (t) => setState(() => _tags.remove(t)),
              ),
            ],
            if (_type != TransactionType.transfer) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _merchantController,
                decoration: const InputDecoration(
                  labelText: 'Магазин / продавец',
                  hintText: 'Заполнится после сканирования чека',
                ),
              ),
              const SizedBox(height: 12),
              _ReceiptSection(
                paths: _receiptPaths,
                scanning: _scanning,
                onPick: _pickReceipt,
                onScan: _pickAndScanReceipt,
                onRemove: _removeReceiptAt,
              ),
              if (_scannedItems.isNotEmpty) ...[
                const SizedBox(height: 8),
                _ScannedItems(
                  items: _scannedItems,
                  onSavePrices: _savePricesFromScan,
                ),
              ],
            ],
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

  List<String> _allTags() {
    final set = <String>{};
    for (final t in ref.read(transactionsProvider)) {
      final tags = t.tags;
      if (tags != null) set.addAll(tags);
    }
    set.removeAll(_tags);
    final list = set.toList()..sort();
    return list.take(12).toList();
  }

  void _addTag(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return;
    if (!_tags.any((e) => e.toLowerCase() == t.toLowerCase())) {
      setState(() => _tags.add(t));
    }
    _tagController.clear();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) return;
    if (_type == TransactionType.transfer && _toAccountId == null) return;
    final merchant = _merchantController.text.trim();
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
      merchant: merchant.isEmpty ? null : merchant,
      tags: _tags.isEmpty ? null : List.of(_tags),
      receiptPaths: _receiptPaths.isEmpty ? null : List.of(_receiptPaths),
    );
    await ref.read(transactionsProvider.notifier).add(tx);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickReceipt() async {
    final source = await _askSource();
    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (picked == null) return;
    final stored = await ReceiptService.instance.persist(File(picked.path));
    if (!mounted) return;
    setState(() => _receiptPaths.add(stored));
  }

  Future<void> _pickAndScanReceipt() async {
    final source = await _askSource();
    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (picked == null) return;
    setState(() => _scanning = true);
    try {
      final stored = await ReceiptService.instance.persist(File(picked.path));
      final result = await ReceiptScanner.instance.scan(picked.path);
      if (!mounted) return;
      setState(() {
        _receiptPaths.add(stored);
        if (result.merchant != null && _merchantController.text.isEmpty) {
          _merchantController.text = result.merchant!;
        }
        if (result.total != null && _amountController.text.isEmpty) {
          _amountController.text = result.total!.toStringAsFixed(2);
        }
        if (result.dateIso != null) {
          final parsed = DateTime.tryParse(result.dateIso!);
          if (parsed != null) _date = parsed;
        }
        _scannedItems = result.items;
      });
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<ImageSource?> _askSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Камера'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Галерея'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  void _removeReceiptAt(int index) {
    final path = _receiptPaths[index];
    setState(() => _receiptPaths.removeAt(index));
    // Best-effort cleanup of the on-disk copy.
    ReceiptService.instance.remove(path);
  }

  Future<void> _savePricesFromScan() async {
    if (_scannedItems.isEmpty) return;
    final store = _merchantController.text.trim();
    final dateIso = DateFormat('yyyy-MM-dd').format(_date);
    final notifier = ref.read(priceHistoryProvider.notifier);
    for (final item in _scannedItems) {
      await notifier.add(PriceHistoryEntry(
        id: const Uuid().v4(),
        itemName: item.name,
        price: item.price,
        date: dateIso,
        store: store.isEmpty ? null : store,
      ));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Сохранено в историю цен: ${_scannedItems.length}')),
    );
    setState(() => _scannedItems = const []);
  }
}

class _ReceiptSection extends StatelessWidget {
  const _ReceiptSection({
    required this.paths,
    required this.scanning,
    required this.onPick,
    required this.onScan,
    required this.onRemove,
  });

  final List<String> paths;
  final bool scanning;
  final Future<void> Function() onPick;
  final Future<void> Function() onScan;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: scanning ? null : onPick,
                icon: const Icon(Icons.attach_file),
                label: const Text('Прикрепить'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: scanning ? null : onScan,
                icon: scanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.document_scanner_outlined),
                label: Text(scanning ? 'Распознаю…' : 'Сканировать'),
              ),
            ),
          ],
        ),
        if (paths.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: paths.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _ReceiptThumb(
                relativePath: paths[i],
                onRemove: () => onRemove(i),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReceiptThumb extends StatelessWidget {
  const _ReceiptThumb({required this.relativePath, required this.onRemove});

  final String relativePath;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: ReceiptService.instance.resolve(relativePath),
      builder: (context, snap) {
        final file = snap.data;
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 88,
                height: 88,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: file == null
                    ? const Center(child: CircularProgressIndicator())
                    : Image.file(file, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
                        return const Icon(Icons.broken_image_outlined);
                      }),
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScannedItems extends StatelessWidget {
  const _ScannedItems({required this.items, required this.onSavePrices});

  final List<ReceiptLineItem> items;
  final Future<void> Function() onSavePrices;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined, size: 18),
                const SizedBox(width: 8),
                Text('Распознано позиций: ${items.length}',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            ...items.take(6).map(
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(i.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(i.price.toStringAsFixed(2),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            if (items.length > 6)
              Text('и ещё ${items.length - 6}',
                  style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onSavePrices,
                icon: const Icon(Icons.price_change_outlined),
                label: const Text('В историю цен'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Free-form tag editor: a text field to add tags, chips for the current
/// selection (tap × to remove) and quick-add chips for previously used tags.
class _TagEditor extends StatelessWidget {
  const _TagEditor({
    required this.controller,
    required this.tags,
    required this.suggestions,
    required this.onAdd,
    required this.onRemove,
  });

  final TextEditingController controller;
  final List<String> tags;
  final List<String> suggestions;
  final void Function(String) onAdd;
  final void Function(String) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Теги',
            hintText: 'напр. отпуск, подарки',
            prefixIcon: const Icon(Icons.sell_outlined),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => onAdd(controller.text),
            ),
          ),
          onSubmitted: onAdd,
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final t in tags)
                InputChip(
                  label: Text(t),
                  onDeleted: () => onRemove(t),
                ),
            ],
          ),
        ],
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final s in suggestions)
                ActionChip(
                  label: Text(s),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onAdd(s),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
